module Docker
  module Rails
    module CLI
      class Main < Thor
        # default_task :help

        desc 'db_check <db>', 'Runs db_check'
        subcommand 'db_check', Docker::Rails::CLI::DbCheck


        desc 'gems_volume <command>', 'Gems volume management'
        subcommand 'gems_volume', Docker::Rails::CLI::GemsVolume


        desc 'ci <build_name> <environment_name>', 'Execute the works, everything with cleanup included i.e. bundle exec docker-rails all 222 test'
        long_desc <<-D

          `ci` will run the targeted environment_name with the given build number then cleanup everything upon completion.
          While it is named `ci`, there is no harm in using this for other environments as long as you understand that volumes
          and remaining dangling images will be cleaned up upon completion.
        D

        def ci(build_name, environment_name)
          invoke :compose
          invoke CLI::GemsVolume, :create
          invoke :before
          begin
            invoke :up
          ensure
            invoke :stop
            invoke :rm_volumes
            invoke :rm_compose
            invoke :rm_dangling
            invoke :show_all_containers
          end
        end

        desc 'compose <build_name> <environment_name>', 'Writes compose file'

        def compose(build_name, environment_name)
          App.configured(build_name, environment_name).compose
        end

        desc 'before <build_name> <environment_name>', 'Invoke before_command'

        def before(build_name, environment_name)
          invoke :compose
          App.configured(build_name, environment_name).exec_before_command
        end

        desc 'up <build_name> <environment_name>', 'up everything'

        def up(build_name, environment_name)

          invoke CLI::GemsVolume, :create
          invoke :before
          App.configured(build_name, environment_name).exec_up
        end

        desc 'stop <build_name> <environment_name>', 'Stop all running containers'

        def stop(build_name, environment_name)
          invoke :compose
          App.configured(build_name, environment_name).exec_stop
        end

        desc 'rm_volumes <build_name> <environment_name>', 'Stop and remove all running container volumes'

        def rm_volumes(build_name, environment_name)
          invoke :stop
          App.configured(build_name, environment_name).exec_remove_volumes
        end

        desc 'rm_compose', 'Remove generated docker_compose file'

        def rm_compose(build_name = nil, environment_name = nil)
          App.instance.rm_compose
        end

        desc 'rm_dangling', 'Remove danging images'

        def rm_dangling(build_name = nil, environment_name = nil)
          App.instance.rm_dangling
        end

        desc 'show_all_containers', 'Show all remaining containers regardless of state'

        def show_all_containers(build_name = nil, environment_name = nil)
          App.instance.show_all_containers
        end


        # desc 'hello NAME', 'This will greet you'
        # long_desc <<-HELLO_WORLD
        #
        # `hello NAME` will print out a message to the person of your choosing.
        #
        # Brian Kernighan actually wrote the first "Hello, World!" program
        # as part of the documentation for the BCPL programming language
        # developed by Martin Richards. BCPL was used while C was being
        # developed at Bell Labs a few years before the publication of
        # Kernighan and Ritchie's C book in 1972.
        #
        # http://stackoverflow.com/a/12785204
        # HELLO_WORLD
        #
        # option :upcase
        #
        # def hello(name)
        #   greeting = "Hello, #{name}"
        #   greeting.upcase! if options[:upcase]
        #   puts greeting
        # end
      end
    end
  end
end
