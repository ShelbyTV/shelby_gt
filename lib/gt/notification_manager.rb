module GT
  class NotificationManager
    
    def self.check_and_send_upvote_notification(user, frame)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?
      # don't email the creator if they are the upvoting user or they dont have an email address!
      return if (user.id == frame.creator_id) or !user.primary_email or (user.primary_email == "")
      
      # Temp: for now only send emails to us
      if Rails.env == "production"
        # only sending notifications for a select few for now
        return unless ["henrysztul"].include?(frame.creator.nickname)
      end
      
      NotificationMailer.upvote_notification(frame.creator, user, frame).deliver
    end

    def self.check_and_send_reroll_notification(old_frame, new_frame)
      raise ArgumentError, "must supply valid new frame" unless new_frame.is_a?(Frame) and !new_frame.blank?
      raise ArgumentError, "must supply valid old frame" unless old_frame.is_a?(Frame) and !old_frame.blank?
      
      # don't email the creator if they are the upvoting user or they dont have an email address!
      user = new_frame.creator
      return if (new_frame.creator_id == old_frame.creator_id) or !user.primary_email or (user.primary_email == "")
      
      # Temp: for now only send emails to us
      if Rails.env == "production"
        return unless ["henry", "spinosa", "reece", "mmatyus", "chris"].include?(old_frame.creator.nickname)
      end
      
      NotificationMailer.reroll_notification(new_frame, old_frame).deliver
    end
    
    def self.check_and_send_comment_notification(user, c, message)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid conversation" unless c.is_a?(Conversation) and !c.blank?
      raise ArgumentError, "must supply valid message" unless message.is_a?(Message) and !message.blank?
      
      # stop if the message user is the user taking the action
      return if new_message.user == u

      # stop if we don't get the frame (otherwise we won't have a permalink for the email)      
      #TODO: This is probably not the *best* way to get the conversations frame, so find a  better way...
      return unless frame = Frame.where(:conversation_id => c.id).first
      
      c.messages.each do |old_message|
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