class CreateAgentWorkspaces < ActiveRecord::Migration[8.2]
  def change
    create_table :agent_workspaces, id: :uuid do |t|
      t.belongs_to :account, type: :uuid, null: false
      t.belongs_to :agent_assignment, type: :uuid, null: false
      t.string :status, null: false, default: "initializing"
      t.json :metadata, default: -> { "(json_object())" }
      t.text :log
      t.timestamps
    end

    add_index :agent_workspaces, :agent_assignment_id, unique: true
  end
end
