module Docker
  module Rails
    module CLI
      class Main < Thor
        # default_task :help

        desc 'db_check <db>', 'Runs db_check'
        subcommand 'db_check', Docker::Rails::CLI::DbCheck


        desc 'gems_volume <command>', 'Gems volume management'
        subcommand 'gems_volume', Docker::Rails::CLI::GemsVolume


        desc 'all <build_name> <environment_name>', 'Execute the works i.e. bundle exec docker-rails all 222 test'

        def all(build_name, environment_name)
          app = App.instance
          app.configure(build_name: build_name, environment_name: environment_name)

          invoke :compose

          CLI::GemsVolume.new.create

          app.exec_before_command
        end

        desc 'compose', 'Writes compose file'

        def compose(build_name, environment_name)
          App.instance.compose
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
