object @roll

attributes :id, :collaborative, :public, :creator_id

code :title do |r|
	if params[:heart_roll]
		"<3 Roll"
	else
		r.title
	end
end

code :thumbnail_url do |r|
	if params[:heart_roll]
		Settings::ShelbyAPI.web_root + "/images/assets/favorite_roll_avatar.png"
	else
		r.thumbnail_url
	end
end

child @frames do
		
	attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id
	
	code :created_at do |f|
		time_ago_in_words(f.created_at) + ' ago' if f.created_at
	end
	
	child :creator => "creator" do
		attributes :id, :name, :nickname, :primary_email, :user_image_original, :user_image, :faux, :public_roll_id
	end
	
	child :roll => "roll" do
		attributes :id, :collaborative, :public, :creator_id, :title, :thumbnail_url
	end
	
	child :video => "video" do
		attributes :id, :provider_name, :provider_id, :title, :description, 
			:duration, :author, :thumbnail_url, :tags, :categories, :source_url, :embed_url, :view_count
	end
	
	child :conversation => "conversation" do
		attributes :id, :public

		child :messages => 'messages' do
			attributes :id, :nickname, :realname, :user_image_url, :text, :origin_network, :origin_id, :origin_user_id, :user_id, :public

			code :created_at do |c|
				time_ago_in_words(c.created_at) + ' ago' if c.created_at
			end
		end
	end
end