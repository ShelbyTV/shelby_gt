object @entry

attributes :id, :action, :actor_id, :read
child :frame => "frame" do |f|
	attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id

	node(:timestamp) { |f| f.created_at.to_time }

	code :created_at do |f|
		concise_time_ago_in_words(f.created_at) if f.created_at
	end

	child :creator => "creator" do
		attributes :id, :name, :nickname, :user_image_original, :user_image, :faux, :public_roll_id, :gt_enabled
	end

	# upvote_users is a fake attribute that is populated in the controller	
 	node :upvote_users do |r|
 	  r[:upvote_users]
  end
	
	child :roll => "roll" do
		attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :creator_thumbnail_url => :thumbnail_url
		
		code :subdomain do |r|
      r.subdomain if r.subdomain_active
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