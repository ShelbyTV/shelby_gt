child @video => :video do
  attributes :id, :provider_name, :provider_id, :tracked_liker_count
end

node do
  { :likers => partial("/v1/video/video_likers", :object => @likers) }
end