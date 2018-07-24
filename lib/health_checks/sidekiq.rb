require 'socket'
require 'health_checks/memory'
require 'health_checks/mongoid_custom_client'

module HealthChecks
  module_function

  def sidekiq(config, mongoid_databases, redis_configs)
    config.on(:startup) do
      LivenessServer.new.start(mongoid_databases, redis_configs)
    end
  end

  private

  class LivenessServer
    LIVENESS_PORT = 8080

    def start(mongoid_databases, redis_configs)
      Sidekiq::Logging.logger.info "Starting liveness server on #{LIVENESS_PORT}"

      Thread.start do
        clients = create_clients(mongoid_databases)
        server = TCPServer.new(LIVENESS_PORT)
        loop do
          Thread.start(server.accept) do |socket|
            begin
              HealthChecks.memory
              check_mongoid_clients(clients)
              check_redis_connections(redis_configs)
              respond_success(socket, 'Live!')
            rescue => e
              log_error(e)
              respond_failure(socket, e.message)
            ensure
              socket.close
            end
          end
        end
      end
    end

    def create_clients(mongoid_databases)
      mongoid_databases.map do |db|
        client_name = "#{db[:name]}_sidekiq_health_check"
        client = MongoidCustomClient.create(client_name, db[:hosts])

        { db_name: db[:name], instance: client }
      end
    end

    def check_mongoid_clients(clients)
      db_name = ''
      clients.each do |client|
        db_name = client[:db_name]
        client[:instance].command(dbStats: 1).first['db']
      end
    rescue => e
      raise "#{e}, Database Name: #{db_name}"
    end

    def check_redis_connections(redis_configs)
      redis_configs.each do |config|
        Redis.new(config).ping
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

    def log_error(error)
      Sidekiq::Logging.logger.error "Error: #{error}"
    end
  end
end
