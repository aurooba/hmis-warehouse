###
# Copyright 2016 - 2021 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class HmisCsvValidation::InclusionInSet < HmisCsvValidation::Validation
  def self.check_scope(scope, column, valid_options: nil)
    list_desc = short_list(valid_options)

    scope.where.not(column => valid_options + ['']).pluck(
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
        status: "Expected #{value} to be included in #{list_desc} for #{column}",
        validated_column: column,
      }
    end
  end

  def self.check_validity!(item, column, valid_options: nil)
    value = item[column]
    return if value.blank? || value.to_s.in?(valid_options)

    list_desc = short_list(valid_options)

    {
      type: sti_name,
      importer_log_id: item['importer_log_id'],
      source_id: item['source_id'],
      source_type: item['source_type'],
      status: "Expected #{value} to be included in #{list_desc} for #{column}",
      validated_column: column,
    }
  end

  def self.short_list(options)
    return options if options.length < 10

    options[0..9] + ['...']
  end

  def self.title
    'Inclusion in specific set'
  end
end
