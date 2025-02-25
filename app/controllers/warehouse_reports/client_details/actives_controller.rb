###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module WarehouseReports::ClientDetails
  class ActivesController < ApplicationController
    include WarehouseReportAuthorization
    include ClientDetailReports
    extend BackgroundRenderAction
    before_action :set_pdf_export

    before_action :set_limited, only: [:index]
    before_action :set_filter

    background_render_action :render_section, ::BackgroundRender::ActiveClientsReportJob do
      {
        filter: @filter.for_params.to_json,
        user_id: current_user.id,
      }
    end

    def index
      @report = report_source.new(filter: @filter, user: current_user)
      @filter.errors.add(:project_type_codes, message: 'are required') if @filter.project_type_codes.blank?

      respond_to do |format|
        format.html {}
        format.xlsx do
          require_can_view_clients!
        end
      end
    end

    def section
      @report = report_source.new(filter: @filter, user: current_user)
    end

    def report_source
      ActiveClientReport
    end

    private def set_pdf_export
      @pdf_export = GrdaWarehouse::WarehouseReports::DocumentExports::ActiveClientReportExport.new
    end
  end
end
