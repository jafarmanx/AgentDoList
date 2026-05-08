class AgentAssignment < ApplicationRecord
  belongs_to :account, default: -> { card.account }
  belongs_to :agent
  belongs_to :card, touch: true
  belongs_to :assigned_by, class_name: "User"

  has_one :workspace, class_name: "Agent::Workspace", dependent: :destroy

  enum :status, %w[ pending working completed failed ].index_by(&:itself), default: :pending

  validates :agent_id, uniqueness: { scope: :card_id }

  scope :ordered, -> { order(created_at: :desc) }

  after_create :provision_workspace
  after_create_commit :execute_later

  def execute_later
    AgentExecutionJob.perform_later(self)
  end

  def start
    update!(status: :working, started_at: Time.current)
    workspace&.update!(status: :ready)
  end

  def complete
    update!(status: :completed, completed_at: Time.current)
    workspace&.update!(status: :completed)
  end

  def fail
    update!(status: :failed, completed_at: Time.current)
    workspace&.update!(status: :failed)
  end

  def duration
    if started_at && completed_at
      completed_at - started_at
    end
  end

  private
    def provision_workspace
      create_workspace!
    end
end
