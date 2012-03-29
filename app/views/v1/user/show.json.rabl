object @user

attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux

if current_user == @user
	child :authentications do
		attributes :uid, :provider
	end	
	
	child :preferences => "preferences" do
		attributes :email_updates, :like_notifications, :watched_notifications, :quiet_mode
	end

	if @csrf
		node :csrf_token do
			@csrf
		end
	end
	
	node "watch_later_roll" do
		@user.watch_later_roll_id
	end
	
	node "public_roll" do
		@user.public_roll_id
	end
	
end

if @include_rolls == true
	child :roll_followings => "roll_followings" do
		glue :roll do
			extends 'v1/roll/show'
		end
	end
end