class Agent::Executor
  attr_reader :agent_assignment

  delegate :agent, :card, :workspace, to: :agent_assignment

  def initialize(agent_assignment)
    @agent_assignment = agent_assignment
  end

  def execute
    agent_assignment.start
    workspace.update!(status: :working)
    workspace.append_log("Starting execution")

    response = call_llm
    workspace.append_log("Received response (#{response.length} chars)")

    workspace.update!(output: response)
    agent_assignment.complete
    workspace.append_log("Execution completed successfully")
  rescue => error
    workspace.append_log("Execution failed: #{error.message}")
    agent_assignment.fail
    raise
  end

  private
    def call_llm
      workspace.append_log("Calling Claude API (model: #{model})")

      client = Anthropic::Client.new(api_key: api_key)
      response = client.messages.create(
        model: model,
        max_tokens: max_tokens,
        system: system_message,
        messages: [{ role: "user", content: user_message }]
      )

      extract_text(response)
    end

    def system_message
      parts = []
      parts << agent.system_prompt if agent.system_prompt.present?
      parts << "Your name is #{agent.name}."
      parts << "Your role: #{agent.role_description}" if agent.role_description.present?
      parts << "Your personality: #{agent.personality}" if agent.personality.present?
      parts << "Skills: #{agent.skill_names.join(', ')}" if agent.agent_skills.any?
      parts << "You are working on a task card. Complete the task described below and provide your output."
      parts << "Be thorough but concise. Format your response with clear sections if needed."
      parts.join("\n\n")
    end

    def user_message
      parts = []
      parts << "# Task: #{card.title}" if card.title.present?

      if card.description&.body.present?
        parts << "## Description\n#{card.description.body.to_plain_text}"
      end

      if agent_assignment.instructions.present?
        parts << "## Specific Instructions\n#{agent_assignment.instructions}"
      end

      if card.comments.any?
        parts << "## Discussion"
        card.comments.chronologically.each do |comment|
          parts << "- #{comment.creator.name}: #{comment.body.body.to_plain_text}"
        end
      end

      if card.steps.any?
        parts << "## Checklist"
        card.steps.each do |step|
          status = step.completed? ? "[x]" : "[ ]"
          parts << "#{status} #{step.content}"
        end
      end

      parts.join("\n\n")
    end

    def extract_text(response)
      response.content
        .select { |block| block.type == "text" }
        .map(&:text)
        .join("\n\n")
    end

    def api_key
      ENV.fetch("ANTHROPIC_API_KEY") do
        raise "ANTHROPIC_API_KEY environment variable is required for agent execution"
      end
    end

    def model
      ENV.fetch("ANTHROPIC_MODEL", "claude-sonnet-4-20250514")
    end

    def max_tokens
      ENV.fetch("ANTHROPIC_MAX_TOKENS", "4096").to_i
    end
end
