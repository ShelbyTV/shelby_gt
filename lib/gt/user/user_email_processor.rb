# encoding: UTF-8

# Looks up and returns user stats.
#
module GT
  class UserEmailProcessor

    def initialize(should_send_email=false)
      @dbe_limit = 30 # How far back we are allowing this to search for a dbe with a video with a rec
      @dbe_skip = 10
      @user_limit = 2000 # FOR TESTING

      @should_send_email = should_send_email
    end

    def process_and_send_rec_email(limit=@user_limit)
      # loop through cursor of all users, primary_email is indexed, use it to filter collection some.
      #  load them with following attributes: gt_enabled, user_type, primary_email, preferences
      puts "[GT::UserEmailProcessor] STARTING WEEKLY EMAIL NOTIFICATIONS PROCESS"
      numSent = 0
      found = 0
      not_found =0

      User.collection.find(
        {:$and => [
          {:primary_email => {:$ne => ""}},
          {:primary_email => {:$ne => nil}},
          {"preferences.email_updates" => true}
        ]},
        {
          :timeout => false,
          :fields => ["ag", "ac", "primary_email", "preferences", "nickname"],
          :limit => limit
        }
      ) do |cursor|
        cursor.each do |doc|
          user = User.load(doc)
          # check if they are real users that we need to process
          if is_real?(user)
            # cycle through dashboard entries till a video is found with a recommendation
            dbe_with_rec = scan_dashboard_entries_for_rec(user)
            if dbe_with_rec
              found += 1
              # TODO:
              # - clone dashboard entry with action type = 31
              # - use new dashboard entry to send email
              #
            else
              not_found += 1
            end
            numSent += 1 #if Notification::Weekly.send(user)
          end
        end
      end
      puts "[GT::UserEmailProcessor] SEND EMAIL: #{@should_send_email}"
      puts "[GT::UserEmailProcessor] FINISHED WEEKLY EMAIL NOTIFICATIONS PROCESS"
      puts "[GT::UserEmailProcessor] Rec Found: #{found}, Not found: #{not_found}"
      puts "[GT::UserEmailProcessor] #{numSent} emails sent"
    end

    # only return real, gt_enabled (ag) users that are not service or faux user_type (ac)
    def is_real?(user)
      if (user["user_type"] == User::USER_TYPE[:real] || user["user_type"] == User::USER_TYPE[:converted]) && user["gt_enabled"]
        return true
      else
        return false
      end
    end

    # cycle through dashboard entries till a video is found with a recommendation
    def scan_dashboard_entries_for_rec(user)
      # loop through dashboard entries until we find one with a rec,
      # stop at a predefined limit so as not to go on forever
      dbe_count = 0
      while (dbe_count < @dbe_limit)
        DashboardEntry.collection.find(
          { :a => user.id },
          {
            :limit => 10,
            :skip => dbe_count
          }
        ) do |cursor|
          cursor.each do |doc|
            dbe = DashboardEntry.load(doc)
            # get the video with only the rec key for each dbe
            video = Video.collection.find_one({ :_id => dbe["video_id"] }, { :fields => ["r"] })
            @dbe_with_rec = dbe if video and video["r"] and !video["r"].empty?
          end
        end
        dbe_count += @dbe_skip
        # if we find a dbe with a recommendation, return it
        return @dbe_with_rec if @dbe_with_rec
      end
      # if we dont find a dbe with a rec after passing our limit on how far back to scan, just return nil
      return nil unless @dbe_with_rec
    end

  end
end
