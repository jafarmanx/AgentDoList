class Agents::SkillsController < ApplicationController
  before_action :set_agent

  def create
    @agent.add_skill(params[:name], proficiency: params[:proficiency] || "intermediate")
    redirect_to agent_path(@agent)
  end

  def destroy
    @agent.agent_skills.find(params[:id]).destroy
    redirect_to agent_path(@agent)
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end
end
