###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module CohortColumns
  class VetSquaresConfirmed < CohortBoolean
    attribute :column, Boolean, lazy: true, default: :vet_squares_confirmed
    attribute :translation_key, String, lazy: true, default: 'Vet Status Confirmed in Squares'
    attribute :title, String, lazy: true, default: ->(model, _attr) { _(model.translation_key) }
  end
end
