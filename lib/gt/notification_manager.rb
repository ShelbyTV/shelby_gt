require 'discussion_roll_utils'

module GT
  class NotificationManager

    def self.check_and_send_upvote_notification(user, frame)
      raise ArgumentError, "must supply valid user" unless user.is_a?(User) and !user.blank?
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?

      # don't email the creator if they are the upvoting user or they dont have an email address!
      user_to = frame.creator
      return if !user_to or (user == user_to) or !user_to.primary_email or (user_to.primary_email == "")

      # Temp: for now only send emails to gt_enabled users
      return unless frame.creator.gt_enabled

      return unless user_to.preferences.upvote_notifications

      NotificationMailer.upvote_notification(user_to, user, frame).deliver
    end

    def self.check_and_send_like_notification(frame, user_from=nil)
      raise ArgumentError, "must supply valid frame" unless frame.is_a?(Frame) and !frame.blank?

      # don't email the creator if they are the liking user or they dont have an email address!
      user_to = frame.creator
      return if !user_to or (user_from == user_to) or !user_to.primary_email or (user_to.primary_email == "")

      # Temp: for now only send emails to gt_enabled users
      return unless user_to.gt_enabled

      return unless user_to.preferences.like_notifications

      NotificationMailer.like_notification(user_to, frame, user_from).deliver
    end

    def self.check_and_send_reroll_notification(old_frame, new_frame)
      raise ArgumentError, "must supply valid new frame" unless new_frame.is_a?(Frame) and !new_frame.blank?
      raise ArgumentError, "must supply valid old frame" unless old_frame.is_a?(Frame) and !old_frame.blank?

      # don't email the creator if they are the upvoting user or they dont have an email address!
      return unless (user_to = old_frame.creator)
      return if (new_frame.creator_id == old_frame.creator_id) or user_to.primary_email.blank?

      # Temp: for now only send emails to gt_enabled users
      return unless user_to.gt_enabled

      return unless user_to.preferences.reroll_notifications

      NotificationMailer.reroll_notification(old_frame, new_frame).deliver
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

      users_to_email.each { |u| NotificationMailer.comment_notification(u, new_message.user, frame, new_message).deliver unless u.primary_email.blank? }

    end

    def self.check_and_send_comment_notification(frame)
      raise ArgumentError, "must supply a Frame" unless frame.is_a?(Frame)

      return unless frame.creator.preferences.comment_notifications

      NotificationMailer.disqus_comment_notification(frame, frame.creator).deliver
    end

    def self.check_and_send_join_roll_notification(user_from, roll)
      raise ArgumentError, "must supply valid user" unless user_from.is_a?(User) and !user_from.blank?
      raise ArgumentError, "must supply valid roll" unless roll.is_a?(Roll) and !roll.blank?

      # for now only send emails to gt_enabled users
      return unless roll.creator and roll.creator.gt_enabled

      # don't email the creator if they are the user joining or they dont have an email address!
      user_to = roll.creator
      return if (user_from == user_to) or !user_to.primary_email or (user_to.primary_email == "")

      return unless user_to.preferences.roll_activity_notifications

      NotificationMailer.join_roll_notification(user_to, user_from, roll).deliver
    end

    def self.check_and_send_invite_accepted_notification(inviter, invitee)
      raise ArgumentError, "must supply valid inviter" unless inviter.is_a?(User) and !inviter.blank?
      raise ArgumentError, "must supply valid invitee" unless invitee.is_a?(User) and !invitee.blank?

      return if !inviter.primary_email or inviter.primary_email == "" or !inviter.preferences.invite_accepted_notifications

      NotificationMailer.invite_accepted_notification(inviter, invitee, invitee.public_roll).deliver
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
          DiscussionRollMailer.on_discussion_roll_creation(opts).deliver
        else
          DiscussionRollMailer.on_discussion_roll_reply(opts).deliver
        end
      end
    end

    def self.send_weekly_recommendation(user, dbe, friend_users=nil)
      mail_message = NotificationMailer.weekly_recommendation(user, dbe, friend_users)
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

    private

      def self.email_address_for_participant(participant)
        participant.is_a?(User) ? participant.primary_email : participant
      end

      def self.identifier_for_participant(participant)
        participant.is_a?(User) ? participant.id : participant
      end

  end

end
