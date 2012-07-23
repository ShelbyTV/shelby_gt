class AdminController < ApplicationController    
  before_filter :is_admin?
  
  def index
    
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