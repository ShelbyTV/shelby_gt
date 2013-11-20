class DashboardEntryCreator
  @queue = :dashboard_entries_queue

  def self.perform(frame_id, action, user_ids, options, persist)
    frame = Frame.find(frame_id)
    GT::Framer.create_dashboard_entries(frame, action, user_ids, options, persist)
    StatsManager::StatsD.increment(Settings::StatsConstants.framer['create_following_dbes'])
  end
end