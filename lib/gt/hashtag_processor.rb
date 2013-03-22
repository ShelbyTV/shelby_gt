# Processes messages looking for shelby-defined hashtags
# Performs appropriate actions when hashtags are found
module GT
  class HashtagProcessor

    # processes the hashtags in a frame's message and adds the frame
    # to a channel if a channel hashtag is found
    # RETURNS: the created dashboard entry if any hashtags are matched
    def self.process_frame_message_hashtags_for_channels(frame)
      raise ArgumentError, "must supply a valid frame" unless frame and frame.is_a?(Frame)

      db_entries = nil

      # process the frame's first message, aka the rolling comment, to see
      # if it contains any channel hashtags
      if message = frame.conversation && frame.conversation.messages && frame.conversation.messages[0]
        if match_info = message.text.match(/\#(\w*)/)
          Settings::Channels.channels.each do |channel|
            if channel['hash_tags'].detect {|tag| tag.casecmp(match_info[1]) == 0}
              # we found a channel for this hashtag, get the user for this channel
              if user = User.find(channel['channel_user_id'])
                # add this frame to the channel user's
                db_entries = GT::Framer.create_dashboard_entry(frame, ::DashboardEntry::ENTRY_TYPE[:new_hashtag_frame], user)
                # for now, only process one hashtag per frame
                break
              end
            end
          end
        end
      end

      return db_entries ? db_entries[0] : nil

    end

  end

end