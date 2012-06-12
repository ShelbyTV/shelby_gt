require "social_poster"
require "link_shortener"
require "social_post_formatter"

class V1::RollController < ApplicationController  
  
  before_filter :user_authenticated?, :except => [:show]
  
  ##
  # Returns one roll, with the given parameters.
  #
  # [GET] /v1/roll/:id
  # 
  # @param [Required, String] id The id of the roll
  # @param [Optional, String] following_users Return the following_users?
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['show']) do
      if params[:id]
        @include_following_users = params[:following_users] == "true" ? true : false
        if @roll = Roll.find(params[:id])
          if (user_signed_in? and @roll.viewable_by?(current_user)) or @roll.public
            @status =  200
          else
            render_error(404, "you are not authorized to see that roll")
          end
        else
          render_error(404, "that roll does not exist")
        end
      end
    end
  end
  
  def show_users_public_roll
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['show_users_public_roll']) do
      if user = User.find(params[:user_id]) or user = User.find_by_nickname(params[:user_id])
        if @roll = user.public_roll
          @include_following_users = params[:following_users] == "true" ? true : false
          @status = 200
        else
          render_error(404, "could not find that roll")
        end
      else
        render_error(404, "could not find the roll of the user specified")
      end
    end
  end
  
  def show_users_heart_roll
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['show_users_heart_roll']) do
      if user = User.find(params[:user_id]) or user = User.find_by_nickname(params[:user_id])
        if @roll = user.upvoted_roll
          @include_following_users = params[:following_users] == "true" ? true : false
          @status = 200
        else
          render_error(404, "could not find that roll")
        end
      else
        render_error(404, "could not find the roll of the user specified")
      end    
    end
  end
  
  ##
  # Returns rolls to browse.
  #
  # [GET] /v1/roll/browse
  # 
  def browse
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['show']) do
      
      case Rails.env
      when 'production'
        hot_rolls = ['4f901bd8b415cc466a0008ec','4f900cf5b415cc466a0005bb', '4fcd0ca888ba6b07e30001d7', '4fbe42069a725b686300004a', '4fa03429b415cc18bf0007b2', '4f8f7f08b415cc4762000172', '4f8f7f17b415cc4762000262', '4f8fac9ab415cc661401317b', '4fbe42031c1cf44d540013f0', '4fbd2d24d10412081e00042e', '4f9d5d0a9a725b3d5f002c14', '4fbe42079a725b6863000077', '4fbd4da49a725b58cf00246b', '4f90223bb415cc466a00091c', '4f8fac9ab415cc661401317b', '4fbaa51d1c1cf44b9d002f58']
      when 'development'
        hot_rolls = [Roll.all[0].id, Roll.all[1].id]
      else
        hot_rolls = params[:rolls]
      end
      
      if @rolls = Roll.find(hot_rolls)
        
        # load frames with select attributes, if params say to
        if params[:frames] == "true"
          # default params
          limit = params[:limit] ? params[:limit] : 1
          # put an upper limit on the number of entries returned
          limit = 20 if limit.to_i > 20
          
          @frames = []                    
          @rolls.each do |r|
            r['frames_subset'] = []
            @frames = r.frames.limit(limit).all
            @frames.each do |f| 
              if f.video # NOTE: not sure why some frames dont have videos, but this is necessary until we know why
                r['frames_subset'] << {
                  :id => f.id, :video => {
                    :id => f.video.id, :thumbnail_url => f.video.thumbnail_url
                  }
                }
              end
            end
          end
        end
        
        @status = 200
      else
        render_error(404, "something went wrong finding those rolls.")
      end
      
    end
  end
  
  ##
  # Returns success if roll is shared successfully, with the given parameters.
  #
  # [GET] /v1/roll/:roll_id/share
  # 
  # @param [Required, String] roll_id The id of the roll to share
  # @param [Required, String] destination Where the roll is being shared to (comma seperated list ok)
  # @param [Required, Escaped String] text What the status update of the post is
  def share
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['share']) do
      unless params.keys.include?("destination") and params.keys.include?("text")
        return  render_error(404, "a destination and a text is required to post") 
      end
      
      unless params[:destination].is_a? Array
        return  render_error(404, "destination must be an array of strings") 
      end
      
      if params[:roll_id]
        return render_error(404, "please specify a valid id") unless (roll_id = ensure_valid_bson_id(params[:roll_id]))
        
        if roll = Roll.find(roll_id)
          return render_error(404, "that roll is private, can not share") unless roll.public
        
          text = params[:text]
        
          # params[:destination] is an array of destinations, 
          #  short_links will be a hash of desinations/links
          short_links = GT::LinkShortener.get_or_create_shortlinks(roll, params[:destination].join(','))
        
          params[:destination].each do |d|
            case d
            when 'twitter'
              text = GT::SocialPostFormatter.format_for_twitter(text, short_links)
              resp = GT::SocialPoster.post_to_twitter(current_user, text)
              StatsManager::StatsD.increment(Settings::StatsConstants.roll['share'][d], current_user.id, 'roll_share', request)
            when 'facebook'
              text = GT::SocialPostFormatter.format_for_facebook(text, short_links)
              resp = GT::SocialPoster.post_to_facebook(current_user, text, roll)
              StatsManager::StatsD.increment(Settings::StatsConstants.roll['share'][d], current_user.id, 'roll_share', request)
            else
              return render_error(404, "we dont support that destination yet :(")
            end
          
            if resp
              @status = 200
            elsif resp == nil
              render_error(404, "that user cant post to that destination")
            end  
          end
        else
          render_error(404, "could not find that roll dude.")
        end
      else
        render_error(404, "must specify a roll_id")
      end
    end
  end
  
  ##
  # Creates and returns one roll, with the given parameters.
  #   REQUIRES AUTHENTICATION
  # 
  # [POST] /v1/roll
  # 
  # @param [Required, String] title The title of the roll
  # @param [Optional, String] thumbnail_url The thumbnail_url for the url
  # @param [Required, String] collaborative Is this roll collaborative?
  # @param [Required, String] public Is this roll public?
  def create
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['create']) do
      if ![:title, :public, :collaborative].all? { |p| params.include?(p) }
        @status = 404
        @message = "title required" unless params.include?(:title)
        @message = "public required" unless params.include?(:public)
        @message = "collaborative required" unless params.include?(:collaborative)
        @message = "not authenticated, could not access user" unless user_signed_in?
        render 'v1/blank'
      else
        @roll = Roll.new(:title => params[:title], :thumbnail_url => params[:thumbnail_url])
        @roll.creator = current_user
        @roll.public = params[:public]
        @roll.collaborative = params[:collaborative]
        
        begin
          if @roll.save! and @roll.add_follower(current_user)
            roll_type = @roll.public ? 'public' : 'private'
            StatsManager::StatsD.increment(Settings::StatsConstants.roll[:create][roll_type], current_user.id, 'roll_create', request)
            @status = 200
          end
        rescue => e
          render_error(404, "could not save roll: #{e}")
        end
      end
    end
  end
  
  ##
  # Joins a roll. Returns success/failure + the roll w updated followers
  #   REQUIRES AUTHENTICATION
  # 
  # [POST] /v1/roll/:roll_id/join
  def join
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['join']) do
      if params[:roll_id]
        return render_error(404, "please specify a valid id") unless (roll_id = ensure_valid_bson_id(params[:roll_id]))
        
        if @roll = Roll.find(roll_id)
          @roll.add_follower(current_user)
          GT::Framer.backfill_dashboard_entries(current_user, @roll, 5)
          @status = 200
          StatsManager::StatsD.increment(Settings::StatsConstants.roll['join'], current_user.id, 'roll_join', request)
        else
          render_error(404, "something went wrong joining that roll.")
        end
      else
        render_error(404, "can't find that roll dude.")
      end
    end
  end
  
  ##
  # Leaves a roll. Returns success/failure + the roll w updated followers
  #   REQUIRES AUTHENTICATION
  # 
  # [POST] /v1/roll/:roll_id/leave
  def leave
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['leave']) do
      if params[:roll_id]
        return render_error(404, "please specify a valid id") unless (roll_id = ensure_valid_bson_id(params[:roll_id]))
        if @roll = Roll.find(params[:roll_id])
          if @roll.leavable_by?(current_user)
            if @roll.remove_follower(current_user)
              @status = 200
              StatsManager::StatsD.increment(Settings::StatsConstants.roll['leave'], current_user.id, 'roll_leave', request)
            else
              return render_error(404, "something went wrong leaving that roll.")
            end
          else
            return render_error(404, "the creator of a roll can not leave a roll.")
          end
        else
          render_error(404, "can't find that roll dude.")
        end
      else
        render_error(404, "please specify a roll_id")
      end
    end
  end
  
  
  ##
  # Updates and returns one roll, with the given parameters.
  #   REQUIRES AUTHENTICATION
  # 
  # [PUT] /v1/roll/:id
  # 
  # @param [Required, String] id The id of the roll
  #
  #TODO: Do not user update_attributes, instead only allow updating specific attrs
  def update
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['update']) do
      id = params.delete(:id)
      params.keep_if {|key,value| [:title].include?key.to_sym}
      if id
        return render_error(404, "please specify a valid id") unless (roll_id = ensure_valid_bson_id(id))
        
        @roll = Roll.find(roll_id)
        if !@roll
          render_error(404, "could not find roll")
        else
          begin
            @status = 200 if @roll.update_attributes!(params)
          rescue => e
            render_error(404, "error while updating roll: #{e}")
          end
        end
      else
        render_error(404, "must specify an id")
      end
    end
  end
  
  ##
  # Destroys one roll, returning Success/Failure
  #   REQUIRES AUTHENTICATION
  # 
  # [DELETE] /v1/roll/:id
  # 
  # @param [Required, String] id The id of the roll
  def destroy
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['destroy']) do
      if params[:id]
        return render_error(404, "please specify a valid id") unless (roll_id = ensure_valid_bson_id(params[:id]))
        return render_error(404, "could not find that roll to destroy") unless @roll = Roll.find(roll_id)
        return render_error(404, "you do not have permission") unless @roll.destroyable_by?(current_user)
        if @roll.following_users.each { |fu| @roll.remove_follower(fu.user) } and @roll.destroy
          @status =  200
        else
          render_error(404, "could not destroy that roll")
        end
      else
        render_error(404, "must specify an id")
      end
    end
  end

end