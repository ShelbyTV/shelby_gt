collection @stats

child :frame do
  attributes :id, :like_count, :view_count, :roll_id

  code :created_at do |f|
    concise_time_ago_in_words(f.created_at) if f.created_at
  end

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

  child :video do
    attributes :view_count, :title, :thumbnail_url
  end

  child :creator => "creator" do
    attributes :id, :name, :nickname, :user_image_original, :user_image, :has_shelby_avatar, :shelby_user_image
  end

  child :conversation => "conversation" do
    attributes :id

    child :messages => 'messages' do
      attributes :id, :nickname, :realname, :user_image_url, :text
    end
  end

end
