# This is the one and only place where UserActions are created.
#
# The list of all UserActions, when played back, will represent the current state of the system.
# This state is always maintained in the other models.
#
module GT
  class UserActionManager

    def self.view!(user_id, frame_id, video_id, start_s=nil, end_s=nil)
      raise ArgumentError, "user_id must be valid ObjectId" unless user_id and BSON::ObjectId.legal? user_id.to_s
      raise ArgumentError, "frame_id must be valid BSON id" unless frame_id and BSON::ObjectId.legal? frame_id.to_s
      return nil unless video_id and BSON::ObjectId.legal? video_id.to_s
      
      start_s = start_s.to_i if start_s
      end_s = end_s.to_i if end_s
      raise ArgumentError, "start_s and end_s must both be nil or Integer" unless (start_s == nil and end_s == nil) or (start_s.is_a?(Integer) and end_s.is_a?(Integer))

      UserAction.create(:type => UserAction::TYPES[:view], :user_id => user_id, :frame_id => frame_id, :video_id => video_id, :start_s => start_s, :end_s => end_s)
    end

    def self.upvote!(user_id, frame_id) create_vote_action(user_id, frame_id, UserAction::TYPES[:upvote]); end
    def self.unupvote!(user_id, frame_id) create_vote_action(user_id, frame_id, UserAction::TYPES[:unupvote]); end

    def self.follow_roll!(user_id, roll_id) create_follow_action(user_id, roll_id, UserAction::TYPES[:follow_roll]); end
    def self.unfollow_roll!(user_id, roll_id) create_follow_action(user_id, roll_id, UserAction::TYPES[:unfollow_roll]); end

    def self.watch_later!(user_id, orig_frame_id) create_watch_later_action(user_id, orig_frame_id, UserAction::TYPES[:watch_later]); end
    def self.unwatch_later!(user_id, frame_id) create_watch_later_action(user_id, frame_id, UserAction::TYPES[:unwatch_later]); end

    def self.like!(user_id, frame_id, video_id) create_like_action(user_id, frame_id, video_id, UserAction::TYPES[:like]); end
    
    def self.frame_rolled!(user_id, frame_id, video_id, roll_id)
      raise ArgumentError, "user_id must be valid BSON id" unless user_id and BSON::ObjectId.legal? user_id.to_s
      raise ArgumentError, "frame_id must be valid BSON id" unless frame_id and BSON::ObjectId.legal? frame_id.to_s
      raise ArgumentError, "video_id must be valid BSON id" unless video_id and BSON::ObjectId.legal? video_id.to_s
      raise ArgumentError, "roll_id must be valid BSON id" unless roll_id and BSON::ObjectId.legal? roll_id.to_s

      UserAction.create(:type => UserAction::TYPES[:roll], :user_id => user_id, :frame_id => frame_id, :video_id => video_id, :roll_id => roll_id)
    end

    private

      def self.create_vote_action(user_id, frame_id, type)
        raise ArgumentError, "user_id must be valid BSON id" unless user_id and BSON::ObjectId.legal? user_id.to_s
        raise ArgumentError, "frame_id must be valid BSON id" unless frame_id and BSON::ObjectId.legal? frame_id.to_s

        UserAction.create(:type => type, :user_id => user_id, :frame_id => frame_id)
      end

      def self.create_follow_action(user_id, roll_id, type)
        raise ArgumentError, "user_id must be valid BSON id" unless user_id and BSON::ObjectId.legal? user_id.to_s
        raise ArgumentError, "roll_id must be valid BSON id" unless roll_id and BSON::ObjectId.legal? roll_id.to_s

        UserAction.create(:type => type, :user_id => user_id, :roll_id => roll_id)
      end

      def self.create_watch_later_action(user_id, frame_id, type)
        raise ArgumentError, "user_id must be valid BSON id" unless user_id and BSON::ObjectId.legal? user_id.to_s
        raise ArgumentError, "frame_id must be valid BSON id" unless frame_id and BSON::ObjectId.legal? frame_id.to_s

        UserAction.create(:type => type, :user_id => user_id, :frame_id => frame_id)
      end

      def self.create_like_action(user_id, frame_id, video_id, type)
        raise ArgumentError, "user_id must be valid BSON id" unless user_id and BSON::ObjectId.legal? user_id.to_s
        raise ArgumentError, "frame_id must be valid BSON id" unless frame_id and BSON::ObjectId.legal? frame_id.to_s
        raise ArgumentError, "video_id must be valid BSON id" unless video_id and BSON::ObjectId.legal? video_id.to_s

        UserAction.create(:type => type, :user_id => user_id, :frame_id => frame_id, :video_id => video_id)
      end

  end
end