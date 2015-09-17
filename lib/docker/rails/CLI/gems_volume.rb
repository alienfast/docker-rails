module Docker
  module Rails
    module CLI
      class GemsVolume < Thor

        default_task :help

        desc 'create', 'Create a gem volume'
        def create
          # Create global gems data volume to cache gems for this version of ruby
          app = App.instance
          begin
            Docker::Container.get(app.gems_volume_name)
            puts "Gem data volume container #{app.gems_volume_name} already exists."
          rescue Docker::Error::NotFoundError => e

            exec "docker create -v #{app.gems_volume_path} --name #{app.gems_volume_path} busybox"
            puts "Gem data volume container #{app.gems_volume_name} created."
          end
        end
      end
    end
  end
end
