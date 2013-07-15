module Embedly
  class Regexes

    VIDEO_REGEX_STRINGS = Settings::Embedly.regexes.map { |i| i['regex'] }.flatten
    VIDEO_REGEXES = VIDEO_REGEX_STRINGS.map { |s| Regexp.new(s) }

    def self.video_regexes_matches?(url)
      VIDEO_REGEXES.each do |regex|
        return true if url =~ regex
      end
      return false
    end

  end
end