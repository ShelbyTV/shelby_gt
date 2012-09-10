module ApplicationHelper
  
  # future times => "just now"
  # < 1 minute => "just now"
  # 1m - 59m => "Xm"
  # 1h - 12h => "Xh"
  # > 12h => "MMM dd" (Feb 22 or Dec 1)
  def concise_time_ago_in_words(from_time, to_time=Time.now)
    if from_time.respond_to?(:to_time) and to_time.respond_to?(:to_time)
      from_time = from_time.to_time
      to_time = to_time.to_time
    else
      return ""
    end
    distance_in_minutes = (((to_time - from_time))/60).round
    
    return "just now" if distance_in_minutes <= 1
    
    case distance_in_minutes
    when 1..59 then "#{distance_in_minutes}m ago"
    when 60..720 then "#{distance_in_minutes/60}h ago"
    else
      from_time.respond_to?(:strftime) ? from_time.strftime("%b %-d") : ""
    end
  end
  
  #valid avatar_size options are "small", "large", "original"
  def avatar_url_for_user(user, avatar_size="small")
    if user.avatar?
      return user.shelby_avatar_url(avatar_size)
    else
      return user.user_image_original || user.user_image || "/images/assets/avatar.png"
    end
  end
  
end
