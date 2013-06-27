# encoding: UTF-8
require 'framer'
require 'api_clients/kiss_metrics_client'

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
      Rails.logger.info "[GT::UserEmailProcessor] STARTING WEEKLY EMAIL NOTIFICATIONS PROCESS"

      numSent = 0
      found = 0
      not_found =0
      error_finding = 0
      user_loaded = 0

      User.collection.find(
        {:$and => [
          {:primary_email => {:$ne => ""}},
          {:primary_email => {:$ne => nil}},
          {"preferences.email_updates" => true},
          {:nickname => 'henry'}
          ]},
        {
          :timeout => false,
          :fields => ["ag", "ac", "primary_email", "preferences", "nickname"],
          :limit => limit
        }
      ) do |cursor|
        cursor.each do |doc|
          Rails.logger.info("[weekly email proc] LOADING USER")
          user = User.load(doc)

          user_loaded += 1

          # check if they are real users that we need to process
          if is_real?(user)
            Rails.logger.info("[weekly email proc] USER IS REAL")
            # cycle through dashboard entries till a video is found with a recommendation
            # NOTE: dbe_with_rec.class = DashboardEntry
            if dbe_with_rec = scan_dashboard_entries_for_rec(user)
              Rails.logger.info("[weekly email proc] HAS DBE WITH REC")
              found += 1

              # create new dashboard entry with action type = 31 (if video graph rec) based on video
              new_dbe = create_new_dashboard_entry(user, dbe_with_rec, DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
              Rails.logger.info("[weekly email proc] NEW DBE CREATED")

              if new_dbe
                # use new dashboard entry to send email
                Rails.logger.info("[weekly email proc] SENDING EMAIL")
                numSent += 1 if @should_send_email and NotificationManager.send_weekly_recommendation(user, new_dbe)
                # track that email was sent
                APIClients::KissMetrics.identify_and_record(user, Settings::KissMetrics.metric['send_email']['weekly_rec_email'])
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
      puts "[GT::UserEmailProcessor] Users Loaded: #{user_loaded}, Rec Found: #{found}, Not found: #{not_found}, Error: #{error_finding}"
      puts "[GT::UserEmailProcessor] #{numSent} emails sent"

      stats = {
        :users_scanned => user_loaded,
        :sent_emails => numSent,
        :errors => error_finding
      }

      return stats
    end

    # only return real, gt_enabled (ag) users that are not service or faux user_type (ac)
    def is_real?(user)
      Rails.logger.info("[weekly email proc] is_real? - started")
      if (user["user_type"] == User::USER_TYPE[:real] || user["user_type"] == User::USER_TYPE[:converted]) && user["gt_enabled"]
        return true
      else
        return false
      end
    end

    # cycle through dashboard entries till a video is found with a recommendation
    def scan_dashboard_entries_for_rec(user)
      Rails.logger.info("[weekly email proc] scan_dashboard_entries_for_rec - started")
      # loop through dashboard entries until we find one with a rec,
      # stop at a predefined limit so as not to go on forever
      dbe_count = 0
      while (dbe_count < @dbe_limit)
        Rails.logger.info("[weekly email proc] scan_dashboard_entries_for_rec - dbe_count = #{dbe_count}")
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
      Rails.logger.info("[weekly email proc] scan_dashboard_entries_for_rec - no rec found")
      return nil
    end

    def create_new_dashboard_entry(user, dbe, action)
      raise ArgumentError, "must supply valid dasboard entry record" unless dbe.is_a?(DashboardEntry)

      Rails.logger.info("[weekly email proc] create_new_dashboard_entry - started")

      if video_rec_id = get_rec_from_video(user, dbe.video.recs)
        Rails.logger.info("[weekly email proc] create_new_dashboard_entry - have video_rec_id")
        new_dbe = GT::Framer.create_frame(
          :video_id => video_rec_id,
          :dashboard_user_id => dbe.user_id,
          :action => action,
          :dashboard_entry_options => {
            :src_frame => dbe.frame
          }
        )
        if new_dbe[:dashboard_entries] and !new_dbe[:dashboard_entries].empty?
          Rails.logger.info("[weekly email proc] create_new_dashboard_entry - CREATED NEW DBE")
          return new_dbe[:dashboard_entries].first
        else
          return nil
        end
      else
        return nil
      end

    end

    # Ensure that we aren't sending a video rec that a user has seen in the "recent" past
    def get_rec_from_video(user, recs)
      Rails.logger.info("[weekly email proc] get_rec_from_video - started")
      recs.each do |r|
        v = Frame.where(:roll_id => user.viewed_roll_id, :id => {"$gt" => BSON::ObjectId.from_time(6.months.ago)}, :video_id=> r['recommended_video_id']).distinct(:b)
        Rails.logger.info("[weekly email proc] get_rec_from_video - looking for frame with video")
        return r["recommended_video_id"] if v.empty?
      end
      return nil
    end

  end
end
