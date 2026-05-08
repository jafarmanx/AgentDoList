class AgentExecutionJob < ApplicationJob
  limits_concurrency to: 1, key: ->(agent_assignment) { agent_assignment.id }

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  discard_on ActiveJob::DeserializationError

  def perform(agent_assignment)
    return unless agent_assignment.pending? || agent_assignment.failed?

    Agent::Executor.new(agent_assignment).execute
  end
end
