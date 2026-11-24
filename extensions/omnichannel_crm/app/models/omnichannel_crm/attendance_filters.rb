# Conversation list filters of the attendance screen:
# - `search`: protocol (conversation number), customer name or phone;
# - `waiting_over`: open conversations whose customer waits for a reply for
#   more than that many minutes ("Atrasados").
module OmnichannelCrm::AttendanceFilters
  LATE_AFTER_MINUTES = 15

  # `conversations` here already joins contacts (ConversationFinder).
  def self.search(conversations, term)
    text = term.to_s.strip
    return conversations if text.blank?

    by_text = conversations.where('contacts.name ILIKE :like OR contacts.email ILIKE :like', like: "%#{ActiveRecord::Base.sanitize_sql_like(text)}%")
    # Numbers are a phone or a protocol only when the search has no letters
    # ("Maria 2" must not match every phone with a 2).
    return by_text if text.match?(/[[:alpha:]]/)

    digits = text.gsub(/\D/, '')
    return by_text if digits.blank?

    by_digits = conversations.where("regexp_replace(coalesce(contacts.phone_number, ''), '[^0-9]', '', 'g') LIKE ?", "%#{digits}%")
    by_protocol = digits.length <= 9 ? conversations.where(display_id: digits.to_i) : conversations.none
    by_text.or(by_digits).or(by_protocol)
  end

  def self.waiting_over(conversations, minutes)
    conversations.where(status: :open).where('conversations.waiting_since <= ?', minutes.to_i.minutes.ago)
  end

  module Finder
    private

    def filter_by_query
      super
      @conversations = OmnichannelCrm::AttendanceFilters.search(@conversations, params[:search]) if params[:search].present?
      return if params[:waiting_over].blank?

      @conversations = OmnichannelCrm::AttendanceFilters.waiting_over(@conversations, params[:waiting_over])
    end
  end
end
