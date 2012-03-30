require "social_poster"

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
    StatsManager::StatsD.client.time(Settings::StatsNames.roll['show']) do
      if @roll = Roll.find(params[:id])
        if user_signed_in?
          @include_following_users = params[:following_users] == "true" ? true : false
          @status =  200
        elsif @roll.public
          @include_following_users = params[:following_users] == "true" ? true : false
          @status =  200        
        else
          render_error(401, "you are not authorized to see that roll")
        end
      else
        render_error(404, "could not find that roll")
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
  # @param [Required, Escaped String] comment What the status update of the post is
  def share
    StatsManager::StatsD.client.time(Settings::StatsNames.roll['share']) do
      unless params.keys.include?("destination") and params.keys.include?("comment")
        return  render_error(404, "a destination and a comment is required to post") 
      end
      
      unless params[:destination].is_a? Array
        return  render_error(404, "destination must be an array of strings") 
      end
      
      if roll = Roll.find(params[:roll_id])
        return render_error(404, "that roll is private, can not share") unless roll.public
        
        #TODO: link_to_roll needs to be created
        comment = params[:comment] #+ link_to_roll
        
        params[:destination].each do |d|
          case d
          when 'twitter'
            resp = GT::SocialPoster.post_to_twitter(current_user, comment, roll)
          when 'facebook'
            resp = GT::SocialPoster.post_to_facebook(current_user, comment, roll)
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
        render_error(404, "could not find that roll")
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
  # @param [Required, String] thumbnail_url The thumbnail_url for the url
  # @param [Optional, String] collaborative Is this roll collaborative?
  # @param [Optional, String] public Is this roll public?
  def create
    StatsManager::StatsD.client.time(Settings::StatsNames.roll['create']) do
      if ( !params.include?(:title) or !params.include?(:thumbnail_url) or !user_signed_in?)
        @status = 404
        @message = "title required" unless params.include?(:title)
        @message = "thumbnail_url required" unless params.include?(:thumbnail_url)
        @message = "not authenticated, could not access user" unless user_signed_in?
        render 'v1/blank'
      else
        @roll = Roll.new(:title => params[:title], :thumbnail_url => params[:thumbnail_url])
        @roll.creator = current_user
        begin        
          @status = 200 if @roll.save!
        rescue => e
          render_error(404, "could not save roll: #{e}")
        end
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
  def update
    StatsManager::StatsD.client.time(Settings::StatsNames.roll['update']) do
      id = params.delete(:id)
      @roll = Roll.find(id)
      if !@roll
        render_error(404, "could not find roll")
      else
        begin
          @status = 200 if @roll.update_attributes!(params)
        rescue => e
          render_error(404, "error while updating roll: #{e}")
        end
      end
    end
  end
  
  ##
  # Destroys one roll, returning Success/Failure
  #   REQUIRES AUTHENTICATION
  # 
  # [DELETE] /v1/roll/:id.json
  # 
  # @param [Required, String] id The id of the roll
  def destroy
    StatsManager::StatsD.client.time(Settings::StatsNames.roll['destroy']) do
      unless @roll = Roll.find(params[:id])
        render_error(404, "could not find that roll to destroy")
      end
      if @roll.destroy
        @status =  200
      else
        render_error(404, "could not destroy that roll")
      end
    end
  end

end