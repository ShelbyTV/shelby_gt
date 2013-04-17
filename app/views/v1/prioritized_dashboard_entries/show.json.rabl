object @pdb_entry

#TODO: be sure to include :score when moving to real C API
attributes :id, :action, :actor_id, :read, :score

child :frame do
  attributes :id, :score, :view_count, :creator_id, :conversation_id, :roll_id, :video_id, :upvoters, :like_count
  
  #TODO: add these for real when moving to C API
  node(:originator_id) { nil }
  node(:originator) { nil }
  
  code :created_at do |f|
    concise_time_ago_in_words(f.created_at) if f.created_at
  end
  
  child :creator => "creator" do
    attributes :id, :name, :nickname, :user_image_original, :user_image, :has_shelby_avatar, :user_type, :public_roll_id, :gt_enabled

    child :authentications do
      attributes :uid, :provider, :nickname
    end
  end

  child :roll => "roll" do
    attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :creator_thumbnail_url => :thumbnail_url
  end
  
  child :video => "video" do
    attributes :id, :provider_name, :provider_id, :title, :description,
      :duration, :author, :thumbnail_url, :source_url, :embed_url, :view_count, :tags, :categories, :first_unplayable_at, :last_unplayable_at
  end
  
  child :conversation => "conversation" do
    attributes :id, :public

    child :messages => 'messages' do
      attributes :id, :nickname, :realname, :user_image_url, :text, :origin_network, :origin_id, :origin_user_id, :user_id, :user_has_shelby_avatar, :public

      code :created_at do |c|
        concise_time_ago_in_words(c.created_at) if c.created_at
      end
    end
  end
  
end

