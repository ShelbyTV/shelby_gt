class ExternalServiceSharer
  @queue = :external_service_share

  def self.perform(frame_id, destinations, email_addresses, text, user_from_id)
    frame = Frame.find(frame_id)
    user_from = User.find(user_from_id)

    if destinations.include?('twitter') || destinations.include?('facebook')
      #  we need a hash of desinations/links for sharing to social services
      short_links = GT::LinkShortener.get_or_create_shortlinks(frame, destinations.join(','), user_from)
    end

    destinations.each do |d|
      case d
      when 'twitter'
        t = GT::SocialPostFormatter.format_for_twitter(text, short_links)
        GT::SocialPoster.post_to_twitter(user_from, t)
      when 'facebook'
        t = GT::SocialPostFormatter.format_for_facebook(text, short_links)
        GT::SocialPoster.post_to_facebook(user_from, t, frame)
      when 'email'
        # save any valid addresses for future use in autocomplete
        user_from.store_autocomplete_info(:email, email_addresses)
        GT::SocialPoster.email_frame(user_from, email_addresses, text, frame)
      end
      StatsManager::StatsD.increment(Settings::StatsConstants.frame['share'][d])
    end
  end
end