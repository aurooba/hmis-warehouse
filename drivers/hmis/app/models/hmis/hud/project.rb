###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class Hmis::Hud::Project < Hmis::Hud::Base
  include ::HmisStructure::Project
  include ::Hmis::Hud::Concerns::Shared
  include ActiveModel::Dirty

  self.table_name = :Project
  self.sequence_name = "public.\"#{table_name}_id_seq\""

  belongs_to :data_source, class_name: 'GrdaWarehouse::DataSource'
  belongs_to :organization, **hmis_relation(:OrganizationID, 'Organization')
  belongs_to :user, **hmis_relation(:UserID, 'User'), inverse_of: :projects
  # Enrollments in this Project, NOT including WIP Enrollments
  has_many :enrollments, **hmis_relation(:ProjectID, 'Enrollment'), inverse_of: :project, dependent: :destroy
  # WIP records representing Enrollments for this Project
  has_many :enrollment_wips, -> { where(source_type: Hmis::Hud::Enrollment.sti_name) }, class_name: 'Hmis::Wip'
  # WIP Enrollments for this Project
  has_many :wip_enrollments, class_name: 'Hmis::Hud::Enrollment', through: :enrollment_wips, source: :source, source_type: Hmis::Hud::Enrollment.sti_name

  has_many :project_cocs, **hmis_relation(:ProjectID, 'ProjectCoc'), inverse_of: :project, dependent: :destroy
  has_many :inventories, **hmis_relation(:ProjectID, 'Inventory'), inverse_of: :project, dependent: :destroy
  has_many :funders, **hmis_relation(:ProjectID, 'Funder'), inverse_of: :project, dependent: :destroy
  has_many :units, -> { active }, dependent: :destroy
  has_many :unit_type_mappings, dependent: :destroy, class_name: 'Hmis::ProjectUnitTypeMapping'
  has_many :custom_data_elements, as: :owner

  has_many :client_projects
  has_many :clients_including_wip, through: :client_projects, source: :client
  has_many :enrollments_including_wip, through: :client_projects, source: :enrollment

  has_many :group_viewable_entity_projects
  has_many :group_viewable_entities, through: :group_viewable_entity_projects, source: :group_viewable_entity

  accepts_nested_attributes_for :custom_data_elements, allow_destroy: true

  # Households in this Project, NOT including WIP Enrollments
  has_many :households, through: :enrollments

  has_many :services, through: :enrollments_including_wip
  has_many :custom_services, through: :enrollments_including_wip
  has_many :hmis_services, through: :enrollments_including_wip

  has_and_belongs_to_many :project_groups,
                          class_name: 'GrdaWarehouse::ProjectGroup',
                          join_table: :project_project_groups

  validates_with Hmis::Hud::Validators::ProjectValidator

  # hide previous declaration of :viewable_by, we'll use this one
  # Any projects the user has been assigned, limited to the data source the HMIS is connected to
  replace_scope :viewable_by, ->(user) do
    ids = user.viewable_projects.pluck(:id)
    ids += user.viewable_organizations.joins(:projects).pluck(p_t[:id])
    ids += user.viewable_data_sources.joins(:projects).pluck(p_t[:id])
    ids += user.viewable_project_access_groups.joins(:projects).pluck(p_t[:id])

    where(id: ids, data_source_id: user.hmis_data_source_id)
  end

  scope :with_access, ->(user, *permissions, **kwargs) do
    ids = user.entities_with_permissions(Hmis::Hud::Project, *permissions, **kwargs).pluck(:id)
    ids += user.entities_with_permissions(Hmis::Hud::Organization, *permissions, **kwargs).joins(:projects).pluck(p_t[:id])
    ids += user.entities_with_permissions(GrdaWarehouse::DataSource, *permissions, **kwargs).joins(:projects).pluck(p_t[:id])
    ids += user.entities_with_permissions(GrdaWarehouse::ProjectAccessGroup, *permissions, **kwargs).joins(:projects).pluck(p_t[:id])

    where(id: ids, data_source_id: user.hmis_data_source_id)
  end

  scope :with_organization_ids, ->(organization_ids) do
    joins(:organization).where(o_t[:id].in(Array.wrap(organization_ids)))
  end

  # Always use ProjectType, we shouldn't need overrides since we can change the source data
  scope :with_project_type, ->(project_types) do
    where(ProjectType: project_types)
  end

  scope :with_funders, ->(funders) do
    joins(:funders).where(f_t[:funder].in(funders))
  end

  scope :open_on_date, ->(date = Date.current) do
    on_or_after_start = p_t[:operating_start_date].lteq(date)
    on_or_before_end = p_t[:operating_end_date].eq(nil).or(p_t[:operating_end_date].gteq(date))
    where(on_or_after_start.and(on_or_before_end))
  end

  scope :closed_on_date, ->(date = Date.current) do
    where(p_t[:operating_end_date].lt(date).or(p_t[:operating_start_date].gt(date)))
  end

  scope :with_statuses, ->(statuses) do
    return self if statuses.include?('OPEN') && statuses.include?('CLOSED')
    return open_on_date(Date.current) if statuses.include?('OPEN')
    return closed_on_date(Date.current) if statuses.include?('CLOSED')

    self
  end

  scope :matching_search_term, ->(search_term) do
    return none unless search_term.present?

    search_term.strip!
    query = "%#{search_term.split(/\W+/).join('%')}%"
    where(p_t[:ProjectName].matches(query).or(p_t[:id].eq(search_term)).or(p_t[:project_id].eq(search_term)))
  end

  SORT_OPTIONS = [:organization_and_name, :name].freeze

  SORT_OPTION_DESCRIPTIONS = {
    organization_and_name: 'Organization and Name',
    name: 'Name',
  }.freeze

  def self.sort_by_option(option)
    raise NotImplementedError unless SORT_OPTIONS.include?(option)

    case option
    when :name
      order(:ProjectName)
    when :organization_and_name
      joins(:organization).order(o_t[:OrganizationName], p_t[:ProjectName])
    else
      raise NotImplementedError
    end
  end

  def self.apply_filters(input)
    Hmis::Filter::ProjectFilter.new(input).filter_scope(self)
  end

  def active
    return true unless operating_end_date.present?

    operating_end_date >= Date.current
  end

  def households_including_wip
    household_ids = enrollments_including_wip.pluck(:household_id)

    Hmis::Hud::Household.where(HouseholdID: household_ids, data_source_id: data_source_id)
  end

  def close_related_funders_and_inventory!
    funders.where(end_date: nil).update_all(end_date: operating_end_date)
    inventories.where(inventory_end_date: nil).update_all(inventory_end_date: operating_end_date)
  end

  def to_pick_list_option
    {
      code: id,
      label: project_name,
      secondary_label: HudUtility.project_type_brief(project_type),
      group_label: organization.organization_name,
      group_code: organization.id,
    }
  end

  include RailsDrivers::Extensions
end
