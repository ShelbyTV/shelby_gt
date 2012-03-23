object @user

attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image, :roll_followings

child :preferences do
	attributes :email_updates, :like_notifications, :watched_notifications, :quiet_mode
end

if @include_auths == true
	child :authentications do
		attributes :uid, :provider, :uid, :oauth_token, :oauth_secret
	end	
end

if @roll_followings == true
	child :roll_followings do
		glue :roll do
			attributes :id, :title, :thumbnail_url, :public, :collaborative
		end
	end
end