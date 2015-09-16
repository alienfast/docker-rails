require 'docker/rails'

Docker::Rails::CLI.start( ARGV )

# compose cli
#   https://docs.docker.com/v1.6/compose/cli/#environment-variables

# compose yml
#   https://docs.docker.com/v1.6/compose/yml/

# remote api
#   https://docs.docker.com/reference/api/docker_remote_api_v1.20


# docker-compose -f docker-compose-build-119.yml -p 119 up -d db
# docker-compose -f docker-compose-build-119.yml -p 119 up  web


exe_env = 'test'
BUILD_NAME = '204' # temp should be passed in
ENV['BUILD_NAME'] = BUILD_NAME

# Discover ruby version from the Dockerfile image
IO.read('Dockerfile') =~ /^FROM \w+\/ruby:(\d+.\d+(?:.\d+))/
BUILD_RUBY_VERSION = $1

# Set as variable for interpolation
GEMS_VOLUME_PATH = "/gems/#{BUILD_RUBY_VERSION}"
GEMS_VOLUME_NAME = "gems-#{BUILD_RUBY_VERSION}"
ENV['GEMS_VOLUME_PATH'] = GEMS_VOLUME_PATH
ENV['GEMS_VOLUME_NAME'] = GEMS_VOLUME_NAME


# Read docker-compose.yml and rewrite with interpolated variables and BUILD_NAME
COMPOSE_FILENAME = "docker-compose-build-#{BUILD_NAME}.yml"
# compose_config = Docker::Rails::ComposeConfig.interpolate_file(COMPOSE_FILENAME)
docker_rails_config = Docker::Rails::Config.new
docker_rails_config.load!(exe_env)

VERBOSE = docker_rails_config['verbose'] || false

def exec(cmd, capture = false)
  puts "Running `#{cmd}`" if VERBOSE
  if capture
    output = %x[#{cmd}]
  else
    system cmd
  end

  raise "Failed to execute: `#{cmd}`" unless $?.success?
  output
end

# Delete old docker compose files
exec 'rm docker-compose-build-*.yml' rescue ''

docker_rails_config.write_docker_compose_file(COMPOSE_FILENAME)

DOCKER_RAILS_CONFIG = docker_rails_config

compose_config = Docker::Rails::ComposeConfig.new
compose_config.load!(nil, COMPOSE_FILENAME)


# -----------
# Create global gems data volume to cache gems for this version of ruby
#
#   Docker::Container.create('name' => 'foo-gems-2.2.2', 'Image' => 'busybox', 'Mounts' => [ { 'Destination' => '/gems/2.2.2' } ])
#
require 'docker'
begin
  Docker::Container.get(GEMS_VOLUME_NAME)
  puts "Gem data volume container #{GEMS_VOLUME_NAME} already exists."
rescue Docker::Error::NotFoundError => e

  exec "docker create -v #{GEMS_VOLUME_PATH} --name #{GEMS_VOLUME_NAME} busybox"
  puts "Gem data volume container #{GEMS_VOLUME_NAME} created."
end
# gems_container.streaming_logs(stdout: true) { |stream, chunk| puts "#{GEMS_VOLUME_NAME}: #{chunk}" }

# convenience to execute docker-compose with file and project params
def exec_compose(cmd, capture = false)
  exec("docker-compose -f #{COMPOSE_FILENAME} -p #{BUILD_NAME} #{cmd}", capture)
end

# service_name i.e. 'db' or 'web'
def get_container_name(service_name)
  output = exec_compose "ps #{service_name}", true
  # puts "get_container(#{service_name}): \n#{output}"
  output =~ /^(\w+)/ # grab the name, only thing that is at the start of the line
  $1
end

# def up(service_name, options = '')
#   exec_compose "up #{options} #{service_name}"
#   container_name = get_container_name(service_name)
#   puts "#{service_name}: container_name #{container_name}"
#
#   container = Docker::Container.get(container_name)
#   # container.streaming_logs(stdout: true) { |stream, chunk| puts "#{service_name}: #{chunk}" }
#   # puts container
#
#   {service_name => {'container' => container, 'container_name' => container_name}}
# end

def rm_v(service_name)
  exec_compose "rm -v --force #{service_name}"
end

def stop(service_name)
  exec_compose "stop #{service_name}"
end

def skip?(command)
  skips = DOCKER_RAILS_CONFIG[:skip]
  return false if skips.nil?
  skip = skips.include? command.to_s # FIXME hack constant to be able to access config
  puts "Skipping #{command}" if skip && VERBOSE
  skip
end

# check before command
before_command = docker_rails_config['before_command']
(exec before_command unless before_command.nil?) unless skip? :before_command

containers = {}
begin
  # Run the compose configuration
  exec_compose 'up' unless skip? :up

ensure
  unless skip? :stop
    puts "\n\n\n\nStopping containers..."
    puts '-----------------------------'
    compose_config.each_key do |service_name|
      stop(service_name)
    end
    # puts "\nDone."
  end

  unless skip? :extract
    puts "\n\n\n\nExtracting container results..."
    puts '-----------------------------'
    # containers.each_pair do |service_name, values|
    #   container = values['container']
    #   container_name = values['container_name']
    #   puts "Extracting for #{service_name} from #{container_name}"
    # end
  end

  unless skip? :remove_volumes
    puts "\n\nRemoving container volumes..."
    puts '-----------------------------'
    compose_config.each_key do |service_name|
      rm_v(service_name)
    end
    # puts "\nDone."
  end

  unless skip? :remove_compose
    # cleanup build interpolated docker-compose.yml
    File.delete COMPOSE_FILENAME if File.exists? COMPOSE_FILENAME
  end

  unless skip? :remove_dangling
    puts "\n\nCleaning up dangling images..."
    puts '-----------------------------'
    exec 'docker images --filter dangling=true -q | xargs docker rmi'
    # puts "\nDone."
  end

  unless skip? :remaining_containers
    puts "\n\nRemaining containers on host..."
    puts '-----------------------------'
    system 'docker ps -a'
  end
end