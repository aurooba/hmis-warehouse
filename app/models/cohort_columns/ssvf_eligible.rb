###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module CohortColumns
  class SsvfEligible < CohortBoolean
    attribute :column, Boolean, lazy: true, default: :ssvf_eligible
    attribute :translation_key, String, lazy: true, default: 'SSVF Eligible'
    attribute :title, String, lazy: true, default: ->(model, _attr) { _(model.translation_key) }
  end
end
