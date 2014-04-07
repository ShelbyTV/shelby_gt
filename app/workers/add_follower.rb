class AddFollower
  @queue = :add_follower_queue

  def self.perform(roll_id, user_id, send_notification=false)
    roll = Roll.find(roll_id)
    user = User.find(user_id)
    roll.add_follower(user, send_notification)
  end

end
