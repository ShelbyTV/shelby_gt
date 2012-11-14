require 'rhombus'

class AdminController < ApplicationController    
  before_filter :is_admin?
  
  def new_users 
    rhombus = Rhombus.new('shelby', '_rhombus_gt')
    
    # create a bson id object that represents the beginning of the day
    start_at = Time.zone.now.yesterday
    time_as_id = BSON::ObjectId.from_time(start_at)
    
    # find all new users as of today that are real users
    @new_new_users = User.where('id' => {'$gte' => time_as_id}, :faux => [0,2] ).all

    # get recent gt enabled users from rhombus
    rhombus_resp = JSON.parse(rhombus.get('/smembers', {:args => ['new_gt_enabled_users'], :limit=>24}))
    gt_enabled_ids = rhombus_resp["error"] ? [] : rhombus_resp["data"].values.flatten 
    @new_gt_enabled_users = User.find(gt_enabled_ids)
    # so we can distinguish these in the html
    @new_gt_enabled_users.map! {|u| u.faux = 9; u }
    
    # remove dupes
    @new_gt_enabled_users.delete_if { |u| @new_new_users.include? u }
      
    # combining the two sets of users 
    @all_new_users = @new_new_users.concat(@new_gt_enabled_users)
    
    # for development purposes to fake some users.
    @all_new_users = User.all[0..5] if Rails.env == "development"
  end
  
  # shows facts and tidbits about a user
  #  requires: 
  #    params[:id]
  def user
    if @user = User.find(params[:id]) or @user = User.find_by_nickname(params[:id]) or @user = User.find_by_nickname(params[:search])
      roll_followings = @user.roll_followings.map {|rf| rf.roll_id }.compact.uniq
      @rolls = Roll.where({:id => { "$in" => roll_followings  }}).limit(roll_followings.length).all
      
      @friends_rolls = @rolls.select {|k,v| k.roll_type == 11 }
      @user_created_public_rolls = @rolls.select {|k,v| k.roll_type == 30 or k.roll_type == 31 }
      @user_created_private_rolls = @rolls.select {|k,v| k.roll_type == 50 }
      
      @public_roll = @user.public_roll
      @heart_roll = @user.upvoted_roll.permalink if @user.upvoted_roll
      @watch_later_roll = @user.watch_later_roll.permalink if @user.watch_later_roll
      
      @social_links = {}
      @user.authentications.each do |a|
        @social_links[:tw] = "http://twitter.com/#{a.nickname}" if a.provider == "twitter"
        @social_links[:fb] = "http://www.facebook.com/#{a.nickname}" if a.provider == "facebook"
        @social_links[:tu] = "http://#{a.nickname}.tumblr.com/" if a.provider == "tumblr"
      end
    end
  end
  
  def active_users
    rhombus = Rhombus.new('shelby', '_rhombus_gt')
    
    # default time is 3 days, but more can be specified with params[:limit] (in days)
    @limit = params[:limit] ? params[:limit].to_i*24 : 72
    rhombus_resp = JSON.parse(rhombus.get('/smembers', {:args => ['active_web'], :limit=>@limit}))
    uids = rhombus_resp["error"] ? [] : rhombus_resp["data"].values.flatten
    
    @active_users = User.find(uids)
    
    # for development purposes to fake some users.
    @active_users = User.all[0..5] if Rails.env == "development"
  end

  def invited_users
    # all the invitations the (current) user has sent
    invites = BetaInvite.where(:sender_id => current_user.id).all

    # get all the users who got into shelby via the (current) user's invitations
    invited_uids = invites.map {|invite| invite.invitee_id}.compact
    @invited_users = User.find(invited_uids)
  end
  
  private
  
    def is_admin?
      if current_user and current_user.is_admin?
        return true
      elsif current_user and !current_user.is_admin?
        render :text => "not authorized."
      else
        redirect_to '/login'
      end
    end
  
end