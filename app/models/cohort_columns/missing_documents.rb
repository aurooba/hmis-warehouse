###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module CohortColumns
  class MissingDocuments < ReadOnly
    attribute :column, String, lazy: true, default: :missing_documents
    attribute :translation_key, String, lazy: true, default: 'Missing Documents'
    attribute :title, String, lazy: true, default: ->(model, _attr) { _(model.translation_key) }

    def available_for_rules?
      false
    end

    def value(cohort_client) # OK
      cohort_client.missing_documents
    end
  end
end
