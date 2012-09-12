module RollHelper

  # This is used in the context: "Dan is following your <title_for_roll_on_follow>"
  def title_for_roll_on_follow(roll)
    case roll.roll_type
    when Roll::TYPES[:special_watch_later]
      "Queue"
    when Roll::TYPES[:special_public_real_user], Roll::TYPES[:special_public], Roll::TYPES[:special_public_upgraded]
      "Personal Roll"
    when Roll::TYPES[:special_upvoted]
      "Hearts Roll"
    else 
      "roll: #{roll.title}"
    end

  end

end