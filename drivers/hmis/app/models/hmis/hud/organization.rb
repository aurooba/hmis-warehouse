###
# Copyright 2016 - 2022 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class Hmis::Hud::Organization < Hmis::Hud::Base
  include ArelHelper
  include ::HmisStructure::Organization
  include ::Hmis::Hud::Shared
  self.table_name = :Organization
  self.sequence_name = "public.\"#{table_name}_id_seq\""

  belongs_to :data_source, class_name: 'GrdaWarehouse::DataSource'
  has_many :projects, **hmis_relation(:OrganizationID, 'Project')
  belongs_to :user, **hmis_relation(:UserID, 'User'), inverse_of: :organizations

  validates_with Hmis::Hud::Validators::OrganizationValidator

  # Any organizations the user has been assigned, limited to the data source the HMIS is connected to
  scope :viewable_by, ->(user) do
    viewable_ids += user.organizations..pluck(:id)
    viewable_ids += user.data_sources.joins(:organizations).pluck(o_t[:id])
    where(id: viewable_ids, data_source_id: user.hmis_data_source_id)
  end

  SORT_OPTIONS = [:name].freeze

  def self.sort_by_option(option)
    raise NotImplementedError unless SORT_OPTIONS.include?(option)

    case option
    when :name
      order(:OrganizationName)
    else
      raise NotImplementedError
    end
  end

  def self.generate_organization_id
    generate_uuid
  end
end
