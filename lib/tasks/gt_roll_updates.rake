namespace :gt_roll_updates do
    
    desc 'Update all rolls so that they have correct thumbnails'
    task :ensure_roll_thumbnails => :environment do

      #can't pass :timeout => nil to find_each, so need to drop down to the driver...
      Roll.collection.find({}, {:timeout => false}) do |cursor| 
        cursor.each do |hsh| 
          r = Roll.load(hsh)
          if r.first_frame_thumbnail_url == nil
            print '*'
            if r.frames.first and video = r.frames.first.video
              r.first_frame_thumbnail_url = video.thumbnail_url
            end
          else
            print '.'
          end
        end
      end
      puts " done!"
    end
    
  end
  
end
