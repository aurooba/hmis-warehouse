###
# Copyright 2016 - 2021 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class HmisCsvValidation::NonBlank < HmisCsvValidation::Error
  def self.check_scope(scope, column, _args)
    scope.where(column => [nil, '']).pluck(
      :importer_log_id,
      :source_id,
      :source_type,
      column,
    ).map do |importer_log_id, source_id, source_type, _value|
      {
        type: sti_name,
        importer_log_id: importer_log_id,
        source_id: source_id,
        source_type: source_type,
        status: "A value is required for #{column}",
        validated_column: column,
      }
    end
  end

  def self.check_validity!(item, column, _args)
    value = item[column]
    return if value.present?

    {
      type: sti_name,
      importer_log_id: item['importer_log_id'],
      source_id: item['source_id'],
      source_type: item['source_type'],
      status: "A value is required for #{column}",
      validated_column: column,
    }
  end

  def self.title
    'Missing required value'
  end
end
