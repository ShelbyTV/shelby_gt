require 'twitter_posting'
require 'facebook_posting'
require 'tumblr_posting'

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
    
    def self.post_to_facebook(from_user, comment, frame)
      begin
        return post_fb_comment(from_user, comment, nil, frame)
      rescue Koala::Facebook::APIError => e
        Rails.logger.error "[GT::SocialPosting] Koala::Facebook::APIError posting comment to FB: #{e}"
        return false
      rescue ArgumentError => fb_error
        Rails.logger.error "[GT::SocialPosting] ArgumentError posting comment to FB: #{fb_error.to_s}"
        return false
      rescue => e
        Rails.logger.error "[GT::SocialPosting] Error posting comment to FB: #{e}"
        return false
      end
    end
    
    #TODO: we need an iframe player for gt before we can post to tumblr!
    #      This will return false no matter what until we do!
    def self.post_to_tumblr(from_user, comment, frame)
      begin
        # post a tumblr video post
        return post_tumblr(from_user, comment, frame)
      rescue => e
        Rails.logger.error "[GT::SocialPosting] Error posting to Tumblr: #{e}"
        return false
      end
    end
    
    #TODO: we need to re work email share template to reflect gt/rolls
    def self.post_to_email(from_user, to_user, comment, frame)
      return send_email(from_user, to_user, comment, frame)
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
      
      def self.post_fb_comment(user, message, fb_post_id=nil, frame=nil)
        if user.has_provider('facebook')
          fb = SocialPosting::Facebook.new(user)
          return fb.post_comment(message, fb_post_id, frame)
        else
          return nil
        end
      end
      
      def self.post_tumblr(user, comment, frame)
        if user.has_provider('tumblr')
          tu = SocialPosting::Tumblr.new(user)

          return tu.post_video(comment, frame)
        else
          return nil
        end
      end
      
      def self.send_email(user, email_to, message=nil, frame=nil)
        from_email = user.primary_email || "Shelby.tv <wecare@shelby.tv>"
        return SharingMailer.share_frame(user, from_email, email_to, message, frame).deliver
      end
    
  end
end