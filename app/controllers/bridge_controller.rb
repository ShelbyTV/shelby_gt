class BridgeController < ApplicationController  
  
  def index
    if user_signed_in? and ["sztul"].include?(current_user.nickname)
      @authorized = true
      
      limit = params[:limit] ? params[:limit].to_i : 20
      # put an upper limit on the number of entries returned
      limit = 20 if limit.to_i > 20
      skip = params[:skip] ? params[:skip] : 20
      
      i=0
      @entries = []
      while @entries.length < 20 do
        e = DashboardEntry.limit(limit).skip(skip*i+20).sort(:id.desc).where(:user_id => current_user.id).all
        @entries.concat(e)
        @entries.delete_if {|e| e.frame.creator.faux == 1 }
        i+=1
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
      
      @user_ids =  (@entries_creator_ids + @entries_hearted_ids).uniq
      if @users = User.where(:id => { "$in" => @user_ids }).limit(@user_ids.length).fields(:id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux, :public_roll_id, :upvoted_roll_id, :viewed_roll_id, :app_progress, :authentication_token).all
        # we have to manually put these users into an identity map (for some reason)
        @users.each {|u| User.identity_map[u.id] = u}
      end
      
      # took this out of the rabl to speed things up: building upvote_users for each frame
      @frames.each do |f|
        f[:upvote_users] = []
        if !f.upvoters.empty?
          f.upvoters.each do |fu|
            if u = User.find(fu)
              f[:upvote_users] << { :id => u.id, :name => u.name, :nickname => u.nickname, 
                                    :user_image_original => u.user_image_original, :user_image => u.user_image,
                                    :public_roll_id => u.public_roll_id }
            end
          end
        end
      end
      
      @videos = Video.find(@entries_video_ids)
      @conversations = Conversation.find(@entries_conversation_ids)
      ########
    else
      @authorized = false
    end
  end
  
end