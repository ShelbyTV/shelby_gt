# encoding: UTF-8

# Sometimes things get messy.  This helps clean up.
module GT
  class UserFixer
    
    def self.clean_roll_followings(u)
      u.roll_followings.delete_if { |rf| rf.roll == nil }
      u.save
    end
    
  end
end