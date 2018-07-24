require 'okcomputer'
require 'health_checks/memory'
require 'health_checks/mongoid_custom_client'

module HealthChecks
  module_function

  def rails(mongoid_databases)
    mongoid_databases.each do |db|
      OkComputer::Registry.register "mongoid #{db[:name]}", CustomMongoidCheck.new(db)
    end
    OkComputer::Registry.register 'redis', RedisCheck.new
    OkComputer::Registry.register 'memory', MemoryCheck.new

    # Authorization: Basic aGVhbHRoY2hlY2tlcjptZXRyaWxvbWFpbmEh
    OkComputer.require_authentication('healthchecker', 'metrilomaina!')
    OkComputer.mount_at = 'healthz'
  end

  private

  module Logger
    module_function

    def error(error)
      Rails.logger.error "Error: #{error}"
    end
  end

  class CustomMongoidCheck < OkComputer::MongoidCheck
    def initialize(db)
      @db_name = db[:name]
      client_name = "#{@db_name}_rails_health_check"
      self.session = MongoidCustomClient.create(client_name, db[:hosts])
    end

    def check
      mongodb_name
      mark_message "Connected to mongodb #{@db_name}"
    rescue => e
      mark_failure
      mark_message e.message
      Logger.error("#{e}, Database Name: #{@db_name}")
    end
  end

  class RedisCheck < OkComputer::Check
    def check
      ::Sidekiq.redis(&:ping)
      mark_message 'Connected to Redis'
    rescue => e
      mark_failure
      mark_message "Sidekiq.redis.ping returned '#{e.message}' instead of PONG"
      Logger.error(e)
    end
  end

  class MemoryCheck < OkComputer::Check
    def check
      usage = HealthChecks.memory
      mark_message "Using #{usage}% memory"
    rescue => e
      mark_failure
      mark_message e.message
      Logger.error(e)
    end
  end
end
