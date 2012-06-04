# encoding: UTF-8
module GT
  class SocialPostFormatter
    
    def self.format_for_twitter(text, links)
      # truncate text so that our link can fit fo sure and be < 140
      t = text.length > 117 ? "#{text[0..116]}…" : text
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