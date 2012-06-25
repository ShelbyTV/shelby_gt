class V1::UserController < ApplicationController  
  
  before_filter :user_authenticated?, :except => [:signed_in, :show]

  extend NewRelic::Agent::MethodTracer
  
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
    StatsManager::StatsD.time(Settings::StatsConstants.api['user']['rolls']) do
      if current_user.id.to_s == params[:id]
        
        self.class.trace_execution_scoped(['UserController/roll_followings/roll_find']) do
          # for some reason calling Roll.find is throwing an error, its thinking its calling:
          #  V1::UserController::Roll which does not exist, for now, just forcing the global Roll
          @rolls = ::Roll.find(current_user.roll_followings.map {|rf| rf.roll_id }.compact.uniq)
        end
        
        if @rolls

          self.class.trace_execution_scoped(['UserController/roll_followings/heart_roll']) do
            # move heart roll to @rolls[1]
            if heartRollIndex = @rolls.index(current_user.upvoted_roll)
              heartRoll = @rolls.slice!(heartRollIndex)
              @rolls.insert(0, heartRoll)
            else
              Rails.logger.error("UserController#roll_followings - could not find heart/upvoted roll for user #{current_user.id}")
            end
          end
          
          self.class.trace_execution_scoped(['UserController/roll_followings/roll_creator_array']) do
            @creator_ids = @rolls.map {|r| r.creator_id }.compact.uniq
          end
          self.class.trace_execution_scoped(['UserController/roll_followings/roll_creator_find']) do
            # Load all roll creators to prevent N+1 queries
            @roll_creators = User.where(:id => { "$in" => @creator_ids }).limit(@creator_ids.length).all
          end
          
          # load frames with select attributes, if params say to
          if params[:frames] == "true"
            # default params
            limit = params[:frames_limit] ? params[:frames_limit] : 1
            # put an upper limit on the number of entries returned
            limit = 20 if limit.to_i > 20

            # intelligently fetching frames and videos for performance purposes
            @frames =[]
            self.class.trace_execution_scoped(['UserController/roll_followings/frames_find']) do
              @rolls.each { |r| @frames << r.frames.limit(limit).all }
            end
            self.class.trace_execution_scoped(['UserController/roll_followings/video_find']) do
              @videos = Video.find( @frames.flatten!.compact.uniq.map {|f| f.video_id }.compact.uniq )
            end
            
            self.class.trace_execution_scoped(['UserController/roll_followings/frames_subset_code']) do
              @rolls.each do |r|
                r['frames_subset'] = []
                r.frames.limit(limit).all.each do |f| 
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
          end
        
          @status = 200
        else
          render_error(404, "something went wrong when getting those rolls.")
        end
      else
        render_error(403, "you are not authorized to view that users rolls.")
      end
    end
  end
  #add_method_tracer :roll_followings
  
end
