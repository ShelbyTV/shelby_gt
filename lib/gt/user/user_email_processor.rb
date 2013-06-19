# encoding: UTF-8

# Looks up and returns user stats.
#
module GT
  class UserEmailProcessor

    def self.send_rec_email

    end

    def real_user_check(user)
      if (user.user_type == User::USER_TYPE[:real] || user.user_type == User::USER_TYPE[:converted]) && user.gt_enabled
        return user
      else
        return nil
      end
    end

  end
end
