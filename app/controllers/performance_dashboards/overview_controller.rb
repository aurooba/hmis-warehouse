###
# Copyright 2016 - 2020 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module PerformanceDashboards
  class OverviewController < BaseController
    before_action :set_filter
    before_action :set_report
    before_action :set_key, only: [:details]

    def index
    end

    def filters
      @sections = @filter.control_sections
      chosen = params[:filter_section_id]
      if chosen
        @chosen_section = @sections.detect do |section|
          section.id == chosen
        end
      end
      @modal_size = :xl if @chosen_section.nil?
    end

    private def section_subpath
      'performance_dashboards/overview/'
    end

    def details
      @options = option_params[:filters]
      @breakdown = params.dig(:filters, :breakdown)
      @sub_key = params.dig(:filters, :sub_key)

      respond_to do |format|
        format.xlsx do
          render(
            xlsx: 'details',
            filename: "#{@report.support_title(@options)} - #{Time.current.to_s.delete(',')}.xlsx",
          )
        end
        format.html
      end
    end

    private def option_params
      params.permit(
        filters: [
          :key,
          :sub_key,
          :age,
          :gender,
          :household,
          :veteran,
          :sub_population,
          :race,
          :ethnicity,
          :project_type,
          :coc,
          :breakdown,
        ],
      )
    end

    private def multiple_project_types?
      true
    end
    helper_method :multiple_project_types?

    private def include_comparison_pattern?
      true
    end
    helper_method :include_comparison_pattern?

    private def set_report
      @report_variant = 'sparse'
      @report = PerformanceDashboards::Overview.new(@filter)
      if @report.include_comparison?
        @comparison = PerformanceDashboards::Overview.new(@comparison_filter)
      else
        @comparison = @report
      end
    end

    private def filter_class
      ::Filters::PerformanceDashboard
    end

    private def set_key
      @key = PerformanceDashboards::Overview.detail_method(params.dig(:filters, :key))
    end

    private def set_pdf_export
      @pdf_export = GrdaWarehouse::DocumentExports::PerformanceDashboardExport.new
    end
    before_action :set_pdf_export
  end
end
