class V1::RollController < ApplicationController  
  
  before_filter :authenticate_user!, :except => [:show]
  
  ##
  # Returns one roll, with the given parameters.
  #
  # [GET] /v1/roll/:id
  # 
  # @param [Required, String] id The id of the roll
  # @param [Optional, String] following_users Return the following_users?
  def show
    if @roll = Roll.find(params[:id])
      @include_following_users = params[:following_users] == "true" ? true : false
      @status =  200
    else
      @status, @message = 500, "could not find that roll"
      render 'v1/blank'
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
    if ( !params.include?(:title) or !params.include?(:thumbnail_url) or !user_signed_in?)
      @status = 500
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
        @status, @message = 500, "could not save roll: #{e}"
        render 'v1/blank'
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
    id = params.delete(:id)
    @roll = Roll.find(id)
    if !@roll
      @status, @message = 500, "could not find roll"
      render 'v1/blank'
    else
      begin
        @roll.save! if @roll.update_attributes!(params)
        @status = 200
      rescue => e
        @roll = nil
        @status, @message = 500, "error while updating roll: #{e}"
        render 'v1/blank'
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
    unless @roll = Roll.find(params[:id])
      @status, @message = 500, "could not find that roll to destroy"
      render 'v1/blank'
    end
    if @roll.destroy
      @status =  200
    else
      @status, @message = 500, "could not destroy that roll"
      render 'v1/blank'
    end
  end

end