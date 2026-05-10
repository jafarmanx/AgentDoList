class Agent::Orchestrator
  class NoSlotAvailable < StandardError; end

  class << self
    def claim_slot!(workspace)
      if slot_available?
        start_container(workspace)
      elsif reclaimable = find_reclaimable_workspace
        Agent::ContainerManager.new(reclaimable).stop
        start_container(workspace)
      else
        raise NoSlotAvailable, "All #{max_concurrent} container slots are in use"
      end
    end

    def release_slot(workspace)
      return unless workspace&.running?
      Agent::ContainerManager.new(workspace).stop
    rescue => error
      Rails.logger.error("[Orchestrator] Failed to release slot: #{error.message}")
    end

    def process_queue
      while slot_available? && (next_assignment = next_queued_assignment)
        AgentExecutionJob.perform_later(next_assignment)
      end
    end

    def slot_available?
      running_count < max_concurrent
    end

    def running_count
      Agent::Workspace.where(container_status: :running).count
    end

    def max_concurrent
      ENV.fetch("AGENT_MAX_CONCURRENT", "2").to_i
    end

    def queued_count
      AgentAssignment.where(status: :pending).count
    end

    def status
      {
        max_concurrent: max_concurrent,
        running: running_count,
        queued: queued_count,
        available_slots: [ max_concurrent - running_count, 0 ].max
      }
    end

    private
      def start_container(workspace)
        manager = Agent::ContainerManager.new(workspace)
        manager.provision unless workspace.provisioned? || workspace.stopped?
        manager.start
      end

      def find_reclaimable_workspace
        Agent::Workspace
          .where(container_status: :running)
          .joins(:agent_assignment)
          .where(agent_assignments: { status: %w[completed failed] })
          .order(container_started_at: :asc)
          .first
      end

      def next_queued_assignment
        AgentAssignment
          .where(status: :pending)
          .order(created_at: :asc)
          .first
      end
  end
end
