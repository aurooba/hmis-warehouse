###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HudApr::Generators::Caper::Fy2023
  class QuestionFifteen < HudApr::Generators::Shared::Fy2023::QuestionFifteen
    QUESTION_TABLE_NUMBER = 'Q15'.freeze

    def run_question!
      @report.start(QUESTION_NUMBER, [QUESTION_TABLE_NUMBER])

      q15_living_situation

      @report.complete(QUESTION_NUMBER)
    end
  end
end
