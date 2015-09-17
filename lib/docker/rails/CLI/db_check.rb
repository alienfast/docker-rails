module Docker
  module Rails
    module CLI
      class DbCheck < Thor

        default_task :help

        desc 'mysql', 'Ping and wait for mysql database to be up'
        option :count, default: 60, desc: 'Number of attempts'
        option :host, default: 'db'
        option :port, default: 3306
        option :username, default: 'root'
        option :password, desc: 'Password-less login if unspecified'

        def mysql
          # ping db to see if it is ready before continuing
          require 'rubygems'
          require 'active_record'
          require 'mysql2'

          puts "\n"
          connect_string = "#{options[:username]}@#{options[:host]}:#{options[:port]}"
          printf "Waiting for confirmation of db service startup at #{connect_string}..."
          last_message = ''
          loop_limit = options[:count].to_i + 1
          loop_limit.times do |i|
            if i == loop_limit - 1
              printf "failed to connect.  #{last_message}\n\n\n"
              raise "Failed to connect to db service at #{connect_string}.  #{last_message}"
            end

            connection_options = {
                adapter: 'mysql2',
                host: options[:host],
                port: options[:port],
                username: options[:username]
            }

            #puts "Password is nil? #{options[:password].nil?}, |#{options[:password]}|"

            connection_options[:password] = options[:password] unless options[:password].nil?

            ActiveRecord::Base.establish_connection (connection_options)
            connected =
                begin
                  ActiveRecord::Base.connection_pool.with_connection { |con| con.active? }
                rescue => e
                  last_message = "#{e.class.name}: #{e.message}"
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
