# encoding: UTF-8
require 'user_manager'

# This class does one thing: merges two users together.
# When the process is done, the into_user will exist and the other user will be gone.
# All actions taken, frames rolled, dashboard entries, etc. by the other_user will be converted
# to into_user actions/frames/etc.
#
module GT
  class UserMerger

    # Merges Authentications, special Rolls, Rolls created, and DashboardEntries.
    # Destroys other_user
    def self.merge_users(other_user, into_user)
      raise ArgumentError, "must supply two valid User's" unless other_user.is_a?(User) and into_user.is_a?(User)

      return false unless self.ensure_valid_user(into_user)

      return false unless self.move_authentications(other_user, into_user)

      # Array of special roll ids so we don't try to double-convert
      special_roll_ids = []
      special_roll_ids << other_user.public_roll.id if other_user.public_roll
      special_roll_ids << other_user.watch_later_roll.id if other_user.watch_later_roll
      special_roll_ids << other_user.upvoted_roll.id if other_user.upvoted_roll
      special_roll_ids << other_user.viewed_roll.id if other_user.viewed_roll

      # Merge the special rolls (and destroy the old ones)
      self.merge_rolls_in_background(other_user.public_roll, other_user, into_user.public_roll, into_user) if other_user.public_roll
      self.merge_rolls_in_background(other_user.watch_later_roll, other_user, into_user.watch_later_roll, into_user) if other_user.watch_later_roll
      self.merge_rolls_in_background(other_user.upvoted_roll, other_user, into_user.upvoted_roll, into_user) if other_user.upvoted_roll
      self.merge_rolls_in_background(other_user.viewed_roll, other_user, into_user.viewed_roll, into_user) if other_user.viewed_roll

      # Change ownership of non-special rolls created by other_user (also takes care Frames)
      Roll.where(:creator_id => other_user.id, :_id.ne => special_roll_ids ).each do |other_roll|
        self.change_roll_ownership_in_background(other_roll, other_user, into_user)
      end

      # Change ownership of DashboardEntries
      self.move_dashboard_entries_in_background(other_user, into_user)

      # Follow public rolls of friends from social networks that Shelby already knows about
      self.follow_all_friends_public_rolls(into_user)

      # If the user being merged in was a faux user, start video processing for the new auth from that user
      self.initialize_video_processing(into_user, other_user.authentications.first) if other_user.user_type == User::USER_TYPE[:faux]

      # Destroy the other user which we have now successfully merged in
      other_user.destroy

    end

    private

      def self.ensure_valid_user(u)
        GT::UserManager.ensure_users_special_rolls(u, true)
        true
      end

      # Will update both users in the DB
      def self.move_authentications(other_user, into_user)
        other_user_auths = other_user.authentications
        into_user.authentications += other_user.authentications
        other_user.authentications = []
        # need to remove old auths first b/c of index requirements
        if other_user.save(:validate => false)
          if into_user.save(:validate => false)
            return true
          else
            #restore the old auths
            other_user.authentications = other_user_auths
            other_user.save(:validate => false)
            return false
          end
        end

        return false
      end

      # *Will destroy other_roll*
      def self.merge_rolls_in_background(other_roll, other_user, into_roll, into_user)
        #These two are effectively performed in background by DB b/c they're fire-and-forget with write concern 0
        #change the roll_id (abbreviated as :a) for all frames in other_roll
        Frame.collection.update({:a => other_roll.id}, {:$set => {:a => into_roll.id}}, {:multi => true, :w => 0})
        #if the creator_id (abbreviated as :d) of those frames (now on their new roll) is other_roll.creator_id, change it to the creator of into_roll
        Frame.collection.update({:a => into_roll.id, :d => other_user.id}, {:$set => {:d => into_user.id}}, {:multi => true, :w => 0})

        #These are slow and can be run in the background by EM
        ShelbyGT_EM.next_tick do
          #move the followers of other_roll to into_roll
          #(not using roll_following.user relationship directly inside of a loop b/c MM identity map then screws with us and state of that User)
          users_to_follower_into_roll = other_roll.following_users.map { |fu| User.find_by_id(fu.user_id) } .compact.uniq
          users_to_follower_into_roll.each { |u| into_roll.add_follower(u, false) }

          other_roll.remove_all_followers!
          other_roll.destroy
        end
      end

      def self.change_roll_ownership_in_background(other_roll, other_user, into_user)
        #Frames on other roll (roll_id :abbr => :a) created by other_user (frame.creator_id :abbr => :d) should now be created by into_user
        Frame.collection.update({:a => other_roll.id, :d => other_user.id}, {:$set => {:d => into_user.id}}, {:multi => true, :w => 0})

        #into_user should now own other_roll
        other_roll.creator = into_user
        other_roll.save
      end

      def self.move_dashboard_entries_in_background(other_user, into_user)
        #All DBEs for other_user.id (:abbr => :a) need a new user_id, that of into_user
        DashboardEntry.collection.update({:a => other_user.id}, {:$set => {:a => into_user.id}}, {:multi => true, :w => 0})
      end

      def self.follow_all_friends_public_rolls(into_user)
        ShelbyGT_EM.next_tick {
          GT::UserTwitterManager.follow_all_friends_public_rolls(into_user)
          GT::UserFacebookManager.follow_all_friends_public_rolls(into_user)
        }
        true
      end

      def self.initialize_video_processing(into_user, auth)
        ShelbyGT_EM.next_tick {
          GT::PredatorManager.initialize_video_processing(into_user, auth)
        }
        true
      end
  end
end