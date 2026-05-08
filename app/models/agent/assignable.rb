module Agent::Assignable
  extend ActiveSupport::Concern

  included do
    has_many :agent_assignments, dependent: :destroy
    has_many :assigned_cards, through: :agent_assignments, source: :card
  end

  def assign_to(card, assigned_by:, instructions: nil)
    agent_assignments.create!(
      card: card,
      assigned_by: assigned_by,
      instructions: instructions
    )
  end

  def assigned_to?(card)
    agent_assignments.exists?(card: card)
  end
end
