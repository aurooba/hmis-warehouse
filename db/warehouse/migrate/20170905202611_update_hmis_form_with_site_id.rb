class UpdateHmisFormWithSiteId < ActiveRecord::Migration[4.2]
  def up
    a_t = GrdaWarehouse::Hmis::Assessment.arel_table
    GrdaWarehouse::Hmis::Assessment.all.each do |assessment|
      GrdaWarehouse::HmisForm.where(data_source_id: assessment.data_source_id, assessment_id: assessment.assessment_id).update_all(site_id: assessment.site_id)
    end
  end
end
