class CreateAgents < ActiveRecord::Migration[8.2]
  def change
    create_table :agents, id: :uuid do |t|
      t.belongs_to :account, type: :uuid, null: false
      t.string :name, null: false
      t.string :role_description
      t.text :personality
      t.text :system_prompt
      t.string :status, null: false, default: "active"
      t.timestamps
    end

    add_index :agents, [:account_id, :name], unique: true
  end
end
