###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module CohortColumns
  class SifEligible < CohortBoolean
    attribute :column, Boolean, lazy: true, default: :sif_eligible
    attribute :translation_key, String, lazy: true, default: 'SIF/PACE Eligible'
    attribute :title, String, lazy: true, default: ->(model, _attr) { _(model.translation_key) }
  end
end
