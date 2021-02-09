class AdjustCohortBooleans < ActiveRecord::Migration[4.2]
  def change
    change_column :cohort_clients, :sif_eligible, 'boolean USING CAST(sif_eligible AS boolean)', default: false
    change_column :cohort_clients, :vash_eligible, 'boolean USING CAST(sif_eligible AS boolean)', default: false
  end
end
