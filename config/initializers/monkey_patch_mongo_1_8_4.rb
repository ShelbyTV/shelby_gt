# Mongo driver 1.8.4 has a bug with authentication.  This monkey patch (specifically line 11) fixes it.
# Leave this in place until we can upgrade to 1.8.5
module Mongo
  class DB
 
    def authenticate(username, password, save_auth=true)
      if @connection.pool_size > 1 && !save_auth
        raise MongoArgumentError, "If using connection pooling, :save_auth must be set to true."
      end
 
      begin
        socket = @connection.checkout_reader(:mode => :primary_preferred)
        issue_authentication(username, password, save_auth, :socket => socket)
      ensure
        socket.checkin if socket
      end
 
      @connection.authenticate_pools
    end
 
  end
end