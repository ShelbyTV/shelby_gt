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
      return false unless posting_user.is_a?(User) and posting_user.public_roll.is_a?(Roll)
      
      message.user = posting_user
      
      if message.public?
        sort_public_message(message, video_hash, observing_user, posting_user)
      else
        sort_private_message(message, video_hash, observing_user, posting_user)
      end
    end
    
    private
      
      # This is a public message: put it on the public roll of the posting user
      # Make sure observing user sees it by first following that roll (unless they've specifically unfollowed it)
      # Everyone else following that public roll will see it as well.
      def self.sort_public_message(message, video_hash, observing_user, posting_user)
        
        #observing_user should be following the posting_user's public roll, unless they specifically unfollowed it
        unless posting_user.public_roll.followed_by?(observing_user) or observing_user.unfollowed_roll?(posting_user.public_roll)
          posting_user.public_roll.add_follower(observing_user, false)
          
          new_following = true
        end

        #Add Frame to posting_user's public roll
        res = GT::Framer.create_frame(
          :creator => posting_user,
          :video => video_hash[:video],
          :message => message,
          :roll => posting_user.public_roll,
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :deep => video_hash[:from_deep]
          )

        if !res
          # conversation was already posted
          convo = Conversation.first_including_message_origin_id(message.origin_id)
          # This has already been posted, so we weren't able to create a Frame.
          #  BUT if observing_user was just added as a follower of posting_user's public_roll, 
          #      a DashboardEntry was never created for this Frame/observing_user...
          if new_following and original_frame = convo.frame
            GT::Framer.create_dashboard_entry(original_frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], observing_user)
          end

          return false
        end

        return res
      end
      
      # This is a private message: don't put it on the public roll of the posting user.
      # Make sure the observing user sees it by creating a Frame that is only attached to their dashboard
      def self.sort_private_message(message, video_hash, observing_user, posting_user)
        # Add Frame to observing_user's dashboard
        GT::Framer.create_frame(
          :creator => posting_user,
          :video => video_hash[:video],
          :message => message,
          :dashboard_user_id => observing_user.id,
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame],
          :deep => video_hash[:from_deep]
          )
      end
      
      def self.get_or_create_posting_user_for(message)
        begin
          GT::UserManager.get_or_create_faux_user(message.nickname, message.origin_network, message.origin_user_id, :user_thumbnail_url => message.user_image_url)
        rescue => e
          Rails.logger.fatal("[GT::SocialSorter#get_or_create_posting_user_for] rescued but re-raising #{e} for message #{message.inspect}")
          raise e
        end
      end
       
  end
end
