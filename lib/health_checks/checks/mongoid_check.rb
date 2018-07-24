module HealthChecks
  module Checks
    class MongoidCheck
      attr_reader :db_name

      def initialize(mongo_database)
        @db_name = mongo_database[:name]
        @client = create_client(mongo_database)
      end

      def run
        @client.command(dbStats: 1).first['db']
      rescue => e
        raise "#{e}, Database Name: #{@db_name}"
      end

      private

      def create_client(database)
        client_name = "#{database[:name]}_sidekiq_health_check"

        ::Mongoid::Config.clients[client_name] = {
          hosts: database[:hosts],
          database: "#{client_name}_db",
          options: { server_selection_timeout: 1 }
        }

        ::Mongoid::Clients.with_name(client_name)
      end
    end
  end
end
