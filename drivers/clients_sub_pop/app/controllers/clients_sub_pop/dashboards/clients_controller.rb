###
# Copyright 2016 - 2020 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module ClientsSubPop::Dashboards
  class ClientsController < ::Dashboards::BaseController
    include ArelHelper
    include WarehouseReportAuthorization

    def sub_population_key
      :clients
    end
    helper_method :sub_population_key

    def active_report_class
      ClientsSubPop::Reporting::MonthlyReports::Clients
    end
  end
end
