module MongoidCustomClient
  def self.create(client_name, hosts)
    Mongoid::Config.clients[client_name] = {
      hosts: hosts,
      database: "#{client_name}_db",
      options: { server_selection_timeout: 1 }
    }

    Mongoid::Clients.with_name(client_name)
  end
end
