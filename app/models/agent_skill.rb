class AgentSkill < ApplicationRecord
  belongs_to :account, default: -> { agent.account }
  belongs_to :agent

  PROFICIENCY_LEVELS = %w[ beginner intermediate advanced expert ].freeze

  validates :name, presence: true, uniqueness: { scope: :agent_id }
  validates :proficiency, inclusion: { in: PROFICIENCY_LEVELS }

  scope :ordered, -> { order(:name) }
end
