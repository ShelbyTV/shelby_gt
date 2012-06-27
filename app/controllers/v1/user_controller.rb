class V1::UserController < ApplicationController  

  extend NewRelic::Agent::MethodTracer
  
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
  # [GET] /v1/user/:id/rolls/postable (returns the subset of rolls the user is following which they can also post to)
  # 
  # @param [Required, String] id The id of the user
  # @param [Optional, boolean] include_children Return the following_users?
  # @param [Optional, boolean] frames Returns a shallow version of frames
  # @param [Optional, boolean] frames_limit limit number of shallow frames to return 
  # @param [Optional, boolean] postable Set this to true (or use the second route) if you only want rolls postable by current user returned (used by bookmarklet)
  def roll_followings
    # disabling garbage collection here because we are loading a whole bunch of documents, and my hypothesis (HIS) is 
    #  it is slowing down this api request
    GC.disable
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['rolls']) do
      if current_user.id.to_s == params[:id]
        
        # for some reason calling Roll.find is throwing an error, its thinking its calling:
        #  V1::UserController::Roll which does not exist, for now, just forcing the global Roll
        @roll_ids = current_user.roll_followings.map {|rf| rf.roll_id }.compact.uniq
        
        # I really wanted to make a mongo query with $and / $or, but it doesn't seem doable with current semantics
        @rolls = Roll.where({:id => { "$in" => @roll_ids }}).limit(@roll_ids.length).all
        if params[:postable]
          @rolls = @rolls.select { |r| r.postable_by?(current_user) }
        end
        
        if @rolls
          
          # move heart roll to @rolls[1]
          if heartRollIndex = @rolls.index(current_user.upvoted_roll)
            heartRoll = @rolls.slice!(heartRollIndex)
            @rolls.insert(0, heartRoll)
          end
          
          # Load all roll creators to prevent N+1 queries
          @creator_ids = @rolls.map {|r| r.creator_id }.compact.uniq
          @roll_creators = User.where(:id => { "$in" => @creator_ids }).limit(@creator_ids.length).fields(:id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux, :public_roll_id, :upvoted_roll_id, :viewed_roll_id, :app_progress).all
          # we have to manually put these users into an identity map, .fields() seems to User.identity map = {}
          @roll_creators.each {|u| User.identity_map[u.id] = u}
          
          
          @rolls.each do |r|
            r[:creator_nickname] = r.creator.nickname if r.creator != nil
            r[:following_user_count] = r.following_users.count
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
  
  
  ##
  # Returns whether the users' oauth tokens are valid
  #   REQUIRES AUTHENTICATION
  #
  # [GET] /v1/user/:id/valid_token
  # 
  # @param [Required, String] id The id of the user
  # @param [Required, String] provider provider that want to check on
  def valid_token
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['valid_token']) do
      if !["facebook"].include?(params[:provider]) # using indludes allows us to do this for twitter/tumblr in the future
        return render_error(404, "this route only currently supports facebook as a provider.")
      end
      
      if a = current_user.first_provider(params[:provider]) and a.is_a? Authentication
        graph = Koala::Facebook::API.new(a.oauth_token)
        begin
          graph.get_object("me")
          @status, @token_valid = 200, true
        rescue Koala::Facebook::APIError => e
          if e.fb_error_type == "OAuthException"
            @status, @token_valid = 200, false
          end
        rescue => e
          Rails.logger.info "[V1::UserController] Unknown error checking validity of users OAuth tokens"
        end
      else
        return render_error(404, "This user does not have a #{params[:provider]} authentication to check on")
      end
    end
  end
  
end
