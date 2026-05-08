class Cards::AgentAssignmentsController < ApplicationController
  include CardScoped

  def new
    @agents = Current.account.agents.active.ordered
    @assigned_agents = @card.agents
  end

  def create
    agent = Current.account.agents.active.find(params[:agent_id])

    if agent.assigned_to?(@card)
      @card.agent_assignments.find_by!(agent: agent).destroy
    else
      agent.assign_to(@card, assigned_by: Current.user, instructions: params[:instructions])
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to card_path(@card) }
    end
  end

  def destroy
    @card.agent_assignments.find(params[:id]).destroy

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.html { redirect_to card_path(@card) }
    end
  end
end
