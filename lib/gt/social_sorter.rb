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
    def self.sort(message, video, observing_user)
      raise ArgumentError, "must supply message" unless message.is_a?(Message)
      raise ArgumentError, "must supply video" unless video.is_a?(Video)
      raise ArgumentError, "must supply observing_user" unless observing_user.is_a?(User)

      posting_user = get_or_create_posting_user_for(message)
      return false unless posting_user.is_a?(User) and posting_user.public_roll.is_a?(Roll)
      
      message.user = posting_user
      
      if message.public?
        sort_public_message(message, video, observing_user, posting_user)
      else
        sort_private_message(message, video, observing_user, posting_user)
      end
    end
    
    private
      
      # This is a public message: put it on the public roll of the posting user
      # Make sure observing user sees it by first following that roll (unless they've specifically unfollowed it)
      # Everyone else following that public roll will see it as well.
      def self.sort_public_message(message, video, observing_user, posting_user)
        
        #observing_user should be following the posting_user's public roll, unless they specifically unfollowed it
        unless posting_user.public_roll.followed_by?(observing_user) or observing_user.unfollowed_roll?(posting_user.public_roll)  
          posting_user.public_roll.add_follower(observing_user)
          new_following = true
          
          posting_user.public_roll.save
          observing_user.save
        end
        
        if convo = already_posted?(message, posting_user.public_roll)
          # This has already been posted, so we're not going to create a Frame.
          #  BUT if observing_user was just added as a follower of posting_user's public_roll, 
          #      a DashboardEntry was never created for this Frame/observing_user...
          if new_following and original_frame = convo.frame
            GT::Framer.create_dashboard_entry(original_frame, DashboardEntry::ENTRY_TYPE[:new_social_frame], observing_user)
          end

          return false
        end
        
        #Add Frame to posting_user's public roll
        GT::Framer.create_frame(
          :creator => posting_user,
          :video => video,
          :message => message,
          :roll => posting_user.public_roll,
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame]
          )
      end
      
      # This is a private message: don't put it on the public roll of the posting user.
      # Make sure the observing user sees it by creating a Frame that is only attached to their dashboard
      def self.sort_private_message(message, video, observing_user, posting_user)
        # Add Frame to observing_user's dashboard
        GT::Framer.create_frame(
          :creator => posting_user,
          :video => video,
          :message => message,
          :dashboard_user_id => observing_user.id,
          :action => DashboardEntry::ENTRY_TYPE[:new_social_frame]
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
      
      def self.already_posted?(message, roll)
        # See if there is a conversation that has a matching message
        if c = Conversation.first_including_message_origin_id(message.origin_id)
          return c if c.messages.any? { |m| m.origin_network == message.origin_network and m.origin_id == message.origin_id }
        end
        return false
      end
       
  end
end