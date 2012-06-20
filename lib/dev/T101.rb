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
    puts "this.terminate"
    puts ""
    puts ""
    puts "**************************************************"
    self
  end
  
  def inspect
    return @user ? "T101 Hunter-Killer // target is set: #{@user.nickname} (#{@user.id})" : "T101 Hunter-Killer // waiting for instructions..."
  end
  
  def terminate!
    user = @user
    puts "Hunting #{user.nickname} (#{user.id}) across the DB..."
    
    rolls_created = Roll.where(:creator_id => user.id).all
    puts " Destroying #{rolls_created.count} rolls created by #{user.nickname}..."
    rolls_created.each do |r|
      puts "  destroying roll #{r.title} (#{r.id})..."
      self.destroy_roll(r)
    end
    
    puts " Destroying special rolls (if they're still around)..."
    if user.public_roll
      puts "   Destroying public_roll..."
      self.destroy_roll user.public_roll
    else
      puts "   User had no public_roll"
    end
    
    if user.watch_later_roll
      puts "   Destroying watch_later_roll..."
      self.destroy_roll user.watch_later_roll
    else
      puts "   User had no watch_later_roll"
    end
    
    if user.upvoted_roll
      puts "   Destroying upvoted_roll..."
      self.destroy_roll user.upvoted_roll
    else
      puts "   User had no upvoted_roll"
    end
    
    if user.viewed_roll
      puts "   Destroying viewed_roll..."
      self.destroy_roll user.viewed_roll
    else
      puts "   User had no viewed_roll"
    end
    
    puts " Undoing #{user.roll_followings.count} roll followings..."
    user.roll_followings.each do |rf|
      rf.roll.remove_follower(user)
      puts "   terminated following of roll: #{rf.roll.title} (#{rf.roll.id})"
    end
    
    puts " Destroying User Model..."
    if user.destroy
      puts "*****************************"
      puts "*#{user.nickname} TERMINATED*"
      puts "*****************************"
    else
      puts "FAILED to terminate user"
    end
  end
  
  private
  
    def destroy_roll(roll)
      raise ArgumentError, "must supply a Roll" unless roll.is_a? Roll

      puts "    undoing #{roll.following_users.count} followings..."
      roll.following_users.each do |fu| 
        roll.remove_follower(fu.user)
        puts "      terminated following for user: #{fu.user.nickname} (#{fu.user.id})"
      end
    
      puts "    destroying #{roll.frames.count} frames..."
      roll.frames.each do |f|
        f.destroy
        puts "      terminated frame #{f.id}"
      end
    
      roll.destroy
      puts "    *Roll Terminated*"
    
    end
  
end