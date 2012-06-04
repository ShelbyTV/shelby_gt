class Preferences
  include MongoMapper::EmbeddedDocument
  
  embedded_in :user 
  
  # User Preferences (eg emails, notifications, etc)
  key :email_updates,               Boolean, :default => true
  key :like_notifications,          Boolean, :default => true
  key :watched_notifications,       Boolean, :default => true
  key :upvote_notifications,        Boolean, :default => true
  key :comment_notifications,       Boolean, :default => true
  key :reroll_notifications,        Boolean, :default => true  
  key :roll_activity_notifications, Boolean, :default => true
  key :quiet_mode,                  Boolean
  
  
  def enabled_quiet_mode?
    if self.quiet_mode == true
      return true
    elsif self.quiet_mode == false
      return false
    else
      return nil
    end
  end
  
  def can_email?
     self.email_updates
  end
  
  def can_send_like_notifications?
    self.like_notifications
  end
  
  def can_send_watch_notifications?
    self.watched_notifications
  end
  
end