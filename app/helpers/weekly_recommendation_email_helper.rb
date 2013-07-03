module WeeklyRecommendationEmailHelper

  def message_text(dbe, friend_users=nil)
    if dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      "We've discovered that people like #{dbe.src_frame.creator.nickname} are sharing, liking, and watching this video."
    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
      friend_users_count = friend_users.count
      "#{friend_users.first.nickname}#{ friend_users_count > 1 ? " and #{pluralize(friend_users_count - 1, 'other')}" : ''} #{friend_users_count > 1 ? "are" : "is"} sharing, liking, and watching this video."
    end
  end

end