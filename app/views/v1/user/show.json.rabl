object @user

attributes :id, :name, :nickname, :primary_email

node @auths do
	attributes :provider, :oauth_token
end