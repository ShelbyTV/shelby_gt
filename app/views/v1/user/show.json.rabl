object @user

attributes :id, :name, :nickname, :primary_email

child @auths do
	attributes :uid, :provider, :oauth_token
end

child @rolls do
	attributes :title, :thumbnail_url, :public, :collaborative
end