collection @categories
if @cache_key
  cache @cache_key
end

node :category_title do |c|
  c["category_title"]
end

node(:include_in, :unless => @segment) do |c|
  c["include_in"]
end

node :rolls do |c|
  c["rolls"]
end

node(:user_channels, :if => lambda { |c| !c["user_channels"].blank? }) do |c|
  c["user_channels"]
end