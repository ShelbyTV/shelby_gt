module WeeklyRecommendationEmailHelper

  def message_text(dbes)
    if dbes.count > 1
      "Some video to share with friends and family..." #"Today's top recommendations, just for you"
    else
      dbe = dbes.first
      case dbe.action
      when DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
        verb = frame_action_string(dbe.src_frame)
        "This video is similar to videos #{dbe.src_frame.creator.nickname} has #{verb}"
      when DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        "This video is similar to \"#{dbe.src_video.title}\""
      when DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        verb = frame_action_string(dbe.frame)
        "This featured video was #{verb} by #{dbe.frame.creator.nickname}"
      when DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
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
      "From us to you. Enjoy!"
    else
      dbe = dbes.first
      case dbe.action
      when DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
        verb = frame_action_string(dbe.src_frame)
        "Watch this, it's similar to videos #{dbe.src_frame.creator.nickname} has #{verb}"
      when DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
        "A video because you liked: \"#{dbe.src_video.title}\""
      when DashboardEntry::ENTRY_TYPE[:channel_recommendation]
        verb = frame_action_string(dbe.frame)
        "This video was #{verb} by #{dbe.frame.creator.nickname}. Check it out."
      when DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
        friend_users = dbe.all_associated_friends
        if friend_users.count > 1
          "Watch this video that #{friend_users.first.nickname} and #{pluralize(friend_users.count - 1, 'other')} shared, liked, and watched"
        else
          "Watch this video that #{friend_users.first.nickname} watched"
        end
      end
    end
  end

  def frame_footer_message(frame)
    frame.conversation.messages.first.text if frame.conversation and frame.conversation.messages and frame.conversation.messages.first
  end

  def dashboard_entry_footer_message(dbe)
    if dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      # VIDEO GRAPH
      if dbe.src_frame && dbe.src_frame.creator
        verb = frame_action_string(dbe.src_frame)
        return "This video is similar to videos #{dbe.src_frame.creator.nickname} has #{verb}"
      else
        return "Check out this video"
      end

    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
      return "There are a lot of people are sharing, liking, and watching this video"

    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
      # MORTAR GRAPH
      if dbe.src_video && dbe.src_video.title
        return "Because you liked #{dbe.src_video.title}"
      else
        return "This video is similar to videos you have liked"
      end

    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:channel_recommendation]
      # CHANNEL
      return dbe.frame.conversation.messages.first.text if dbe.frame.conversation and dbe.frame.conversation.messages and dbe.frame.conversation.messages.first
    else
      return dbe.frame.conversation.messages.first.text if dbe.frame.conversation and dbe.frame.conversation.messages and dbe.frame.conversation.messages.first
    end
  end

  def dashboard_entry_footer_avatar(dbe)
    if dbe.action == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
      return "http://#{Settings::Global.web_host}/images/recommendations/share-2.jpg"
    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation]
      return "http://#{Settings::Global.web_host}/images/recommendations/share-1.jpg"
    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:mortar_recommendation]
      return "http://#{Settings::Global.web_host}/images/recommendations/share-2.jpg"
    elsif dbe.action == DashboardEntry::ENTRY_TYPE[:channel_recommendation]
      return avatar_url_for_user(dbe.frame.creator)
    else
      return avatar_url_for_user(dbe.frame.creator)
    end
  end

  private

    def frame_action_string(frame)
      (frame.frame_type == Frame::FRAME_TYPE[:light_weight]) ? "liked" : "shared"
    end

end
