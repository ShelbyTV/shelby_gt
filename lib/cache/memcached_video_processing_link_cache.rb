# encoding: UTF-8

# Keeping track of video metadata from embed.ly to reduce the number of calls we have to make
# memcached key is an MD5 hash of the URL (although memcached authors say this isn't necessary)

class MemcachedVideoProcessingLinkCache
  
  attr_accessor :embedly_json
  
  def self.create(options, memcached)
    #md5 = Digest::MD5.hexdigest(options[:url])
    key = get_key_from_url(options[:url])
    
    #store the embedly json (w/ they key being the md5 hash of the url)
    ##embedly json may be nil, this is okay, we want to cache that too
    #no actual need to do this atomically, and it seems that was fucking with EventMachine

    begin
      memcached.add key, {EMBEDLY_FIELD => options[:embedly_json]}
    rescue Memcached::NotStored
      #puts 'video cache already contains item'
    end

    #If we had video (i.e. embed.ly json isn't nil) update that counter, otherwise update no video counter
    Stats.increment (options[:embedly_json] ? Stats::HAS_VIDEO : Stats::NO_VIDEO)

  end

  def self.find_by_url(url, memcached)
    #md5 = Digest::MD5.hexdigest(url)
    key = get_key_from_url(url)
    #resolved is nil if there's nothing in memcached, the raw embedly json, or empty string if embedly returned nothing
    begin
      resolved = memcached.get key 
    rescue Memcached::NotFound
      resolved = nil
      #puts 'video cache miss'
    end

    if resolved 
      #Building an object to match the old sematics
      obj = MemcachedVideoProcessingLinkCache.new()
      obj.embedly_json = (resolved.empty? ? nil : resolved[EMBEDLY_FIELD])
      return obj
    else
      return nil
    end
  end

  def self.get_key_from_url(url)
    return Digest::MD5.hexdigest(KEY_PREFIX+url)
  end

  private
  
  EMBEDLY_FIELD = "e"
  KEY_PREFIX = "e"

end
