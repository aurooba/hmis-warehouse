###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module Mutations
  class DeleteInventory < BaseMutation
    argument :id, ID, required: true

    field :inventory, Types::HmisSchema::Inventory, null: true

    def resolve(id:)
      record = Hmis::Hud::Inventory.viewable_by(current_user).find_by(id: id)
      default_delete_record(record: record, field_name: :inventory, permissions: [:can_edit_project_details])
    end
  end
end
