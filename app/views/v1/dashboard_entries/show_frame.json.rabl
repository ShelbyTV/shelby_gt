object @entry

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
