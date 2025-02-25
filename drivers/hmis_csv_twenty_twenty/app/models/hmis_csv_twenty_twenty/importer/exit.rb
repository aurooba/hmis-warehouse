###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HmisCsvTwentyTwenty::Importer
  class Exit < GrdaWarehouse::Hud::Base
    include ::HmisStructure::Exit
    include ImportConcern
    include ArelHelper

    # Because GrdaWarehouse::Hud::* defines the table name, we can't use table_name_prefix :(
    self.table_name = 'hmis_2020_exits'

    has_one :destination_record, **hud_assoc(:ExitID, 'Exit')
    belongs_to :enrollment, primary_key: [:EnrollmentID, :PersonalID, :data_source_id, :importer_log_id], foreign_key: [:EnrollmentID, :PersonalID, :data_source_id, :importer_log_id], class_name: 'HmisCsvTwentyTwenty::Importer::Enrollment', autosave: false, optional: true

    def self.involved_warehouse_scope(data_source_id:, project_ids:, date_range:)
      return none unless project_ids.present?

      # this has to be a bit convoluted because active record doesn't rename the exit joins appropriately
      ids = HmisCsvTwentyTwenty::Importer::Enrollment.involved_warehouse_scope(
        data_source_id: data_source_id,
        project_ids: project_ids,
        date_range: date_range,
      ).with_deleted.
        joins(:exit).
        pluck(ex_t[:id])
      return none unless ids

      warehouse_class.importable.where(id: ids)
    end

    def self.warehouse_class
      GrdaWarehouse::Hud::Exit
    end

    def self.hmis_validations
      {
        EnrollmentID: [
          class: HmisCsvValidation::NonBlank,
        ],
        PersonalID: [
          class: HmisCsvValidation::NonBlank,
        ],
        ExitDate: [
          class: HmisCsvValidation::NonBlankValidation,
        ],
        Destination: [
          {
            class: HmisCsvValidation::NonBlankValidation,
          },
          {
            class: HmisCsvValidation::InclusionInSet,
            arguments: { valid_options: HudUtility.available_situations.keys.map(&:to_s).freeze },
          },
        ],
      }
    end
  end
end
