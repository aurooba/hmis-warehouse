###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module CohortColumns
  class RrhSsvfEligible < ReadOnly
    attribute :column, String, lazy: true, default: :rrh_ssvf_eligible
    attribute :translation_key, String, lazy: true, default: 'SSVF Eligible (from RRH Assessment)'
    attribute :title, String, lazy: true, default: ->(model, _attr) { _(model.translation_key) }

    def cast_value(val)
      val.to_s == 'true'
    end

    def arel_col
      c_t[:ssvf_eligible]
    end

    def renderer
      'html'
    end

    def value(cohort_client) # OK
      checkmark_or_x text_value(cohort_client)
    end

    def text_value(cohort_client)
      cohort_client.client.ssvf_eligible
    end
  end
end
