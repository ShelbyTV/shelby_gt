class RollFollower
  @queue = :roll_follower_queue

  def self.perform(user, roll_id)
    roll = Roll.find(Settings::Roll.shelby_roll_id)
    roll.add_follower(user, false)
    GT::Framer.backfill_dashboard_entries(user, roll, 30, {:async_dashboard_entries => false})
  end

end
