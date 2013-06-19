# encoding: UTF-8

# Looks up and returns user stats.
#
module GT
  class UserEmailProcessor

    DBE_LIMIT = 30 # Howfar back we are allowing this to search for a dbe with a video with a rec
    DBE_SKIP = 10
    TEST_LIMIT = 200 # FOR TESTING

    def self.send_rec_email
      # loop through cursor of all users, primary_email is indexed, use it to filter collection some.
      #  load them with following attributes: gt_enabled, user_type, primary_email, preferences
      puts "[GT::UserEmailProcessor] STARTING WEEKLY EMAIL NOTIFICATIONS PROCESS"
      numSent = 0
      User.collection.find(
        {:$and => [
          {:primary_email => {:$ne => ""}},
          {:primary_email => {:$ne => nil}},
          {"preferences.email_updates" => true},
          {:nickname => "henry"}
        ]},
        {
          :timeout => true,
          :fields => ["ag", "ac", "primary_email", "preferences", "nickname"],
          :limit => TEST_LIMIT
        }
      ) do |cursor|
        cursor.each do |doc|
          user = User.load(doc)
          puts "[GT::UserEmailProcessor] Processing user: #{user.nickname}, #{real_user_check(user)}"
          # check if they are real users that we need to process
          if real_user_check(user)
            # cycle through dashboard entries till a video is found with a recommendation
            dbe_with_rec = scan_dasboard_entries_for_rec(user)

            #numSent += 1 if Notification::Weekly.send(user)
          else
            # log this ?
          end
          #puts "[GT::UserEmailProcessor] Finished processing user: #{user.nickname}"
        end
      end


      #    if so,

      #      dashboard_entrie.video.recs.empty? // with a small limit and skipping
      #       clone dashboard entry with new action type
      #        use new dashboard entry to send email
      puts "[GT::UserEmailProcessor] FINISHED WEEKLY EMAIL NOTIFICATIONS PROCESS"
      puts "[GT::UserEmailProcessor] #{numSent} emails sent"
    end

    # only return real, gt_enabled (ag) users that are not service or faux user_type (ac)
    def real_user_check(user)
      if (user["ac"] == User::USER_TYPE[:real] || user["ac"] == User::USER_TYPE[:converted]) && user["ag"]
        return true
      else
        return false
      end
    end

    # cycle through dashboard entries till a video is found with a recommendation
    def scan_dasboard_entries_for_rec(user)
      dbe_count = 0
      until dbe_count == DBE_LIMIT
        DashboardEntry.collection.find(
          { :a => user["_id"] },
          {
            :limit => 10,
            :skip => dbe_count
          }
        ) do |cursor|
          cursor.each do |doc|
            video = Video.collection.find_one({ :_id => doc["g"] }, { :fields => ["r"] })
            if video and video["r"] and !video["r"].empty?
              puts "[GT::UserEmailProcessor] Found DBE with a video recommendation!"
            end
          end
        end
        dbe_count += DBE_SKIP
        puts "[GT::UserEmailProcessor] dbe_count: #{dbe_count}"
      end

    end

  end
end
