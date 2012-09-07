# Initially, watch later rolls were public, and some users followed others' watch_later rolls (queues).
# This was written to fix up all the follow references. Left checked
# in as demo code / in case it's useful in the near future.
#
# *Should only be used for DB repair/fixing* 
#
# Usage:
#   Dev::WatchLaterPrivateFixer.fix!
#
module Dev
  class WatchLaterPrivateFixer 
    
    def self.fix!
      rollsToFix = Roll.where(:roll_type => Roll::TYPES[:special_watch_later])
      rollsToFix.each do |r|
        r.remove_all_followers!
        r.push_uniq :following_users => FollowingUser.new(:user => r.creator).to_mongo
        r.creator.push_uniq :roll_followings => RollFollowing.new(:roll => r).to_mongo
        r.save
        r.creator.save
      end
    end
  end
end
