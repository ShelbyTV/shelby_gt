#Warden::Manager.after_set_user do |user, auth, opts|
#end

Warden::Manager.before_logout do |user, auth, opts|
  auth.cookies[:_shelby_gt_common] = {
    :value => "authenticated_user_id=nil,csrf_token=nil,api_logout=true",
    :expires => 20.years.from_now,
    :domain => '.shelby.tv'
  }
end

####
# Q: WHY ISNT THIS COOKIE BEING CLEARED WHEN A SESSION IS FUCKED (for whatever reason)??
###

=begin
module ActionDispatch
  class Request
        
    def self.reset_session

      cookies[:_shelby_gt_common] = {
        :value => "authenticated_user_id=nil,csrf_token=nil",
        :expires => 20.years.from_now,
        :domain => '.shelby.tv'
      }

      Rails.logger.info "====== RESET SESSION: #{cookies[:_shelby_gt_common]}"
    end
    
  end
end
=end