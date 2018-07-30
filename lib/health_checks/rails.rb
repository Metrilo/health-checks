require 'okcomputer'
require 'health_checks/custom/memory_check'
require 'health_checks/custom/mongoid_check'
require 'health_checks/custom/redis_check'

module HealthChecks
  module_function

  def rails(mongo_databases, redis_configs)
    mongo_databases.each do |db|
      mongoid_check = Custom::MongoidCheck.new(db)
      OkComputer::Registry.register "mongoid #{db[:name]}", MongoidCheck.new(mongoid_check)
    end

    redis_configs.each do |config|
      redis_check = Custom::RedisCheck.new(config)
      OkComputer::Registry.register 'redis', RedisCheck.new(redis_check)
    end

    OkComputer::Registry.register 'memory', MemoryCheck.new

    # Authorization: Basic aGVhbHRoY2hlY2tlcjptZXRyaWxvbWFpbmEh
    OkComputer.require_authentication('healthchecker', 'metrilomaina!')
    OkComputer.mount_at = 'healthz'
  end

  private

  class MongoidCheck < OkComputer::Check
    def initialize(mongoid_check)
      @mongoid_check = mongoid_check
    end

    def check
      @mongoid_check.run
      mark_message "Connected to mongodb #{@mongoid_check.db_name}"
    rescue => e
      mark_failure
      mark_message e
      Rails.logger.error e
    end
  end

  class RedisCheck < OkComputer::Check
    def initialize(redis_check)
      @redis_check = redis_check
    end

    def check
      @redis_check.run
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
      usage = Custom::MemoryCheck.new.run
      mark_message "Using #{usage}% memory"
    rescue => e
      mark_failure
      mark_message e.message
      Rails.logger.error e.message
    end
  end
end
