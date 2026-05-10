class Agent::ContainerManager
  WORKSPACE_PATH = "/home/agent/workspace"
  DEFAULT_IMAGE = "curioarch-agent-workspace:latest"

  attr_reader :workspace

  delegate :agent_assignment, :agent, to: :workspace

  def initialize(workspace)
    @workspace = workspace
  end

  def provision
    workspace.update!(
      volume_name: generate_volume_name,
      container_name: generate_container_name,
      container_image: DEFAULT_IMAGE,
      container_status: :provisioned
    )

    create_volume
    workspace.append_log("Volume provisioned: #{workspace.volume_name}")
  end

  def start
    raise "Container not provisioned" unless workspace.provisioned? || workspace.stopped?

    container_id = run_container
    workspace.update!(
      container_id: container_id,
      container_status: :running,
      container_started_at: Time.current,
      container_stopped_at: nil
    )

    workspace.append_log("Container started: #{workspace.container_name}")
    container_id
  end

  def stop
    return unless workspace.running?

    docker("stop", workspace.container_name, timeout: 30)
    docker("rm", workspace.container_name)

    workspace.update!(
      container_id: nil,
      container_status: :stopped,
      container_stopped_at: Time.current
    )

    workspace.append_log("Container stopped")
  end

  def destroy
    stop if workspace.running?
    docker("volume", "rm", workspace.volume_name) if workspace.volume_name.present?
    workspace.update!(container_status: :destroyed)
    workspace.append_log("Workspace destroyed")
  end

  def exec(command)
    raise "Container not running" unless workspace.running?

    stdout, stderr, status = docker_capture(
      "exec", workspace.container_name,
      "bash", "-c", command
    )

    { stdout: stdout, stderr: stderr, exit_code: status.exitstatus }
  end

  def copy_from(container_path, local_path)
    docker("cp", "#{workspace.container_name}:#{container_path}", local_path)
  end

  def copy_to(local_path, container_path)
    docker("cp", local_path, "#{workspace.container_name}:#{container_path}")
  end

  def running?
    return false unless workspace.container_name.present?

    output, _, status = docker_capture("inspect", "-f", "{{.State.Running}}", workspace.container_name)
    status.success? && output.strip == "true"
  rescue
    false
  end

  private
    def run_container
      output, _, status = docker_capture(
        "run", "-d",
        "--name", workspace.container_name,
        "--hostname", workspace.container_name,
        "-v", "#{workspace.volume_name}:#{WORKSPACE_PATH}",
        "--memory", memory_limit,
        "--cpus", cpu_limit,
        "--network", "none",
        workspace.container_image
      )

      raise "Failed to start container" unless status.success?
      output.strip
    end

    def create_volume
      docker("volume", "create", workspace.volume_name)
    end

    def generate_volume_name
      "curioarch-agent-#{agent.id[0..7]}-#{workspace.id[0..7]}"
    end

    def generate_container_name
      "curioarch-agent-#{agent.id[0..7]}-#{workspace.id[0..7]}"
    end

    def memory_limit
      ENV.fetch("AGENT_CONTAINER_MEMORY", "512m")
    end

    def cpu_limit
      ENV.fetch("AGENT_CONTAINER_CPUS", "0.5")
    end

    def docker(*args, timeout: 60)
      system("docker", *args.map(&:to_s), exception: true)
    end

    def docker_capture(*args)
      Open3.capture3("docker", *args.map(&:to_s))
    end
end
