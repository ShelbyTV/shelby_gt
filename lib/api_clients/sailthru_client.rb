require 'sailthru'

module APIClients
  class SailthruClient
        
    def self.add_user_to_list(user, list)
      raise ArgumentError, 'Must provide a valid user' unless user.is_a? User
      raise ArgumentError, 'Must provide a list' unless list
      
      return unless Rails.env == 'production'
      
      lists = { list => 1 }

      vars = {
          'name' => user.name,
          'nickname' => user.nickname,
          'avatar' => get_shelby_avatar(user),
          'subdomain' => user.public_roll.subdomain
      }
      data = {
          'id' => user.primary_email,
          'lists' => lists,
          'vars' => vars
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
      
      def self.get_shelby_avatar(user)
        if user.has_shelby_avatar
          avatar = user.shelby_avatar_url("small")
        else
          avatar = user.user_image_original || user.user_image || "/images/assets/avatar.png"
        end
      end
  
  end
end