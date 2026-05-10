class Agent::Workspace < ApplicationRecord
  self.table_name = "agent_workspaces"

  belongs_to :account, default: -> { agent_assignment.account }
  belongs_to :agent_assignment

  has_rich_text :output
  has_many_attached :deliverables

  enum :status, %w[ initializing ready working completed failed ].index_by(&:itself), default: :initializing
  enum :container_status, {
    not_provisioned: "not_provisioned",
    provisioned: "provisioned",
    running: "running",
    stopped: "stopped",
    destroyed: "destroyed"
  }, default: :not_provisioned, prefix: true

  delegate :agent, :card, to: :agent_assignment

  scope :with_running_containers, -> { where(container_status: :running) }
  scope :with_stopped_containers, -> { where(container_status: :stopped) }

  def container_manager
    Agent::ContainerManager.new(self)
  end

  def provisioned?
    container_status_provisioned?
  end

  def running?
    container_status_running?
  end

  def stopped?
    container_status_stopped?
  end

  def append_log(message)
    timestamp = Time.current.strftime("%Y-%m-%d %H:%M:%S")
    new_entry = "[#{timestamp}] #{message}"

    if log.present?
      update!(log: "#{log}\n#{new_entry}")
    else
      update!(log: new_entry)
    end
  end

  def log_lines
    log&.split("\n") || []
  end
end
