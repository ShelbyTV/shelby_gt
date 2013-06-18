if Rails.env.development?
  class MailPreview < MailView

      def reroll_notification #old_roll, new_roll

        old_user = User.all.first
        old_user.primary_email = "test@test.com"
        old_roll = old_user.public_roll
        old_video = Video.all.first
        old_frame = Factory.create(:frame, :roll => old_roll, :video => old_video, :creator => old_user)

        new_user = User.all.last
        new_roll = new_user.public_roll
        new_video = Video.all.last
        new_frame = Factory.create(:frame, :roll => new_roll, :video => new_video, :creator => new_user)

        NotificationMailer.reroll_notification(old_frame, new_frame)

        # remove frames from db
        #new_frame.delete
        #old_frame.delete
      end

      def like_notification #(user_to, frame, user_from=nil)
        user_to = User.all.first
        user_from = User.all.last
        roll = user_to.public_roll
        video = Video.all.first
        frame = Factory.create(:frame, :roll => roll, :video => video, :creator => user_to)

        NotificationMailer.like_notification(user_to, frame, user_from)

        #frame.delete
      end

      def join_roll_notification # user_to, user_from, roll
        user_to = User.all.first
        user_from = User.all.last
        roll = user_to.public_roll

        NotificationMailer.join_roll_notification(user_to, user_from, roll)
      end

  end
end
