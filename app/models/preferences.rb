class Preferences
  include MongoMapper::EmbeddedDocument
  
  embedded_in :user 
  
  # User Preferences (eg emails, notifications, etc)
  key :email_updates,                 Boolean, :default => true
  key :like_notifications,            Boolean, :default => true
  key :watched_notifications,         Boolean, :default => true
  key :upvote_notifications,          Boolean, :default => true
  key :comment_notifications,         Boolean, :default => true
  key :reroll_notifications,          Boolean, :default => true  
  key :roll_activity_notifications,   Boolean, :default => true
  key :open_graph_posting,            Boolean
  key :discussion_roll_notifications, Boolean, :default => true
  key :invite_accepted_notifications, Boolean, :default => true
  
  
  def can_post_to_open_graph?
    if self.open_graph_posting == true
      return true
    elsif self.open_graph_posting == false
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