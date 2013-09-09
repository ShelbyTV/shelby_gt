# encoding: UTF-8
module GT
  class MortarHarvester
    # pass a user object or user id as the parameter
    def self.get_recs_for_user(u, limit=20)
      user_id = u.is_a?(User) ? u.id : u
      response = HTTParty.get("https://recs.mortardata.com/v1/recommend/users/#{user_id}?limit=#{limit}",
                     :basic_auth => {:username => 'henry@shelby.tv', :password => 'review-before-policeman-she'})
      response.code == 200 ? response.parsed_response['recommended_items'] : nil
    end
  end
end