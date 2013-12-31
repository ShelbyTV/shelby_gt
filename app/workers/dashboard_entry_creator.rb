class DashboardEntryCreator
  @queue = :dashboard_entries_queue

  def self.perform(frame_ids, action, user_ids, options)
    # when resque serializes the options, it changes the keys from symbols to strings
    # so, we change them back to symbols because that's what our code is expecting
    options = options.symbolize_keys
    # time is serialized to a string, so we have to convert it back to a time object
    options[:creation_time] = Time.parse(options[:creation_time]) if options[:creation_time]
    # user_ids are serialized into strings, we need to turn them back into BSON IDs
    user_ids.map! { |uid| BSON::ObjectId.from_string(uid) }

    unless (frame_ids.length == 1) && (frame_ids[0].nil?)
      frames = Frame.find(frame_ids)
    else
      # sometimes the frame_ids array will contain a single nil entry,
      # which is used for creating notification dbentries, like follow_notifications,
      # that don't have a frame
      # in that case, we skip looking up the frames by id in the db and simply pass through
      # the nil
      frames = frame_ids
    end

    # if we're going to create push notifications based on these dashboard entries, we
    # need to pass some special arguments to the db to make sure we get back the ids
    # of the new dashboard entries
    push_notification = options.delete(:push_notification_options)
    if push_notification
      options[:acknowledge_write] = true
      options[:return_dbe_ids] = true
    end
    res = GT::Framer.create_dashboard_entries(frames, action, user_ids, options)
    # if specified, send a push notification based on this dashboard entry, asynchronously
    if push_notification
      custom_options = {:dashboard_entry_id => res[0]}
      custom_options[:ga_event] = push_notification["ga_event"].symbolize_keys if push_notification["ga_event"]
      GT::AppleIOSPushNotifier.push_notification_to_devices_async(
        push_notification["devices"],
        push_notification["alert"],
        custom_options
      )
    end
  end

end