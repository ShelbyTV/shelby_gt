module GT
  class InvitationManager
    
   def self.private_roll_invite(user, roll, gt_roll_invite_cookie)
     invite_info = gt_roll_invite_cookie.split(',')
     # save their email if we don't have it already
     user.primary_email = invite_info[1] unless user.primary_email
     # let them into gt
     user.gt_enabled = true
     user.save(:validate => false)
     
     roll.add_follower(user)
     roll.save
   end 
    
  end
end