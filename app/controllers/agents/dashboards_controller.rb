class Agents::DashboardsController < ApplicationController
  def show
    @status = Agent::Orchestrator.status
    @running = Agent::Workspace.with_running_containers
      .joins(agent_assignment: :agent)
      .where(agent_assignments: { account_id: Current.account.id })
      .includes(agent_assignment: [ :agent, :card ])
    @queued = Current.account.agents
      .joins(:agent_assignments)
      .where(agent_assignments: { status: :pending })
      .distinct
  end
end
