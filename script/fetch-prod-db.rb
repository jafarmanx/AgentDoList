#!/usr/bin/env ruby
require "tmpdir"
require "fileutils"
require "open3"

if ARGV.size != 1
  warn "Usage: #{$PROGRAM_NAME} TENANT_ID"
  exit 1
end

tenant_id = ARGV[0]

app_host = ENV.fetch("PROD_APP_HOST") do
  abort "ERROR: Set PROD_APP_HOST to the production server hostname (e.g. app-101.example.com)"
end
container_prefix = ENV.fetch("PROD_CONTAINER_PREFIX", "curio-arch-web-production")
ssh_user = ENV.fetch("PROD_SSH_USER", "app")

# Automatically detect the web production container
puts "→ Detecting #{container_prefix} container on #{app_host}..."
container_output, status = Open3.capture2(%(ssh #{ssh_user}@#{app_host} "docker ps --format '{{.Names}}' | grep #{container_prefix}"))
abort("Failed to detect container") unless status.success?

CONTAINER = container_output.strip
abort("No #{container_prefix} container found") if CONTAINER.empty?
puts "→ Using container: #{CONTAINER}"

REMOTE_PATH = "/rails/storage/tenants/production/#{tenant_id}/db/main.sqlite3.1"

Dir.mktmpdir do |tmpdir|
  local_file = File.join(tmpdir, "main.sqlite3")

  puts "→ Copying #{REMOTE_PATH} from container to #{local_file}"
  cmd = %(ssh #{ssh_user}@#{app_host} "docker cp #{CONTAINER}:#{REMOTE_PATH} -" | tar -xOf - > #{local_file})
  system(cmd) or abort("Failed to copy database file")

  puts "→ Running script/load-prod-db-in-dev.rb with #{local_file}"
  exec("bundle", "exec", "ruby", "script/load-prod-db-in-dev.rb", local_file)
end
