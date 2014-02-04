require 'twitter_posting'
require 'facebook_posting'
require 'tumblr_posting'

module GT
  class SocialPoster

    def self.post_to_twitter(from_user, text)
      begin
        #post a new tweet
        return post_tweet(from_user, text, nil)
      rescue Grackle::TwitterError => twit_err
        Rails.logger.error "[GT::SocialPosting] Error posting tweet to twitter via Grackle: #{twit_err.to_s}"
        return false
      rescue => e
        Rails.logger.error "[GT::SocialPosting] Error posting text to Twitter: #{e}"
        return false
      end
    end

    def self.post_to_facebook(from_user, text, entity)
      begin
        return post_fb_comment(from_user, text, nil, entity)
      rescue Koala::Facebook::APIError => e
        Rails.logger.error "[GT::SocialPosting] Koala::Facebook::APIError posting text to FB: #{e}"
        return false
      rescue ArgumentError => fb_error
        Rails.logger.error "[GT::SocialPosting] ArgumentError posting text to FB: #{fb_error.to_s}"
        return false
      rescue => e
        Rails.logger.error "[GT::SocialPosting] Error posting text to FB: #{e}"
        return false
      end
    end

    #TODO: we need an iframe player for gt before we can post to tumblr!
    #      This will return false no matter what until we do!
    def self.post_to_tumblr(from_user, text, entity)
      begin
        # post a tumblr video post
        return post_tumblr(from_user, text, entity)
      rescue => e
        Rails.logger.error "[GT::SocialPosting] Error posting to Tumblr: #{e}"
        return false
      end
    end

    # to_emails is a comma or semicolon deliniated string of email addresses
    def self.email_frame(from_user, to_emails, message, frame)
      return send_email(from_user, to_emails, message, frame)
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

      def self.post_fb_comment(user, message, fb_post_id=nil, entity=nil)
        if user.has_provider('facebook')
          fb = SocialPosting::Facebook.new(user)
          return fb.post_comment(message, fb_post_id, entity)
        else
          return nil
        end
      end

      def self.post_tumblr(user, text, entity)
        if user.has_provider('tumblr')
          tu = SocialPosting::Tumblr.new(user)

          return tu.post_video(text, entity)
        else
          return nil
        end
      end

      # to_emails is a comma or semicolon deliniated string of email addresses
      def self.send_email(user, to_emails, message, frame)
        from_email = user.primary_email || "Shelby.tv <wecare@shelby.tv>"
        to_emails = to_emails.split(/[,;]/)
        # Just send 1 email to all the recipients (mailer expects a comma deliniated string)
        SharingMailer.share_frame(user, from_email, to_emails.join(','), message, frame).deliver
      end

  end
end