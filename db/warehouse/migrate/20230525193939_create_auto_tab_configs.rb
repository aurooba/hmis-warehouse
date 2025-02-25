class CreateAutoTabConfigs < ActiveRecord::Migration[6.1]
  def change
    create_table :cohort_tabs do |t|
      t.references :cohort, null: false
      t.string :name
      t.jsonb :rules
      t.integer :order, null: false, default: 0
      t.jsonb :permissions, null: false, default: []
      t.string :base_scope, default: :current_scope

      t.timestamps
      t.datetime :deleted_at
    end
  end
end
