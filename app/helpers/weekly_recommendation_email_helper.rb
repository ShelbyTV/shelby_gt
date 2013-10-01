module WeeklyRecommendationEmailHelper

  def message_text(dbe, friend_users=nil)
    if dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      "We've discovered that this video is similar to those that #{dbe.src_frame.creator.name || dbe.src_frame.creator.nickname} are sharing, liking, and watching."
    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
      friend_users_count = friend_users.count
      if friend_users_count > 1
        "#{friend_users.first.nickname} and #{pluralize(friend_users_count - 1, 'other')} are sharing, liking, and watching this video."
      else
        "We've discovered that #{friend_users.first.nickname} checked out this video."
      end
    end
  end

  def message_subject(dbes, friend_users=nil)
    first_dbe = dbes.first
    if first_dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
       "We've discovered that this video is similar to those that #{first_dbe.src_frame.creator.nickname} are sharing, liking, and watching."
    elsif first_dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
      friend_users_count = friend_users.count
      if friend_users_count > 1
        "Watch this video that #{friend_users.first.nickname} and #{pluralize(friend_users_count - 1, 'other')} shared, liked, and watched"
      else
        "Watch this video that #{friend_users.first.nickname} watched"
      end
    end
  end

end
