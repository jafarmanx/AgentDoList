class AgentsController < ApplicationController
  before_action :set_agent, only: %i[ show edit update destroy ]

  def index
    @agents = Current.account.agents.ordered
  end

  def show
  end

  def new
    @agent = Agent.new
  end

  def create
    @agent = Current.account.agents.create!(agent_params)
    redirect_to agent_path(@agent)
  end

  def edit
  end

  def update
    @agent.update!(agent_params)
    redirect_to agent_path(@agent), notice: "Saved"
  end

  def destroy
    @agent.destroy
    redirect_to agents_path
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:id])
    end

    def agent_params
      params.expect(agent: [ :name, :role_description, :personality, :system_prompt, :status ])
    end
end
