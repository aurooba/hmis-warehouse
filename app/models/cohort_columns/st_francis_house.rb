###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module CohortColumns
  class StFrancisHouse < Select
    attribute :column, String, lazy: true, default: :st_francis_house
    attribute :translation_key, String, lazy: true, default: 'St. Francis House'
    attribute :title, String, lazy: true, default: ->(model, _attr) { _(model.translation_key) }
  end
end
