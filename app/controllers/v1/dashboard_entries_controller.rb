class V1::DashboardEntriesController < ApplicationController  
    
  before_filter :authenticate_user!
  
  extend NewRelic::Agent::MethodTracer
  
  ##
  # Returns dashboad entries, with the given parameters.
  #
  # [GET] v1/dashboard
  # 
  # @param [Optional, String] user_id The id of the user otherwise user = current_user
  # @param [Optional, Integer] limit The number of entries to return (default/max 20)
  # @param [Optional, Integer] skip The number of entries to skip (default 0)
  # @param [Optional, Boolean] include_children if set to true, will not include all goodies, eg roll, frame etc
  def index
    # disabling garbage collection here because we are loading a whole bunch of documents, and my hypothesis (HIS) is 
    #  it is slowing down this api request
    GC.disable
    
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['index']) do
      # default params
      @limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      @limit = 20 if @limit.to_i > 20
          
      skip = params[:skip] ? params[:skip] : 0

      # get user
      if params[:user_id]
        return render_error(404, "could not find that user") unless user = User.find(params[:user_id])
      elsif user_signed_in?
        user = current_user
      end
    
      # get and render dashboard entries
      if user
        
        if @limit == 0
          @status, @entries = 200, []
          render 'index' and return
        end
        
        if params[:since_id]
          return render_error(404, "invalid since_id #{params[:since_id]}") unless BSON::ObjectId.legal?(params[:since_id])
          since_object_id = BSON::ObjectId(params[:since_id])
          
          case params[:order]
          when "1", nil, "forward"
            @entries = DashboardEntry.limit(@limit).skip(skip).sort(:id.desc).where(:user_id => user.id, :id.lte => since_object_id).all
          when "-1", "reverse", "backward"
            @entries = DashboardEntry.limit(@limit).skip(skip).sort(:id.desc).where(:user_id => user.id, :id.gt => since_object_id).all
          end
        else
          @entries = DashboardEntry.limit(@limit).skip(skip).sort(:id.desc).where(:user_id => user.id).all
        end
        
        #########
        # solving the N+1 problem with loading all children of a dashboard_entry
        @entries_frame_ids = @entries.map {|e| e.frame_id }.compact.uniq
              
        @frames = Frame.find(@entries_frame_ids)
      
        @entries_roll_ids = @frames.map {|f| f.roll_id }.compact.uniq
        @entries_creator_ids = @frames.map {|f| f.creator_id }.compact.uniq
        @entries_hearted_ids = @frames.map {|f| f.upvoters }.flatten.compact.uniq
        @entries_conversation_ids = @frames.map {|f| f.conversation_id }.compact.uniq
        @entries_video_ids = @frames.map {|f| f.video_id }.compact.uniq

        # for some reason calling Roll.find is throwing an error, its thinking its calling:
        #  V1::DashboardEntriesController::Roll which does not exist, for now, just forcing the global Roll
        @rolls = ::Roll.find(@entries_roll_ids)
        if @users = User.find((@entries_creator_ids + @entries_hearted_ids).uniq)
          # we have to manually put these users into an identity map (for some reason)
          @users.each {|u| User.identity_map[u.id] = u}
        end
        
        @videos = Video.find(@entries_video_ids)
        @conversations = Conversation.find(@entries_conversation_ids)
        ##########
        
        @include_children = params[:include_children] != "false" ? true : false
        @status = 200
      else
        render_error(404, "no user info found")
      end    
    end
    GC.enable
  end
  add_method_tracer :index

  ##
  # Updates and returns one dashboard entry, with the given parameters.
  #
  # [PUT] v1/dashboard/:id.json
  # 
  # @param [Required, String] id The id of the dashboard entry
  #
  #TODO: Do not user update_attributes, instead only allow updating specific attrs
  def update
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['update']) do
      if params[:id]
        if @dashboard_entry = DashboardEntry.find(params[:id])
          begin 
            @status = 200 if @dashboard_entry.update_attributes!(params)
          rescue => e
            render_error(404, "could not update dashboard_entry: #{e}")
          end
        else
          render_error(404, "could not find dashboard_entry with id #{params[:id]}")
        end
      else
        render_error(404, "must specify an id.")
      end
    end
  end
 

end
