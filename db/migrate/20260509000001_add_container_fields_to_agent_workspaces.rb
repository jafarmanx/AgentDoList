class AddContainerFieldsToAgentWorkspaces < ActiveRecord::Migration[8.2]
  def change
    add_column :agent_workspaces, :container_id, :string
    add_column :agent_workspaces, :container_name, :string
    add_column :agent_workspaces, :volume_name, :string
    add_column :agent_workspaces, :container_image, :string, default: "curioarch-agent-workspace:latest"
    add_column :agent_workspaces, :container_status, :string, default: "not_provisioned"
    add_column :agent_workspaces, :container_started_at, :datetime
    add_column :agent_workspaces, :container_stopped_at, :datetime
    add_column :agent_workspaces, :port, :integer

    add_index :agent_workspaces, :container_status
    add_index :agent_workspaces, :container_name, unique: true
  end
end
