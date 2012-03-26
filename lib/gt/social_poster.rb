require 'twitter_posting'
#require 'facebook_posting'
#require 'tumblr_posting'

module GT
  class SocialPoster
    
    def self.post_to_twitter(from_user, comment, frame)
      begin
        original_message = frame.conversation.messages.first
        if original_message.origin_network == "twitter"
          #post as reply to tweet
          return post_tweet(from_user, comment, original_message.origin_id)
        else
          #post a new tweet
          return post_tweet(from_user, comment, nil)
        end
      rescue Grackle::TwitterError => twit_err
        Rails.logger.error "[GT::SocialPosting] Error posting tweet to twitter via Grackle: #{twit_err.to_s}"
        return false
      rescue => e
        Rails.logger.error "[GT::SocialPosting] Error posting comment to Twitter: #{e}"
        return false
      end
    end
  
    private 
  
      def self.post_tweet(user, message, in_reply_to_tweet_id=nil)
        if user.has_provider('twitter')
          tw = SocialPosting::Twitter.new(user)
        
          return tw.post_tweet(message, in_reply_to_tweet_id)
        else
          return nil
        end
      end
    
  #FIXME: Below
=begin  
  def self.post_to_facebook(from_user, params)
    begin
      comment = params["comment"]
      # UPDATED: ALWAYS posting new 
      return post_fb_comment(from_user, comment, nil, params["frame_id"])
    rescue Koala::Facebook::APIError => e
      Rails.logger.error "Koala::Facebook::APIError posting comment to FB: #{e}"
      return false
    rescue ArgumentError => fb_error
      Rails.logger.error "ArgumentError posting comment to FB: #{fb_error.to_s}"
      return false
    rescue => e
      Rails.logger.error "Error posting comment to FB: #{e}"
      return false
    end
  end
  
  def self.post_to_tumblr(from_user, params)
    begin
      # post a tumblr video post
      return post_tumblr(from_user, params["comment"], params["frame_id"])
    rescue => e
      Rails.logger.error "Error posting to Tumblr: #{e}"
      return false
    end
  end
  
  def self.post_to_email(from_user, params)
    return send_email(from_user, params["to"], params["comment"], params["broadcast_id"])
  end
  
  private 
      
    def self.post_tumblr(user, comment, frame_id)
      if user.has_provider('tumblr')
        tu = SocialPosting::Tumblr.new(user)
      
        return tu.post_video(comment, frame_id)
      else
        return nil
      end
    end
  
    def self.post_fb_comment(user, message, fb_post_id=nil, frame_id=nil)
      if user.has_provider('facebook')
        fb = SocialPosting::Facebook.new(user)
        
        return fb.post_comment(message, fb_post_id, frame_id)
      else
        return nil
      end
    end
=end    
    #TODO: BUILD EMAIL SHARING INTO GT
=begin
    def self.send_email(user, email_to, message=nil, broadcast_id=nil)
      # rebroadcast to person email is to if they are a shelby user
      if to_user = User.find_by_email(email_to) 
        rebroadcast = to_user.find_or_create_rebroadcast!(broadcast, to_user.stream_incoming_channel)
        rebroadcast.update_attributes({:owner_watch_later => true, :description => message})
      end
      
      from_email = user.primary_email || "Shelby.tv <wecare@shelby.tv>"
      return SharingMailer.send_video(user, from_email, email_to, message, broadcast_id).deliver
    end
=end

  end
end