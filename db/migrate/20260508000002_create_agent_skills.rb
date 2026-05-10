class CreateAgentSkills < ActiveRecord::Migration[8.2]
  def change
    create_table :agent_skills, id: :uuid do |t|
      t.belongs_to :account, type: :uuid, null: false
      t.belongs_to :agent, type: :uuid, null: false
      t.string :name, null: false
      t.string :proficiency, null: false, default: "intermediate"
      t.timestamps
    end

    add_index :agent_skills, [:agent_id, :name], unique: true
  end
end
