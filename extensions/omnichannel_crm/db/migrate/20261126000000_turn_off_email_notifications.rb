# Agents are notified inside AlvoChat (and by browser push); e-mail for every
# assigned conversation was filling their inboxes. Turns e-mail notifications
# off for everyone once. Anyone can turn them back on in Perfil > Notificações.
class TurnOffEmailNotifications < ActiveRecord::Migration[7.1]
  def up
    execute('UPDATE notification_settings SET email_flags = 0, updated_at = NOW() WHERE email_flags <> 0')
  end

  def down
    # The previous choices are not kept; nothing to restore.
  end
end
