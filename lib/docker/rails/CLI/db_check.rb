module Docker
  module Rails
    module CLI
      require 'thor'
      class DbCheck < Thor

        default_task :help

        desc 'mysql', 'Ping and wait for mysql database to be up'

        def mysql
          # ping db to see if it is ready before continuing
          require 'rubygems'
          require 'active_record'
          require 'mysql2'

          puts "\n"
          printf 'Waiting for confirmation of db service startup...'
          loop_limit = options[:count] + 1
          loop_limit.times do |i|
            if i == loop_limit - 1
              printf 'failed to connect.'
              raise 'Failed to connect to db service.'
            end

            ActiveRecord::Base.establish_connection ({
                                                        adapter: 'mysql2',
                                                        host: 'db',
                                                        port: 3306,
                                                        username: 'root'})
            connected =
                begin
                  ActiveRecord::Base.connection_pool.with_connection { |con| con.active? }
                rescue => e
                  # puts "#{e.class.name}: #{e.message}"
                  false
                end
            printf '.'
            if connected
              printf 'connected.'
              break
            end
            sleep 1
          end
          puts "\n"
        end
      end
    end
  end
end
