require 'socket'
require 'health_checks/memory'
require 'health_checks/mongoid_custom_client'

module HealthChecks
  module_function

  def sidekiq(config, mongo_databases, redis_configs)
    config.on(:startup) do
      LivenessServer.new.start(mongo_databases, redis_configs)
    end
  end

  private

  class LivenessServer
    LIVENESS_PORT = 8080

    def start(mongo_databases, redis_configs)
      Sidekiq::Logging.logger.info "Starting liveness server on #{LIVENESS_PORT}"

      Thread.start do
        clients = create_clients(mongo_databases)
        server = TCPServer.new(LIVENESS_PORT)
        loop do
          Thread.start(server.accept) do |socket|
            begin
              HealthChecks.memory
              check_mongo_connections(clients)
              check_redis_connections(redis_configs)
              respond_success(socket, 'Live!')
            rescue => e
              Sidekiq::Logging.logger.error e
              respond_failure(socket, e.message)
            ensure
              socket.close
            end
          end
        end
      end
    end

    def create_clients(mongo_databases)
      mongo_databases.map do |db|
        client_name = "#{db[:name]}_sidekiq_health_check"
        client = MongoidCustomClient.create(client_name, db[:hosts])

        { db_name: db[:name], instance: client }
      end
    end

    def check_mongo_connections(clients)
      clients.each do |client|
        begin
          client[:instance].command(dbStats: 1).first['db']
        rescue => e
          raise "#{e}, Database Name: #{client[:db_name]}"
        end
      end
    end

    def check_redis_connections(redis_configs)
      redis_configs.each do |config|
        begin
          Redis.new(config).ping
        rescue => e
          raise "#{e}, Database Host: #{config[:host]}"
        end
      end
    end

    def respond_success(socket, response)
      respond(socket, '200 OK', response)
    end

    def respond_failure(socket, response)
      respond(socket, '500 Internal Server Error', response)
    end

    def respond(socket, status, response)
      socket.print <<~HEREDOC
        HTTP/1.1 #{status}\r
        Content-Type: text/plain\r
        Content-Length: #{response.bytesize}\r
        Connection: close\r
      HEREDOC
      socket.print "\r\n" # blank line as required by the protocol
      socket.print response
    end
  end
end
