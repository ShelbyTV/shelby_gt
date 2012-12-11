require "social_poster"
require "link_shortener"
require "social_post_formatter"

class V1::RollController < ApplicationController
  
  before_filter :user_authenticated?, :except => [:index, :show, :index_associated, :explore, :featured]
  ##
  # Returns a collection of rolls according to search criteria.
  #
  # [GET] /v1/roll
  #
  # @param [Required, String] subdomain The shelby.tv subdomain of the roll
  def index
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['index']) do
      if params[:subdomain]
        @rolls = ::Roll.where(:subdomain => params[:subdomain], :subdomain_active => true).all
        if user_signed_in?
          @rolls = @rolls.select {|roll| roll.viewable_by?(current_user) or roll.public}
        else
          @rolls = @rolls.select {|roll| roll.public}
        end
        @status = 200
      else
        render_error(400, "required parameter subdomain not specified")
      end
    end
  end

  ##
  # Returns one roll, with the given parameters.
  #
  # [GET] /v1/roll/:id
  # 
  # @param [Required, String] id The id or shelby.tv subdomain of the roll
  # @param [Optional, String] following_users Return the following_users?
  def show
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['show']) do
      if params[:id]
        @include_following_users = params[:following_users] == "true" ? true : false
        
        if BSON::ObjectId.legal? params[:id]
          @roll = Roll.find(params[:id])
        else
          @roll = Roll.where(:subdomain => params[:id], :subdomain_active => true).find_one
        end
        
        if @roll
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
  
  ##
  # Returns all rolls "associated" with the given roll (inclusive of the given roll).
  # "associated" is currently defined as: public rolls created by the same user (less the "hearted" roll).
  # This is used for navigation between multiple iso-rolls
  #
  # [GET] /v1/roll/:roll_id/associated
  #   AUTHENTICATON OPTIONAL
  # 
  # @param [Required, String] roll_id The id or shelby.tv subdomain of the roll
  def index_associated
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['show']) do
      if params[:roll_id]        
        if BSON::ObjectId.legal? params[:roll_id]
          seed_roll = Roll.find(params[:roll_id])
        else
          seed_roll = Roll.where(:subdomain => params[:id], :subdomain_active => true).find_one
        end
        
        if seed_roll
          if (user_signed_in? and seed_roll.viewable_by?(current_user)) or seed_roll.public
            @rolls = Roll.where(
              :creator_id => seed_roll.creator_id, 
              :public => true, 
              :roll_type => [ Roll::TYPES[:special_public_real_user],
                              Roll::TYPES[:special_public_upgraded],
                              Roll::TYPES[:user_public],
                              Roll::TYPES[:global_public],
                              Roll::TYPES[:hashtag] ]).all
            @rolls = [seed_roll] + (@rolls - [seed_roll])
            @status =  200
            render 'index_array'
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
  
  ## DEPRECATED, use roll#featured
  #
  # Returns a hierarchy of rolls to explore.
  #
  # Returns an array of objects that define the hierarchy of Rolls for the Explore section.
  # [{category_name: "sports", rolls: [array_of_rolls]}, {category_name: "tech", rolls: [array_of_rolls]}, ...]
  #
  # The rolls will include the first three Frames which will include Video information sufficient to display on an Explore view.
  #
  # [GET] /v1/roll/explore
  #
  def explore
    #DEPRECATED, use roll#featured
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['explore']) do
      
      # Get all the Documents from the DB so we don't hit N+1 problem later
      rolls = Roll.find( Settings::Roll.explore.map { |name, cat| cat['rolls'] }.flatten )
      @frames_map = {}
      rolls.each do |r|
        @frames_map[r.id.to_s] = r.frames.limit(10).all
      end
      videos = Video.find( (@frames_map.values.flatten.compact.uniq).map { |f| f.video_id }.compact.uniq )
      
      @categories = []
      
      Settings::Roll.explore.each do |foo, cat|
        # single Roll.find uses identity map, preventing N+1
        rolls = []
        cat['rolls'].each { |roll_id| rolls << Roll.find(roll_id) }
        @categories << { 
          :category_name => cat['category_name'],
          :rolls => rolls.flatten
        }
      end
      
      @status = 200
    end
  end
  
  ##
  # Returns a categorical hierarchy of featured rolls (useful in Explore, Onboarding, and possibly more in the future)
  #
  # The Rolls themsleves are NOT returned, use the /v1/roll/:id route for that.
  #
  # By default, all featured categories are included.  If you only want featured categories specific to a particular 
  # area of the app, use the segment parameter.
  #
  # [GET] /v1/roll/featured
  #
  # @params [Optional, String] segment <onboarding | explore> Use when you only want a segment of the feature rolls
  #
  def featured
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['featured']) do
      
      @categories = Settings::Roll.featured
      
      if (@segment = params[:segment])
        @categories = @categories.select { |f| f["include_in"][@segment] }
        @categories.each { |c| c['rolls'] = c['rolls'].select { |r| r['include_in'][@segment] } }
      end
      
      #rabl caching
      #@cache_key = "featured#{params[:segment]}"
      
      @status = 200
    end
  end
    
  ##
  # Returns success if roll is shared successfully, with the given parameters.
  #
  # [GET] /v1/roll/:roll_id/share
  # 
  # @param [Required, String] roll_id The id of the roll to share
  # @param [Required, String] destination Where the roll is being shared to (comma seperated list)
  # @param [Optional, String] addresses The email addresses to send to
  # @param [Required, Escaped String] text What the status update of the post is
  def share
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['share']) do
      unless params.keys.include?("destination") and params.keys.include?("text")
        return  render_error(404, "a destination and a text is required to post") 
      end
      
      unless params[:destination].is_a? Array
        return  render_error(404, "destination must be an array of strings") 
      end
      
      if roll = Roll.find(params[:roll_id])      
        text = params[:text]
        resp = true
      
        # params[:destination] is an array of destinations, 
        #  short_links will be a hash of desinations/links
        short_links = GT::LinkShortener.get_or_create_shortlinks(roll, params[:destination].join(','), current_user)
      
        params[:destination].each do |d|
          case d
          when 'twitter'
            return render_error(404, "that roll is private, can not share to twitter") unless roll.public
            text = GT::SocialPostFormatter.format_for_twitter(text, short_links)
            resp &= GT::SocialPoster.post_to_twitter(current_user, text)
            StatsManager::StatsD.increment(Settings::StatsConstants.roll['share'][d])
          when 'facebook'
            return render_error(404, "that roll is private, can not share to facebook") unless roll.public
            text = GT::SocialPostFormatter.format_for_facebook(text, short_links)
            resp &= GT::SocialPoster.post_to_facebook(current_user, text, roll)
            StatsManager::StatsD.increment(Settings::StatsConstants.roll['share'][d])
          else
            return render_error(404, "we dont support that destination yet :(")
          end

          if resp
            @status = 200
          else
            render_error(404, "that user cant post to that destination")
          end  
        end
      else
        render_error(404, "could not find roll with id #{params[:roll_id]}")
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
        @status = 400
        @message = "title required" unless params.include?(:title)
        @message = "public required" unless params.include?(:public)
        @message = "collaborative required" unless params.include?(:collaborative)
        @message = "not authenticated, could not access user" unless user_signed_in?
        render 'v1/blank'
      else
        @roll = Roll.new(:title => params[:title], :creator_thumbnail_url => params[:thumbnail_url])
        @roll.creator = current_user
        @roll.public = params[:public]
        @roll.collaborative = params[:collaborative]
        @roll.roll_type = @roll.public ? Roll::TYPES[:user_public] :  Roll::TYPES[:user_private]
        
        begin
          if @roll.save! and @roll.add_follower(current_user)
            roll_type = @roll.public ? 'public' : 'private'
            StatsManager::StatsD.increment(Settings::StatsConstants.roll[:create][roll_type])
            @status = 200
          end
        rescue MongoMapper::DocumentNotValid => e
          render_error(409, "roll invalid: #{e}")
        rescue => e
          render_error(400, "could not save roll: #{e}")
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
      if @roll = Roll.find(params[:roll_id])
        @roll.add_follower(current_user)
        GT::Framer.backfill_dashboard_entries(current_user, @roll, 5)
        @status = 200
        StatsManager::StatsD.increment(Settings::StatsConstants.roll['join'])
      else
        render_error(404, "could not find roll with id #{params[:roll_id]}")
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
      if @roll = Roll.find(params[:roll_id])
        if @roll.leavable_by?(current_user)
          if @roll.remove_follower(current_user)
            @status = 200
            StatsManager::StatsD.increment(Settings::StatsConstants.roll['leave'])
          else
            return render_error(404, "something went wrong leaving that roll.")
          end
        else
          return render_error(404, "the creator of a roll can not leave a roll.")
        end
      else
        render_error(404, "can't find roll with id #{params[:roll_id]}")
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
  def update
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['update']) do   
      @roll = Roll.find(params[:id])
      return render_error(404, "could not find roll with id #{params[:roll_id]}") unless @roll and @roll.postable_by?(current_user)

      begin
        @status = 200 if @roll.update_attributes!(params)
      rescue MongoMapper::DocumentNotValid => e
        render_error(409, "roll invalid: #{e}")
      rescue => e
        render_error(400, "error while updating roll: #{e}")
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
        return render_error(404, "could not find roll with id #{params[:id]}") unless @roll = Roll.find(params[:id])
        return render_error(404, "you do not have permission") unless @roll.destroyable_by?(current_user)
        if @roll.remove_all_followers! and @roll.destroy
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
