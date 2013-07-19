# Remove a user, the Rolls they've created, their special Rolls, and all the Frames in those Rolls.
#
# *Should only be used for testing* 
# NB: If this user has taken actions (liked, commented, re-rolled) to other frames/rolls they will reference a null user.
#
# Usage:
#  t = T101.new(:target => some_user)  --or--  t = T101.new; t.set_target(some_user)
#  t.terminate!
class T101
  
  def initialize(options = {})
    set_target(options[:target]) if options.has_key? :target
  end
    
  def set_target(user)
    raise ArgumentError, "must supply a User" unless user.is_a? User
    @user = user
    
    puts "**************************************************"
    puts ""
    puts ""
    puts "Be sure you wish to TERMINATE #{user.nickname} (#{user.id})..."
    puts ""
    puts "user created on: #{user.created_at}"
    puts "rolls created: #{Roll.where(:creator_id => user.id).count}"
    puts "rolls following: #{user.roll_followings.count}"
    puts ""
    puts "To completely remove the user, the rolls they've created, their special rolls, and all frames in those rolls,"
    puts "this.terminate!"
    puts ""
    puts "To reset the user to the newly-created state; emptying rolls and resetting all user settings/authorizations,"
    puts "this.reset!"
    puts ""
    puts ""
    puts "**************************************************"
    self
  end
  
  def inspect
    return @user ? "T101 Hunter-Killer // target is set: #{@user.nickname} (#{@user.id})" : "T101 Hunter-Killer // waiting for instructions..."
  end
  
  def terminate!
    puts "Hunting #{@user.nickname} (#{@user.id}) across the DB for TERMINATION..."
    wipe_rolls!(true)
    wipe_dashboard!
    destroy_users_roll_followings!
    destroy_user!
  end
  
  def reset!
    puts "Hunting #{@user.nickname} (#{@user.id}) across the DB for RESET..."
    wipe_rolls!(false)
    wipe_dashboard!
    destroy_users_roll_followings!
    reset_user!
  end
  
  private
  
    def wipe_dashboard!
      puts " Destroying all DashboardEntries with user_id #{@user.id}..."
      DashboardEntry.collection.remove({:a => @user.id}, {:w => 0})
    end
  
    def wipe_rolls!(should_destroy=false)
      user = @user
    
      rolls_created = Roll.where(:creator_id => user.id).all
      puts " Hunting #{rolls_created.count} rolls created by #{user.nickname}..."
      rolls_created.each do |r|
        puts "  target acquired: roll #{r.title} (#{r.id})..."
        wipe_roll!(r, should_destroy)
      end
    
      puts " Hunting special rolls (if they're still around)..."
      if user.public_roll
        puts "   target acquired: public_roll..."
        wipe_roll!(user.public_roll, should_destroy)
      else
        puts "   User had no public_roll"
      end
    
      if user.watch_later_roll
        puts "   target acquired: watch_later_roll..."
        wipe_roll!(user.watch_later_roll, should_destroy)
      else
        puts "   User had no watch_later_roll"
      end
    
      if user.upvoted_roll
        puts "   target acquired: upvoted_roll..."
        wipe_roll!(user.upvoted_roll, should_destroy)
      else
        puts "   User had no upvoted_roll"
      end
    
      if user.viewed_roll
        puts "   target acquired: viewed_roll..."
        wipe_roll!(user.viewed_roll, should_destroy)
      else
        puts "   User had no viewed_roll"
      end
    end
    
    def destroy_users_roll_followings!
      puts " Undoing #{@user.roll_followings.count} roll followings..."
      @user.roll_followings.each do |rf|
        if rf.roll
          rf.roll.remove_follower(@user)
          puts "   terminated following of roll: #{rf.roll.title} (#{rf.roll.id})"
        else
          puts "   Roll DNE.  Removed following for roll_id: #{rf.roll_id}"
        end
      end
    end
    
    def reset_user!
      puts " Resetting User Authentications..."
      @user.authentications = []
      
      puts " Resetting User App Progress..."
      @user.app_progress = AppProgress.new()
      
      puts " Resetting User Miscelaneous stuff..."
      @user.rolls_unfollowed = []
      @user.preferences = Preferences.new()
      @user.authentication_token = nil
      
      puts " Saving User Model..."
      if @user.save(:validate=>false)
        puts "*****************************"
        puts "* #{@user.nickname} RESET *"
        puts "*****************************"
      else
        puts " FAILED to Reset User"
      end
    end
    
    def destroy_user!
      puts " Destroying User Model..."
      if @user.destroy
        puts "*****************************"
        puts "* #{@user.nickname} TERMINATED *"
        puts "*****************************"
      else
        puts "FAILED to terminate user"
      end
    end
  
    def wipe_roll!(roll, should_destroy)
      raise ArgumentError, "must supply a Roll" unless roll.is_a? Roll

      puts "    undoing #{roll.following_users.count} followings..."
      roll.following_users.each do |fu| 
        roll.remove_follower(fu.user)
        puts "      terminated following for user: #{fu.user.nickname} (#{fu.user.id})"
      end
    
      # Need to actually call .destroy on each frame b/c of side effects
      puts "    destroying #{roll.frames.count} frames..."
      roll.frames.each do |f|
        f.destroy
        puts "      terminated frame #{f.id}"
      end
    
      if should_destroy
        roll.destroy
        puts "    * Roll Destroyed *"
      end
      
      puts "    * Roll Wiped *"
    end
  
end