###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HudApr::Generators::Apr::Fy2023
  class Generator < ::HudReports::GeneratorBase
    include HudApr::CellDetailsConcern
    def self.fiscal_year
      'FY 2023'
    end

    def self.generic_title
      'Annual Performance Report'
    end

    def self.short_name
      'APR'
    end

    def self.default_project_type_codes
      GrdaWarehouse::Hud::Project::RESIDENTIAL_PROJECT_TYPES.keys
    end

    def url
      hud_reports_apr_url(report, { host: ENV['FQDN'], protocol: 'https' })
    end

    def self.filter_class
      ::Filters::HudFilterBase
    end

    def self.questions
      [
        HudApr::Generators::Apr::Fy2023::QuestionFour, # Project Identifiers in HMIS
        HudApr::Generators::Apr::Fy2023::QuestionFive, # Report Validations Table
        HudApr::Generators::Apr::Fy2023::QuestionSix, # Data Quality
        HudApr::Generators::Apr::Fy2023::QuestionSeven, # Persons Served
        HudApr::Generators::Apr::Fy2023::QuestionEight, # Households Served
        HudApr::Generators::Apr::Fy2023::QuestionNine, # Contacts and Engagements
        HudApr::Generators::Apr::Fy2023::QuestionTen, # Gender
        HudApr::Generators::Apr::Fy2023::QuestionEleven, # Age-Household Breakdown
        HudApr::Generators::Apr::Fy2023::QuestionTwelve, # Race & Ethnicity
        HudApr::Generators::Apr::Fy2023::QuestionThirteen, # Health
        HudApr::Generators::Apr::Fy2023::QuestionFourteen, # Domestic Violence
        HudApr::Generators::Apr::Fy2023::QuestionFifteen, # Living Situation
        HudApr::Generators::Apr::Fy2023::QuestionSixteen, #  Cash Income - Ranges
        HudApr::Generators::Apr::Fy2023::QuestionSeventeen, # Cash Income - Sources
        HudApr::Generators::Apr::Fy2023::QuestionEighteen, # Client Cash Income Category - Earned/Other Income Category - by Start and t/Exit Status
        HudApr::Generators::Apr::Fy2023::QuestionNineteen, # Cash Income - Changes over Time
        HudApr::Generators::Apr::Fy2023::QuestionTwenty, # Non-Cash Benefits
        HudApr::Generators::Apr::Fy2023::QuestionTwentyOne, # Health Insurance
        HudApr::Generators::Apr::Fy2023::QuestionTwentyTwo, # Length of participation
        HudApr::Generators::Apr::Fy2023::QuestionTwentyThree, # Destination
        HudApr::Generators::Apr::Fy2023::QuestionTwentyFive, # Veterans
        HudApr::Generators::Apr::Fy2023::QuestionTwentySix, # Chronically Homeless
        HudApr::Generators::Apr::Fy2023::QuestionTwentySeven, # Youth
      ].map do |q|
        [q.question_number, q]
      end.to_h.freeze
    end

    def self.valid_question_number(question_number)
      questions.keys.detect { |q| q == question_number } || 'Question 4'
    end
  end
end
