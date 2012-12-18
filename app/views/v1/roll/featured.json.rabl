collection @categories
cache @cache_key

node :category_title do |c|
  c["category_title"]
end

node(:include_in, :unless => @segment) do |c|
  c["include_in"]
end

node :rolls do |c|
  c["rolls"]
end