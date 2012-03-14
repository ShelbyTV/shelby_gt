module GT
  module Arnold
    class MemcachedManager
      @@memcached = nil
      def self.get_client
        if !@@memcached
          @@memcached = Memcached.new(Settings::Memcached.uri)
        end
        return @@memcached
      end
    end
  end
end