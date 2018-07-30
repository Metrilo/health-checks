module HealthChecks
  module Custom
    class RedisCheck
      def initialize(config)
        @config = config
      end

      def run
        Redis.new(@config).ping
      end
    end
  end
end
