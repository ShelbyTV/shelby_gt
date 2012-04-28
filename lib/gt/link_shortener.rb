module GT
  class Linkshortener
   
   def self.get_or_create_shortlink(obj, destinations)
     raise ArgumentError, "must supply at least one destination" unless destinations and destinations.is_a?(Array)
     raise ArgumentError, "must supply a roll or frame" unless obj and (obj.is_a?(Roll) or obj.is_a?(Frame))
     
     d_copy = Array.new(destinations)

     # 1. check if a destination exists for each destination given, delete if we have it already
     d_copy.delete_if { |d| obj.short_links[d] != nil }

     # 2. if d_copy is not empty, create whatever short link that is missing form frames hash of short_links    
     links = {}
     if !d_copy.empty?
       # 3. create long url
       if obj.is_a?(Roll)
         long_url = "http://#{Settings::ShelbyAPI.web_root}/roll/#{obj.id}"
       elsif obj.is_a?(Roll)
         long_url = "http://#{Settings::ShelbyAPI.web_root}/roll/#{obj.roll.id}/frame/#{obj.id}"
       end
       
       params = {  :url => long_url,
                   :channel => destinations,
                   :key=> Settings::Awesm.api_key,
                   :tool => Settings::Awesm.tool_key 
                 }
       code, resp = Awesm::Url.batch( params )
       if code == 200
         resp["awesm_urls"].each do |u|
           awesm_url = u["awesm_url"]
           
           case u["channel"]
           when "twitter"
             obj.short_links[:twitter] = awesm_url
           when "facbeook-post"
             obj.short_links[:facbeook] = awesm_url
           when "tumblr-video"
             obj.short_links[:tumblr] = awesm_url
           when "email"
             obj.short_links[:email] = awesm_url
           end
         end
         obj.save
       else
         raise AwesmError, "something went wrong in the request to Awesm"
       end
     end
     # 4. return the short_links with the requested destinations
     destinations.each { |d| links[d] = obj.short_links[d.to_sym] }
     return links
   end
   
  end
end