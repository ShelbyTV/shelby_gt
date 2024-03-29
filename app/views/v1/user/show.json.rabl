object @user

attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image, :user_type, :cohorts, :has_shelby_avatar, :avatar_updated_at, :beta_invites_available, :additional_abilities, :website, :dot_tv_description, :created_at
attributes :has_password? => :has_password

node :personal_roll_id do |u|
	u.public_roll_id
end

node "personal_roll_subdomain" do
  @user_personal_roll_subdomain
end

if user_twitter_auth = @user.authentications.detect {|auth| auth.provider == 'twitter'}
  node :twitter_uid do
    user_twitter_auth.uid
  end
end

child :authentications do
	attributes :uid, :provider, :nickname, :name
end

if current_user == @user

	attributes :authentication_token, :autocomplete, :rolled_since_last_notification, :session_count

	child :preferences => "preferences" do
		attributes :email_updates, :like_notifications, :like_notifications_ios, :watched_notifications, :comment_notifications, :upvote_notifications, :reroll_notifications, :reroll_notifications_ios, :roll_activity_notifications, :roll_activity_notifications_ios, :open_graph_posting
	end

	node "watch_later_roll_id" do
		@user.watch_later_roll_id
	end

	node "heart_roll_id" do
		@user.upvoted_roll_id
	end

	node "viewed_roll_id" do
		@user.viewed_roll_id
	end

	code :app_progress do |u|
		u.app_progress ? u.app_progress.as_json : {}
	end

	if @user.is_admin
		node :admin do
			@user.is_admin
		end
	end
end
