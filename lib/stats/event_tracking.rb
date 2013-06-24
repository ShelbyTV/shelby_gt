require 'api_clients/google_analytics_client'

module StatsManager
  class GoogleAnalytics

    def self.track_nth_session(user, n)
      user.reload
      return unless user.session_count == n

      time_to_nth_session = (Time.zone.now - user.created_at).to_i / 1.day
      category, action, label = "Sessions", "Reached #{n.ordinalize} Session", user.nickname
      APIClients::GoogleAnalyticsClient.track_event(category, action, label, time_to_nth_session)
    end

  end
end
