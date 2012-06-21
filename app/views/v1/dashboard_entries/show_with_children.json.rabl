object @entry

attributes :id, :action, :actor_id, :read
child :frame => "frame" do |f|
	attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id

	node(:timestamp) { |f| f.created_at.to_time }

	code :created_at do |f|
		concise_time_ago_in_words(f.created_at) if f.created_at
	end

	child :creator => "creator" do
		attributes :id, :name, :nickname, :user_image_original, :user_image, :faux, :public_roll_id
	end
	
	code do |f|
  	child (User.find(f.upvoters)) => :upvote_users do
  	  attributes :id, :name, :nickname, :user_image_original, :user_image, :public_roll_id
    end
  end
	
	child :roll => "roll" do
		attributes :id, :collaborative, :public, :creator_id, :title, :creator_thumbnail_url => :thumbnail_url
		
		code :first_frame_thumbnail_url do |r|
			r.first_frame_thumbnail_url if r.first_frame_thumbnail_url
		end
		
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
				concise_time_ago_in_words(c.created_at) if c.created_at
			end
		end
	end

end