class CreateAgentAssignments < ActiveRecord::Migration[8.2]
  def change
    create_table :agent_assignments, id: :uuid do |t|
      t.belongs_to :account, type: :uuid, null: false
      t.belongs_to :agent, type: :uuid, null: false
      t.belongs_to :card, type: :uuid, null: false
      t.belongs_to :assigned_by, type: :uuid, null: false
      t.string :status, null: false, default: "pending"
      t.text :instructions
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :agent_assignments, [:agent_id, :card_id], unique: true
    add_index :agent_assignments, [:account_id, :status]
  end
end
