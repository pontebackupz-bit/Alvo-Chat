# messages.content_attributes is a json column written through `store`, so
# most rows hold the attributes as a JSON *string* ("{\"external_echo\":true}")
# and `content_attributes ->> 'key'` finds nothing on them. `field` reads a key
# from either form.
module OmnichannelCrm::MessageAttributesSql
  OBJECT = "(CASE json_typeof(messages.content_attributes) WHEN 'string' " \
           "THEN (messages.content_attributes #>> '{}')::json ELSE messages.content_attributes END)".freeze

  module_function

  # SQL for the text value at the given path, e.g. field('activity', 'status').
  def field(*path)
    "(#{OBJECT} #>> '{#{path.join(',')}}')"
  end
end
