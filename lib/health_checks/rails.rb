require 'okcomputer'
require 'health_checks/memory'

module HealthChecks
  module_function

  def rails
    OkComputer::Registry.register 'database', OkComputer::MongoidCheck.new
    OkComputer::Registry.register 'redis', RedisCheck.new
    OkComputer::Registry.register 'memory', MemoryCheck.new

    # Authorization: Basic aGVhbHRoY2hlY2tlcjptZXRyaWxvbWFpbmEh
    OkComputer.require_authentication('healthchecker', 'metrilomaina!')
    OkComputer.mount_at = 'healthz'
  end

  private

  class RedisCheck < OkComputer::Check
    def check
      sidekiq_response = ::Sidekiq.redis(&:ping)

      if sidekiq_response == 'PONG'
        mark_message 'Connected to Redis'
        return
      end

      mark_failure
      mark_message "Sidekiq.redis.ping returned #{sidekiq_response.inspect} instead of PONG"
    end
  end

  class MemoryCheck < OkComputer::Check
    def check
      usage = HealthChecks.memory
      mark_message "Using #{usage}% memory"
    rescue => e
      mark_failure
      mark_message e.message
    end
  end
end
