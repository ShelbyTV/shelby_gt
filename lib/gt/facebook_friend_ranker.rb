require 'koala'

module APIClients
  class FacebookFriendRanker

    # pass in FB access token for user and desired weights for each attribute
    def initialize(user, photo_rank_weight=150, link_rank_weight=30, post_rank_weight=140, tagged_rank_weight=70, liked_photo_weight=10)
      raise ArgumentError, "Must supply a user" unless user.is_a? User
      @fb_auth = user.authentications.select { |a| a.provider == 'facebook'  }.first
      raise ArgumentError, "User must have a Facebook authentication" unless @fb_auth

      @photo_rank_weight = photo_rank_weight
      @link_rank_weight = link_rank_weight
      @post_rank_weight  = post_rank_weight
      @tagged_rank_weight = tagged_rank_weight
      @liked_photo_weight = liked_photo_weight
    end

    # returns array of friend ids, sorted by their score (descending)
    def get_friends_sorted_by_rank
      # for all of user's friends, grab the posts/links/photos that user is involved in if it isn't already set
      @fb_resp ||= get_fb_resp()
      # FB API response comes back looking like [friends => [{dataPoint1 => createdTime, uid}, dataPoint2...], photos...]
      @friends_array = convert_to_array(@fb_resp['friends'])
      @photo_scores  = score(convert_to_array(@fb_resp['photo']),         @photo_rank_weight )
      @link_scores   = score(convert_to_array(@fb_resp['link']),          @link_rank_weight  )
      @post_scores   = score(convert_to_array(@fb_resp['post']),        @post_rank_weight  )
      @tagged_scores = score(convert_tagged_to_array(@fb_resp['tagged']), @tagged_rank_weight)
      @likedPhoto_scores = score(convert_to_array(@fb_resp['likePhoto']), @liked_photo_weight)

      #returns a 2d array sorted by score [[id,score]]
      sorted_score_id = rank_data_by_score([@photo_scores, @link_scores, @post_scores, @tagged_scores, @likedPhoto_scores])
      ranked_ids=[]
      #grab only the id
      sorted_score_id.each do |el|
        ranked_ids.push(el[0]) if !(ranked_ids.include? el[0])
      end
      #return the list where the highest scored ID is first in array
      return ranked_ids.reverse
    end

    private
      def client
        unless @client
          @client = Koala::Facebook::API.new(@fb_auth.oauth_token)
        end
        @client
      end

      # expects data to look like:  [{dataPoint1 => uid, time}, ...]
      # returns [[id1, time1]...]
      def convert_to_array(data)
        result = []
        data.each do |first|
          first.values.each do |value|
            result.push(value.to_i)
          end
        end
        return result
      end
      # this is similar to convert_to_array but we have to extract the timestamp
      def convert_tagged_to_array (data)
        ids = {}
        result = []
        times =[]
        me = @fb_auth.uid
        data.each do |tag|
          # seperate post_ids associated with me and friends since it will say
          # that I'm associated with my friend and also that my friend is associated with me
          # so we have to make sure we don't double count
          if tag['actor_id']== me
            ids[tag['post_id']]=(ids[tag['post_id']] || []).push(tag['target_id'])
          else
            ids[tag['post_id']]=(ids[tag['post_id']] || []).push(tag['actor_id'])
          end
        end
        # push the timestamp for each post_id that we got above
        client.get_objects(ids.keys).each do |x|
          ids[x[0]].each do |tag|
            result.push(tag)
            result.push(Time.parse(x[1]['updated_time']).to_i)
          end
        end
        return result
      end

      # takes in [id1,time1,id2,time2...] and returns [[id1,score1]...]
      def score(data, weight)
        ids =[]
        score =[]
        result= {}
        # step by two so we can match the time and id correctly
        # since it's in the form [id1,time1]
        (0..data.length).step(2) do |x|
          if @friends_array.include?(data[x])
            ids.push(data[x])
            # the score is just the weight times the time decay
            score.push(weight*timeDecay(data[x+1]))
          end
        end
        # iterate through the ids to add a repeat score to one uid
        (0..ids.length).step(1) do |x|
          result[ids[x]]=(result[ids[x]] || 0) + (score[x] || 0)
        end
        return result
      end

      # time decay calculated with a crux point of 90 days yielding value of .2
      def timeDecay (time)
        return 2.71**(-0.017*(Time.now.to_i-time)/86400)
      end

      # multiquery call
      def get_fb_resp()
        return client.fql_multiquery(
          :friends => "SELECT uid1 FROM friend WHERE uid2=me()",
          :objects => "SELECT object_id FROM like WHERE user_id=me() LIMIT 300",
          :post =>'SELECT actor_id,created_time FROM stream WHERE source_id=me() and actor_id in (SELECT uid1 FROM #friends) LIMIT 100',
          :link =>'SELECT owner,created_time FROM link WHERE link_id in (SELECT object_id FROM #objects) and owner in (SELECT uid1 FROM #friends)',
          :photo =>'SELECT subject,created FROM photo_tag WHERE pid in (SELECT pid FROM photo_tag WHERE subject=me())',
          :tagged =>'SELECT actor_id, target_id, post_id FROM stream_tag WHERE target_id=me() or actor_id=me()',
          :likePhoto => 'SELECT owner, created FROM photo WHERE object_id in (SELECT object_id FROM like WHERE user_id=me())'
        )
      end

      def rank_data_by_score (hashes)
        all_hashes = {}
        hashes.each do |hash|
          hash.each do |key,value|
            key=Integer(key || 0)
            if key!=0
              all_hashes[key]= (all_hashes[key] || 0) + (value || 0)
            end
          end
        end
        #sort the 2d array based on the score
        return all_hashes.sort_by{|k|k[1]}
      end

  end
end
