# Audio is served through the app (ActiveStorage proxy) instead of a signed
# redirect: the redirect address expires in 5 minutes, and the player fetches
# the rest of the file only when play is pressed, so audio opened earlier
# stopped at 00:00. Proxy addresses do not expire and support seeking.
module OmnichannelCrm::AttachmentAudioUrl
  private

  def inline_audio_url
    return '' unless file.attached?

    Rails.application.routes.url_helpers.rails_storage_proxy_url(file, disposition: 'inline')
  end
end
