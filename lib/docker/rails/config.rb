module Docker
  module Rails
    require 'dry/config'
    class Config < Dry::Config::Base

      def initialize(options = {})
        raise 'build unspecified' if options[:build].nil?
        build = options[:build]

        raise 'target unspecified' if options[:target].nil?
        target = options[:target]

        # determine project_name
        dir_name = Dir.pwd.split('/').last
        project_name = "#{dir_name}_#{target}_#{build}"

        # FIXME: temporarily sanitize project_name until they loosen restrictions see https://github.com/docker/compose/issues/2119
        project_name = project_name.gsub(/[^a-z0-9]/, '')

        super({
                  default_configuration: {
                      build: build,
                      target: target,
                      project_name: project_name,
                      verbose: false
                  },
                  prune: [:development, :test, :parallel_tests, :staging, :production]
              }.merge(options))
      end


      def write_docker_compose_file(output_filename = 'docker-compose.yml')
        write_yaml_file(output_filename, self[:'compose'])
      end

      def to_yaml(config = @configuration)
        yaml = super(config)
        yaml = yaml.gsub(/command: .$/, 'command: >')
        yaml
      end

      def load!(environment, *filenames)

        # reject nil target environments
        raise 'Target environment unspecified.' if environment.nil?

        # default the filename if unspecified
        if filenames.empty?
          puts 'Using docker-rails.yml'
          filenames = ['docker-rails.yml']
        end

        # reject unknown target environments
        unpruned_config = load_unpruned(environment, *filenames)
        raise "Unknown target environment '#{environment.to_sym}'" if unpruned_config[environment.to_sym].nil?


        # -----------------------------------------------------
        # Generate defaults for GEMSET_VOLUME and SSH_AGENT
        generated_defaults = {compose: {}}
        compose = generated_defaults[:compose]

        # now add the generated to the seeded default configuration
        @default_configuration.merge!(generated_defaults)

        # reset the base @configuration by loading the new default configuration
        clear

        # finally, load the config as internal state
        super(environment, *filenames)
      end
    end
  end
end
