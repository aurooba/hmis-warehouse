###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module Hmis
  class UnitType < HmisBase
    has_many :units, class_name: 'Hmis::Unit'
    has_many :unit_type_mappings, dependent: :destroy, class_name: 'Hmis::ProjectUnitTypeMapping'
    alias_attribute :date_updated, :updated_at
    alias_attribute :date_created, :created_at

    # HUD bed types specified on Inventory
    enum(
      bed_type: {
        ch_vet_bed_inventory: 7,
        youth_vet_bed_inventory: 8,
        vet_bed_inventory: 9,
        ch_youth_bed_inventory: 10,
        youth_bed_inventory: 11,
        ch_bed_inventory: 12,
        other_bed_inventory: 13,
      },
    )

    def to_pick_list_option
      { code: id&.to_s, label: description }
    end

    include RailsDrivers::Extensions
  end
end
