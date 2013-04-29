module Dev
  class UserDestroyer
    
    # Does not destroy the user.
    #
    # Merely updates all conversations on users's public_roll's frames with `public=false`
    # which prevents front end from showing them.
    #
    def self.remove_users_comments_from_seo_results(u, allow_non_faux=false)
      return false if u.user_type != User::USER_TYPE[:faux] and !allow_non_faux
      u.public_roll.frames.find_each do |frame|
        frame.conversation.update_attribute(:public, false)
      end
      return true
    end
    
  end
end
