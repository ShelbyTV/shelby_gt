object @user

attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux

node :personal_roll_id do |u|
	u.public_roll_id
end

if current_user == @user

	child :authentications do
		attributes :uid, :provider, :nickname
	end	
	
	child :preferences => "preferences" do
		attributes :email_updates, :like_notifications, :watched_notifications, :quiet_mode, :comment_notifications, :upvote_notifications, :reroll_notifications, :roll_activity_notifications
	end
	
	node "watch_later_roll_id" do
		@user.watch_later_roll_id
	end
	
	code :heart_roll_id do |u|
		u.upvoted_roll_id
	end

	code :app_progress do |u|
		u.app_progress ? u.app_progress.as_json : {}
	end
	
end

if @include_rolls == true
	child @roll_followings => "roll_followings" do |r|
		attributes :id, :collaborative, :public, :creator_id, :title, :thumbnail_url, :origin_network
	end
end