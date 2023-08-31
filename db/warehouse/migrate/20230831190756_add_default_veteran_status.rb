class AddDefaultVeteranStatus < ActiveRecord::Migration[6.1]
  def change
    change_column_default :Client, :VeteranStatus, from: nil, to: 99
    change_column_default :Enrollment, :DisablingCondition, from: nil, to: 99
  end
end
