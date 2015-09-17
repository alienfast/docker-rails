# @compose_config = Docker::Rails::ComposeConfig.interpolate_file(@compose_filename)



containers = {}
begin
  # Run the compose configuration
  exec_compose 'up' unless skip? :up

ensure
  unless skip? :stop
    puts "\n\n\n\nStopping containers..."
    puts '-----------------------------'
    @compose_config.each_key do |service_name|
      stop(service_name)
    end
    # puts "\nDone."
  end

  unless skip? :extract
    puts "\n\n\n\nExtracting container results..."
    puts '-----------------------------'
    # containers.each_pair do |service_name, values|
    #   container = values['container']
    #   container_name = values['container_name']
    #   puts "Extracting for #{service_name} from #{container_name}"
    # end
  end

  unless skip? :remove_volumes
    puts "\n\nRemoving container volumes..."
    puts '-----------------------------'
    @compose_config.each_key do |service_name|
      rm_v(service_name)
    end
    # puts "\nDone."
  end

  unless skip? :remove_compose
    # cleanup build interpolated docker-compose.yml
    File.delete @compose_filename if File.exists? @compose_filename
  end

  unless skip? :remove_dangling
    puts "\n\nCleaning up dangling images..."
    puts '-----------------------------'
    exec 'docker images --filter dangling=true -q | xargs docker rmi'
    # puts "\nDone."
  end

  unless skip? :remaining_containers
    puts "\n\nRemaining containers on host..."
    puts '-----------------------------'
    system 'docker ps -a'
  end
end