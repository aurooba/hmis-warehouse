###
# Copyright 2016 - 2022 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

# frozen_string_literal: true

module Types
  class HmisSchema::Organization < Types::BaseObject
    include Types::HmisSchema::HasProjects

    description 'HUD Organization'
    field :id, ID, null: false
    field :organization_name, String, null: false
    projects_field :projects, 'Get a list of projects for this organization'
    field :victim_service_provider, Boolean, null: true
    field :description, String, null: true
    field :contact_information, String, null: true
    field :date_updated, GraphQL::Types::ISO8601DateTime, null: false
    field :date_created, GraphQL::Types::ISO8601DateTime, null: false
    field :date_deleted, GraphQL::Types::ISO8601DateTime, null: true

    def projects(**args)
      resolve_projects_with_loader(:projects, **args)
    end

    def victim_service_provider
      resolve_yes_no_missing(object.victim_service_provider)
    end

    def self.organizations(scope = Hmis::Hud::Organization.all, user:)
      scope.viewable_by(user)
    end
  end
end
