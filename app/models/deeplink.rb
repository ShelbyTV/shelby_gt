module GT
  class DeeplinkCache
  include MongoMapper::Document
    safe

    include Plugins::MongoMapperConfigurator
    configure_mongomapper Settings::Video

    plugin MongoMapper::Plugins::IdentityMap

    key :url, String, :abbr=>:a
    key :videos, Array, :abbr=> :b
    key :time, Time, :abbr=> :c

    validates_uniqueness_of :url

    def created_at() self.id.generation_time; end
  end
end
