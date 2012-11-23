require 'api_clients/vimeo_client'
require 'api_clients/youtube_client'
require 'api_clients/dailymotion_client'

module Search
  class Combiner
    
    def self.get_videos_and_combine(query, opts)
      videos = get_videos(query, opts)
      {:status => "ok", :limit => opts[:limit], :page => opts[:page], :videos => combine(videos) }
    end
    
    def self.get_videos(query, opts)
      v = APIClients::Vimeo.search(query, opts)
      y = APIClients::Youtube.search(query, opts)
      d = APIClients::Dailymotion.search(query, opts)
      return {:youtube => y[:videos], :vimeo => v[:videos], :dailymotion => d[:videos]}
    end
    
    def self.combine(mixed_videos)
      all_videos = mixed_videos[:vimeo].concat(mixed_videos[:dailymotion]).concat(mixed_videos[:youtube])
      with_scores = add_scores(all_videos)
      videos_sorted_by_score = with_scores.sort_by { |x| x[:score] }
      return videos_sorted_by_score.reverse
    end
    
    
    def self.add_scores(videos)
      weight = {
        "youtube" => 1.2,
        "vimeo" => 0.8,
        "dailymotion" => 0.6
      }
      
      videos.each do |vid|
        vid[:score] = (videos.index(vid)/videos.length.to_f)*weight[vid[:"provider_name"]]
      end
      return videos
    end
  end
end