module APIClients
  class GoogleAnalyticsClient

   def self.track_event(category, action, label, options={})

     return if !["production", "staging", "test"].include?(Rails.env)

      defaults = {
        :account_id => Settings::GoogleAnalytics.web_account_id,
        :domain => Settings::Global.domain,
        :value => nil
      }

     options = defaults.merge(options)

     client = get_client(options[:account_id], options[:domain])
     client.event(category, action, label, options[:value])
   end

   private

    @gabba_clients = {}
    def self.get_client(account_id, domain)
      client_string = "#{account_id}::#{domain}"
      @gabba_clients[client_string] || (@gabba_clients[client_string] = Gabba::Gabba.new(account_id, domain))
    end

  end
end