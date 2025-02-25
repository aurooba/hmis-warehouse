###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module CohortColumns
  class HealthPrioritized < ReadOnly
    attribute :column, String, lazy: true, default: :health_prioritized
    attribute :translation_key, String, lazy: true, default: 'Health Priority'
    attribute :title, String, lazy: true, default: ->(model, _attr) { _(model.translation_key) }

    def cast_value(val)
      val.to_s == true
    end

    def arel_col
      c_t[:health_prioritized]
    end

    def renderer
      'html'
    end

    def value(cohort_client) # OK
      text_value(cohort_client)
    end

    def text_value(cohort_client)
      cohort_client.client.health_prioritized
    end
  end
end
