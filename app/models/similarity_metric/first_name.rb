###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module SimilarityMetric
  class FirstName < SimilarityMetric::Levenshtein
    include NameDataQuality

    def field
      :FirstName
    end
  end
end
