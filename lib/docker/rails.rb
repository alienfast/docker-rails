require 'docker/rails/version'

module Docker
  module Rails
  end
end

require 'thor'
require 'docker'
require 'archive/tar/minitar'

require 'docker/rails/ext/hash'
require 'docker/rails/ext/container'

require 'docker/rails/config'
require 'docker/rails/compose_config'
require 'docker/rails/app'

require 'docker/rails/cli/db_check'
require 'docker/rails/cli/gemset_volume'
require 'docker/rails/cli/ssh_agent'

require 'docker/rails/cli/main'
