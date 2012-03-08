# encoding: UTF-8

# This is the one and only place where Users are created.
#
# Used to create actual users (on signup) and faux Users (for public Roll)
#
module GT
  class UserManager
    
    
    # Creates a fake User with an Authentication matching the given network and user_id
    #
    # --arguments--
    # nickname => REQUIRED the unclean nickname for this user
    # provider => REQUIRED the name of the fucking social network
    # uid => REQUIRED the id given to the user by the social network
    #
    # --returns--
    # a User - which may be an actual User or a faux User - with a public Roll
    # Or the Errors, if save failed.
    #
    def self.get_or_create_faux_user(nickname, provider, uid)
      u = User.first( :conditions => { 'authentications.provider' => provider, 'authentications.uid' => uid } )
      return u if u
      
      # No user (faux or real) existed, create a faux user...
      u = User.new
      u.nickname = nickname
      u.faux = true
      
      # This Authentication is how the user will be looked up...
      auth = Authentication.new(:provider => provider, :uid => uid, :nickname => nickname)
      u.authentications << auth
      
      ensure_valid_unique_nickname!(u)
      u.downcase_nickname = u.nickname.downcase
      
      # Create the public Roll for this new User
      r = Roll.new
      r.creator = u
      r.public = true
      r.collaborative = false
      r.title = u.nickname
      u.public_roll = r
      
      if u.save
        return u
      else
        puts u.errors.full_messages
        return u.errors
      end
    end
    
    
    # *******************
    # TODO UserManager needs to be DRY and SIMPLE!  After merging w/ the rest of user/auth creation, things will get messy.
    # TODO That's fine, at first.  Make sure it's well tested and the tests pass.
    # TODO When we know that everythings working, we refactor this shit out of this.
    # *******************
    
    # TODO: Going to need to handle faux User becoming *real* User
    
    private
    
      def self.ensure_valid_unique_nickname!(u)
        #replace whitespace with underscore
        u.nickname = u.nickname.gsub(' ','_');
        #remove punctuation
        u.nickname = u.nickname.gsub(/['‘’"`]/,'');
        
        orig_nick = u.nickname
        i = 2
        while( User.count( :conditions => { :downcase_nickname => u.nickname.downcase } ) > 0 ) do
          u.nickname = "#{orig_nick}_#{i}"
          i = i*2
        end
      end
    

    
  end
end