###
# Copyright 2016 - 2023 Green River Data Analysis, LLC
#
# License detail: https://github.com/greenriver/hmis-warehouse/blob/production/LICENSE.md
###

module GrdaWarehouse::Census
  class CensusBuilder
    def create_census(start_date, end_date)
      batch_start_date = start_date.to_date
      while batch_start_date <= end_date.to_date
        # Batches are 1 month, or to the end_date if closer
        batch_end_date = [batch_start_date + 1.years, end_date].min

        GrdaWarehouseBase.transaction do
          batch_by_project = ProjectBatch.new(batch_start_date, batch_end_date)
          batch_by_project.build_census_batch

          # Remove any existing census data for the batch range
          ByProject.where(date: batch_start_date..batch_end_date).delete_all

          # Save the new batch
          headers = nil
          values = []
          batch_by_project.by_count.values.flat_map do |project|
            headers = project.values.first.attributes.except('id').keys if headers.blank?
            project.values.each do |day|
              row = day.attributes.except('id')
              row['created_at'] = Time.now
              row['updated_at'] = Time.now
              values << row.values
            end
            # project.values.each(&:save)
          end
          ByProject.new.insert_batch(ByProject, headers, values, transaction: false, batch_size: 500)
        end

        # Move batch forward
        batch_start_date = batch_end_date + 1.day
      end
    end
  end
end
