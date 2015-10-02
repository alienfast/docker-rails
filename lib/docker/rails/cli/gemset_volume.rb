module Docker
  module Rails
    module CLI
      class GemsetVolume < Thor

        default_task :help

        desc 'create', 'Create a gem volume'
        def create(target = nil)
          App.configured(target, options).create_gems_volume
        end


        # TODO: add destroy volume
      end
    end
  end
end
