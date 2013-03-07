collection @stats

child :frame do
  attributes :id, :like_count, :view_count

  child :video do
    attributes :view_count
  end
end