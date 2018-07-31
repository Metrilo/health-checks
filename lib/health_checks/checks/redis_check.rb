module HealthChecks
  module Checks
    class RedisCheck
      def initialize(config)
        @config = config
      end

      def run
        @config[:connect_timeout] = 1
        Redis.new(@config).ping
      end
    end
  end
end
