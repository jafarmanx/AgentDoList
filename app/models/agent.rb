class Agent < ApplicationRecord
  include Assignable, Skilled

  belongs_to :account

  has_one_attached :avatar

  enum :status, %w[ active inactive ].index_by(&:itself), default: :active

  validates :name, presence: true, uniqueness: { scope: :account_id }

  scope :ordered, -> { order(:name) }

  def initials
    name.split.map(&:first).join.upcase.first(2)
  end
end
