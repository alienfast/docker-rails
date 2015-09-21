module Docker
  module Rails
    require 'dry/config'
    class Config < Dry::Config::Base
      def initialize(options = {})
        super({
                  default_configuration: {
                      verbose: false

                  },
                  prune: [:development, :test, :parallel_tests, :staging, :production]
              }.merge(options))
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
        config = load_unpruned(environment, *filenames)
        raise "Unknown target environment '#{environment.to_sym}'" if config[environment.to_sym].nil?

        # finally, load the config as internal state
        super(environment, *filenames)
      end

      def write_docker_compose_file(output_filename = 'docker-compose.yml')
        write_yaml_file(output_filename, self[:'compose'])
      end

      def to_yaml(config = @configuration)
        yaml = super(config)
        yaml = yaml.gsub(/command: .$/, 'command: >')
        yaml
      end
    end
  end
end