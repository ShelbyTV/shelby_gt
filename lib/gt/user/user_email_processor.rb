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
      @pdbe_limit = 20 # How far back we are allowing this to search for a pdbe which hasn't been watched
      @dbe_limit = 60  # How far back we are allowing this to search for a dbe with a video with a rec
      @dbe_skip = 10

      # How many recently watched videos will we check to see if the user has watched the video we want to recommend
      @recent_videos_limit = 1000

      @should_send_email = should_send_email
    end

    def process_and_send_rec_email(user_nicknames=nil)
      # loop through cursor of all users, primary_email is indexed, use it to filter collection some.
      #  load them with following attributes: gt_enabled, user_type, primary_email, preferences
      Rails.logger.info "[GT::UserEmailProcessor] STARTING WEEKLY EMAIL NOTIFICATIONS PROCESS"

      numSent = 0
      found = 0
      found_pdbe = 0
      found_dbe_with_video_rec = 0
      not_found =0
      error_finding = 0
      user_loaded = 0

      if user_nicknames
        # user_nicknames parameter for testing allows us to send to only a specific set of users
        # and bypass the check on whether they have opted in to receive emails
        query = {:$and => [
          {:nickname => {:$in => user_nicknames}},
          {:primary_email => {:$ne => ""}},
          {:primary_email => {:$ne => nil}}
          ]}
      else
        # under normal circumstances, we want to send to all users who have a valid email
        # and who have opted in to receive email updates
        query = {:$and => [
          {:primary_email => {:$ne => ""}},
          {:primary_email => {:$ne => nil}},
          {"preferences.email_updates" => true}
          ]}
      end

      User.collection.find(
        query,
        {
          :timeout => false,
          :fields => ["ac", "af", "ag", "primary_email", "preferences", "nickname"]
        }
      ) do |cursor|
        cursor.each do |doc|
          user = User.load(doc)

          user_loaded += 1

          # check if they are real users that we need to process
          if is_real?(user)
            # cycle through dashboard entries till a video is found with a recommendation
            # NOTE: dbe_with_rec.class = DashboardEntry || PrioritizedDashboardEntry
            if dbe_with_rec = scan_dashboard_entries_for_rec(user)
              found += 1

              new_dbe = nil
              friend_users = nil
              if dbe_with_rec.is_a?(DashboardEntry)
                found_dbe_with_video_rec += 1
                # create new dashboard entry with action type = 31 (video graph rec) based on video
                new_dbe = create_new_dashboard_entry(user, dbe_with_rec, DashboardEntry::ENTRY_TYPE[:video_graph_recommendation])
              elsif dbe_with_rec.is_a?(PrioritizedDashboardEntry)
                found_pdbe +=1
                # create new dashboard entry with action type = 32 (entertainment graph rec) based on prioritized dashboard entry
                new_dbe = create_new_dashboard_entry_from_prioritized(user, dbe_with_rec)
                friend_users = new_dbe.all_associated_friends
              end

              if new_dbe
                # use new dashboard entry to send email
                if @should_send_email
                  numSent += 1 if NotificationManager.send_weekly_recommendation(user, new_dbe, friend_users)
                  # track that email was sent
                  APIClients::KissMetrics.identify_and_record(user, Settings::KissMetrics.metric['send_email']['weekly_rec_email'])
                end
              else
                error_finding += 1
              end

            else
              not_found += 1
            end
          end
        end
      end
      Rails.logger.info "[GT::UserEmailProcessor] SENDING EMAIL: #{@should_send_email}"
      Rails.logger.info "[GT::UserEmailProcessor] FINISHED WEEKLY EMAIL NOTIFICATIONS PROCESS"
      Rails.logger.info "[GT::UserEmailProcessor] Users Loaded: #{user_loaded}, Rec Found: #{found} - (#{found_dbe_with_video_rec} video graph, #{found_pdbe} entertainment graph), Not found: #{not_found}, Error: #{error_finding}"
      Rails.logger.info "[GT::UserEmailProcessor] #{numSent} emails sent"

      stats = {
        :users_scanned => user_loaded,
        :sent_emails => numSent,
        :video_graph_recs => found_dbe_with_video_rec,
        :entertainment_graph_recs => found_pdbe,
        :errors => error_finding
      }

      return stats
    end

    # only return real, gt_enabled (ag) users that are not service or faux user_type (ac)
    def is_real?(user)
      if (user["user_type"] == User::USER_TYPE[:real] || user["user_type"] == User::USER_TYPE[:converted]) && user["gt_enabled"]
        return true
      else
        return false
      end
    end

    # look for recommendations in this order
    # 1) a prioritized dashboard entry for the user, or fall back to
    # 2) a regular dashboard entry with a video with a recommendation
    def scan_dashboard_entries_for_rec(user)
      watched_video_ids = nil
      # if there's a prioritized dashboard entry not watched recently by the user, use that as the recommendation
      pdbe_cursor = PrioritizedDashboardEntry.for_user_id(user.id).ranked.limit(@pdbe_limit).find_each
      while (pdbe = pdbe_cursor.next)
        # once we know that we need to check something against the user's recently watched videos,
        # load them only once
        if !watched_video_ids
          watched_video_ids = user.viewed_roll_id ? Frame.where(:roll_id => user.viewed_roll_id).fields(:video_id).limit(@recent_videos_limit).all.map {|f| f.video_id}.compact : []
        end
        if !pdbe.watched_by_owner && !watched_video_ids.find_index(pdbe.video_id)
          # yay, we found an unwatched prioritized dashboard entry, return it immediately
          pdbe_cursor.close
          return pdbe
        end
      end
      pdbe_cursor.close

      # if there's no unwatched prioritized dashboard entry
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
        ) do |dbe_cursor|
          dbe_cursor.each do |doc|
            dbe = DashboardEntry.load(doc)
            next if dbe.is_recommendation?
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

    def create_new_dashboard_entry(user, dbe, action)
      raise ArgumentError, "must supply valid dasboard entry record" unless dbe.is_a?(DashboardEntry)

      if video_rec_id = get_rec_from_video(user, dbe.video.recs)
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
      else
        return nil
      end

    end

    def create_new_dashboard_entry_from_prioritized(user, pdbe)
      new_dbe = GT::Framer.create_frame(
        :video_id => pdbe.video_id,
        :dashboard_user_id => user.id,
        :action => DashboardEntry::ENTRY_TYPE[:entertainment_graph_recommendation],
        :dashboard_entry_options => {
          :friend_sharers_array => pdbe.friend_sharers_array,
          :friend_viewers_array => pdbe.friend_viewers_array,
          :friend_likers_array => pdbe.friend_likers_array,
          :friend_rollers_array => pdbe.friend_rollers_array,
          :friend_complete_viewers_array => pdbe.friend_complete_viewers_array,
        }
      )
      if new_dbe[:dashboard_entries] and !new_dbe[:dashboard_entries].empty?
        return new_dbe[:dashboard_entries].first
      else
        return nil
      end
    end

    # Ensure that we aren't sending a video rec that a user has seen in the "recent" past
    def get_rec_from_video(user, recs)
      frames = user.viewed_roll_id ? Frame.where(:roll_id => user.viewed_roll_id).fields(:id, :video_id).limit(@recent_videos_limit) : []
      recs.each do |r|
        video_watched = false
        frames.find_each.each do |f|
          if r['recommended_video_id'] == f.video_id
            video_watched = true
            break
          end
        end

        if !video_watched
          return r['recommended_video_id']
        else
          next
        end

      end
      return nil
    end

  end
end
