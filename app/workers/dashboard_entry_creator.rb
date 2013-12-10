require 'new_relic/agent/method_tracer'
class DashboardEntryCreator
  extend ::NewRelic::Agent::MethodTracer
  @queue = :dashboard_entries_queue

  def self.perform(frame_ids, action, user_ids, options)
    # when resque serializes the options, it changes the keys from symbols to strings
    # so, we change them back to symbols because that's what our code is expecting
    self.class.trace_execution_scoped(['Custom/perform/symbolizing_keys']) do
      options.symbolize_keys!
    end
    # time is serialized to a string, so we have to convert it back to a time object
    self.class.trace_execution_scoped(['Custom/perform/converting_time_string_to_object']) do
      options[:creation_time] = Time.parse(options[:creation_time]) if options[:creation_time]
    end

    frames = Frame.find(frame_ids)
    GT::Framer.create_dashboard_entries(frames, action, user_ids, options)
  end

end