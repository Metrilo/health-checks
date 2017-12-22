require 'socket'
require 'health_checks/memory'

module HealthChecks
  module_function

  def sidekiq(config)
    config.on(:startup) do
      LivenessServer.new.start
    end
  end

  private

  class LivenessServer
    LIVENESS_PORT = 8080

    def start
      Sidekiq::Logging.logger.info "Starting liveness server on #{LIVENESS_PORT}"
      Thread.start do
        server = TCPServer.new(LIVENESS_PORT)
        loop do
          Thread.start(server.accept) do |socket|
            begin
              HealthChecks.memory
              check_redis
              check_mongo
              respond_success(socket, 'Live!')
            rescue => e
              respond_failure(socket, e.message)
            ensure
              socket.close
            end
          end
        end
      end
    end

    def check_redis
      sidekiq_response = ::Sidekiq.redis(&:ping)
      return if sidekiq_response == 'PONG'

      raise "Sidekiq.redis.ping returned #{sidekiq_response.inspect} instead of PONG"
    end

    def check_mongo
      session = Mongoid::Clients.with_name(:default)
      session.database_names
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
