# encoding: UTF-8

# Keeping track of resolved urls so we don't have to resolve them every time
# memcached key is an MD5 hash of the URL (although memcached authors say this isn't necessary)

class MemcachedLinkResolvingCache
  
  attr_accessor :resolved_url
  
  def self.create(options, memcached)
    #md5 = Digest::MD5.hexdigest(options[:original_url])
    key = get_key_from_url(options[:original_url])
    # store the resvoled url and set its expiration to 2 weeks (doesn't need to be atomic)
    begin
      memcached.add key, {RESOLVED_URL_FIELD => options[:resolved_url]}
    rescue Memcached::NotStored
      #puts 'link cache already contains item'
    end
  end

  def self.find_by_original_url(url, memcached)
    #md5 = Digest::MD5.hexdigest(url)
    key = get_key_from_url(url)
    begin
      #resolved = memcached.get md5
      resolved = memcached.get key
    rescue Memcached::NotFound
      resolved = nil
      #puts 'link cache miss'
    end

    if resolved
      #Building an object to match the old sematics -- memcached stores nil as "" (empty string)
      obj = MemcachedLinkResolvingCache.new()
      obj.resolved_url = resolved[RESOLVED_URL_FIELD]
      return obj
    else
      return nil
    end
  end

  def self.get_key_from_url(url)
    return Digest::MD5.hexdigest(KEY_PREFIX+url)
  end

  private
        
  RESOLVED_URL_FIELD = "r"
  KEY_PREFIX = "r"

end
