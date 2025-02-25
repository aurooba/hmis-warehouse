###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

class BackgroundRender::ExitClientsReportJob < BackgroundRenderJob
  def render_html(filter:, user_id:)
    current_user = User.find(user_id)
    @filter = ::Filters::FilterBase.new(user_id: user_id).set_from_params(JSON.parse(filter).with_indifferent_access[:filters])
    @report = report_source.new(filter: @filter, user: current_user)
    @show_ph_destinations = true
    WarehouseReports::ClientDetails::ExitsController.render(
      partial: 'report',
      assigns: {
        filter: @filter,
        report: @report,
        show_ph_destinations: @show_ph_destinations,
        limited: limited(current_user),
        visible_projects: visible_projects(current_user),
      },
      locals: {
        current_user: current_user,
      },
    )
  end

  def visible_projects(user)
    GrdaWarehouse::Hud::Project.viewable_by(user).order(id: :asc).pluck(:id, :ProjectName).to_h
  end

  def limited(user)
    all_project_ids = GrdaWarehouse::Hud::Project.order(id: :asc).pluck(:id)
    all_project_ids != visible_projects(user).keys
  end

  def report_source
    ExitClientReport
  end
end
