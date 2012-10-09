require 'sailthru'

module APIClients
  class SailthruClient
    
    def self.add_user_to_list(user, list)
      raise ArgumentError, 'Must provide a valid user' unless user.is_a? User
      
      lists = { list => 1 }
      
      if user.has_shelby_avatar
        avatar = user.shelby_avatar_url
      else
        avatar = user.user_image_original || user.user_image || "/images/assets/avatar.png"
      end
      vars = {
          'name' => user.name,
          'nickname' => user.nickname,
          'avatar' => avatar,
          'subdomain' => user.public_roll.subdomain
      }
      data = {
          'id' => user.primary_email,
          'lists' => lists,
          'vars' => vars
      }
      
      response = sailthru_client.api_post('user', data)
    end
  
    private

      def self.sailthru_client
        @client ||= Sailthru::SailthruClient.new(Settings::Sailthru.api_key, Settings::Sailthru.api_secret, Settings::Sailthru.api_url) 
      end
  
  end
end