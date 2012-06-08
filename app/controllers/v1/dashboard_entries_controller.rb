class V1::DashboardEntriesController < ApplicationController  
    
  before_filter :authenticate_user!
  before_filter :set_current_user
  oauth_required
 
  
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
    StatsManager::StatsD.time(Settings::StatsConstants.api['dashboard']['index']) do
      # default params
      @limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      @limit = 20 if @limit.to_i > 20
          
      skip = params[:skip] ? params[:skip] : 0

      # get user
      if params[:user_id]
        return render_error(404, "please specify a valid id") unless (user_id = ensure_valid_bson_id(params[:user_id]))
        return render_error(404, "could not find that user") unless user = User.find(user_id)
      elsif user_signed_in?
        user = current_user
      end
    
      # get and render dashboard entries
      if user
        
        if @limit == 0
          @status = 200
          @entries = []
          render 'index'
          return
        end
        
        
        if params[:since_id]
          
          return render_error(404, "please specify a valid id") unless since_id = ensure_valid_bson_id(params[:since_id])
          
          case params[:order]
          when "1", nil, "forward"
            @entries = DashboardEntry.limit(@limit).skip(skip).sort(:id.desc).where(:user_id => user.id, :id.lte => since_id).all
          when "-1", "reverse", "backward"
            @entries = DashboardEntry.limit(@limit).skip(skip).sort(:id.desc).where(:user_id => user.id, :id.gt => since_id).all
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

        @rolls = Roll.find(@entries_roll_ids)
        @users = User.find((@entries_creator_ids + @entries_hearted_ids).uniq)
        @videos = Video.find(@entries_video_ids)
        @conversations = Conversation.find(@entries_conversation_ids)
        ##########
        
        @include_children = params[:include_children] != "false" ? true : false
        @status = 200
      else
        render_error(404, "no user info found")
      end    
    end
  end

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

        return render_error(404, "please specify a valid id") unless (id = ensure_valid_bson_id(params.delete(:id)))
        
        if @dashboard_entry = DashboardEntry.find(id)
          begin 
            @status = 200 if @dashboard_entry.update_attributes!(params)
          rescue => e
            render_error(404, "could not update dashboard_entry: #{e}")
          end
        else
          render_error(404, "could not find that dashboard_entry")
        end
      else
        render_error(404, "must specify an id.")
      end
    end
  end

  protected
    def set_current_user
      @current_user = User.find(oauth.identity) if oauth.authenticated?
    end
 

end
