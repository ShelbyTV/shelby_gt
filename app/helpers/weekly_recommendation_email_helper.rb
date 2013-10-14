module WeeklyRecommendationEmailHelper

  def message_text(dbes)
    if dbes.count > 1
      "Today's top recommendations, just for you"
    else
      dbe = dbes.first
      if dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
        "This video is similar to videos #{dbe.src_frame.creator.nickname} has shared"
      elsif dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
        friend_users = dbe.all_associated_friends
        if friend_users.count > 1
          "#{friend_users.first.nickname} and #{pluralize(friend_users.count - 1, 'other')} are sharing, liking, and watching this video."
        else
          "We've discovered that #{friend_users.first.nickname} checked out this video."
        end
      end
    end
  end

  def message_subject(dbes)
    if dbes.count > 1
      "Have a few minutes?"
    else
      dbe = dbes.first
      if dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
         "This video is similar to videos #{dbe.src_frame.creator.nickname} has shared"
      elsif dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
        friend_users = dbe.all_associated_friends
        if friend_users.count > 1
          "Watch this video that #{friend_users.first.nickname} and #{pluralize(friend_users.count - 1, 'other')} shared, liked, and watched"
        else
          "Watch this video that #{friend_users.first.nickname} watched"
        end
      end
    end
  end

  def frame_footer_message(dbe)
    if dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      # VIDEO GRAPH
      if dbe.src_frame && dbe.src_frame.creator
        return "This video is similar to videos #{dbe.src_frame.creator.nickname} has shared"
      else
        return "Check out this video"
      end

    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
      return "There are a lot of people are sharing, liking, and watching this video"

    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
      # MORTAR GRAPH
      if dbe.src_video && dbe.src_video.title
        return "Because you shared #{dbe.src_video.title}"
      else
        return "This video is similar to videos you have shared"
      end

    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:channel_recommendation]
      # CHANNEL
      return dbe.frame.conversation.messages.first.text if dbe.frame.conversation and dbe.frame.conversation.messages and dbe.frame.conversation.messages.first
    else
      return dbe.frame.conversation.messages.first.text if dbe.frame.conversation and dbe.frame.conversation.messages and dbe.frame.conversation.messages.first
    end
  end

  def frame_footer_avatar(dbe)
    if dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      return "//#{Settings::Global.web_host}/images/recommendations/share-2.jpg"
    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
      return "//#{Settings::Global.web_host}/images/recommendations/share-1.jpg"
    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
      return "//#{Settings::Global.web_host}/images/recommendations/share-2.jpg"
    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:channel_recommendation]
      return avatar_url_for_user(dbe.frame.creator)
    else
      return avatar_url_for_user(dbe.frame.creator)
    end
  end

end
