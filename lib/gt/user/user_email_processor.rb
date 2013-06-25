# encoding: UTF-8
require 'framer'

##############
# Cycles through users and finds a video to recommend
#
#
module GT
  class UserEmailProcessor

    def initialize(should_send_email=false)
      @dbe_limit = 60 # How far back we are allowing this to search for a dbe with a video with a rec
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
      error_finding = 0

      User.collection.find(
        {:$and => [
          {:primary_email => {:$ne => ""}},
          {:primary_email => {:$ne => nil}},
          {"preferences.email_updates" => true},
          {:nickname => {:$in => [ 'henry',
            'matyus',
            'iceberg901',
            'chris',
            'vondoom',
            'reece',
            'spinosa',
            'kershite',
            'johnvehr',
            'sheynk',
            'nfpagliaro',
            'enelson1',
            'dihard',
            'blackopal',
            'iperry',
            'arthur',
            'jacqueline'
            ]}},
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
            # NOTE: dbe_with_rec.class = DashboardEntry
            if dbe_with_rec = scan_dashboard_entries_for_rec(user)

              found += 1

              # create new dashboard entry with action type = 31 (if video graph rec) based on video
              new_dbe = create_new_dashboard_entry(dbe_with_rec, DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])

              if new_dbe
                # use new dashboard entry to send email
                numSent += 1 if @should_send_email and NotificationMailer.weekly_recommendation(user, new_dbe).deliver
              else
                error_finding += 1
              end

            else
              not_found += 1
            end
          end
        end
      end
      puts "[GT::UserEmailProcessor] SENDING EMAIL: #{@should_send_email}"
      puts "[GT::UserEmailProcessor] FINISHED WEEKLY EMAIL NOTIFICATIONS PROCESS"
      puts "[GT::UserEmailProcessor] Rec Found: #{found}, Not found: #{not_found}, Error: #{error_finding}"
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
            next if dbe['action'] == DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]
            # get the video with only the rec key for each dbe
            video = Video.collection.find_one({ :_id => dbe["video_id"] }, { :fields => ["r"] })
            dbe_with_rec = dbe if video and video["r"] and !video["r"].empty?
            # if we find a dbe with a recommendation, return it
            return dbe_with_rec if dbe_with_rec
          end
        end
        dbe_count += @dbe_skip
      end
      # if we dont find a dbe with a rec after passing our limit on how far back to scan, just return nil
      return nil
    end

    def create_new_dashboard_entry(dbe, action)
      raise ArgumentError, "must supply valid dasboard entry record" unless dbe.is_a?(DashboardEntry)

      video_rec_id = dbe.video.recs.first.recommended_video_id

      new_dbe = GT::Framer.create_frame(
        :video_id => video_rec_id,
        :dashboard_user_id => dbe.user_id,
        :action => action,
        :dashboard_entry_options => {
          :src_frame => dbe.frame
        }
      )

      if new_dbe[:dashboard_entries] and !new_dbe[:dashboard_entries].empty?
        return new_dbe[:dashboard_entries].first
      else
        return nil
      end

    end

  end
end
