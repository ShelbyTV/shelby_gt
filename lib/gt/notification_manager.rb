require 'discussion_roll_utils'
require 'apple_push_notification_services_manager'

module GT
  class NotificationManager

    def self.check_and_send_upvote_notification(user, frame)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?

      # don't email the creator if they are the upvoting user or they dont have an email address!
      user_to = frame.creator
      return if !user_to or (user == user_to) or !user_to.primary_email or (user_to.primary_email == "") or !user_to.is_real?

      # Temp: for now only send emails to gt_enabled users
      return unless frame.creator.gt_enabled

      return unless user_to.preferences.upvote_notifications

      #NotificationMailer.upvote_notification(user_to, user, frame).deliver
    end

    def self.check_and_send_like_notification(frame, user_from=nil, destinations=[:email])
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?

      user_to = frame.creator

      if destinations.include?(:email)
        # don't email the creator if they are the liking user or they dont have an email address!
        if !user_to or (user_from == user_to) or !user_to.primary_email or (user_to.primary_email == "") or !user_to.preferences.like_notifications or !user_to.is_real?
          StatsManager::StatsD.increment(Settings::StatsConstants.notification['not_sent']['like'])
          return
        else
          StatsManager::StatsD.increment(Settings::StatsConstants.notification['sent']['like'])
          #NotificationMailer.like_notification(user_to, frame, user_from).deliver
        end
      end
      if destinations.include?(:notification_center) && user_to && (user_from != user_to)
        # create dbe for iOS Push and Notification Center notifications, asynchronously
        # if the liking user has user_type anonymous or there is no liking user, treat this as an anonymous like notification
        user_from = nil if user_from && user_from.user_type == User::USER_TYPE[:anonymous]
        dbe_type = user_from ? DashboardEntry::ENTRY_TYPE[:like_notification] : DashboardEntry::ENTRY_TYPE[:anonymous_like_notification]
        options = {:actor_id => user_from && user_from.id}
        # if the user is eligible, also do an ios push notification
        if user_to && user_to.preferences.like_notifications_ios && !user_to.apn_tokens.empty? && user_to.is_real?
          user_from_name = user_from ? (user_from.name_or_nickname) : "Someone"
          alert = insert_invisible_character_at_random_position(Settings::PushNotifications.like_notification['alert'] % { :likers_name => user_from_name })
          options[:push_notification_options] = {
            :devices => user_to.apn_tokens,
            :alert => alert,
            :ga_event => {
              :category => "Push Notification",
              :action => "Send Like Notification",
              :label => user_to.id
            }
          }
        end
        GT::Framer.create_dashboard_entries_async([frame], dbe_type, [user_to.id], options)
      end
    end

    def self.check_and_send_reroll_notification(old_frame, new_frame, destinations=[:email])
      raise ArgumentError, "must supply valid new frame" unless new_frame.is_a?(Frame) and !new_frame.blank?
      raise ArgumentError, "must supply valid old frame" unless old_frame.is_a?(Frame) and !old_frame.blank?

      return unless (user_to = old_frame.creator)
      user_from_id = new_frame.creator_id

      if destinations.include?(:email)
        # don't email the creator if they are the upvoting user or they dont have an email address!
        if (user_from_id == user_to.id) or user_to.primary_email.blank? or !user_to.preferences.reroll_notifications or !user_to.gt_enabled or !user_to.is_real?
          StatsManager::StatsD.increment(Settings::StatsConstants.notification['not_sent']['share'])
          return
        else
          StatsManager::StatsD.increment(Settings::StatsConstants.notification['sent']['share'])
          #NotificationMailer.reroll_notification(old_frame, new_frame).deliver
        end
      end
      if destinations.include?(:notification_center) && (user_from_id != user_to.id)
        # create dbe for iOS Push and Notification Center notifications, asynchronously
        options = {:actor_id => user_from_id}
        # if the user is eligible, also do an ios push notification
        if user_to.preferences.reroll_notifications_ios && !user_to.apn_tokens.empty? && user_to.is_real?
          user_from = new_frame.creator
          user_from_name = user_from.name_or_nickname
          alert = insert_invisible_character_at_random_position(Settings::PushNotifications.reroll_notification['alert'] % { :re_rollers_name => user_from_name })
          options[:push_notification_options] = {
            :devices => user_to.apn_tokens,
            :alert => alert,
            :ga_event => {
              :category => "Push Notification",
              :action => "Send Share Notification",
              :label => user_to.id
            }
          }
        end
        GT::Framer.create_dashboard_entries_async([old_frame], DashboardEntry::ENTRY_TYPE[:share_notification], [user_to.id], options)
      end
    end

    def self.send_new_message_notifications(c, new_message, user)
      raise ArgumentError, "must supply Conversation" unless c.is_a?(Conversation)
      raise ArgumentError, "must supply Message" unless new_message.is_a?(Message)
      raise ArgumentError, "must supply Message" unless user.is_a?(User)

      return false unless frame = c.frame

      # Email everybody...
      if c.frame and c.frame.roll and !c.frame.roll.public?
        # ...following a private roll
        users_to_email = c.frame.roll.following_users_models
      else
        # ..in the conversation (for a public roll)
        users_to_email = [frame.creator] + c.messages.map { |m| m.user }
      end
      users_to_email = users_to_email.uniq.compact

      # except for the person who just wrote this new message
      users_to_email -= [new_message.user]
      # and those who don't wish to receive comment notifications
      # Temp: for now only send emails to gt_enabled users
      users_to_email.select! { |u| u.gt_enabled and u.preferences and u.preferences.comment_notifications? }

      #users_to_email.each { |u| NotificationMailer.comment_notification(u, new_message.user, frame, new_message).deliver unless u.primary_email.blank? }

    end

    def self.check_and_send_comment_notification(frame)
      raise ArgumentError, "must supply a Frame" unless frame.is_a?(Frame)

      return unless frame.creator.preferences.comment_notifications

      #NotificationMailer.disqus_comment_notification(frame, frame.creator).deliver
    end

    def self.check_and_send_join_roll_notification(user_from, roll, destinations=[:email])
      raise ArgumentError, "must supply valid user" unless user_from.is_a?(User) and !user_from.blank?
      raise ArgumentError, "must supply valid roll" unless roll.is_a?(Roll) and !roll.blank?

      user_to = roll.creator

      # for now only send notifications to gt_enabled users
      return unless user_to and user_to.gt_enabled and user_to.is_real?

      if destinations.include?(:email)
        # don't email the creator if they are the user joining or they dont have an email address!
        if (user_from == user_to) || !user_to.primary_email || (user_to.primary_email == "") ||
           !user_to.preferences.roll_activity_notifications || !user_to.is_real? || (user_from.user_type == User::USER_TYPE[:anonymous])
          StatsManager::StatsD.increment(Settings::StatsConstants.notification['not_sent']['follow'])
          return
        else
          StatsManager::StatsD.increment(Settings::StatsConstants.notification['sent']['follow'])
          #NotificationMailer.join_roll_notification(user_to, user_from, roll).deliver
        end
      end
      if destinations.include?(:notification_center) && (user_from != user_to) && (user_from.user_type != User::USER_TYPE[:anonymous])
        # create dbe for iOS Push and Notification Center notifications, asynchronously
        GT::Framer.create_dashboard_entries_async([nil], DashboardEntry::ENTRY_TYPE[:follow_notification], [user_to.id], {:actor_id => user_from.id})
        # if the user is eligible, also do an ios push notification
        if user_to.preferences.roll_activity_notifications_ios && !user_to.apn_tokens.empty?
          user_from_name = user_from.name_or_nickname
          alert = insert_invisible_character_at_random_position(Settings::PushNotifications.follow_notification['alert'] % { :followers_name => user_from_name })
          GT::ApplePushNotificationServicesManager.push_notification_to_user_devices_async(
            user_to,
            alert,
            {
              :user_id => user_from.id,
              :ga_event => {
                :category => "Push Notification",
                :action => "Send Follow Notification",
                :label => user_to.id
              }
            }
          )
        end
      end
    end

    def self.check_and_send_invite_accepted_notification(inviter, invitee)
      raise ArgumentError, "must supply valid inviter" unless inviter.is_a?(User) and !inviter.blank?
      raise ArgumentError, "must supply valid invitee" unless invitee.is_a?(User) and !invitee.blank?

      return if !inviter.primary_email or inviter.primary_email == "" or !inviter.preferences.invite_accepted_notifications

      #NotificationMailer.invite_accepted_notification(inviter, invitee, invitee.public_roll).deliver
    end

    # Email all of the participants, except for the posting_participant.
    # Emails are slightly different if this is the initial_email or not, but otherwise similar:
    #   subject identifies who sent the video (or reply) and who they sent it to (you + others)
    #   meat of the body is a summary of the current state of the conversation, similar to web view of convo
    #   body also contains additional explanatory copy
    #
    # discussion_roll: a Roll
    # posting_participant: a User or an email address (as String)
    # initial_email: is this notificaiton being sent as the direct result of creating a new (dicussion) Roll?
    #                if so, the email is altered to put focus on explaining what Shelby Mail is
    def self.send_discussion_roll_notifications(discussion_roll, posting_participant, initial_email=false)
      raise ArgumentError, "must supply discussion roll" unless discussion_roll.is_a?(Roll)
      raise ArgumentError, "must supply poster as User or email address" unless posting_participant.is_a?(User) or posting_participant.is_a?(String)

      # Full array of everybody in the conversation, ex: [UserObject1, "email1@gmail.com", UserObject2, "email2@gmail.com", ...]
      # NB: This does include posting_participant
      all_participants = discussion_roll.discussion_roll_participants.map { |p| BSON::ObjectId.legal?(p) ? User.find(p) : p } .compact

      (all_participants - [posting_participant]).each do |receiving_participant|
        next if receiving_participant.is_a?(User) and !receiving_participant.preferences.discussion_roll_notifications?

        receiving_participant_email_address = email_address_for_participant(receiving_participant)
        token = GT::DiscussionRollUtils.encrypt_roll_user_identification(discussion_roll, identifier_for_participant(receiving_participant))

        opts = {
          :discussion_roll => discussion_roll,
          :posting_participant => posting_participant,
          :receiving_participant => receiving_participant,
          :receiving_participant_email_address => receiving_participant_email_address,
          :all_participants => all_participants,
          :token => token
        }

        if initial_email
          #DiscussionRollMailer.on_discussion_roll_creation(opts).deliver
        else
          #DiscussionRollMailer.on_discussion_roll_reply(opts).deliver
        end
      end
    end

    def self.send_weekly_recommendation(user, dbes, options=nil)
      mail_message = NotificationMailer.weekly_recommendation(user, dbes, options)
      # override the smtp settings to relay this through Shelby's onboard postfix server
      mail_message.delivery_method.settings = {
        :address => Settings::Email.postfix["server_address"],
        :domain => Settings::Email.postfix["server_domain"],
        :user_name => nil,
        :password => nil,
        :authentication => nil,
        :enable_starttls_auto => false
      }
      mail_message.deliver
    end

    def self.send_takeout_notification(user, email_to, attachment)
      mail_message = NotificationMailer.takeout_notification(user, email_to, attachment)

      mail_message.deliver
    end

    private

      def self.email_address_for_participant(participant)
        participant.is_a?(User) ? participant.primary_email : participant
      end

      def self.identifier_for_participant(participant)
        participant.is_a?(User) ? participant.id : participant
      end

      # to avoid some problems with iOS push notifications it's important that we not send messages with identical contents
      # so, we use this to insert an invisible character at a random position to make the messages unique with high probability
      # http://stackoverflow.com/questions/18074529/duplicate-push-notifications-on-ios
      # NB: This could become a problem when we internationalize, so hopefully Apple will fix their bug and we can take this out

      def self.insert_invisible_character_at_random_position(message)
        message.clone.insert(rand(message.length + 1), "\u200C")
      end

  end

end
