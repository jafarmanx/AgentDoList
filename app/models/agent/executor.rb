class Agent::Executor
  MAX_ITERATIONS = 25
  TOOL_DEFINITIONS = [
    {
      name: "execute_command",
      description: "Execute a shell command in the agent's workspace container. Use this to run Python scripts, install packages, run tests, or any other command-line operation.",
      input_schema: {
        type: "object",
        properties: {
          command: { type: "string", description: "The shell command to execute" }
        },
        required: ["command"]
      }
    },
    {
      name: "write_file",
      description: "Write content to a file in the workspace. Creates parent directories automatically.",
      input_schema: {
        type: "object",
        properties: {
          path: { type: "string", description: "File path relative to /home/agent/workspace" },
          content: { type: "string", description: "The file content to write" }
        },
        required: ["path", "content"]
      }
    },
    {
      name: "read_file",
      description: "Read the contents of a file in the workspace.",
      input_schema: {
        type: "object",
        properties: {
          path: { type: "string", description: "File path relative to /home/agent/workspace" }
        },
        required: ["path"]
      }
    },
    {
      name: "list_files",
      description: "List files and directories in the workspace.",
      input_schema: {
        type: "object",
        properties: {
          path: { type: "string", description: "Directory path relative to /home/agent/workspace. Defaults to root." }
        },
        required: []
      }
    },
    {
      name: "task_complete",
      description: "Call this when the task is fully completed. Provide a summary of what was accomplished and any deliverables.",
      input_schema: {
        type: "object",
        properties: {
          summary: { type: "string", description: "A summary of what was accomplished" },
          deliverable_paths: {
            type: "array",
            items: { type: "string" },
            description: "List of file paths (relative to workspace) that are the deliverables"
          }
        },
        required: ["summary"]
      }
    }
  ].freeze

  attr_reader :agent_assignment, :container_manager

  delegate :agent, :card, :workspace, to: :agent_assignment

  def initialize(agent_assignment)
    @agent_assignment = agent_assignment
    @container_manager = Agent::ContainerManager.new(workspace)
    @messages = []
  end

  def execute
    agent_assignment.start
    workspace.update!(status: :working)
    workspace.append_log("Starting agentic execution")

    Agent::Orchestrator.claim_slot!(workspace)
    run_agent_loop

    agent_assignment.complete
    workspace.append_log("Execution completed successfully")
  rescue Agent::Orchestrator::NoSlotAvailable => error
    workspace.append_log("No container slot available, requeueing")
    agent_assignment.update!(status: :pending, started_at: nil)
    raise
  rescue => error
    workspace.append_log("Execution failed: #{error.message}")
    agent_assignment.fail
    raise
  ensure
    Agent::Orchestrator.release_slot(workspace)
    Agent::Orchestrator.process_queue
  end

  private
    def run_agent_loop
      @messages = [{ role: "user", content: user_message }]

      MAX_ITERATIONS.times do |iteration|
        workspace.append_log("Iteration #{iteration + 1}")

        response = call_llm
        assistant_content = response.content

        text_parts = assistant_content.select { |b| b.type == "text" }.map(&:text)
        tool_uses = assistant_content.select { |b| b.type == "tool_use" }

        if text_parts.any?
          workspace.append_log("Agent: #{text_parts.join(' ').truncate(200)}")
        end

        @messages << { role: "assistant", content: serialize_content(assistant_content) }

        if response.stop_reason == "end_turn" || tool_uses.empty?
          workspace.update!(output: text_parts.join("\n\n")) if text_parts.any?
          workspace.append_log("Agent finished (no more tool calls)")
          return
        end

        tool_results = tool_uses.map do |tool_use|
          result = handle_tool_use(tool_use)

          if tool_use.name == "task_complete"
            return
          end

          { type: "tool_result", tool_use_id: tool_use.id, content: result }
        end

        @messages << { role: "user", content: tool_results }
      end

      workspace.append_log("Reached max iterations (#{MAX_ITERATIONS})")
      workspace.update!(output: "Agent reached maximum iterations without completing. Check the work log for details.")
    end

    def handle_tool_use(tool_use)
      name = tool_use.name
      input = tool_use.input.is_a?(Hash) ? tool_use.input : tool_use.input.to_h

      workspace.append_log("Tool: #{name}(#{input.except('content').to_json.truncate(150)})")

      case name
      when "execute_command"
        handle_execute_command(input)
      when "write_file"
        handle_write_file(input)
      when "read_file"
        handle_read_file(input)
      when "list_files"
        handle_list_files(input)
      when "task_complete"
        handle_task_complete(input)
      else
        "Unknown tool: #{name}"
      end
    rescue => error
      "Error: #{error.message}"
    end

    def handle_execute_command(input)
      result = container_manager.exec(input["command"])
      output = ""
      output += result[:stdout] if result[:stdout].present?
      output += "\nSTDERR: #{result[:stderr]}" if result[:stderr].present?
      output += "\nExit code: #{result[:exit_code]}"
      output.truncate(10_000)
    end

    def handle_write_file(input)
      path = sanitize_path(input["path"])
      content = input["content"]

      container_manager.exec("mkdir -p $(dirname '#{path}')")
      container_manager.exec("cat > '#{path}' << 'CURIOARCH_EOF'\n#{content}\nCURIOARCH_EOF")

      "File written: #{path}"
    end

    def handle_read_file(input)
      path = sanitize_path(input["path"])
      result = container_manager.exec("cat '#{path}'")

      if result[:exit_code] == 0
        result[:stdout].truncate(10_000)
      else
        "File not found: #{path}"
      end
    end

    def handle_list_files(input)
      path = sanitize_path(input.fetch("path", "."))
      result = container_manager.exec("find '#{path}' -maxdepth 2 -type f -o -type d | head -100")

      result[:stdout].presence || "Directory empty or not found"
    end

    def handle_task_complete(input)
      summary = input["summary"]
      deliverable_paths = input.fetch("deliverable_paths", [])

      workspace.update!(output: summary)
      workspace.append_log("Task completed: #{summary.truncate(200)}")

      collect_deliverables(deliverable_paths)

      "Task marked as complete"
    end

    def collect_deliverables(paths)
      Dir.mktmpdir do |tmpdir|
        paths.each do |path|
          safe_path = sanitize_path(path)
          local_path = File.join(tmpdir, File.basename(safe_path))

          container_manager.copy_from(
            "#{Agent::ContainerManager::WORKSPACE_PATH}/#{safe_path}",
            local_path
          )

          if File.exist?(local_path)
            workspace.deliverables.attach(
              io: File.open(local_path),
              filename: File.basename(safe_path)
            )
            workspace.append_log("Deliverable collected: #{File.basename(safe_path)}")
          end
        rescue => error
          workspace.append_log("Failed to collect deliverable #{path}: #{error.message}")
        end
      end
    end

    def sanitize_path(path)
      Pathname.new(path).cleanpath.to_s.delete_prefix("/")
    end

    def serialize_content(content_blocks)
      content_blocks.map do |block|
        case block.type
        when "text"
          { type: "text", text: block.text }
        when "tool_use"
          input = block.input.is_a?(Hash) ? block.input : block.input.to_h
          { type: "tool_use", id: block.id, name: block.name, input: input }
        else
          { type: block.type }
        end
      end
    end

    def call_llm
      client = Anthropic::Client.new(api_key: api_key)
      client.messages.create(
        model: model,
        max_tokens: max_tokens,
        system: system_message,
        tools: TOOL_DEFINITIONS,
        messages: @messages
      )
    end

    def system_message
      parts = []
      parts << agent.system_prompt if agent.system_prompt.present?
      parts << "Your name is #{agent.name}."
      parts << "Your role: #{agent.role_description}" if agent.role_description.present?
      parts << "Your personality: #{agent.personality}" if agent.personality.present?
      parts << "Skills: #{agent.skill_names.join(', ')}" if agent.agent_skills.any?

      parts << <<~INSTRUCTIONS
        You are an autonomous AI agent working in a Docker container with a Python environment.
        You have a workspace at /home/agent/workspace where you can create files, run code, and produce deliverables.

        Available tools:
        - execute_command: Run any shell command (python, pip, git, curl, etc.)
        - write_file: Create or overwrite files in your workspace
        - read_file: Read file contents
        - list_files: Browse your workspace directory
        - task_complete: Call this when done, with a summary and list of deliverable file paths

        Work autonomously. Plan your approach, execute it step by step, verify your work, then call task_complete.
        If something fails, debug and retry. You have full control over your workspace.
      INSTRUCTIONS

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
