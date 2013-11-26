# Did somebody say something on the Internet? OMFG!
#
# Decided you want to remove the comment by twitterer "@snowden" on the following page?
# http://shelby.tv/video/youtube/h3fLQhZ4JVc/passion-pit-it-s-not-my-fault-i-m-happy
#
# Well then do it like this:
# Dev::SEOScrubber.interactive_video_page_clean("snowden", "h3fLQhZ4JVc", "youtube")
#
module Dev
  class SEOScrubber
    
    def self.interactive_video_page_clean(nickname, video_id, video_provider="youtube")
      u = User.first(:conditions=>{:downcase_nickname => nickname.downcase})
      if !u
        puts "Failed to find User with Nickname #{nickname}"
        return
      end

      puts "Found User with nickname #{u.nickname}, user type: #{u.user_type}"
      puts "*** WARNING: NOT A FAUX USER ***" unless u.user_type == User::USER_TYPE[:faux]

      nick = u.authentications[0].nickname
      convos = Conversation.where(:video_id => Video.where(:provider_name => video_provider, :provider_id => video_id).first.id, 'messages.e' => nick).all
      
      # try searching convos by user id if nickname failed
      if convos.count == 0
        convos = Conversation.where(:video_id => Video.where(:provider_name => video_provider, :provider_id => video_id).first.id, 'messages.d' => u.id).all
      end

      if convos.count > 0
        puts "Found #{convos.count} conversations..."
        convos.each { |c| puts "Will clear conversation for #{nickname} with message: #{c.messages[0].text}" }
      else
        puts "Failed to find conversation for #{nickname}"
        return
      end

      puts "Continue? (y/n)"
      should_proceed = gets

      if should_proceed.chomp == "y"
        puts "Cleaning #{convos.count} conversations..."
        convos.each { |c| c.update_attribute(:messages, []) }
        puts "Done!"
      else
        puts "Doing Nothing...."
        puts "Done! ;-]"
      end
    end
    
  end
end