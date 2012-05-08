require 'video_manager'
require 'memcached_manager'

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
    
    def self.get_from_file(filename, starting_line=0, use_memcached=true)
      count = 0
      line = 0
      
      mem_client = use_memcached ? GT::Arnold::MemcachedManager.get_client : nil
      
      File.open(filename, "r") do |file_handle|
        enum = file_handle.lines
        starting_line.times{ enum.next }
        line += starting_line
        
        enum.each do |l|
          provider_name, provider_id = l.chomp.split(',')
          
          case provider_name
          when 'youtube'
            url = "http://youtube.com/v/#{provider_id}"
          when 'vimeo'
            url = "http://vimeo.com/#{provider_id}"
          when 'collegehumor'
            url = "http://www.collegehumor.com/video/#{provider_id}"
          else
            url = nil
          end
          
          if url
            begin
              v = GT::VideoManager.get_or_create_videos_for_url(url, false, mem_client, false)
              count += v.size
              puts "no video found at #{url}" if v.empty?
            rescue
            end
          end
          
          if line % 10 == 0
            puts "Completed #{line} lines, found #{count} Videos.  sleeping 1s..."
            sleep(1)
          end
          
          line += 1
        end
      end
    
    end
    
  end
end