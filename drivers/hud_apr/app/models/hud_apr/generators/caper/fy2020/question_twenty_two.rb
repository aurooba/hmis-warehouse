###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HudApr::Generators::Caper::Fy2020
  class QuestionTwentyTwo < HudApr::Generators::Shared::Fy2020::QuestionTwentyTwo
    QUESTION_TABLE_NUMBERS = ['Q22a2', 'Q22c', 'Q22d', 'Q22e'].freeze
  end
end
