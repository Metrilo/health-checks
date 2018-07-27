require 'okcomputer'
require 'health_checks/memory'
require 'health_checks/mongoid_custom_client'

module HealthChecks
  module_function

  def rails(mongo_databases)
    mongo_databases.each do |db|
      OkComputer::Registry.register "mongoid #{db[:name]}", CustomMongoidCheck.new(db)
    end
    OkComputer::Registry.register 'redis', RedisCheck.new
    OkComputer::Registry.register 'memory', MemoryCheck.new

    # Authorization: Basic aGVhbHRoY2hlY2tlcjptZXRyaWxvbWFpbmEh
    OkComputer.require_authentication('healthchecker', 'metrilomaina!')
    OkComputer.mount_at = 'healthz'
  end

  private

  class CustomMongoidCheck < OkComputer::MongoidCheck
    def initialize(db)
      @db_name = db[:name]
      client_name = "#{@db_name}_rails_health_check"
      self.session = MongoidCustomClient.create(client_name, db[:hosts])
    end

    def check
      mongodb_name # this is the method OkComputer::MongoidCheck#check uses
      mark_message "Connected to mongodb #{@db_name}"
    rescue => e
      mark_failure
      mark_message e
      Rails.logger.error "#{e}, Database Name: #{@db_name}"
    end
  end

  class RedisCheck < OkComputer::Check
    def check
      ::Sidekiq.redis(&:ping)
      mark_message 'Connected to Redis'
    rescue => e
      mark_failure
      message = "Sidekiq.redis.ping returned '#{e}' instead of PONG"
      mark_message message
      Rails.logger.error message
    end
  end

  class MemoryCheck < OkComputer::Check
    def check
      usage = HealthChecks.memory
      mark_message "Using #{usage}% memory"
    rescue => e
      mark_failure
      mark_message e.message
      Rails.logger.error e.message
    end
  end
end
