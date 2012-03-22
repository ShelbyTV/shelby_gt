# encoding: UTF-8

# Keeping track of video metadata from embed.ly to reduce the number of calls we have to make
# memcached key is an MD5 hash of the URL (although memcached authors say this isn't necessary)

class MemcachedVideoProcessingLinkCache
  
  attr_accessor :embedly_json
  
  # Store the embed.ly resolution in memcached.
  #
  # --arguments--
  #
  # options -- REQUIRED:
  #  :url  -- REQUIRED -- the URL for which we are storing the result of the call to embed.ly
  #  :embedly_json  -- REQUIRED -- the raw json returned by embed.ly
  # memcached -- REQUIRED -- should be an instance of a Memcached client.  Use GT::Arnold::MemcachedManager.get_client
  #
  def self.create(options, memcached)
    raise ArgumentError, "options must include :url as String" unless options[:url] and options[:url].is_a? String
    raise ArgumentError, "options must include :embedly_json as String" unless options[:embedly_json] and options[:embedly_json].is_a? String
    
    key = get_key_from_url(options[:url])
    
    #store the embedly json (w/ they key being the md5 hash of the url)
    #embedly json may be nil, this is okay, we want to cache that too

    begin
      memcached.add key, {EMBEDLY_FIELD => options[:embedly_json]}
    rescue Memcached::NotStored
      #puts 'video cache already contains item'
    end

  end

  # Get the embed.ly raw json for a URL
  #
  # --arguments--
  #
  # url -- REQUIRED -- The URL for which you want the embed.ly json result.  NOTE: This is the the embed.ly API call, this is the video source url as seen in the wild.
  # memcached -- REQUIRED -- should be an instance of a Memcached client.  Use GT::Arnold::MemcachedManager.get_client
  #
  # --returns--
  # an instance of MemcachedVideoProcessingLinkCache upon which you can call embedly_json to get the raw embed.ly json as embed.ly returned it for this url.
  # nil on cache miss.
  #
  def self.find_by_url(url, memcached)
    key = get_key_from_url(url)
    
    #resolved is nil if there's nothing in memcached, the raw embedly json, or empty string if embedly returned nothing
    begin
      resolved = memcached.get key 
    rescue Memcached::NotFound
      resolved = nil
      #puts 'video cache miss'
    end

    if resolved and resolved.is_a? Hash

      #Building an object to match the old sematics
      obj = MemcachedVideoProcessingLinkCache.new()
      if resolved.empty?
        obj.embedly_json = nil
      elsif resolved[EMBEDLY_FIELD].is_a? String
        obj.embedly_json = resolved[EMBEDLY_FIELD]
      elsif resolved[EMBEDLY_FIELD].is_a? Hash
        #be robust to bad stuff in cache
        obj.embedly_json = resolved[EMBEDLY_FIELD].to_json
      else
        return nil
      end

      return obj
    else
      return nil
    end
  end

  private
  
    def self.get_key_from_url(url)
      return Digest::MD5.hexdigest(KEY_PREFIX+url)
    end
  
    EMBEDLY_FIELD = "e"
    KEY_PREFIX = "e"

end
