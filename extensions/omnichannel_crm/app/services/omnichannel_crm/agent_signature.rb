# Agent name shown above replies sent to WhatsApp, so the contact knows who
# is answering:
#
#   *```Maria Souza```*  (bold monospace)
#   Bom dia!
#
# Only the WhatsApp copy carries the name; AlvoChat keeps the message as typed.
module OmnichannelCrm::AgentSignature
  PREFIX = /\A\*?```[^`\n]{1,80}```\*?\n/

  module_function

  def name_for(message)
    sender = message.sender
    return unless sender.is_a?(::User)

    sender.try(:available_name).presence || sender.name.presence
  end

  def apply(text, name)
    return text if name.blank?

    label = "*```#{name.to_s.delete('`*').squish.truncate(80)}```*"
    text.present? ? "#{label}\n#{text}" : label
  end

  # The WhatsApp echo of a signed reply, without the name.
  def strip(text)
    text.to_s.sub(PREFIX, '')
  end
end
