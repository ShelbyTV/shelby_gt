namespace :recommendations do

  desc 'Generate recommendations in active users streams'
  task :generate => :environment do
    require "user_recommendation_processor"

    include_pdbe = false
    processor = GT::UserRecommendationProcessor.new(include_pdbe, false)

    processor.insert_recommendations_into_users_stream()

  end
end
