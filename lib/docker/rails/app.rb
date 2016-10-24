module Docker
  module Rails
    require 'singleton'
    class App
      include Singleton
      attr_reader :config,
                  :compose_config,
                  :compose_filename,
                  :exit_code

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
      end

      def configure(options)
        # Allow CLI option `build` to fallback to an env variable DOCKER_RAILS_BUILD.  Note that CLI provides a default build value of 1, so check against the default and existence of the env var.
        build = options[:build]
        build = ENV['DOCKER_RAILS_BUILD'] if build.to_i == 1 && !ENV['DOCKER_RAILS_BUILD'].nil?
        ENV['DOCKER_RAILS_BUILD'] = build

        target = options[:target]

        # load the docker-rails.yml
        @config = Docker::Rails::Config.new({build: build, target: target})
        @config.load!(target)
        @is_configured = true
      end

      # Create a dockito vault container for serving private keys
      #     https://github.com/dockito/vault
      def create_dockito_vault
        begin
          Docker::Container.get(dockito_vault_name)
          puts "Dockito vault container #{dockito_vault_name} already exists."
        rescue Docker::Error::NotFoundError => e

          # docker run --detach --name vault -p 14242:3000 -v ~/.ssh:/vault/.ssh dockito/vault:latest
          exec "docker run --detach --name #{dockito_vault_name} -p 14242:3000 -v ~/.ssh:/vault/.ssh dockito/vault:latest"
          puts "Dockito vault container #{dockito_vault_name} created."
        end
      end

      def rm_dockito_vault
        begin
          container = Docker::Container.get(dockito_vault_name)
          rm_v(container)
        rescue Docker::Error::NotFoundError => e
          puts "Dockito vault container #{dockito_vault_name} does not exist."
        end
      end

      # FIXME this needs to by dynamic to this run?
      def dockito_vault_name
        'vault' #@config[:dockito][:vault][:name]
      end

      def dockito_vault_enabled?
        @config[:dockito][:vault] || false
      end


      def compose
        # Write a docker-compose.yml with interpolated variables
        @compose_filename = compose_filename_from project_name

        rm_compose

        @config.write_docker_compose_file(@compose_filename)

        @compose_config = Docker::Rails::ComposeConfig.new
        @compose_config.load!(nil, @compose_filename)

        # check the exit_code
        if @config['exit_code'].nil?
          first_defined_service = @compose_config.services.keys[0]
          puts "exit_code not set in configuration, using exit code from first defined service: #{first_defined_service}"
          @config['exit_code'] = first_defined_service
        end
      end

      def is_configured?
        @is_configured || false
      end

      def extract_all

        # For each container, process extractions
        #  Containers are defined in compose, extractions are defined at root under container name e.g.:
        #     web:
        #         extract:
        #         - '<from_container>:<to_host>'
        #         - '/project/target:.'
        #         - '/project/vcr'      # same as extract to '.'
        #         - '/project/tmp'
        #         - '/project/spec/dummy/log:spec/dummy'
        #         - '/project/tmp/parallel_runtime_cucumber.log:./tmp'
        #         - '/project/tmp/parallel_runtime_rspec.log:./tmp'

        @compose_config.services.each_key do |service_name|
          service_config = @config[service_name]
          extractions = service_config[:extract] unless service_config.nil?
          next if extractions.nil?

          puts "\n\nProcessing extract for #{service_name}:"
          puts '---------------------------------'
          container = get_container(service_name) rescue nil
          if container.nil?
            puts 'none.'
            next
          end

          extract(container, service_name, extractions)
        end
      end

      def extract(container, service_name, extractions)
        extractions.each do |extraction|
          if extraction =~ /:/
            tokens = extraction.split(':')
            from = tokens[0]
            to = tokens[1]
          else
            from = extraction
            to = '.'
          end

          puts "\nExtracting #{service_name} #{from} to #{to}"
          begin
            extract_files(container, from, to)
          rescue => e
            puts e.message
          end
        end
      end

      def rm_compose
        # Delete old docker compose files
        exec "rm #{compose_filename_from '*'}" rescue ''
      end

      def before_command
        before_command = @config['before_command']
        (exec before_command unless before_command.nil?)
      end

      def after_build_command
        after_build_command = @config['after_build_command']
        (exec after_build_command unless after_build_command.nil?)
      end

      def up(options = '')
        # Run the compose configuration
        exec_compose 'up', false, options #unless skip? :up
      end

      def down(options = '')
        # `compose down` doesn't support force removing images, so we use `rm --force`
        exec_compose 'rm', '--force --all -v'

        # Stop and remove all the linked services and network
        exec_compose 'down', false, options
      end

      def compose_build
        # Run the compose configuration
        exec_compose 'build'
      end

      def ps
        # Run the compose configuration
        exec_compose 'ps'
      end

      def ps_all
        puts "\n\nAll remaining containers..."
        puts '-----------------------------'
        exec 'docker ps -a'
      end

      # def stop_all
      #   puts "\n\n\n\nStopping containers..."
      #   puts '-----------------------------'
      #   containers = Docker::Container.all(all: true)
      #   containers.each do |container|
      #     if is_project_container?(container)
      #       stop(container)
      #
      #       service_name = container.compose.service
      #       if @config['exit_code'].eql?(service_name)
      #         if container.up?
      #           puts "Unable to determine exit code, the #{service_name} is still up, current status: #{container.status}"
      #           @exit_code = -999
      #         else
      #           @exit_code = container.exit_code
      #         end
      #       end
      #     end
      #   end
      #   puts 'Done.'
      # end

      # def rm_volumes
      #   puts "\n\nRemoving container volumes..."
      #   puts '-----------------------------'
      #
      #   # http://docs.docker.com/v1.7/reference/api/docker_remote_api_v1.19/#remove-a-container
      #   containers = Docker::Container.all(all: true)
      #   containers.each do |container|
      #     if is_project_container?(container)
      #       puts container.name
      #       rm_v(container)
      #     end
      #   end
      #   puts 'Done.'
      # end

      def rm_dangling
        puts "\n\nCleaning up dangling images..."
        puts '-----------------------------'

        list_images_cmd = 'docker images --filter dangling=true -q'
        output = exec(list_images_cmd, true)

        # if there are any dangling, let's clean them up.
        exec("#{list_images_cmd} | xargs docker rmi", false, true) if !output.nil? && output.length > 0
        puts 'Done.'
      end

      def rm_exited
        puts "\n\nCleaning up exited containers..."
        puts '-----------------------------'

        exec('docker rm -v $(docker ps -a -q -f status=exited)', false, true)
        puts 'Done.'
      end

      def run_service_command(service_name, command)
        # Run the compose configuration
        exec_compose("run #{service_name} #{command}", false, '', true)
      end

      def bash_connect(service_name)
        # docker exec -it 2ed97d0bb938 bash
        container = get_container(service_name)
        if container.nil?
          puts "#{service_name} does not appear to be running for build #{build}"
          return
        end

        exec "docker exec -it #{container.id} bash"
        container
      end

      protected

      def exec(cmd, capture = false, ignore_errors = false)
        puts "Running `#{cmd}`" if verbose?
        if capture
          output = %x[#{cmd}]
        else
          system cmd
        end

        (raise "Failed to execute: `#{cmd}`" unless $?.success?) unless ignore_errors
        output
      end

# convenience to execute docker-compose with file and project params
      def exec_compose(cmd, capture = false, options = '', ignore_errors = false)
        # in the case of running a bash session, this file may dissappear, just make sure it is there.
        compose unless File.exists?(@compose_filename)

        exec("docker-compose -f #{@compose_filename} -p #{project_name} #{cmd} #{options}", capture, ignore_errors)
      end

      def get_container(service_name)
        containers = Docker::Container.all(all: true)
        containers.each do |container|
          if is_project_container?(container) && container.compose.service.eql?(service_name.to_s)
            return container
          end
        end

        nil
      end

      def is_project_container?(container)
        # labels = container.info['Labels']
        # build = labels['com.docker.compose.project']

        return false if container.compose.nil?
        return true if project_name.eql? container.compose.project
        false
      end

      def verbose?
        @verbose ||= (@config['verbose'] unless @config.nil?) || false
      end

# accessible so that we can delete patterns
      def compose_filename_from(project_name)
        "docker-compose-#{project_name}.yml"
      end

      def extract_files(container, from, to)
        # or something like
        tar_stringio = StringIO.new
        container.copy(from) do |chunk|
          tar_stringio.write(chunk)
        end

        tar_stringio.rewind

        input = Archive::Tar::Minitar::Input.new(tar_stringio)
        input.each { |entry|

          # Need to check the file name length to prevent some very bad things from happening.
          if entry.full_name.length > 255
            puts "ERROR - file name length is > 255 characters: #{entry.full_name}"
          elsif entry.full_name.length <= 0
            puts "ERROR - file name length is too small: #{entry.full_name}"
          else
            puts "Extracting #{entry.full_name}"
            input.extract_entry(to, entry)
          end
        }
      end

      def stop(container)
        printf "#{container.name}.."

        # Stop it
        container.stop
        60.times do |i|
          printf '.'
          if container.down?
            printf "done.\n"
            break
          end
          sleep 1
        end

        # kill it if necessary
        kill(container)
      end

# kill container, progressively more forceful from -1, -9, then full Chuck Norris.
      def kill(container)
        %w(SIGHUP SIGKILL SIGSTOP).each do |signal|
          if container.up?
            printf "killing(#{signal})"
            container.kill(signal: signal)
            10.times do |i|
              printf '.'
              if container.down?
                printf "done.\n"
                break
              end
              sleep 1
            end
          end
        end
      end

      def rm_v(container)
        container.remove(v: true, force: true)
      end

      def project_name
        @config[:project_name]
      end

      def build
        @config[:build]
      end

      def target
        @config[:target]
      end
    end
  end
end
