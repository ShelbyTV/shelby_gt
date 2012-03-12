object @user

attributes :id, :name, :nickname, :primary_email

child @auths do
	attributes :uid, :provider, :oauth_token
end

child @rolls_following => :rolls_followings do
	attributes :id, :title, :thumbnail_url, :public, :collaborative
end