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
    
    # TODO: this should work with or without EventMachine, maybe with an option?
    
    #
    #
    def self.get_or_create_video_for_url(url, use_em=false, memcache_client=nil, options={})
      return nil unless (url = GT::UrlHelper.get_clean_url(url))
      
      # If we have video at this point, return it
      if (provider_info = GT::UrlHelper.parse_url_for_provider_info(url))
        v = Video.find(:provider_name => provider_info[:provider_name], provider_info[:provider_id] => provider_id)
        return v if v
      end
      
      # No video (yet)? Time to resolve it if it's a shortlink
      url = GT::UrlHelper.resolve_url(url, use_em, memcache_client)
      
      # See if we have Video at this point
      if (provider_info = GT::UrlHelper.parse_url_for_provider_info(url))
        v = Video.find(:provider_name => res[:provider_info][:provider_name], res[:provider_info][:provider_id] => provider_id)
        return v if v
      end
      
      # Still no video? 
      #TODO: time to hit some external service!
      
    end
    
    private
    
      
    
  end
end