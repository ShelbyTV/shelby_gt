class V1::UserController < ApplicationController  
  
  before_filter :user_authenticated?, :except => [:signed_in, :show]

  ####################################
  # Returns true (false) if user is (not) signed in
  #
  # [GET] /v1/signed_in
  def signed_in
    @status = 200
    @signed_in = user_signed_in? ? true : false
  end
  
  ####################################
  # Returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id
  # 
  # @param [Optional, String] id The id of the user, if not present, user is current_user
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['show']) do
      if params[:id]
        unless @user = User.find(params[:id]) or @user = User.find_by_nickname(params[:id])
          return render_error(404, "could not find that user")
        end
      elsif user_signed_in?
        @user = current_user
      else
        return render_error(404, "could not find that user")
      end

      @status = 200
    end
  end
  
  ####################################
  # Updates and returns one user, with the given parameters.
  #   REQUIRES AUTHENTICATION
  #
  # [PUT] /v1/user/:id
  # 
  # @param [Required, String] attr The attribute(s) to update
  def update
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['update']) do
      @user = current_user
      params.keep_if {|key,value| [:name, :nickname, :primary_email, :preferences, :app_progress].include?key.to_sym}
      begin
        if @user.update_attributes!(params)
          @status = 200
        else
          render_error(404, "error while updating user.")
        end
      rescue => e
        render_error(404, "error while updating user: #{e}")
      end
    end
  end

  ##
  # Returns the rolls the current_user is following
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id/rolls/following 
  # 
  # @param [Required, String] id The id of the user
  # @param [Optional, boolean] include_children Return the following_users?
  # @param [Optional, boolean] frames Returns a shallow version of frames
  # @param [Optional, boolean] frames_limit limit number of shallow frames to return 
  def roll_followings
    # disabling garbage collection here because we are loading a whole bunch of documents, and my hypothesis (HIS) is 
    #  it is slowing down this api request
    GC.disable
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['rolls']) do
      if current_user.id.to_s == params[:id]
        
        # for some reason calling Roll.find is throwing an error, its thinking its calling:
        #  V1::UserController::Roll which does not exist, for now, just forcing the global Roll
        @roll_ids = current_user.roll_followings.map {|rf| rf.roll_id }.compact.uniq
        @rolls = Roll.where(:id => { "$in" => @roll_ids }).limit(@roll_ids.length).all
        
        if @rolls
          
          # move heart roll to @rolls[1]
          if heartRollIndex = @rolls.index(current_user.upvoted_roll)
            heartRoll = @rolls.slice!(heartRollIndex)
            @rolls.insert(0, heartRoll)
          else
            Rails.logger.error("UserController#roll_followings - could not find heart/upvoted roll for user #{current_user.id}")
          end
          
          self.class.trace_execution_scoped(['UserController/roll_followings/roll_creator_find']) do
            # Load all roll creators to prevent N+1 queries
            @creator_ids = @rolls.map {|r| r.creator_id }.compact.uniq
            @roll_creators = User.where(:id => { "$in" => @creator_ids }).limit(@creator_ids.length).fields(:id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux, :public_roll_id, :upvoted_roll_id, :viewed_roll_id, :app_progress).all
            # we have to manually put these users into an identity map, .fields() seems to User.identity map = {}
            @roll_creators.each {|u| User.identity_map[u.id] = u}
          end
        
          @status = 200
        else
          render_error(404, "something went wrong when getting those rolls.")
        end
      else
        render_error(403, "you are not authorized to view that users rolls.")
      end
    end
    GC.enable
  end
  
end
