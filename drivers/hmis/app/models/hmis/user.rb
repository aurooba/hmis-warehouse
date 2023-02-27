###
# Copyright 2016 - 2022 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

# NOTE:
# r = Hmis::Role.create(name: 'test')
# u = Hmis::User.first; u.hmis_data_source_id = 3
# u.user_hmis_data_sources_roles.create(role: r, data_source_id: u.hmis_data_source_id)
# u.can_view_full_ssn?
require 'memery'
class Hmis::User < ApplicationRecord
  include UserConcern
  include HasRecentItems
  self.table_name = :users

  has_many :user_hmis_data_sources_roles, class_name: '::Hmis::UserHmisDataSourceRole', dependent: :destroy, inverse_of: :user # join table with user_id, data_source_id, role_id
  has_many :roles, through: :user_hmis_data_sources_roles, source: :role
  has_many :hmis_data_sources, through: :user_hmis_data_sources_roles, source: :data_source
  has_many :groups, class_name: '::Hmis::AccessGroup'
  has_recent :clients, Hmis::Hud::Client
  has_recent :projects, Hmis::Hud::Project
  attr_accessor :hmis_data_source_id # stores the data_source_id of the currently logged in HMIS

  def skip_session_limitable?
    true
  end

  # load a hash of permission names (e.g. 'can_view_all_reports')
  # to a boolean true if the user has the permission through one
  # of their roles
  def load_effective_permissions
    {}.tap do |h|
      roles.merge(Hmis::UserHmisDataSourceRole.where(data_source_id: hmis_data_source_id)).each do |role|
        ::Hmis::Role.permissions.each do |permission|
          h[permission] ||= role.send(permission)
        end
      end
    end
  end

  # define helper methods for looking up if this
  # user has an permission through one of its roles
  ::Hmis::Role.permissions.each do |permission|
    define_method(permission) do
      @permissions ||= load_effective_permissions
      @permissions[permission]
    end

    # Methods for determining if a user has permission
    # e.g. the_user.can_administer_health?
    define_method("#{permission}?") do
      send(permission)
    end

    # Provide a scope for each permission to get any user who qualifies
    # e.g. User.can_administer_health
    scope permission, -> do
      joins(:roles).
        where(roles: { permission => true })
    end
  end

  def lock_access!(opts = {})
    super opts.merge({ send_instructions: false })
  end

  private def viewable(model)
    model.where(
      id: GrdaWarehouse::GroupViewableEntity.where(
        access_group_id: access_groups.viewable.pluck(:id),
        entity_type: model.sti_name,
      ).select(:entity_id),
    )
  end

  def viewable_data_sources
    viewable GrdaWarehouse::DataSource
  end

  def viewable_organizations
    viewable GrdaWarehouse::Hud::Organization
  end

  def viewable_projects
    viewable GrdaWarehouse::Hud::Project
  end

  def viewable_project_access_groups
    viewable GrdaWarehouse::ProjectAccessGroup
  end

  def viewable_project_ids
    @viewable_project_ids ||= Hmis::Hud::Project.viewable_by(self).pluck(:id)
  end

  private def cached_viewable_project_ids(force_calculation: false)
    key = [self.class.name, __method__, id]
    Rails.cache.delete(key) if force_calculation
    Rails.cache.fetch(key, expires_in: 1.minutes) do
      Hmis::Hud::Project.viewable_by(self).pluck(:id).to_set
    end
  end

  private def editable(model)
    model.where(
      id: GrdaWarehouse::GroupViewableEntity.where(
        access_group_id: access_groups.editable.pluck(:id),
        entity_type: model.sti_name,
      ).select(:entity_id),
    )
  end

  def editable_data_sources
    editable GrdaWarehouse::DataSource
  end

  def editable_organizations
    editable GrdaWarehouse::Hud::Organization
  end

  def editable_projects
    editable GrdaWarehouse::Hud::Project
  end

  def editable_project_access_groups
    editable GrdaWarehouse::ProjectAccessGroup
  end

  def editable_project_ids
    @editable_project_ids ||= Hmis::Hud::Project.editable_by(self).pluck(:id)
  end
end
