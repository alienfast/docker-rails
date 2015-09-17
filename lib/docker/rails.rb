require 'docker/rails/version'

module Docker
  module Rails
  end
end

require 'thor'
require 'docker'

require 'docker/rails/config'
require 'docker/rails/compose_config'
require 'docker/rails/app'

require 'docker/rails/cli/db_check'
require 'docker/rails/cli/gems_volume'

require 'docker/rails/cli/main'
