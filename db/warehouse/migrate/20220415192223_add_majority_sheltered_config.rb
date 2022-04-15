class AddMajorityShelteredConfig < ActiveRecord::Migration[6.1]
  def change
    add_column :configs, :majority_sheltered_calculation, :string, default: 'current_living_situation'
  end
end
