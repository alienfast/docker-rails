module Docker
  module Rails
    require 'dry/config'
    class Config < Dry::Config::Base

      # environment:
      #   # make ssh keys available via ssh forwarding (see volume entry)
      #   - SSH_AUTH_SOCK=/ssh-agent/socket
      #
      # volumes_from:
      #   # Use configured whilp/ssh-agent long running container for keys
      #   - ssh-agent
      SSH_AGENT_DEFAULT_CONFIG = {
          environment: ['SSH_AUTH_SOCK=/ssh-agent/socket'],
          volumes_from: ['ssh-agent']
      }


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


        # -----------------------------------------------------
        # Generate defaults for GEMSET_VOLUME and SSH_AGENT
        generated_defaults = {compose: {}}
        compose = generated_defaults[:compose]

        # ----
        # ssh-agent
        ssh_agent = config[:'ssh-agent']
        if !ssh_agent.nil?
          ssh_agent[:containers].each do |container|
            raise "Unknown container #{container}" if config[:compose][container.to_sym].nil?
            compose[container.to_sym] ||= {}
            compose[container.to_sym].deeper_merge! ({}.merge SSH_AGENT_DEFAULT_CONFIG)
          end
        end

        # ----
        # gemset volume
        gemset = config[:gemset]
        raise "Expected to find 'gemset:' in #{filenames}" if gemset.nil?

        gemset_name = gemset[:name]
        raise "Expected to find 'gemset: name' in #{filenames}" if gemset_name.nil?

        ENV['DOCKER_RAILS_GEMSET_VOLUME_PATH'] = gemset_volume_path = "/gemset/#{gemset_name}"
        ENV['DOCKER_RAILS_GEMSET_VOLUME_NAME'] = gemset_volume_name = "gemset-#{gemset_name}"

        raise "Expected to find 'gemset: containers' with at least one entry" if gemset[:containers].nil? || gemset[:containers].length < 1
        gemset[:containers].each do |container|
          raise "Unknown container #{container}" if config[:compose][container.to_sym].nil?
          compose[container.to_sym] ||= {}
          compose[container.to_sym].deeper_merge! ({
                                                      environment: ["GEM_HOME=#{gemset_volume_path}"],
                                                      volumes_from: [gemset_volume_name]
                                                  })
        end

        # now add the generated to the seeded default configuration
        @default_configuration.merge!(generated_defaults)

        # reset the base @configuration by loading the new default configuration
        clear

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