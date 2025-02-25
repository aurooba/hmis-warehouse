###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module AdultOnlyHouseholdsSubPop::GrdaWarehouse::Census
  class AdultOnlyHouseholdsFactory
    def self.get_client_counts(batch, project_type)
      batch.get_client_counts(project_type, :service_history_enrollment, GrdaWarehouse::ServiceHistoryEnrollment.adult_only_households)
    end

    def self.get_homeless_client_counts(batch)
      batch.get_aggregate_client_counts(
        joins: :service_history_enrollment,
        client_scope: GrdaWarehouse::ServiceHistoryEnrollment.adult_only_households,
        second_scope: GrdaWarehouse::ServiceHistoryService.homeless_between(start_date: @start_date, end_date: @end_date),
      )
    end

    def self.get_literally_homeless_client_counts(batch)
      batch.get_aggregate_client_counts(
        joins: :service_history_enrollment,
        client_scope: GrdaWarehouse::ServiceHistoryEnrollment.adult_only_households,
        second_scope: GrdaWarehouse::ServiceHistoryService.literally_homeless_between(start_date: @start_date, end_date: @end_date),
      )
    end

    def self.get_system_client_counts(batch)
      batch.get_aggregate_client_counts(
        joins: :service_history_enrollment,
        client_scope: GrdaWarehouse::ServiceHistoryEnrollment.adult_only_households,
      )
    end
  end
end
