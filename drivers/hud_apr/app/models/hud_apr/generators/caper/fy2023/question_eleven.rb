###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HudApr::Generators::Caper::Fy2023
  class QuestionEleven < HudApr::Generators::Shared::Fy2023::QuestionEleven
    QUESTION_TABLE_NUMBER = 'Q11'.freeze

    def run_question!
      @report.start(QUESTION_NUMBER, [QUESTION_TABLE_NUMBER])

      q11_ages

      @report.complete(QUESTION_NUMBER)
    end
  end
end
