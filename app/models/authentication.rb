class Authentication
  include MongoMapper::EmbeddedDocument
  plugin MongoMapper::Plugins::Timestamps
  
  timestamps!

  embedded_in :user 
  
  key :provider,  String
  key :uid,       String
  key :oauth_token,   String
  key :oauth_secret,  String
  
  #oauth user info
  key :name,        String
  key :nickname,    String
  key :email,       String
  key :first_name,  String
  key :last_name,   String
  key :location,    String
  key :description, String
  key :image,       String
  key :phone,       String
  key :urls,        String
  key :user_hash,   String
  key :gender,      String
  key :timezone,    String
  
  key :permissions, Array
  
  validate :ensure_valid_for_provider

  def twitter?() provider == "twitter"; end
  def facebook?() provider == "facebook"; end
  def tumblr?() provider == "tumblr"; end
    
  private
    
    def ensure_valid_for_provider
      if 'twitter' == provider
        errors.add(:provider, "is mising some info.  nickname:#{nickname}, name:#{name}, provider:#{provider}, uid:#{uid}, oauth_token:#{oauth_token}, oauth_secret:#{oauth_secret}") if
          (nickname.blank? and name.blank?) or provider.blank? or uid.blank? or oauth_token.blank? or oauth_secret.blank?
      elsif 'facebook' == provider
        errors.add(:provider, "is mising some info.  nickname:#{nickname}, name:#{name}, provider:#{provider}, uid:#{uid}, oauth_token:#{oauth_token}") if
          (nickname.blank? and name.blank?) or provider.blank? or uid.blank? or oauth_token.blank?
      elsif 'tumblr' == provider
        errors.add(:provider, "is mising some info.  nickname:#{nickname}, name:#{name}, provider:#{provider}, uid:#{uid}, oauth_token:#{oauth_token}, oauth_secret:#{oauth_secret}") if
          (nickname.blank? and name.blank?) or provider.blank? or uid.blank? or oauth_token.blank? or oauth_secret.blank?
      else
        errors.add(:provider, "we don't support this provider yet")
      end
    end
  
end