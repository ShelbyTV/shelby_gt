if Rails.env.development?
  require 'mortar_harvester'

  class MailPreview < MailView

      def reroll_notification #old_roll, new_roll

        old_user               = User.all.first
        old_user.primary_email = "test@test.com"
        old_roll               = old_user.public_roll
        old_video              = Video.all.first
        old_frame              = Factory.create(:frame, :roll => old_roll, :video => old_video, :creator => old_user)

        new_user  = User.all.last
        new_roll  = new_user.public_roll
        new_video = Video.all.last
        new_frame = Factory.create(:frame, :roll => new_roll, :video => new_video, :creator => new_user)

        NotificationMailer.reroll_notification(old_frame, new_frame)

        # remove frames from db
        #new_frame.delete
        #old_frame.delete
      end

      def like_notification #(user_to, frame, user_from=nil)
        user_to   = User.all.first
        user_from = User.all.last
        roll      = user_to.public_roll
        video     = Video.all.last
        frame     = Factory.create(:frame, :roll => roll, :video => video, :creator => user_to)

        NotificationMailer.like_notification(user_to, frame, user_from)

        #frame.delete
      end

      def join_roll_notification # user_to, user_from, roll
        user_to               = User.all.first
        user_to.primary_email = "test@test.com"
        user_from             = User.all.last
        roll                  = user_to.public_roll

        NotificationMailer.join_roll_notification(user_to, user_from, roll)
      end

      def disqus_comment_notification # frame
        user_to   = User.all.first
        roll      = user_to.public_roll
        video     = Video.all.last
        user_to.primary_email = "TEST@TEST.COM"
        frame     = Factory.create(:frame, :roll => roll, :video => video, :creator => user_to)

        NotificationMailer.disqus_comment_notification(frame, user_to)
      end

      def weekly_email_summary
        stats = {
          :users_scanned => 2013,
          :sent_emails => 1999,
          :errors => 1
        }
        AdminMailer.weekly_email_summary(stats)
      end

      def mortar_trial
        user = User.first
        user.id = '4f32e49fad9f11053b00020a'
        user.nickname = 'iceberg901'
        user.primary_email = 'josh@shelby.tv'
        recs = GT::MortarHarvester.get_recs_for_user(user, 9)

        MortarMailer.mortar_recommendation_trial(user, recs)
      end

      def mortar_trial_with_reason
        user = User.first
        user.id = '4f32e49fad9f11053b00020a'
        user.nickname = 'iceberg901'
        user.primary_email = 'josh@shelby.tv'
        recs = GT::MortarHarvester.get_recs_for_user(user, 9)

        MortarMailer.mortar_recommendation_trial(user, recs, true)
      end

      def weekly_recommendation__video_graph
        user      = User.first
        frame     = Factory.create(:frame, :video => Video.first, :creator => user, :conversation => Conversation.first)

        src_user  = User.last #Factory.create(:user)
        src_frame = Factory.create(:frame, :creator => src_user, :conversation => Conversation.first)

        db_entries = []
        db_entries.push(Factory.create(:dashboard_entry, :frame => frame, :src_frame => src_frame, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]))

        NotificationMailer.weekly_recommendation(user, db_entries)
      end
      def weekly_recommendation__mortar
        user      = User.first
        frame     = Factory.create(:frame, :video => Video.first, :creator => user, :conversation => Conversation.first)

        src_user  = User.last #Factory.create(:user)
        src_frame = Factory.create(:frame, :creator => src_user, :conversation => Conversation.first)

        db_entries = []
        db_entries.push(Factory.create(:dashboard_entry, :frame => frame, :src_frame => src_frame, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]))

        NotificationMailer.weekly_recommendation(user, db_entries)
      end
      def weekly_recommendation__channel
        user      = User.first
        frame     = Factory.create(:frame, :video => Video.first, :creator => user, :conversation => Conversation.first)

        src_user  = User.last #Factory.create(:user)
        src_frame = Factory.create(:frame, :creator => src_user, :conversation => Conversation.first)

        db_entries = []
        db_entries.push(Factory.create(:dashboard_entry, :frame => frame, :src_frame => src_frame, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]))

        NotificationMailer.weekly_recommendation(user, db_entries)
      end
      def weekly_recommendation__array
        user      = User.first
        frame     = Factory.create(:frame, :video => Video.first, :creator => user, :conversation => Conversation.first)

        src_user  = User.last #Factory.create(:user)
        src_frame = Factory.create(:frame, :creator => src_user, :conversation => Conversation.first)

        db_entries = []
        db_entries.push(Factory.create(:dashboard_entry, :frame => frame, :src_frame => src_frame, :action => DashboardEntry::ENTRY_TYPE[:video_graph_recommendation]))
        db_entries.push(Factory.create(:dashboard_entry, :frame => frame, :src_frame => src_frame, :action => DashboardEntry::ENTRY_TYPE[:mortar_recommendation]))
        db_entries.push(Factory.create(:dashboard_entry, :frame => frame, :src_frame => src_frame, :action => DashboardEntry::ENTRY_TYPE[:channel_recommendation]))

        #permalinks ≠ state dependent,
        #relative to user's stream

        NotificationMailer.weekly_recommendation(user, db_entries)
      end
  end
end
