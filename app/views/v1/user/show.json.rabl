object @user

attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image

child :preferences do
	attributes :email_updates, :like_notifications, :watched_notifications, :quiet_mode
end

if @include_auths == true
	child :authentications do
		attributes :uid, :provider, :oauth_token
	end	
end

child @rolls_following => :rolls_followings do
	attributes :id, :title, :thumbnail_url, :public, :collaborative
end