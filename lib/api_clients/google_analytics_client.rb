module APIClients
  class GoogleAnalyticsClient

   def self.track_event(category, action, label)

     return if !["production", "test"].include?(Rails.env)

     init_ga

     @gabba_client.event(category, action, label)
   end

   private

    @gabba_client = nil
    def self.init_ga()
      @gabba_client = Gabba::Gabba.new(Settings::GoogleAnalytics.account_id, Settings::Global.domain) unless @gabba_client
    end

  end
end