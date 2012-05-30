# encoding: UTF-8

# Sometimes things get messy.  This helps clean up.
module GT
  class UserFixer
    
    def self.clean_roll_followings(u, save=true)
      u.roll_followings.delete_if { |rf| rf.roll == nil }
      u.save if save
    end
    
    def self.update_rolls_metadata(u, save=true)
      u.upvoted_roll.upvoted_roll = true
      u.upvoted_roll.save if save
    end
    
    def self.fix_heart_roll_creators(u)
      u.upvoted_roll.frames.each do |f|
        f_ancestor = Frame.find(f.frame_ancestors.first)
        f.creator_id = f_ancestor.creator_id
        f.save
      end
    end
    
  end
end