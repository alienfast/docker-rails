require 'docker/rails/version'

module Docker
  module Rails
  end
end

require 'docker/rails/config'
require 'docker/rails/compose_config'
require 'docker/rails/cli/db_check'

require 'docker/rails/cli/main'
