module GT
  class LinkShortener
   
   include Awesm
   
   
   # linkable - object (roll or frame) that supports permalink()
   # destinations is a comma seperated string eg "email,twitter"
   def self.get_or_create_shortlinks(linkable, destinations, user=nil)
     raise ArgumentError, "must supply at least one destination" unless destinations and destinations.is_a?(String)
     raise ArgumentError, "must supply a roll, frame, or video" unless linkable and (linkable.is_a?(Roll) or linkable.is_a?(Frame) or linkable.is_a?(Video))
     
     destinations = destinations.split(',')
     
     d_copy = Array.new(destinations)

     # 1. check if a destination exists for each destination given, delete if we have it already
     d_copy.delete_if { |d| linkable.short_links[d.to_sym] != nil }

     d_copy.each do |d|
       d_copy[d_copy.index(d)] = "facebook-post" if d == "facebook"
       d_copy[d_copy.index(d)] = "tumblr-video" if d == "tumblr"
     end
     
     # 2. if d_copy is not empty, create whatever short link that is missing form frames hash of short_links    
     links = {}
     if !d_copy.empty?
       # 3. create long url
       if destinations.include?("twitter") or destinations.include?("facebook")
         long_url =  linkable.subdomain_permalink()
       elsif destinations.include?("manual") and linkable.is_a?(Frame)
         # for legit shelby rolls, link to roll instead of SEO page
         long_url = linkable.subdomain_permalink(:require_legit_roll => true) || linkable.video_page_permalink()
       elsif destinations.include?("manual") and linkable.is_a?(Roll)
         long_url = linkable.permalink() + "?roll_id=#{linkable.id}"
       else
         long_url = linkable.permalink()
       end
       
       d_copy = d_copy.join(",")
       params = {  :url => long_url,
                   :channel => d_copy,
                   :key=> Settings::Awesm.api_key,
                   :tool => Settings::Awesm.tool_key
                 }
       
       params[:user_id] = user.id.to_s if user
       
       code, resp = Awesm::Url.batch( params )
       
       if code == 200
         resp["awesm_urls"].each do |u|
           awesm_url = u["awesm_url"]
           
           case u["channel"]
           when "twitter"
             linkable.short_links[:twitter] = awesm_url
           when "facebook-post"
             linkable.short_links[:facebook] = awesm_url
           when "tumblr-video"
             linkable.short_links[:tumblr] = awesm_url
           when "email"
             linkable.short_links[:email] = awesm_url
           when "manual"
             linkable.short_links[:manual] = awesm_url
           end
         end
         linkable.save
       else
         Rails.logger.info "[ GT::LinkShortener ERROR] link not created: #{resp}"
       end
     end
     # 4. return the short_links with the requested destinations
     destinations.each { |d| links[d] = linkable.short_links[d.to_sym] }
     
     links.each do |l|
       links[links.index(l)] = "facebook" if l == "facebook-post"
       links[links.index(l)] = "tumblr" if l == "tumblr-video"
     end

     return links
   end
   
  end
end