module GT
  class NotificationManager
    
    def self.check_and_send_upvote_notification(user, frame)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?
      
      #return if Rails.env != "production"
      
      # don't email the creator if they are the upvoting user or they dont have an email address!
      return if (user.id == frame.creator_id) or !user.primary_email or (user.primary_email == "")
      
      # only sending notifications for a select few for now
      if Rails.env == "production"
        return unless ["henry", "spinosa", "reece", "mmatyus", "chris"].include?(frame.creator.nickname)
      end
      
      NotificationMailer.upvote_notification(frame.creator, user, frame).deliver
    end
    
    def self.check_and_send_comment_notification(u, c, new_message)
      raise ArgumentError, "must supply valid user" unless u.is_a?(User) and !u.blank?
      raise ArgumentError, "must supply valid conversation" unless c.is_a?(Conversation) and !c.blank?
      raise ArgumentError, "must supply valid message" unless new_message.is_a?(Message) and !new_message.blank?
      
      #return if Rails.env != "production"
      
      # stop if the message user is the user taking the action
      return if new_message.user == u

      # stop if we don't get the frame (otherwise we won't have a permalink for the email)      
      #TODO: This is probably not the *best* way to get the conversations frame, so find a  better way...
      return unless frame = Frame.where(:conversation_id => c.id).first
      
      c.messages.each do |old_message|
        # cant email anyone if we dont have their email address :)
        break unless old_message.user and old_message.user.primary_email
        
        if Rails.env == "production"
          break unless ["henry", "spinosa", "reece", "mmatyus", "chris"].include?(old_message.user.nickname)
        end
        
        NotificationMailer.comment_notification(old_message.user, new_message.user, frame, new_message).deliver
      end
    end
  end
end