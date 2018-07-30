require 'socket'
require 'health_checks/custom/memory_check'
require 'health_checks/custom/mongoid_check'
require 'health_checks/custom/redis_check'

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
        checks = mongo_databases.map { |db| Checks::MongoidCheck.new(db) }
        checks += redis_configs.map{ |config| Checks::RedisCheck.new(config) }
        checks << Checks::MemoryCheck.new
        server = TCPServer.new(LIVENESS_PORT)
        loop do
          Thread.start(server.accept) do |socket|
            begin
              checks.each(&:run)
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
