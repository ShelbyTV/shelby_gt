require 'framer'
require 'user_manager'

# When a tweet, facebook post, or tumblr post comes in, we need to put it somewhere.
#
# I'LL TELL YOU WHERE TO PUT IT
#
# I'll even put it there.
#
module GT
  class SocialSorter

    # Create appropriate Frames for the social posting based on it's details and who saw it.
    # See comments on sort_public_message and sort_private_message for algo details.
    #
    # --arguments--
    #
    # message - REQUIRED the normalized social posting turned into a non-persisted Message
    # video - REQUIRED the persisted Video this social posting is in reference to (use GT::VideoManager to create this)
    # observing_user - REQUIRED the persisted (real) Shelby user who saw this social posting
    #
    # --returns--
    #
    # The created Frames and DashboardEntries (via GT::Framer)
    #
    def self.sort(message, video_hash, observing_user)
      raise ArgumentError, "must supply message" unless message.is_a?(Message)
      raise ArgumentError, "must supply video" unless video_hash[:video].is_a?(Video)
      raise ArgumentError, "must supply observing_user" unless observing_user.is_a?(User)

      posting_user = get_or_create_posting_user_for(message)
      puts "[SORTER] posting_user: #{posting_user.inspect} "
      return false unless posting_user.is_a?(User) and posting_user.public_roll.is_a?(Roll)

      message.user = posting_user

      if message.public?
        sort_public_message(message, video_hash, observing_user, posting_user)
      else
        sort_private_message(message, video_hash, observing_user, posting_user)
      end
    end

    private

      # This is a public message: put it on the public roll of the posting user.
      #
      # In the normal posting case, we make sure observing user sees it by first following that roll (unless they've specifically unfollowed it)
      # Everyone else following that public roll will see it as well.
      def self.sort_public_message(message, video_hash, observing_user, posting_user)
        #observing_user should be following the posting_user's public roll, unless they specifically unfollowed it
        unless posting_user.public_roll.followed_by?(observing_user) or observing_user.unfollowed_roll?(posting_user.public_roll)
          Rails.logger.error "[GT::SocialSorter] LOGGING (1) user: #{observing_user.id} about to follow #{posting_user.id}"
          posting_user.public_roll.add_follower(observing_user, false)
          # To make sure new users get a bunch of historical content, backfill.
          # (This means old users will also get the backfill when they follow sombody new on twitter/fb)
          Rails.logger.error "[GT::SocialSorter] LOGGING (2) about to backfill dashboard_entries for: #{observing_user.id}"
          GT::Framer.backfill_dashboard_entries(observing_user, posting_user.public_roll, 20)
          Rails.logger.error "[GT::SocialSorter] LOGGING (3) done backfilling dashboard_entries for: #{observing_user.id}"
          new_following = true
        end

        # Show on poster's public roll (which will result in a dashbaord entry for all observers)
        # If the posting user posted the same video within the last 24 hours, don't create a new frame, just add to the convo
        if old_frame = recent_posting_of_video_on_roll(posting_user.public_roll_id, video_hash[:video].id, 24.hours.ago)
          unless old_frame.conversation and old_frame.conversation.messages.any? { |m| m.origin_id == message.origin_id }
            # This message hasn't been appended to the conversation yet
            # Do so atomically (w/ set semantics so timing doesn't result in multiple posts)
            Conversation.add_to_set(old_frame.conversation.id, :messages => message.to_mongo)
          end
        else

          # Hasn't been recently posted, add Frame to (faux) posting_user's public roll
          res = GT::Framer.create_frame(
            :creator => posting_user,
            :video => video_hash[:video],
            :message => message,
            :roll => posting_user.public_roll,
            :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
            :deep => video_hash[:from_deep]
            )
        end

        if !res
          # New frame was not created b/c 1) conversation was already posted OR 2) video was posted recently and we added this message to it
          #  BUT if observing_user was just added as a follower of posting_user's public_roll,
          #      a DashboardEntry may not have been created for this Frame/observing_user...
          if new_following and (convo = Conversation.first_including_message_origin_id(message.origin_id)) and (original_frame = convo.frame)
            # Only create if backfill didn't catch it for us
            # Keep performance high by only looking back through 60 seconds of dashboard entries for this user
            unless observing_user.dashboard_entries.where(:frame_id => original_frame.id, :_id.gt => BSON::ObjectId.from_time(60.seconds.ago)).exists?
              GT::Framer.create_dashboard_entry(original_frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], observing_user)
            end
          end

          return false
        end

        return res
      end

      # This is a private message: don't put it on the public roll of the posting user.
      # Make sure the observing user sees it by creating a Frame that is only attached to their dashboard
      def self.sort_private_message(message, video_hash, observing_user, posting_user)
        # Add Frame to observing_user's dashboard unless they unfollowed posting_user
        if observing_user.unfollowed_roll?(posting_user.public_roll)
          return nil
        else
          return GT::Framer.create_frame(
            :creator => posting_user,
            :video => video_hash[:video],
            :message => message,
            :dashboard_user_id => observing_user.id,
            :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
            :deep => video_hash[:from_deep]
            )
        end
      end

      def self.get_or_create_posting_user_for(message)
        begin
          GT::UserManager.get_or_create_faux_user(message.nickname, message.origin_network, message.origin_user_id, :user_thumbnail_url => message.user_image_url)
        rescue => e
          Rails.logger.fatal("[GT::SocialSorter#get_or_create_posting_user_for] rescued but re-raising #{e} for message #{message.inspect}")
          raise e
        end
      end

      def self.recent_posting_of_video_on_roll(roll_id, video_id, time_ago=24.hours.ago)
        return nil unless roll_id and video_id
        Frame.where(:roll_id  => roll_id, :video_id => video_id, :_id.gt => BSON::ObjectId.from_time(time_ago)).first
      end

  end
end
