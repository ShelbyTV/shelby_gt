# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "http://onshelby.tv"

# Set the host name for where the sitemap exists; okay to be different if pointed to by robots.txt on default_host
SitemapGenerator::Sitemap.sitemaps_host = "http://api.shelby.tv"

# Use a shared directory that stays constant across capistrano deploys on API server to hold sitemaps
SitemapGenerator::Sitemap.sitemaps_path = 'system/'


SitemapGenerator::Sitemap.create do


  # ONLY Look through last 10M starting at most recent...
  # For future SEO domains, eg shelbyapp.tv, can start at video 10M deep and go 10M deep
  start_at = 0
  end_at = 10000000
  # As of 09/06 we have 32,631,053 videos

  # TODO: use mongo driver to do this query
  Video.collection.find(
        {},
        {
          :timeout => false,
          :sort => ['_id', -1],
          :limit => end_at,
          :skip => start_at
        }
      ) do |cursor|
        cursor.each do |doc|
          begin
            video = Video.load(doc)
            titleHyph = video.title ? video.title.downcase.gsub(/\W/,'-').gsub(/"/,"'").squeeze('-').chomp('-') : ""
            add("video/#{video.provider_name}/#{video.provider_id}/#{titleHyph}")
            # this keeps memory usage and object lookup speed at reasonable levels
            MongoMapper::Plugins::IdentityMap.clear
          rescue => e

          end
        end
      end
end

