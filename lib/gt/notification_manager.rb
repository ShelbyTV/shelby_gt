module GT
  class NotificationManager
    
    def self.check_and_send_upvote_notification(user, frame)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?
      
      #return if Rails.env != "production"
      
      # don't email the creator if they are the upvoting user or they dont have an email address!
      return if (user.id == frame.creator_id) or !user.primary_email or (user.primary_email == "")
      
      # only sending notifications for a select few for now
      #return unless ["henrysztul"].include?(frame.creator.nickname)
      
      NotificationMailer.upvote_notification(frame.creator, user, frame).deliver
    end
    
    def self.check_and_send_comment_notification(user, c, message)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid conversation" unless c.is_a?(Conversation) and !c.blank?
      raise ArgumentError, "must supply valid message" unless message.is_a?(Message) and !message.blank?
      
      first_message = c.messages.first
      
      c.messages.each do |m|
        # stop if the message user is the current user
        break if m.user == user
        
        # cant email anyone if we dont have their email address :)
        break unless m and m.user and m.user.primary_email
        
        if Rails.env == "production"
          # only sending notifications for a select few for now
          break unless ["henrysztul"].include?(m.user.nickname)
        end
        
        NotificationMailer.comment_notification(first_message.user, m.user, c, m).deliver
      end
    end
  end
end