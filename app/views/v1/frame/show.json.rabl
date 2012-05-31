object @frame

if @include_frame_children == true

	attributes :id, :score, :upvoters, :frame_ancestors, :frame_children
	
	code :created_at do |f|
		concise_time_ago_in_words(f.created_at) if f.created_at
	end
	
	child :roll => "roll" do
		attributes :id, :collaborative, :public, :creator_id
		attributes :display_title => :title, :display_thumbnail_url => :thumbnail_url
	end

	child :creator => "creator" do
		attributes :id, :name, :nickname, :user_image_original, :user_image, :faux
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
else
	attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id
	
	code :created_at do |c|
		time_ago_in_words(c.created_at) + ' ago' if c.created_at
	end
	
end