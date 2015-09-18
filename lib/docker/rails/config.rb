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
        if environment.nil?
          puts 'Environment unspecified, generating docker-compose.yml based on root :compose yaml key.'
          environment = 'docker-compose'
        end

        if filenames.empty?
          puts 'Using docker-rails.yml'
          filenames = ['docker-rails.yml']
        end

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