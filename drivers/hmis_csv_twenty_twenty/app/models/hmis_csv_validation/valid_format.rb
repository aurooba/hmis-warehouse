###
# Copyright 2016 - 2021 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class HmisCsvValidation::ValidFormat < HmisCsvValidation::Validation
  def self.check_scope(scope, column, regex: nil)
    c = scope.connection
    scope.where(["#{c.quote_column_name column}::text = '' OR #{c.quote_column_name column}::text ~ ?", regex.source]).pluck(
      :importer_log_id,
      :source_id,
      :source_type,
      column,
    ).map do |importer_log_id, source_id, source_type, value|
      {
        type: sti_name,
        importer_log_id: importer_log_id,
        source_id: source_id,
        source_type: source_type,
        status: "Expected #{value} to match regular expression #{regex} for #{column}",
        validated_column: column,
      }
    end
  end

  def self.check_validity!(item, column, regex: nil)
    value = item[column]
    return if value.blank? || regex.blank? || value.to_s.match?(regex)

    {
      type: sti_name,
      importer_log_id: item['importer_log_id'],
      source_id: item['source_id'],
      source_type: item['source_type'],
      status: "Expected #{value} to match regular expression #{regex} for #{column}",
      validated_column: column,
    }
  end

  def self.title
    'Expected pattern was not found'
  end
end
