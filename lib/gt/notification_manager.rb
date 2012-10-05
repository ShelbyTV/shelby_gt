module GT
  class NotificationManager
    
    def self.check_and_send_upvote_notification(user, frame)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?
      
      # don't email the creator if they are the upvoting user or they dont have an email address!
      user_to = frame.creator
      return if !user_to or (user == user_to) or !user_to.primary_email or (user_to.primary_email == "")
      
      # Temp: for now only send emails to gt_enabled users
      return unless frame.creator.gt_enabled
      
      return unless user_to.preferences.upvote_notifications
            
      NotificationMailer.upvote_notification(user_to, user, frame).deliver
    end

    def self.check_and_send_reroll_notification(old_frame, new_frame)
      raise ArgumentError, "must supply valid new frame" unless new_frame.is_a?(Frame) and !new_frame.blank?
      raise ArgumentError, "must supply valid old frame" unless old_frame.is_a?(Frame) and !old_frame.blank?
            
      # don't email the creator if they are the upvoting user or they dont have an email address!
      user_to = old_frame.creator
      return if (new_frame.creator_id == old_frame.creator_id) or !user_to.primary_email or (user_to.primary_email == "")
      
      # Temp: for now only send emails to gt_enabled users
      return unless user_to.gt_enabled
      
      return unless user_to.preferences.reroll_notifications
            
      NotificationMailer.reroll_notification(old_frame, new_frame).deliver
    end
    
    def self.send_new_message_notifications(c, new_message, user)
      raise ArgumentError, "must supply Conversation" unless c.is_a?(Conversation)
      raise ArgumentError, "must supply Message" unless new_message.is_a?(Message)
      raise ArgumentError, "must supply Message" unless user.is_a?(User)
      
      return false unless frame = c.frame
      
      # Email everybody...
      if c.frame and c.frame.roll and !c.frame.roll.public?
        # ...following a private roll
        users_to_email = c.frame.roll.following_users_models
      else
        # ..in the conversation (for a public roll)
        users_to_email = [frame.creator] + c.messages.map { |m| m.user }
      end
      users_to_email = users_to_email.uniq.compact
      
      # except for the person who just wrote this new message
      users_to_email -= [new_message.user]
      # and those who don't wish to receive comment notifications
      # Temp: for now only send emails to gt_enabled users
      users_to_email.select! { |u| u.gt_enabled and u.preferences and u.preferences.comment_notifications? }
      
      users_to_email.each { |u| NotificationMailer.comment_notification(u, new_message.user, frame, new_message).deliver unless u.primary_email.blank? }
      
    end

    def self.check_and_send_join_roll_notification(user_from, roll)
      raise ArgumentError, "must supply valid user" unless user_from.is_a?(User) and !user_from.blank?
      raise ArgumentError, "must supply valid roll" unless roll.is_a?(Roll) and !roll.blank?
      
      # for now only send emails to gt_enabled users
      return unless roll.creator and roll.creator.gt_enabled
            
      # don't email the creator if they are the user joining or they dont have an email address!
      user_to = roll.creator
      return if (user_from == user_to) or !user_to.primary_email or (user_to.primary_email == "")
      
      return unless user_to.preferences.roll_activity_notifications
      
      NotificationMailer.join_roll_notification(user_to, user_from, roll).deliver
    end
  end
end