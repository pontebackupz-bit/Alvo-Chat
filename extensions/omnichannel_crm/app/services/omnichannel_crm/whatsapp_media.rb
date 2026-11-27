# File types of WhatsApp media as browsers can play them. Voice notes come as
# "audio/ogg; codecs=opus" and are detected as "audio/opus", which Chrome's
# player refuses; they are OGG files and are stored as "audio/ogg".
module OmnichannelCrm::WhatsappMedia
  ALIASES = { 'audio/opus' => 'audio/ogg', 'audio/x-opus+ogg' => 'audio/ogg' }.freeze

  module_function

  def content_type(mime)
    base = mime.to_s.split(';').first.to_s.strip.downcase
    ALIASES.fetch(base, base.presence || 'application/octet-stream')
  end

  def extension(mime)
    { 'audio/ogg' => 'ogg', 'audio/mpeg' => 'mp3', 'audio/mp4' => 'm4a', 'image/jpeg' => 'jpg' }
      .fetch(content_type(mime)) { content_type(mime).split('/').last.gsub(/[^a-z0-9]/, '').presence || 'bin' }
  end

  # Audio keeps the type given here instead of the one detected from its bytes.
  def attach(file_attachment, bytes, filename:, mime:)
    type = content_type(mime)
    file_attachment.attach(io: StringIO.new(bytes), filename: filename, content_type: type, identify: !type.start_with?('audio/'))
  end
end
