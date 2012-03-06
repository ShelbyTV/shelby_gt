class V1::RollController < ApplicationController  
  
  ##
  # Returns one roll, with the given parameters.
  #
  # [GET] /v1/roll/:id.json
  # 
  # @param [Required, String] id The id of the roll
  def show
    if @roll = Roll.find(params[:id])
      @status =  200
    else
      @status, @message = 500, "could not find that roll"
    end
  end
  
  ##
  # Creates and returns one roll, with the given parameters.
  # 
  # [POST] /v1/roll.json
  # 
  # @param [Required, String] title The title of the roll
  # @param [Required, String] thumbnail_url The thumbnail_url for the url
  # @param [Optional, String] collaborative Is this roll collaborative?
  # @param [Optional, String] public Is this roll public?
  def create
    if !params.include?(:title) and !params.include?(:thumbnail_url) and !user_signed_in?
      @status = 500
      @message = "title required" unless params.include?(:title)
      @message = "thumbnail_url required" unless params.include?(:thumbnail_url)
      @message = "not authenticated, could not access user" unless user_signed_in?
      render 'v1/blank'
    else
      @roll = Roll.new(params)
      @roll.creator = current_user
      begin
        @roll.save!
        @status = 200
      rescue => e
        @status, @message = 500, e
      end
    end
  end
  
  ##
  # Updates and returns one roll, with the given parameters.
  # 
  # [PUT] /v1/roll/:id.json
  # 
  # @param [Required, String] id The id of the roll
  def update
    id = params.delete(:id)
    @roll = Roll.find(id)
    @status, @message = 500, "could not find roll" unless @roll
    if @roll.update_attributes(params)
      @status = 200
    else
      @status, @message = 500, "could not update roll"
    end
  end
  
  ##
  # Destroys one roll, returning Success/Failure
  # 
  # [DELETE] /v1/roll/:id.json
  # 
  # @param [Required, String] id The id of the roll
  def destroy
    @roll = Roll.find(params[:id])
    @status, @message = 500, "could not find that roll to destroy" if @roll == nil
    if @roll.destroy
      @status =  200
    else
      @status, @message = 500, "could not destroy that roll"
    end
  end

end