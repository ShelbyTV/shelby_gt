require 'sailthru'

module APIClients
  class SailthruClient
        
    def self.add_or_update_user_to_list(user, list)
      raise ArgumentError, 'Must provide a valid user' unless user.is_a? User
      raise ArgumentError, 'Must provide a list' unless list
      
      return unless Rails.env == 'production'
      
      #first check if user email was not nil
      if user.primary_email_was != nil and check_sailthru_for_user(user.primary_email_was)
        
      else
        add_user_to_list(user, list)
      end

    end
    
    def self.add_user_to_list(user, list)
      raise ArgumentError, 'Must provide a valid user' unless user.is_a? User
      raise ArgumentError, 'Must provide a list' unless list
      
      #return unless Rails.env == 'production'
      
      lists = { list => 1 }

      data = {
          'id' => user.primary_email,
          'lists' => lists,
          'vars' => {
              'name' => user.name
          }
      }
    
      sailthru_client.api_post('user', data)
    end
    
    def self.send_email(user_to, template, send_time=nil)
      raise ArgumentError, 'Must provide a valid user' unless user_to.is_a? User
      raise ArgumentError, 'Must provide an email template' unless template
      
      return unless Rails.env == 'production'
      
      vars = {
        'name' => user_to.name, 
        "nickname" => user_to.nickname,
        'avatar' => get_shelby_avatar(user_to),
        'subdomain' => user_to.public_roll.subdomain
      }
      
      send_time ||= '+24 hours'
      
      sailthru_client.send(template, user_to.primary_email, vars, {}, send_time)
    end
    
    private

      def self.sailthru_client
        @client ||= Sailthru::SailthruClient.new(Settings::Sailthru.api_key, Settings::Sailthru.api_secret, Settings::Sailthru.api_url) 
      end
      
      def self.check_sailthru_for_user(email_address)
        r = sailthru_client.api_get('user', {"id"=>email_address})
        r["error"] ? nil : r
      end
      
      ####################
      # HACK: This should just be called from ApplicationHelper, not sure how to so for now
      #  just created this helper method that is redundant.
      def self.get_shelby_avatar(user)
        if user.has_shelby_avatar
          avatar = user.shelby_avatar_url("small")
        else
          avatar = user.user_image_original || user.user_image || "/images/assets/avatar.png"
        end
      end
  
  end
end