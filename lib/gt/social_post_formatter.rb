# encoding: UTF-8
module GT
  class SocialPostFormatter
    MAX_TWEET_LENGTH = 140
    TWITTER_SHORTLINK_LENGTH = 22
    
    # Twitter's link shortener effectively turns all links into 22 characters
    # Need to account for each link in text, plus our own link, plus our own added characters
    def self.format_for_twitter(text, links)
      shelby_added_length = 2
      max_length = MAX_TWEET_LENGTH - TWITTER_SHORTLINK_LENGTH - shelby_added_length
      
      URI.extract(text, ["http", "https"]).each do |link|
        # we get space back if our link is shorter than twitters
        # otherwise we have to give up more space
        max_length -= (TWITTER_SHORTLINK_LENGTH - link.length)
      end
      
      t = text.length > max_length ? "#{text[0...max_length]}…" : text
      t += " #{links["twitter"]}" if links["twitter"]
      return t
    end
    
    def self.format_for_facebook(text, links)
      t = text
      t += " #{links["facebook"]}" if links["facebook"]
      return t
    end
    
  end
end