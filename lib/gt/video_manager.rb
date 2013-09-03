require 'url_helper'
require 'video_provider_api'
require 'url_video_detector'
require 'deeplink_parser'

# This is the one and only place where Videos are created.
# They might be created in video_provider_api but that is only called through this method
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
    def self.get_or_create_videos_for_url(url, use_em=false, memcache_client=nil, should_resolve_url=true, check_deep=false, prob=1)
      begin
        return {:videos => [], :from_deep => false} unless (url = GT::UrlHelper.get_clean_url(url))
      rescue
        return {:videos => [], :from_deep => false}
      end

      # Are we looking at a known provider that has a unique video at this url?
      if (provider_info = GT::UrlHelper.parse_url_for_provider_info(url))
        v = Video.where(:provider_name => provider_info[:provider_name], :provider_id => provider_info[:provider_id]).first
        return {:videos => [v], :from_deep => false} if v
      else

        # couldn't determine provider from URL; try resolving it and trying again
        # (if we did find provider info, just didn't have a Video, no need to resolve and look again)

        begin
          url = GT::UrlHelper.resolve_url(url, use_em, memcache_client) if should_resolve_url
          url = GT::UrlHelper.post_process_url(url)
        rescue
          return {:videos => [], :from_deep => false}
        end

        # Is the new, resolved URL of a known provider that has a unique video at this url?
        if (provider_info = GT::UrlHelper.parse_url_for_provider_info(url))
          v = Video.where(:provider_name => provider_info[:provider_name], :provider_id => provider_info[:provider_id]).first
          return {:videos => [v], :from_deep => false} if v
        end
      end

      ##### -- -- -- -- >>>
      # Deep-exampine pages for video...

      # first check cached
      if checkcached = DeeplinkCache.where(:url => url).first
        vid_ids = checkcached[:videos]
        deep_videos = Video.find(vid_ids)
        return {:videos => deep_videos, :from_deep => true}
      end

      # if it's not in the cache, do actual deep-examination (on some % of links)
      if check_deep && rand < prob
        deep_response = GT::DeeplinkParser.find_deep_link(url)
        deep_video_ids = []
        deep_videos = []
        deep_response[:urls].each do |deep_url|
          deep_video = get_or_create_videos_for_url(deep_url, false)[:videos]
          deep_videos += deep_video
        end
        deep_videos.each do |video|
          deep_video_ids << video.id
        end
        #cache
        if deep_response[:to_cache]
          cachedlinks = DeeplinkCache.new
          cachedlinks.url = url
          cachedlinks.videos = deep_video_ids
          cachedlinks.save
        end
        #if haven't found videos yet go to embedly
        if deep_videos.length > 0
          return {:videos => deep_videos, :from_deep => true}
        end
      end

      ##### -- -- -- -- >>>
      # since there are no deep links, leave now if we don't support this type of url
      unless provider_info
        return {:videos => [], :from_deep => false}
      end

      #cut embed.ly out of the loop for youtube videos
      if provider_info[:provider_name] == "youtube"
        yt_video = GT::VideoProviderApi.examine_url_for_youtube_video(provider_info[:provider_id], use_em)
        return {:videos => [yt_video], :from_deep => false} if yt_video
      end

      # Still no video...
      # Examine that URL (via our cache or external service like embed.ly), looking for video
      video_hashes = GT::UrlVideoDetector.examine_url_for_video(url, use_em, memcache_client)

      # turn that array of hashes into Videos
      videos = find_or_create_videos_for_hashes(video_hashes)

      # videos will be an Array of 0 or more Videos
      return {:videos => videos, :from_deep => false}
    end

    def self.fix_video_if_necessary(video, use_em=false)
      # can't do anything if video is missing source_url
      return video if video.source_url.blank?

      if video_needs_fixing?(video)
        # pull it from embed.ly w/o hitting our cache
        video_hashes = GT::UrlVideoDetector.examine_url_for_video(video.source_url, use_em, false)

        # update Video
        return video unless video_hashes and video_hashes[0] and video_hashes[0][:embedly_hash]
        h = video_hashes[0][:embedly_hash]
        video.title = h['title']
        video.name = h['name']
        video.description = h['description']
        video.author = h['author_name']
        video.video_height = h['height']
        video.video_width = h['width']
        video.thumbnail_url = h['thumbnail_url']
        video.thumbnail_height = h['thumbnail_height']
        video.thumbnail_width = h['thumbnail_width']
        video.source_url = h['url']
        video.embed_url = h['html']

        video.save
      end

      return video
    end

    def self.video_needs_fixing?(video)
      return video.title.blank? ||
             video.description.blank? ||
             video.thumbnail_url.blank? ||
             video.embed_url.blank?
    end

    def self.update_video_info(video, cache=true)
      # if we're caching, don't update unless the last update was long enough ago (both youtube and vimeo
      #   recommend not fetching the info for the same video more than once every couple hours to avoid
      #   rate limiting)
      if !cache || !video.info_updated_at || video.info_updated_at < 2.hours.ago
        response = GT::VideoProviderApi.get_video_info(video.provider_name, video.provider_id)
        if response
          if ![200, 404].include? response.code
            # if we're not getting normal response codes, I might start worrying about rate limiting
            # so make a note of it and move on
            Rails.logger.info("[GT::VideoManager#update_video_info] Request to #{video.provider_name} API returned code #{response.code} - maybe being rate limited?")
            return nil
          end
          # if the video can't be found, mark it as unavailable
          video.available = (response.code != 404)
          # if something has changed, save the changes
          video.save if video.changed?
        end
      end
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
