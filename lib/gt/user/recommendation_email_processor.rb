# encoding: UTF-8
require 'framer'
require 'api_clients/kiss_metrics_client'
require 'recommendation_manager'

##############
# Cycles through users and finds a video to recommend
#
#
module GT
  class RecommendationEmailProcessor

    def self.process_send_weekly_rec_email_for_users(options={})

      defaults = {
        :send_emails => true,
      }

      options = defaults.merge(options)

      do_send_emails = options.delete(:send_emails)
      user_nicknames = options.delete(:user_nicknames)

      # loop through cursor of all users, primary_email is indexed, use it to filter collection.
      Rails.logger.info "[GT::RecommendationsEmailProcessor] STARTING WEEKLY RECOMMENDATION EMAIL PROCESS"

      user_loaded = 0
      user_sendable = 0
      num_sent = 0
      num_with_recs = 0
      num_with_no_recs = 0
      errors = 0

      if user_nicknames
        # user_nicknames parameter for testing allows us to send to only a specific set of users
        query = {:$and => [
          {:_id => {:$lte => BSON::ObjectId.from_time(Time.at(Time.now.utc.to_f.ceil))}},
          {:nickname => {:$in => user_nicknames}},
          {:primary_email => {:$nin => ["", nil]}},
          ]}
      else
        # under normal circumstances, we want to send to all users who have a valid email
        # and who have opted in to receive email updates
        query = {:$and => [
          {:_id => {:$lte => BSON::ObjectId.from_time(Time.at(Time.now.utc.to_f.ceil))}},
          {:primary_email => {:$nin => ["", nil]}},
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
          begin
            user = User.load(doc)

            user_loaded += 1

            # check if they are real users that we need to process
            if user.is_real? && user.gt_enabled
              user_sendable += 1
              dbes = self.get_recommendations_for_user(user)
              unless dbes.empty?
                num_with_recs += 1
                if do_send_emails && GT::NotificationManager.send_weekly_recommendation(user, dbes)
                  num_sent += 1
                  # track that email was sent
                  APIClients::KissMetrics.identify_and_record(user, Settings::KissMetrics.metric['send_email']['weekly_rec_email'])
                end
              else
                num_with_no_recs += 1
              end
            end
          rescue Exception => e
            Rails.logger.info "[GT::RecommendationsEmailProcessor] EXCEPTION: #{e}"
            Rails.logger.info "[GT::RecommendationsEmailProcessor] BACKTRACE:"
            e.backtrace.each do |line|
              Rails.logger.info line
            end
            errors += 1
          end
        end
      end
      Rails.logger.info "[GT::RecommendationsEmailProcessor] SENDING EMAIL: #{do_send_emails}"
      Rails.logger.info "[GT::RecommendationsEmailProcessor] FINISHED WEEKLY EMAIL NOTIFICATIONS PROCESS"
      Rails.logger.info "[GT::RecommendationsEmailProcessor] Users Loaded: #{user_loaded}"
      Rails.logger.info "[GT::RecommendationsEmailProcessor] #{num_sent} emails sent"

      stats = {
        :users_scanned => user_loaded,
        :user_sendable => user_sendable,
        :sent_emails => num_sent,
        :have_user_recommendations => num_with_recs,
        :no_user_recommendations => num_with_no_recs,
        :errors => errors
      }

      return stats
    end

    def self.get_recommendations_for_user(user)
      rec_manager = GT::RecommendationManager.new(user)
      recs = rec_manager.get_recs_for_user({
        :limits => [1,1,1],
        :sources => [DashboardEntry::ENTRY_TYPE[:video_graph_recommendation], DashboardEntry::ENTRY_TYPE[:channel_recommendation],  DashboardEntry::ENTRY_TYPE[:mortar_recommendation]],
        :video_graph_entries_to_scan => 60
      })

      dbes = recs.map { |rec|
        res = GT::RecommendationManager.create_recommendation_dbentry(
          user,
          rec[:recommended_video_id],
          rec[:action],
          {
            :src_id => rec[:src_id]
          }
        )
        res ? res[:dashboard_entry] : nil
      }.compact

      dbes.shuffle!

      return dbes
    end

  end
end
