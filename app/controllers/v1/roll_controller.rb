require "social_poster"
require "link_shortener"
require "social_post_formatter"

class V1::RollController < ApplicationController  
  
  before_filter :user_authenticated?, :except => [:show]
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
          @roll = ::Roll.find(params[:id])
        else
          @roll = ::Roll.where(:subdomain => params[:id], :subdomain_active => true).find_one
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
  
  ##
  # Returns rolls to browse.
  #
  # [GET] /v1/roll/browse
  # 
  def browse
    StatsManager::StatsD.time(Settings::StatsConstants.api['roll']['show']) do
      
      case Rails.env
      when 'production'
        hot_rolls = ['4f99c6d0b415cc07f9000c3e' ,'4f933289b415cc5b250003fc', '4fdf3d27b415cc69340008f8', '4f901d4bb415cc661405fde9', '4f95630e9a725b76d40019d1', '4f900d56b415cc6614056681', '4f9ec30c9a725b424e00442e', '4f8feb54b415cc6614041213', '4f902217b415cc466a000909', '4f95db5388ba6b61a3004577', '4fa057c388ba6b0f4200183c', '4fa28d309a725b77f700070f', '4fbad2c5d1041266bc000d4f', '4fb40c9bd104126ad900a57b', '4fb489939a725b5ca8003e9b', '4fa41cfa88ba6b0dcf001a65', '4f9c3588b415cc0f0f000893', '4fbe42069a725b686300004a', '4f9e93879a725b12ab001c48', '4fa1eef188ba6b5f440007b9', '4fb3d39988ba6b33460043bb', '4f95cfe19a725b0a8c0384af', '4f902316b415cc466a0009dd']
      when 'development'
        hot_rolls = [Roll.all[0].id, Roll.all[1].id]
      else
        hot_rolls = params[:rolls]
      end
      
      if @rolls = Roll.find(hot_rolls)
        
        # load frames with select attributes, if params say to
        if params[:frames] == "true"
          # default params
          limit = params[:frames_limit] ? params[:frames_limit] : 1
          # put an upper limit on the number of entries returned
          limit = 20 if limit.to_i > 20

          # intelligently fetching frames and videos for performance purposes
          @frames =[]
          @rolls.each { |r| @frames << r.frames.limit(limit).all }
          @videos = Video.find( @frames.flatten!.compact.uniq.map {|f| f.video_id }.compact.uniq )
          
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
        
        @status = 200
      else
        render_error(404, "something went wrong finding those rolls.")
      end
      
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
        short_links = GT::LinkShortener.get_or_create_shortlinks(roll, params[:destination].join(','))
      
        params[:destination].each do |d|
          case d
          when 'twitter'
            return render_error(404, "that roll is private, can not share to twitter") unless roll.public
            text = GT::SocialPostFormatter.format_for_twitter(text, short_links)
            resp &= GT::SocialPoster.post_to_twitter(current_user, text)
            StatsManager::StatsD.increment(Settings::StatsConstants.roll['share'][d], current_user.id, 'roll_share', request)
          when 'facebook'
            return render_error(404, "that roll is private, can not share to facebook") unless roll.public
            text = GT::SocialPostFormatter.format_for_facebook(text, short_links)
            resp &= GT::SocialPoster.post_to_facebook(current_user, text, roll)
            StatsManager::StatsD.increment(Settings::StatsConstants.roll['share'][d], current_user.id, 'roll_share', request)
          when 'email'
            # If this is private roll, email sent will be an invite.  Otherwise, it's just a Frame share of the first frame (for now, since that isn't used)
            email_addresses = params[:addresses]
            return render_error(404, "you must provide addresses") if email_addresses.blank?
            
            # save any valid addresses for future use in autocomplete
            current_user.store_autocomplete_info(:email, email_addresses)

            ShelbyGT_EM.next_tick { GT::SocialPoster.post_to_email(current_user, email_addresses, text, roll.frames.first) }
            resp &= true
            StatsManager::StatsD.increment(Settings::StatsConstants.roll['share'][d], current_user.id, 'roll_share', request)
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
            StatsManager::StatsD.increment(Settings::StatsConstants.roll[:create][roll_type], current_user.id, 'roll_create', request)
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
        StatsManager::StatsD.increment(Settings::StatsConstants.roll['join'], current_user.id, 'roll_join', request)
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
            StatsManager::StatsD.increment(Settings::StatsConstants.roll['leave'], current_user.id, 'roll_leave', request)
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
      return render_error(404, "could not find roll with id #{params[:roll_id]}") unless @roll

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
