class AddJobIdToUnprocessedEnrollments < ActiveRecord::Migration[5.2]
  def change
    add_reference :Enrollment, :service_history_processing_job unless column_exists? :Enrollment, :service_history_processing_job_id
  end
end
