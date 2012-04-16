object @roll
cache @roll

attributes :id, :collaborative, :public, :creator_id, :title, :thumbnail_url

if @include_following_users == true
	child :following_users => "following_users" do
		attributes :id, :nickname, :name, :user_image
	end
end