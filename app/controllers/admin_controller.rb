require 'rhombus'

class AdminController < ApplicationController    
  before_filter :is_admin?
  
  def index
    
  end
  
  def new_users 
    rhombus = Rhombus.new('shelby', '_rhombus_gt')
    
    # create a bson id object that represents the beginning of the day
    start_at = Time.zone.now.beginning_of_day
    time_as_id = BSON::ObjectId.from_time(start_at)
    
    # find all new users as of today that are real users
    @new_new_users = User.where('id' => {'$gte' => time_as_id}, :faux => 0 ).all
    @converted_new_users = User.where('id' => {'$gte' => time_as_id}, :faux => 2 ).all

    # get recent gt enabled users from rhombus
    rhombus_resp = JSON.parse(rhombus.get('/smembers', {:args => ['new_gt_enabled_users'], :limit=>24}))
    gt_enabled_ids = rhombus_resp["error"] ? [] : rhombus_resp["data"].values.flatten 
    @new_gt_enabled_users = User.find(gt_enabled_ids)
    # so we can distinguish these in the html.erb
    @new_gt_enabled_users.map! {|u| u.faux = 9; u }
    
    @new_gt_enabled_users.delete_if { |u| @new_new_users.include? u }
      
    # send email summary if there are new users
    if !@new_new_users.concat(@new_gt_enabled_users).concat(@converted_new_users).empty?
      @all_new_users = @new_new_users.concat(@converted_new_users).concat(@new_gt_enabled_users)
    end
  end
  
  # shows facts and tidbits about a user
  #  requires: 
  #    params[:id]
  def user
    if @user = User.find(params[:id]) or @user = User.find_by_nickname(params[:id])    
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
  
  private
  
    def is_admin?
      if current_user and current_user.is_admin?
        return true
      elsif current_user and !current_user.is_admin?
        render :nothing => true
      else
        redirect_to '/login'
      end
    end
  
end