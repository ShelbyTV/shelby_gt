object @frame

if @include_frame_children == true

	attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id
	
	code :created_at do |f|
		concise_time_ago_in_words(f.created_at) if f.created_at
	end
	
	child :roll => "roll" do
		attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :creator_thumbnail_url => :thumbnail_url
		attributes :display_thumbnail_url => :thumbnail_url
		
		code :subdomain do |r|
      r.subdomain if r.subdomain_active
    end
	end

	child :creator => "creator" do
		attributes :id, :name, :nickname, :user_image_original, :user_image, :has_shelby_avatar
	end
	
        #child User.find(@frame.upvoters) => :upvote_users do
    	#  attributes :id, :name, :nickname, :user_image_original, :user_image, :public_roll_id
        #end
        node :upvote_users do |frame| 
            users = (User.find(frame.upvoters))
            jsonList = []
            if users
              users.each do |user|
                user_data = {}
                user_data[:id] = user.id
                user_data[:name] = user.name
                user_data[:nickname] = user.nickname
                user_data[:user_image_orignal] = user.user_image_original
                user_data[:user_image] = user.user_image
                user_data[:has_shelby_avatar] = user.has_shelby_avatar
                user_data[:public_roll_id] = user.public_roll_id
                jsonList << user_data.to_s
              end
            end
            jsonList
        end
              

	child :video => "video" do
		attributes :id, :provider_name, :provider_id, :title, :description, 
			:duration, :author, :thumbnail_url, :tags, :categories, :source_url, :embed_url, :view_count
	end

	child :conversation => "conversation" do
		attributes :id, :public

		child :messages => 'messages' do
			attributes :id, :nickname, :realname, :user_image_url, :text, :origin_network, :origin_id, :origin_user_id, :user_id, :public, :user_has_shelby_avatar

			code :created_at do |c|
				concise_time_ago_in_words(c.created_at) if c.created_at
			end
		end
	end
else
	attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id
	
	code :created_at do |c|
		concise_time_ago_in_words(c.created_at) if c.created_at
	end
	
end
