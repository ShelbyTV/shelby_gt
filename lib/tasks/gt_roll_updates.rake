namespace :gt_roll_updates do
    
  desc 'Update all rolls so that they have correct thumbnails'
  task :ensure_thumbnails => :environment do
    
    #so that we can run this in multiple rails console sessions
    @n = 10
    p = 1
    @n.times do |i|
      @limit = 50000
      @skip = (i)*@limit + (@limit*@n*p)
      #can't pass :timeout => nil to find_each, so need to drop down to the driver...
      Roll.collection.find({"m" => nil}, {:limit => @limit, :skip => @skip, :timeout => false}) do |cursor| 
        cursor.each do |hsh|
          r = Roll.load(hsh)
          if r.first_frame_thumbnail_url == nil and r.frames.first and video = r.frames.first.video
            print '*'
            r.first_frame_thumbnail_url = video.thumbnail_url
            r.save
          else
            print '.'
          end
        end
      end
    end
    puts "#{@skip} - #{@skip+@limit*@n} done!"
  end  
end