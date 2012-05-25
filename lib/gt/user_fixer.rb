# encoding: UTF-8

# Sometimes things get messy.  This helps clean up.
module GT
  class UserFixer
    
    def self.clean_roll_followings(u)
      u.roll_followings.delete_if { |rf| rf.roll == nil }
      u.save
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