# The AlvoChat editor writes Markdown: a line break typed with Shift+Enter
# is saved as "\" at the end of the line, bold as **text**, and so on.
# WhatsApp has its own formatting, so the text is converted before it is
# sent, or the customer sees the raw "\" characters.
module OmnichannelCrm::WhatsappText
  module_function

  def render(text)
    return text if text.blank?

    Messages::MarkdownRendererService.new(text, 'Channel::Whatsapp').render.gsub(/[ \t]+$/, '')
  end
end
