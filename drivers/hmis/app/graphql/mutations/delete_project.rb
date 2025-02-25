###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module Mutations
  class DeleteProject < BaseMutation
    argument :id, ID, required: true

    field :project, Types::HmisSchema::Project, null: true

    def resolve(id:)
      record = Hmis::Hud::Project.viewable_by(current_user).find_by(id: id)
      default_delete_record(record: record, field_name: :project, permissions: :can_delete_project)
    end
  end
end
