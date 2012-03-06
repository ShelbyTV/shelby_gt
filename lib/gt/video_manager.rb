require 'url_helper'

# This is the one and only place where Videos are created.
# VideoManager handles the URLs resolution/parsing in the background
#
# If Arnold 2, the bookmarklet, or a dev script needs (to create) a Video, that goes through us.
#
#
module GT
  class VideoManager
    
    
    # I think I only need
    #  get_or_create_video_for_url(url)
    # and then a bunch of private methods to do the rest
    
    # -- options --
    #
    # url --- REQUIRED, the url (unclean, unresvoled) where we are looking for video
    # use_em --- [fase] should we use EventMachine for blocking processes? (allows same code to be used in multiple environments)
    # memcache_client --- [nil] if memcache is availble, this client should give us access to it 
    #                 *** Memcached client should be EventMachine aware if applicalbe!
    #
    # -- returns --
    #
    # [Video] --- and Array of 0 or more Videos, persisted.
    # 
    def self.get_or_create_videos_for_url(url, use_em=false, memcache_client=nil)
      return nil unless (url = GT::UrlHelper.get_clean_url(url))
      
      # Are we looking at a known provider that has a unique video at this url?
      if (provider_info = GT::UrlHelper.parse_url_for_provider_info(url))
        v = Video.find(:provider_name => provider_info[:provider_name], :provider_id => provider_info[:provider_id])
        return v if v
      end
      
      # No video? Resolve it if it's a shortlink and then look again
      url = GT::UrlHelper.resolve_url(url, use_em, memcache_client)
      url = GT::UrlHelper.post_process_url(url)
      
      # Is the final URL looking at a known provider that has a unique video at this url?
      if (provider_info = GT::UrlHelper.parse_url_for_provider_info(url))
        v = Video.find(:provider_name => provider_info[:provider_name], :provider_id => provider_info[:provider_id])
        return v if v
      end
      
      ##### -- -- -- -- >>>
      # In the future, if we deep-examine pages for video, would have a cross-references DB that we would look at right now
      # For a given URL, it would return an array of id's for Videos which we could then return
      ##### -- -- -- -- >>>
      
      # Still no video...
      # Examine that URL (via our cache, our service, or external service like embed.ly), looking for video
      video_hashes = GT::UrlVideoDetecor.examine_url_for_video(url, use_em, memcache_client)
      
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
          if( vh.key == :from_embedly )
            v = find_or_create_video_for_embedly_hash(vh)
            videos << v if v
          elsif( vh.key == :from_shelby )
            v = find_or_create_video_for_shelby_hash(vh)
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
          Rails.logger.error("[GT::VideoManager#create_video_for_embedly_hash] could not determine provider name, id based on embed.ly hash #{vh}")
          return nil
        end
        
        v = Video.find(:provider_name => provider_name, :provider_id => provider_id)
        return v if v
        
        v = Video.new
        v.provider_name = provider_name
        v.provider_id = provider_id
        v.provider_name = h['provider_name']
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
        
        v.save
        return v
      end
    
  end
end