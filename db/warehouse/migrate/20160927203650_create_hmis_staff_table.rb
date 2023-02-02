class CreateHmisStaffTable < ActiveRecord::Migration[4.2]
  def change
    table_name = GrdaWarehouse::Hmis::Staff.table_name
    create_table table_name do |t|
      t.integer :site_id
      t.string :first_name
      t.string :last_name
      t.string :middle_initial
      t.string :work_phone
      t.string :cell_phone
      t.string :email
      t.string :ssn
      t.string :source_class
      t.string :source_id
    end
  end
end
