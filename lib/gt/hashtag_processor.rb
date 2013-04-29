require 'api_clients/google_analytics_client'

# Processes messages looking for shelby-defined hashtags
# Performs appropriate actions when hashtags are found
module GT
  class HashtagProcessor

    # processes the hashtags in a frame's message and adds the frame
    # to a channel if a channel hashtag is found
    # RETURNS: the created dashboard entry if any hashtags are matched
    def self.process_frame_message_hashtags_for_channels(frame)
      raise ArgumentError, "must supply a valid frame" unless frame and frame.is_a?(Frame)

      db_entries = []
      channels_rolled_to = []

      # process the frame's first message, aka the rolling comment, to see
      # if it contains any channel hashtags
      if message = frame.conversation && frame.conversation.messages && frame.conversation.messages[0]
        message.text.scan(/\#(\w*)/) do |hashtag_match|
          Settings::Channels.channels.each do |channel|
            # skip this channel if we've already added to it
            next if channels_rolled_to.include? channel['channel_user_id']

            if channel['hash_tags'] && channel['hash_tags'].detect {|tag| tag.casecmp(hashtag_match[0]) == 0}
              # we found a channel for this hashtag, get the user for this channel
              if user = User.find(channel['channel_user_id'])
                # add this frame to the channel user's dashboard
                res = GT::Framer.create_dashboard_entry(frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], user)
                db_entries << res[0]
                channels_rolled_to << channel['channel_user_id']
                # for now we assume a given hashtag can only match one channel,
                # so we're done processing this hashtag
                break
              end
            end
          end
        end
      end

      db_entries.compact!
      return !db_entries.empty? ? db_entries : nil

    end

    # processes the hashtags in a frame's message and sends an event to google analytics
    # for every hashtag encountered, even if that hashtag doesn't match a Shelby channel
    def self.process_frame_message_hashtags_send_to_google_analytics(frame)
      raise ArgumentError, "must supply a valid frame" unless frame and frame.is_a?(Frame)

      if message = frame.conversation && frame.conversation.messages && frame.conversation.messages[0]
        message.text.scan(/\#(\w*)/) do |hashtag_match|
          APIClients::GoogleAnalyticsClient.track_event('hashtag', 'rolled to', hashtag_match[0].downcase)
        end
      end
    end

  end

end