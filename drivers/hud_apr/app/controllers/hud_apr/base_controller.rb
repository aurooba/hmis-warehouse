###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module HudApr
  class BaseController < ::HudReports::BaseController
    before_action :filter

    def available_report_versions
      {
        'FY 2020' => { slug: :fy2020, active: false },
        'FY 2022' => { slug: :fy2021, active: true },
        'FY 2023 (current)' => { slug: :fy2023, active: true },
      }.freeze
    end
    helper_method :available_report_versions

    def default_report_version
      :fy2023
    end

    private def filter_class
      ::Filters::HudFilterBase
    end
  end
end
