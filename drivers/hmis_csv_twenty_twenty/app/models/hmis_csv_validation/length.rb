###
# Copyright 2016 - 2021 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class HmisCsvValidation::Length < HmisCsvValidation::Error
  def self.check_scope(scope, column, max:, min: 0)
    c = scope.connection
    scope.where(["LENGTH(#{c.quote_column_name column}::text) BETWEEN ? AND ?", min, max]).pluck(
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
        status: "The length of #{column} must be in range #{min}..#{max}",
        validated_column: column,
      }
    end
  end

  def self.check_validity!(item, column, max:, min: 0)
    value = item[column].to_s
    return if value.size >= min && value.size <= max

    {
      type: sti_name,
      importer_log_id: item['importer_log_id'],
      source_id: item['source_id'],
      source_type: item['source_type'],
      status: "The length of #{column} must be in range #{min}..#{max}",
      validated_column: column,
    }
  end

  def self.title
    'Incorrect column length'
  end
end
