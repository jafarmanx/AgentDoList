module Agent::Skilled
  extend ActiveSupport::Concern

  included do
    has_many :agent_skills, dependent: :destroy
  end

  def add_skill(name, proficiency: "intermediate")
    agent_skills.find_or_create_by!(name: name) do |skill|
      skill.proficiency = proficiency
    end
  end

  def has_skill?(name)
    agent_skills.exists?(name: name)
  end

  def skill_names
    agent_skills.pluck(:name)
  end
end
