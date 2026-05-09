class Agent::ContainerProvisionJob < ApplicationJob
  queue_as :agent_execution

  limits_concurrency to: 1, key: ->(workspace) { workspace.id }

  def perform(workspace)
    Agent::ContainerManager.new(workspace).provision
    workspace.agent_assignment.execute_later
  end
end
