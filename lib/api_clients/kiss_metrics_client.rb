module APIClients
  class KissMetrics
   
   def self.identify_and_record(user, event, options=nil)
     raise ArgumentError, 'Must provide a User' unless user.is_a?(User)
     raise ArgumentError, 'Must provide an event to track' unless event
     raise ArgumentError, 'If providing options, it must be a Hash' if options and !options.is_a?(Hash)
          
     return if Rails.env != "production"
     
     init_km()
     
     # tell KM who this person is thats doing something
     KM.identify(user.nickname)
     
     # tell KM whats happening
     options ? KM.record(event, options) : KM.record(event);
   end 
   
   private
   
    def self.init_km()
      @client ||= KM.init( Settings::KissMetrics.api_key,
                          :log_dir => 'log')
    end
    
  end
end