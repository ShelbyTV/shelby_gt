object @user

attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux, :cohorts

node :personal_roll_id do |u|
	u.public_roll_id
end

if current_user == @user
  
  attributes :authentication_token, :autocomplete

	child :authentications do
		attributes :uid, :provider, :nickname
	end	
	
	child :preferences => "preferences" do
		attributes :email_updates, :like_notifications, :watched_notifications, :comment_notifications, :upvote_notifications, :reroll_notifications, :roll_activity_notifications, :open_graph_posting
	end
	
	node "watch_later_roll_id" do
		@user.watch_later_roll_id
	end
	
	node "heart_roll_id" do
		@user.upvoted_roll_id
	end

	code :app_progress do |u|
		u.app_progress ? u.app_progress.as_json : {}
	end
	
end