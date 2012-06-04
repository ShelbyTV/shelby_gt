class DeeplinkCache
  include MongoMapper::Document

  include Plugins::MongoMapperConfigurator
  configure_mongomapper Settings::DeeplinkCache

  key :url, String, :abbr=>:a
  key :videos, Array, :typecast => 'ObjectId', :abbr=> :b

  def created_at() self.id.generation_time; end
end
