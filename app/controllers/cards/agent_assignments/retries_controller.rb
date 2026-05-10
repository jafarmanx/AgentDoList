class Cards::AgentAssignments::RetriesController < ApplicationController
  include CardScoped

  def create
    assignment = @card.agent_assignments.find(params[:agent_assignment_id])
    assignment.update!(status: :pending, started_at: nil, completed_at: nil)
    assignment.workspace&.update!(status: :initializing, log: nil)
    assignment.execute_later

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.html { redirect_to card_path(@card) }
    end
  end
end
