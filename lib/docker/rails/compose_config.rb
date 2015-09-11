module Docker
  module Rails
    require 'dry/config'
    class ComposeConfig < Dry::Config::Base
      class << self
        def interpolate_file(output_filename, input_filename = 'docker-compose.yml')
          compose = ComposeConfig.new(symbolize: false)
          compose.load!(nil, input_filename)
          compose.write_yaml_file(output_filename)
          compose
        end
      end
    end
  end
end
