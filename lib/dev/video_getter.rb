require 'video_manager'

# 
# The video DB doesn't have 2/3rds of the videos from NOS
# Mark has a CSV with everything that's missing, it looks like this
=begin
youtube,b_h3feDZ2HI
youtube,mCxmEpN8YeI
youtube,EKQa3LAYQkg
youtube,YL5_Nbbanhg
youtube,HXHkCn-HtUg
=end
#
# I'm going to run thru that file and add those videos to our DB
module Dev
  class VideoGetter
    
    def self.get_from_file(filename)
      count = 0
      line = 0
      
      File.open(filename, "r") do |file_handle|
        file_handle.each do |l|
          line += 1
          provider_name, provider_id = l.chomp.split(',')
          
          case provider_name
          when 'youtube'
            v = GT::VideoManager.get_or_create_videos_for_url("http://youtube.com/v/#{provider_id}")
            count += v.size
          when 'vimeo'
            v = GT::VideoManager.get_or_create_videos_for_url("http://vimeo.com/#{provider_id}")
            count += v.size
          when 'collegehumor'
            v = GT::VideoManager.get_or_create_videos_for_url("http://www.collegehumor.com/video/#{provider_id}")
            count += v.size
          end
          
          if line % 10 == 0
            puts "Completed #{line} lines, found #{count} Videos.  sleeping 1s..."
            sleep(1)
          end
          
        end
      end
    
    end
    
  end
end