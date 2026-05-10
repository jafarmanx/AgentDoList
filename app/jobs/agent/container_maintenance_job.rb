class Agent::ContainerMaintenanceJob < ApplicationJob
  queue_as :agent_execution

  def perform
    reap_idle_containers
    Agent::Orchestrator.process_queue
    reconcile_container_states
  end

  private
    def reap_idle_containers
      idle_threshold = ENV.fetch("AGENT_CONTAINER_IDLE_TIMEOUT", "300").to_i.seconds.ago

      Agent::Workspace
        .where(container_status: :running)
        .joins(:agent_assignment)
        .where(agent_assignments: { status: %w[completed failed] })
        .or(
          Agent::Workspace
            .where(container_status: :running)
            .where(container_started_at: ...idle_threshold)
            .joins(:agent_assignment)
            .where.not(agent_assignments: { status: :working })
        )
        .find_each do |workspace|
          Agent::ContainerManager.new(workspace).stop
          Rails.logger.info("[ContainerMaintenance] Reaped idle container: #{workspace.container_name}")
        end
    end

    def reconcile_container_states
      Agent::Workspace.where(container_status: :running).find_each do |workspace|
        manager = Agent::ContainerManager.new(workspace)
        unless manager.running?
          workspace.update!(container_status: :stopped, container_stopped_at: Time.current)
          Rails.logger.info("[ContainerMaintenance] Reconciled stale state: #{workspace.container_name}")
        end
      end
    end
end
