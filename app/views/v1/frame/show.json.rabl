object @frame

node :originator_id do
  @originator && @originator.id
end

child @originator => :originator do
  attributes :id, :name, :nickname, :faux
end

if @include_frame_children

  attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id, :like_count

  node :created_at do |f|
    concise_time_ago_in_words(f.created_at) if f.created_at
  end

  node :anonymous_creator_nickname do |f|
    f.anonymous_creator_nickname if f.anonymous_creator_nickname
  end

  child :roll => "roll" do
    attributes :id, :collaborative, :public, :creator_id, :origin_network, :genius, :frame_count, :first_frame_thumbnail_url, :title, :roll_type, :creator_thumbnail_url => :thumbnail_url
    attributes :display_thumbnail_url => :thumbnail_url

    node :subdomain do |r|
      r.subdomain if r.subdomain_active
    end
  end

  child :creator => "creator" do
    attributes :id, :name, :nickname, :user_image_original, :user_image, :has_shelby_avatar

    child :authentications do
      attributes :uid, :provider, :nickname
    end
  end

  child :video => "video" do
    attributes :id, :provider_name, :provider_id, :title, :description,
      :duration, :author, :thumbnail_url, :tags, :categories, :source_url, :embed_url, :view_count, :like_count
    child :recs => "recs" do
      attributes :recommended_video_id, :score
    end
  end

  child :conversation => "conversation" do
    attributes :id, :public

    child :messages => 'messages' do
      attributes :id, :nickname, :realname, :user_image_url, :text, :origin_network, :origin_id, :origin_user_id, :user_id, :public, :user_has_shelby_avatar

      node :created_at do |c|
        concise_time_ago_in_words(c.created_at) if c.created_at
      end
    end
  end

else
  attributes :id, :score, :upvoters, :view_count, :frame_ancestors, :frame_children, :creator_id, :conversation_id, :roll_id, :video_id, :like_count

  node :created_at do |c|
    concise_time_ago_in_words(c.created_at) if c.created_at
  end

end
