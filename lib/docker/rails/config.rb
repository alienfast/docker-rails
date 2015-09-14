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
          puts 'Environment unspecified, generating based on root docker-compose key.'
          environment = 'docker-compose'
        end

        if filenames.empty?
          puts 'Environment unspecified, using docker-rails.yml'
          filenames = ['docker-rails.yml']
        end

        super(environment, *filenames)
      end
    end
  end
end