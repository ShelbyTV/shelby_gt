require 'url_helper'
require 'url_video_detector'

# This is the one and only place where Videos are created.
# VideoManager handles the URLs resolution/parsing in the background
#
# If Arnold 2, the bookmarklet, or a dev script needs (to create) a Video, that goes through us.
#
#
module GT
  class VideoManager
    
    # Given a URL, do everything in our power to return Video(s).
    # If we already have Video(s) in our DB for that URL, will return that.  If there is video there,
    # but we haven't seen it, will create new Video(s) object(s) and return that.
    #
    # -- options --
    #
    # url --- REQUIRED, the url (unclean, unresvoled) where we are looking for video
    # use_em --- [false] should we use EventMachine for blocking processes? (allows same code to be used in multiple environments)
    # memcache_client --- [nil] if memcache is availble, this client should give us access to it 
    #                 *** Memcached client should be EventMachine aware if applicable!
    # should_resolve_url --- [true] should we try to resolve the url?  
    #                        When we get URLs assured to be resolved (ie from Twitter entities) we don't try to resolve
    #
    # -- returns --
    #
    # [Video] --- and Array of 0 or more Videos, persisted.
    # 
    def self.get_or_create_videos_for_url(url, use_em=false, memcache_client=nil, should_resolve_url=true)
      begin
        return [] unless (url = GT::UrlHelper.get_clean_url(url))
      rescue
        return []
      end
      
      # Are we looking at a known provider that has a unique video at this url?
      if (provider_info = GT::UrlHelper.parse_url_for_provider_info(url))
        v = Video.where(:provider_name => provider_info[:provider_name], :provider_id => provider_info[:provider_id]).first
        return [v] if v
      end
      
      # No video? Resolve it and then look again
      begin
        url = GT::UrlHelper.resolve_url(url, use_em, memcache_client) if should_resolve_url
        url = GT::UrlHelper.post_process_url(url)
      rescue
        return []
      end
      
      # Is the final URL looking at a known provider that has a unique video at this url?
      if (provider_info = GT::UrlHelper.parse_url_for_provider_info(url))
        v = Video.where(:provider_name => provider_info[:provider_name], :provider_id => provider_info[:provider_id]).first
        return [v] if v
      end
      
      ##### -- -- -- -- >>>
      # In the future, if we deep-examine pages for video, would have a cross-references DB that we would look at right now
      # For a given URL, it would return an array of id's for Videos which we could then return
      ##### -- -- -- -- >>>
      
      # Still no video...
      # Examine that URL (via our cache, our service, or external service like embed.ly), looking for video
      video_hashes = GT::UrlVideoDetector.examine_url_for_video(url, use_em, memcache_client)
      
      # turn that array of hashes into Videos
      videos = find_or_create_videos_for_hashes(video_hashes)
      
      # videos will be an Array of 0 or more Videos
      return videos
    end
    
    private
    
      def self.find_or_create_videos_for_hashes(video_hashes)
        return [] unless video_hashes
        videos = []
        
        video_hashes.each do |vh|
          if( vh.keys.include? :embedly_hash )
            v = find_or_create_video_for_embedly_hash(vh[:embedly_hash])
            videos << v if v
          elsif( vh.keys.include? :shelby_hash )
            v = find_or_create_video_for_shelby_hash(vh[:shelby_hash])
            videos << v if v
          end
        end
        
        return videos
      end
      
      def self.find_or_create_video_for_shelby_hash(h)
        #TODO in the future: handle shelby service hash => video conversion
        return nil
      end
      
      def self.find_or_create_video_for_embedly_hash(h)
        # Determine provider name and id
        if (provider_info = GT::UrlHelper.parse_url_for_provider_info(h['url'])) or
            (provider_info = GT::UrlHelper.parse_url_for_provider_info(h['html'])) or
            (provider_info = GT::UrlHelper.parse_url_for_provider_info(h['thumbnail_url']))
          provider_name = provider_info[:provider_name]
          provider_id = provider_info[:provider_id]
        else
          Rails.logger.info("[GT::VideoManager#find_or_create_video_for_embedly_hash] could not determine provider name, id based on embed.ly hash #{h}")
          return nil
        end
        
        v = Video.where(:provider_name => provider_name, :provider_id => provider_id).first
        return v if v
        
        v = Video.new
        v.provider_name = provider_name
        v.provider_id = provider_id
        v.title = h['title']
        v.name = h['name']
        v.description = h['description']
        v.author = h['author_name']
        v.video_height = h['height']
        v.video_width = h['width']
        v.thumbnail_url = h['thumbnail_url']
        v.thumbnail_height = h['thumbnail_height']
        v.thumbnail_width = h['thumbnail_width']
        v.source_url = h['url']
        v.embed_url = h['html']
        
        # ---missing from embed.ly
        # v.duration
        # v.tags
        # v.categories
        
        begin
          v.save
          return v
        rescue Mongo::OperationFailure => e
          # If this was a timing issue, and Video got created after we checked, that means the Video exists now.  See if we can't recover...
          v = Video.where(:provider_name => provider_name, :provider_id => provider_id).first
          return v if v
          Rails.logger.error "[GT::VideoManager#find_or_create_video_for_embedly_hash] rescuing Mongo::OperationFailure #{e}"
          return nil
        end
      end
    
  end
end