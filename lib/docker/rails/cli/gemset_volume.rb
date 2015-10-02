module Docker
  module Rails
    module CLI
      class GemsetVolume < Thor
        desc 'create', 'Create a gemset volume'
        def create(target = nil)
          App.configured(target, options).create_gemset_volume
        end

        desc 'rm', 'Remove a gemset volume'
        def rm(target = nil)
          App.configured(target, options).rm_gemset_volume
        end
      end
    end
  end
end
