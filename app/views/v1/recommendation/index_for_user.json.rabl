collection @results

glue :dashboard_entry do
  attributes :id, :user_id, :action, :actor_id, :src_frame_id, :video_id

  child :src_frame => 'src_frame' do

    attributes :id, :creator_id

    child :creator => 'creator' do
      attributes :id, :nickname
    end

  end

  child :src_video => 'src_video' do

    attributes :id, :title

  end

end

child :frame do
  extends "v1/frame/show"
end