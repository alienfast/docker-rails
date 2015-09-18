module Docker
  module Rails
    require 'singleton'
    class App
      include Singleton
      attr_reader :config, :compose_config, :ruby_version, :build, :target, :gems_volume_path, :gems_volume_name, :compose_filename

      class << self
        def configured(target, options)
          app = App.instance
          if app.is_configured?
            # puts "Already configured"
          else
            app.configure(Thor::CoreExt::HashWithIndifferentAccess.new(target: target).merge(options))
          end
          app
        end
      end

      def initialize
        discover_ruby_version
        set_gems_volume_vars
      end

      def configure(options)
        ENV['DOCKER_RAILS_BUILD'] = @build = options[:build]
        @target = options[:target]

        # load the docker-rails.yml
        @config = Docker::Rails::Config.new
        @config.load!(@target)

        @is_configured = true
      end

      def is_configured?
        @is_configured || false
      end

      def compose
        # Write a docker-compose.yml with interpolated variables
        @compose_filename = compose_filename_from @build, @target

        rm_compose

        @config.write_docker_compose_file(@compose_filename)

        @compose_config = Docker::Rails::ComposeConfig.new
        @compose_config.load!(nil, @compose_filename)
      end

      def rm_compose
        # Delete old docker compose files
        exec "rm #{compose_filename_from '*', '*'}" rescue ''
      end

      def exec_before_command
        before_command = @config['before_command']
        (exec before_command unless before_command.nil?) #unless skip? :before_command
      end

      def exec_up(options = '')
        # Run the compose configuration
        exec_compose 'up', false, options #unless skip? :up
      end

      def exec_ps
        # Run the compose configuration
        exec_compose 'ps'
      end

      def exec_stop
        puts "\n\n\n\nStopping containers..."
        puts '-----------------------------'
        @compose_config.each_key do |service_name|
          stop(service_name)
        end
        # puts "\nDone."
      end

      def exec_remove_volumes
        puts "\n\nRemoving container volumes..."
        puts '-----------------------------'
        @compose_config.each_key do |service_name|
          rm_v(service_name)
        end
        # puts "\nDone."
      end

      def rm_dangling
        puts "\n\nCleaning up dangling images..."
        puts '-----------------------------'
        exec 'docker images --filter dangling=true -q | xargs docker rmi'
        # puts "\nDone."
      end

      def show_all_containers
        puts "\n\nAll remaining containers..."
        puts '-----------------------------'
        system 'docker ps -a'
      end

      def exec_bash(service_name)
        # docker exec -it 222_db_1 bash
        container_name = get_container_name(service_name)
        exec "docker exec -it #{container_name} bash"
      end

      protected

      def exec(cmd, capture = false)
        puts "Running `#{cmd}`" if verbose?
        if capture
          output = %x[#{cmd}]
        else
          system cmd
        end

        raise "Failed to execute: `#{cmd}`" unless $?.success?
        output
      end

      # convenience to execute docker-compose with file and project params
      def exec_compose(cmd, capture = false, options = '')
        exec("docker-compose -f #{@compose_filename} -p #{@build} #{cmd} #{options}", capture)
      end

      # service_name i.e. 'db' or 'web'
      def get_container_name(service_name)
        output = exec_compose "ps #{service_name}", true
        # puts "get_container(#{service_name}): \n#{output}"
        output =~ /^(\w+)/ # grab the name, only thing that is at the start of the line
        $1
      end

      # def up_service(service_name, options = '')
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

      # def skip?(command)
      #   skips = @config[:skip]
      #   return false if skips.nil?
      #   skip = skips.include? command.to_s
      #   puts "Skipping #{command}" if skip && verbose?
      #   skip
      # end


      def verbose?
        @verbose ||= (@config['verbose'] unless @config.nil?) || false
      end

      def set_gems_volume_vars
        # Set as variable for interpolation
        ENV['DOCKER_RAILS_GEMS_VOLUME_PATH'] = @gems_volume_path = "/gems/#{@ruby_version}"
        ENV['DOCKER_RAILS_GEMS_VOLUME_NAME'] = @gems_volume_name = "gems-#{@ruby_version}"
      end

      def discover_ruby_version
        # Discover ruby version from the Dockerfile image
        IO.read('Dockerfile') =~ /^FROM \w+\/ruby:(\d+.\d+(?:.\d+))/
        @ruby_version = $1
      end

      # accessible so that we can delete patterns
      def compose_filename_from(build, target)
        "docker-compose-#{target}-#{build}.yml"
      end
    end
  end
end
