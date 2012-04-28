module GT
  class SocialPostFormatter
    
    def self.format_for_twitter(text, links)
      # truncate text so that our link can fit fo sure and be < 140
      text = text.length > 119 ? "#{text[0..119]}..." : text
      text += " #{links["twitter"]}" if links["twitter"]
    end
    
    def self.format_for_facebook(text, links)
      text += " #{links["facebook"]}" if links["facebook"]
    end
    
  end
end