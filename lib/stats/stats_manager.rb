module StatsManager
  class StatsD
    
    SERVER_NAME = "gt"
    VERSION = "v1"
    STAT_PREFIX = "api.#{VERSION}.#{SERVER_NAME}.web."
    
    @@client = nil
    def self.client
      #server is localhost when not in production
      @@client ||= Statsd.new(Settings::StatsD.statsd_server, Settings::StatsD.statsd_port)
    end
    
    def self.increment(stat, request=false)
      # source = request if request
      stat = STAT_PREFIX + stat
      client.increment(stat)
    end
  
    def self.decrement(stat)
      stat = STAT_PREFIX + stat
      client.decrement(stat)
    end
  
    def self.timing(stat, time)
      stat = STAT_PREFIX + stat
      client.timing(stat, time)
    end
    
    def self.time(stat, &block)
      start_t = Time.now
      yield block
      end_t = Time.now
      
      stat = STAT_PREFIX + stat
      client.timing(stat, ((end_t - start_t)*1000).round)
    end
  
    def self.count(stat, amount)
      stat = STAT_PREFIX + stat
      client.count(stat, amount)
    end
  
  end
end