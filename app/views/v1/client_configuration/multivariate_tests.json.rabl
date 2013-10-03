collection @tests
cache @cache_key

node :name do |c|
  c["name"]
end

node :buckets do |c|
  c["buckets"]
end