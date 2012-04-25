# encoding: UTF-8

# Keeping track of resolved urls so we don't have to resolve them every time
# memcached key is an MD5 hash of the URL (although memcached authors say this isn't necessary)

class MemcachedLinkResolvingCache
  
  attr_accessor :resolved_url
  
  # Store a URL resolution in memcached.
  #
  # --arguments--
  #
  # options -- REQUIRED:
  #  :original_url  -- REQUIRED -- the original URL that was resolved
  #  :resolved_url  -- REQUIRED -- the ultimate URL that the original URL was resolved to
  # memcached -- REQUIRED -- should be an instance of a Memcached client.  Use GT::Arnold::MemcachedManager.get_client
  #
  def self.create(options, memcached)
    raise ArgumentError, "options must include :original_url as String" unless options[:original_url] and options[:original_url].is_a? String
    raise ArgumentError, "options must include :resolved_url as String" unless options[:resolved_url] and options[:resolved_url].is_a? String
    
    key = get_key_from_url(options[:original_url])
    # store the resvoled url
    begin
      memcached.add key, {RESOLVED_URL_FIELD => options[:resolved_url]}
    rescue Memcached::NotStored
      #puts 'link cache already contains item'
    end
  end

  # Get a previous URL resolution
  #
  # --arguments--
  #
  # url -- REQUIRED -- The URL you want to resolve
  # memcached -- REQUIRED -- should be an instance of a Memcached client.  Use GT::Arnold::MemcachedManager.get_client
  #
  # --returns--
  # an instance of MemcachedLinkResolvingCache upon which you can call resolved_url to get the resolved url on cache hit.
  # nil on cache miss.
  #
  def self.find_by_original_url(url, memcached)
    return nil if url == nil
    
    key = get_key_from_url(url)
    begin
      resolved = memcached.get key
    rescue Memcached::NotFound
      resolved = nil
    end

    if resolved and resolved.is_a? Hash
      #Building an object to match the old sematics -- memcached stores nil as "" (empty string)
      obj = MemcachedLinkResolvingCache.new()
      obj.resolved_url = resolved[RESOLVED_URL_FIELD]
      return obj
    else
      return nil
    end
  end

  private
  
    def self.get_key_from_url(url)
      return Digest::MD5.hexdigest(KEY_PREFIX+url)
    end
        
    RESOLVED_URL_FIELD = "r"
    KEY_PREFIX = "r"

end
