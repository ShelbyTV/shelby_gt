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
    
    def self.increment(stat, uid=false, action=false, request=false)
      # source = request if request
      stat = STAT_PREFIX + stat
      stat = "#{stat}/?uid=#{uid.to_s}&action=#{action}" if uid and action
      client.increment(stat)
    end
  
    def self.decrement(stat, uid=false, action=false)
      stat = STAT_PREFIX + stat
      stat = "#{stat}/?uid=#{uid.to_s}&action=#{action}" if uid and action
      client.decrement(stat)
    end
  
    def self.timing(stat, time, uid=false, action=false)
      stat = STAT_PREFIX + stat
      stat = "#{stat}/?uid=#{uid.to_s}&action=#{action}" if uid and action
      client.timing(stat, time)
    end
    
    def self.time(stat, uid=false, action=false, &block)
      start_t = Time.now
      yield block
      end_t = Time.now
      
      stat = STAT_PREFIX + stat
      client.timing(stat, ((end_t - start_t)*1000).round)
    end
  
    def self.count(stat, amount, uid=false, action=false)
      stat = STAT_PREFIX + stat
      stat = "#{stat}/?uid=#{uid.to_s}&action=#{action}" if uid and action
      client.count(stat, amount)
    end
  
  end
end