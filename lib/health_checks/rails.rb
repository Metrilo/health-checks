require 'okcomputer'
require 'health_checks/checks/memory_check'
require 'health_checks/checks/mongoid_check'
require 'health_checks/checks/redis_check'

module HealthChecks
  module_function

  def rails(mongo_databases, redis_configs)
    mongo_databases.each do |db|
      mongoid_check = Checks::MongoidCheck.new(db)
      OkComputer::Registry.register "mongoid #{db[:name]}", CustomOkComputer::MongoidCheck.new(mongoid_check)
    end

    redis_configs.each do |config|
      redis_check = Checks::RedisCheck.new(config)
      OkComputer::Registry.register 'redis', CustomOkComputer::RedisCheck.new(redis_check)
    end

    OkComputer::Registry.register 'memory', CustomOkComputer::MemoryCheck.new

    # Authorization: Basic aGVhbHRoY2hlY2tlcjptZXRyaWxvbWFpbmEh
    OkComputer.require_authentication('healthchecker', 'metrilomaina!')
    OkComputer.mount_at = 'healthz'
  end

  private

  module CustomOkComputer
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
        usage = Checks::MemoryCheck.new.run
        mark_message "Using #{usage}% memory"
      rescue => e
        mark_failure
        mark_message e.message
        Rails.logger.error e.message
      end
    end
  end
end
