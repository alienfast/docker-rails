module Docker
  module Rails
    module CLI
      class Main < Thor
        # default_task :help

        class_option :build, aliases: ['-b'], type: :string, desc: 'Build name e.g. 123.  Can also be specified as environment variable DOCKER_RAILS_BUILD', default: '1'

        desc 'db_check <db>', 'Runs db_check e.g. bundle exec docker-rails db_check mysql'
        subcommand 'db_check', Docker::Rails::CLI::DbCheck

        desc 'gems_volume <command>', 'Gems volume management e.g. bundle exec docker-rails gems_volume create'
        subcommand 'gems_volume', Docker::Rails::CLI::GemsVolume

        desc 'ci <target>', 'Execute the works, everything with cleanup included e.g. bundle exec docker-rails ci --build=222 test'
        long_desc <<-D

          `ci` will run the target with the given build (-b) number then cleanup everything upon completion.
          While it is named `ci`, there is no harm in using this for other environments as long as you understand that volumes
          and remaining dangling images will be cleaned up upon completion.
        D

        def ci(target)
          # init singleton with full options
          App.configured(target, options)

          invoke :before, [target], []
          invoke :compose, [target], []
          invoke CLI::GemsVolume, :create, [target], options
          begin
            invoke :build # on CI - always build to ensure dockerfile hasn't been altered - small price to pay for consistent CI.
            invoke :up
          ensure
            invoke :cleanup
          end
        end

        desc 'cleanup <target>', 'Runs container cleanup functions stop, rm_volumes, rm_compose, rm_dangling, ps_all e.g. bundle exec docker-rails cleanup --build=222 development'
        def cleanup(target)
          invoke :stop
          invoke :rm_volumes
          invoke :rm_compose
          invoke :rm_dangling
          invoke :ps_all
        end

        desc 'up <target>', 'Up the docker-compose configuration for the given build/target. Use -d for detached mode. e.g. bundle exec docker-rails up -d --build=222 test'

        option :detached, aliases: ['-d'], type: :boolean, desc: 'Detached mode: Run containers in the background'

        def up(target)
          # init singleton with full options
          app = App.configured(target, options)
          base_options = options.except(:detached)

          invoke :before, [target], base_options
          invoke CLI::GemsVolume, :create, [target], base_options

          compose_options = ''
          compose_options = '-d' if options[:detached]

          app.exec_up(compose_options)
        end

        desc 'build <target>', 'Build for the given build/target e.g. bundle exec docker-rails build --build=222 development'

        def build(target)
          invoke :compose
          App.configured(target, options).exec_build
        end


        desc 'compose <target>', 'Writes a resolved docker-compose.yml file e.g. bundle exec docker-rails compose --build=222 test'

        def compose(target)
          App.configured(target, options).compose
        end

        desc 'before <target>', 'Invoke before_command', hide: true

        def before(target)
          app = App.configured(target, options)
          invoke :compose, [target], []
          app.exec_before_command
        end


        desc 'stop <target>', 'Stop all running containers for the given build/target e.g. bundle exec docker-rails stop --build=222 development'

        def stop(target)
          invoke :compose
          App.configured(target, options).exec_stop
        end

        desc 'rm_volumes <target>', 'Stop all running containers and remove corresponding volumes for the given build/target e.g. bundle exec docker-rails rm_volumes --build=222 development'

        def rm_volumes(target)
          invoke :stop
          App.configured(target, options).exec_remove_volumes
        end

        desc 'rm_compose', 'Remove generated docker_compose file e.g. bundle exec docker-rails rm_compose --build=222 development', hide: true

        def rm_compose(build = nil, target = nil)
          App.instance.rm_compose
        end

        desc 'rm_dangling', 'Remove danging images e.g. bundle exec docker-rails rm_dangling'

        def rm_dangling(build = nil, target = nil)
          App.instance.rm_dangling
        end

        desc 'ps <target>', 'List containers for the target compose configuration e.g. bundle exec docker-rails ps --build=222 development'

        def ps(target)
          invoke :compose
          App.configured(target, options).exec_ps
        end

        desc 'ps_all', 'List all remaining containers regardless of state e.g. bundle exec docker-rails ps_all'

        def ps_all(build = nil, target = nil)
          App.instance.show_all_containers
        end

        desc 'bash_connect <target> <service_name>', 'Open a bash shell to a running container e.g. bundle exec docker-rails bash --build=222 development db'

        def bash_connect(target, service_name)
          # init singleton with full options
          app = App.configured(target, options)

          invoke :compose, [target], []

          app.exec_bash_connect(service_name)
        end


        desc 'exec <target> <service_name> <command>', 'Run an arbitrary command on a given service container e.g. bundle exec docker-rails exec --build=222 development db bash'

        def exec(target, service_name, command)
          # init singleton with full options
          app = App.configured(target, options)

          invoke :compose, [target], []

          app.exec_run(service_name, command)
        end


        protected

        # invoke with an empty set of options
        # def invoke_new(command, options=[])
        #   invoke command, nil, options
        # end
      end
    end
  end
end
