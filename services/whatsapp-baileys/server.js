import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import express from 'express';
import makeWASocket, {
  Browsers,
  DisconnectReason,
  downloadMediaMessage,
  fetchLatestBaileysVersion,
  useMultiFileAuthState,
} from '@whiskeysockets/baileys';
import pino from 'pino';
import QRCode from 'qrcode';

const port = Number(process.env.PORT || 3001);
const dataDirectory = process.env.BAILEYS_DATA_DIR || '/data';
const sessionConfigurationPath = path.join(dataDirectory, 'sessions.json');
const apiToken = process.env.BAILEYS_API_TOKEN;
const sessions = new Map();
const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
const maxCachedMessages = 1000;

if (!apiToken) throw new Error('BAILEYS_API_TOKEN must be configured');

const app = express();
app.use((request, response, next) => {
  response.setHeader('access-control-allow-origin', process.env.BAILEYS_ALLOWED_ORIGIN || 'http://localhost:3000');
  response.setHeader('access-control-allow-headers', 'authorization, content-type');
  if (request.method === 'OPTIONS') return response.status(204).end();
  return next();
});
const maxMediaBytes = 12 * 1024 * 1024;

const mediaFileName = (messageKey, media) => {
  if (media.fileName) return media.fileName;

  const extension = {
    audioMessage: 'ogg',
    imageMessage: 'jpg',
    videoMessage: 'mp4',
    documentMessage: 'bin',
    stickerMessage: 'webp',
  }[messageKey] || 'bin';

  return `${messageKey}.${extension}`;
};

const normalizedMediaMimeType = (messageKey, media) => {
  if (messageKey === 'stickerMessage') return 'image/webp';

  // Baileys can include codec parameters (for example, "audio/ogg; codecs=opus").
  // Active Storage and the dashboard work more reliably with the canonical MIME type.
  return media.mimetype?.split(';')[0]?.trim() || 'application/octet-stream';
};

app.use(express.json({ limit: '18mb' }));

const authenticate = (request, response, next) => {
  if (request.path.startsWith('/chatwoot/')) return next();
  const token = request.get('authorization')?.replace(/^Bearer\s+/i, '');
  if (token !== apiToken) return response.status(401).json({ error: 'unauthorized' });
  return next();
};

const sessionDirectory = sessionId => {
  if (!/^[a-zA-Z0-9_-]{1,64}$/.test(sessionId)) throw new Error('invalid session id');
  return path.join(dataDirectory, sessionId);
};

const persistedSession = session => ({
  id: session.id,
  webhookUrl: session.webhookUrl,
  webhookSecret: session.webhookSecret,
  phoneNumbers: session.phoneNumbers,
});

const loadPersistedSessions = async () => {
  try {
    return JSON.parse(await fs.readFile(sessionConfigurationPath, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return [];
    throw error;
  }
};

const persistSessions = async () => {
  const temporaryPath = `${sessionConfigurationPath}.tmp`;
  const configuration = JSON.stringify([...sessions.values()].map(persistedSession));
  await fs.writeFile(temporaryPath, configuration);
  await fs.rename(temporaryPath, sessionConfigurationPath);
};

const unwrapMessage = message => {
  let currentMessage = message;
  const wrappers = [
    'ephemeralMessage',
    'viewOnceMessage',
    'viewOnceMessageV2',
    'viewOnceMessageV2Extension',
    'documentWithCaptionMessage',
  ];

  while (wrappers.some(wrapper => currentMessage?.[wrapper]?.message)) {
    const wrapper = wrappers.find(item => currentMessage?.[item]?.message);
    currentMessage = currentMessage[wrapper].message;
  }

  return currentMessage || {};
};

const messageText = message => {
  const content = unwrapMessage(message);
  return content.conversation || content.extendedTextMessage?.text || content.imageMessage?.caption ||
    content.videoMessage?.caption || content.documentMessage?.caption || '';
};

const mediaDetails = message => {
  const content = unwrapMessage(message);
  const mediaTypes = [
    ['imageMessage', 'image'],
    ['audioMessage', 'audio'],
    ['videoMessage', 'video'],
    ['documentMessage', 'file'],
    ['stickerMessage', 'image'],
  ];
  const [messageKey, fileType] = mediaTypes.find(([key]) => content[key]) || [];
  if (!messageKey) return null;

  const media = content[messageKey];
  return {
    content,
    fileType,
    mimeType: normalizedMediaMimeType(messageKey, media),
    fileName: mediaFileName(messageKey, media),
    isSticker: messageKey === 'stickerMessage',
    isAnimatedSticker: Boolean(media.isAnimated),
    isVoiceMessage: Boolean(media.ptt),
  };
};

const jidUser = jid => jid?.split('@')[0]?.split(':')[0] || null;

const messageCacheKey = key => `${key.remoteJid}:${key.id}`;

const rememberMessage = (session, message) => {
  session.messages.set(messageCacheKey(message.key), message);
  if (session.messages.size > maxCachedMessages) session.messages.delete(session.messages.keys().next().value);
};

const contactDetails = (session, message) => {
  const remoteJid = message.key.remoteJid;
  const sourceId = jidUser(remoteJid);
  const phoneNumber = jidUser(message.key.senderPn) || session.phoneNumbers?.[sourceId] ||
    (remoteJid?.endsWith('@s.whatsapp.net') ? sourceId : null);

  return { sourceId, phoneNumber, isLid: remoteJid?.endsWith('@lid') || false };
};

const outgoingMediaMessage = (media, text) => {
  const buffer = Buffer.from(media.data, 'base64');
  const caption = text?.trim() || undefined;
  // WhatsApp voice notes use an Ogg container with the Opus codec. Active
  // Storage identifies these recordings as `audio/opus`, but Baileys/WhatsApp
  // expects the wire MIME type below when `ptt` is set.
  const isVoiceMessage = Boolean(media.is_voice_message);
  const mimetype = isVoiceMessage && media.mime_type === 'audio/opus'
    ? 'audio/ogg; codecs=opus'
    : (media.mime_type || 'application/octet-stream');

  if (!buffer.length) throw new Error('media payload is empty');
  if (media.is_sticker || mimetype === 'image/webp') return { sticker: buffer };
  if (media.file_type === 'image') return { image: buffer, caption, mimetype };
  if (media.file_type === 'audio') return { audio: buffer, mimetype, ptt: isVoiceMessage };
  if (media.file_type === 'video') return { video: buffer, caption, mimetype };

  return {
    document: buffer,
    caption,
    mimetype,
    fileName: media.file_name || 'arquivo',
  };
};

const publishPhoneNumber = async (session, sourceId, phoneNumber) => {
  if (!session.webhookUrl) return;

  const callbackUrl = new URL(session.webhookUrl);
  callbackUrl.pathname = callbackUrl.pathname.replace(/\/messages$/, `/contacts/${encodeURIComponent(sourceId)}`);
  const response = await fetch(callbackUrl, {
    method: 'PUT',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${apiToken}`,
    },
    body: JSON.stringify({ phone_number: phoneNumber }),
  });
  if (!response.ok && response.status !== 404) {
    throw new Error(`Chatwoot contact update failed with status ${response.status}`);
  }
};

const publishIncomingMessage = async (session, message) => {
  if (!session.webhookUrl) return;

  const { sourceId, phoneNumber, isLid } = contactDetails(session, message);
  const content = messageText(message.message || {});
  const media = mediaDetails(message.message || {});
  if (!sourceId || (!content && !media)) return;

  const payload = {
    event: 'message.received',
    session_id: session.id,
    message_id: message.key.id,
    from: phoneNumber || sourceId,
    source_id: sourceId,
    phone_number: phoneNumber,
    is_lid: isLid,
    name: message.pushName,
    content,
    timestamp: message.messageTimestamp,
  };
  if (media) {
    const mediaMessage = media.content === message.message ? message : { ...message, message: media.content };
    const buffer = await downloadMediaMessage(mediaMessage, 'buffer', {}, {
      logger,
      // Keep the socket context. Passing the method directly may break media
      // re-upload requests for expired audio/sticker URLs.
      reuploadRequest: mediaToReupload => session.socket.updateMediaMessage(mediaToReupload),
    });
    if (!Buffer.isBuffer(buffer) || !buffer.length) {
      throw new Error('WhatsApp returned an empty media payload');
    }
    if (buffer.length > maxMediaBytes) {
      throw new Error(`Incoming media exceeds the ${maxMediaBytes / 1024 / 1024} MB limit`);
    }
    payload.media = {
      data: buffer.toString('base64'),
      file_type: media.fileType,
      mime_type: media.mimeType,
      file_name: media.fileName,
      is_sticker: media.isSticker,
      is_animated_sticker: media.isAnimatedSticker,
      is_voice_message: media.isVoiceMessage,
    };
  }

  const response = await fetch(session.webhookUrl, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${apiToken}`,
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(`Chatwoot inbound delivery failed with status ${response.status}`);

  logger.info({ session: session.id, sourceId, messageId: message.key.id }, 'Delivered incoming WhatsApp message to Chatwoot');
};

const publicSession = session => ({
  id: session.id,
  status: session.status,
  phone: session.phone,
  qr: session.qr,
  error: session.error,
  webhook_configured: Boolean(session.webhookUrl && session.webhookSecret),
  updated_at: session.updatedAt,
});

const startSession = async session => {
  if (session.isDestroyed) return;

  if (session.socket) {
    try {
      session.socket.ev.removeAllListeners();
      session.socket.end(undefined);
    } catch (_) {}
    session.socket = null;
  }

  const { state, saveCreds } = await useMultiFileAuthState(sessionDirectory(session.id));
  session.phoneNumbers ||= {};
  session.messages ||= new Map();
  const { version } = await fetchLatestBaileysVersion();
  const socket = makeWASocket({
    auth: state,
    version,
    browser: Browsers.ubuntu('Comercial Alvorada'),
    printQRInTerminal: false,
    logger: logger.child({ session: session.id, level: 'warn' }),
    getMessage: async key => session.messages.get(messageCacheKey(key))?.message,
  });
  session.socket = socket;
  session.status = 'connecting';
  session.error = null;
  session.updatedAt = new Date().toISOString();

  socket.ev.on('creds.update', saveCreds);
  socket.ev.on('chats.phoneNumberShare', ({ jid, lid }) => {
    if (session.isDestroyed || !sessions.has(session.id)) return;
    const sourceId = jidUser(lid);
    const phoneNumber = jidUser(jid);
    if (!sourceId || !phoneNumber) return;

    session.phoneNumbers ||= {};
    session.phoneNumbers[sourceId] = phoneNumber;
    persistSessions().catch(error => logger.warn(error));
    publishPhoneNumber(session, sourceId, phoneNumber).catch(error => logger.warn(error));
  });
  socket.ev.on('connection.update', async update => {
    if (session.isDestroyed || !sessions.has(session.id)) return;
    const { connection, lastDisconnect, qr } = update;
    session.updatedAt = new Date().toISOString();

    if (qr) session.qr = await QRCode.toDataURL(qr, { margin: 1, width: 360 });
    if (connection === 'open') {
      session.status = 'connected';
      session.phone = socket.user?.id?.split(':')[0] || null;
      session.qr = null;
    }
    if (connection !== 'close') return;

    const statusCode = lastDisconnect?.error?.output?.statusCode;
    if (statusCode === DisconnectReason.loggedOut || session.isDestroyed) {
      session.status = 'logged_out';
      session.qr = null;
      return;
    }

    session.status = 'reconnecting';
    session.error = lastDisconnect?.error?.message || 'connection closed';
    setTimeout(() => {
      if (session.isDestroyed || !sessions.has(session.id)) return;
      startSession(session).catch(error => logger.error(error));
    }, 3000);
  });
  socket.ev.on('messages.upsert', ({ type, messages }) => {
    if (session.isDestroyed || !sessions.has(session.id)) return;
    messages
      .filter(message => !message.key.remoteJid?.endsWith('@g.us'))
      .forEach(message => rememberMessage(session, message));
    if (!['notify', 'append'].includes(type)) return;
    messages
      .filter(message => !message.key.fromMe && !message.key.remoteJid?.endsWith('@g.us'))
      .forEach(message => publishIncomingMessage(session, message).catch(error => logger.warn(error)));
  });
};

app.get('/health', (_, response) => response.json({ status: 'ok' }));
app.use(authenticate);

app.get('/sessions', (_, response) => response.json([...sessions.values()].filter(s => !s.isDestroyed).map(publicSession)));
app.get('/sessions/:sessionId', (request, response) => {
  const session = sessions.get(request.params.sessionId);
  return session && !session.isDestroyed ? response.json(publicSession(session)) : response.status(404).json({ error: 'not found' });
});
app.post('/sessions', async (request, response, next) => {
  try {
    const { session_id: sessionId, webhook_url: webhookUrl, webhook_secret: webhookSecret } = request.body;
    if (!sessionId) return response.status(422).json({ error: 'invalid session_id' });
    const existing = sessions.get(sessionId);
    if (existing && !existing.isDestroyed) return response.status(422).json({ error: 'duplicate session_id' });
    const session = {
      id: sessionId,
      webhookUrl,
      webhookSecret,
      phoneNumbers: {},
      status: 'starting',
      updatedAt: new Date().toISOString(),
    };
    sessions.set(sessionId, session);
    await persistSessions();
    await startSession(session);
    return response.status(201).json(publicSession(session));
  } catch (error) {
    return next(error);
  }
});
app.post('/sessions/:sessionId/messages', async (request, response, next) => {
  try {
    const session = sessions.get(request.params.sessionId);
    const { to, text, media } = request.body;
    if (!session || session.isDestroyed || session.status !== 'connected') return response.status(409).json({ error: 'session is not connected' });
    const recipient = /^\d{8,20}@(s\.whatsapp\.net|lid)$/.test(String(to)) ? to : `${to}@s.whatsapp.net`;
    if (!/^\d{8,20}@(s\.whatsapp\.net|lid)$/.test(recipient) || (!text?.trim() && !media?.data)) {
      return response.status(422).json({ error: 'to and text or media are required' });
    }
    if (media && Buffer.byteLength(media.data, 'base64') > maxMediaBytes) {
      return response.status(413).json({ error: 'media file is too large' });
    }
    const message = media ? outgoingMediaMessage(media, text) : { text: text.trim() };
    const result = await session.socket.sendMessage(recipient, message);
    rememberMessage(session, result);
    logger.info({ session: session.id, recipient, messageId: result.key.id }, 'Delivered Chatwoot message to WhatsApp');
    return response.status(201).json({ id: result.key.id });
  } catch (error) {
    return next(error);
  }
});
app.put('/sessions/:sessionId/webhook', (request, response) => {
  const session = sessions.get(request.params.sessionId);
  if (!session || session.isDestroyed) return response.status(404).json({ error: 'not found' });
  session.webhookUrl = request.body.webhook_url;
  session.webhookSecret = request.body.webhook_secret;
  persistSessions()
    .then(() => response.json(publicSession(session)))
    .catch(error => response.status(500).json({ error: error.message }));
});
app.delete('/sessions/:sessionId', async (request, response, next) => {
  try {
    const session = sessions.get(request.params.sessionId);
    if (!session) return response.status(404).json({ error: 'not found' });
    session.isDestroyed = true;
    if (session.socket) {
      try {
        session.socket.ev.removeAllListeners();
        session.socket.end(undefined);
      } catch (_) {}
      session.socket = null;
    }
    sessions.delete(session.id);
    await fs.rm(sessionDirectory(session.id), { recursive: true, force: true });
    await persistSessions();
    return response.status(204).end();
  } catch (error) {
    return next(error);
  }
});
app.use((error, _, response, __) => {
  logger.error(error);
  const status = error.type === 'entity.too.large' ? 413 : 500;
  response.status(status).json({ error: status === 413 ? 'media file is too large' : 'internal error' });
});

await fs.mkdir(dataDirectory, { recursive: true });
for (const configuration of await loadPersistedSessions()) {
  const session = {
    ...configuration,
    phoneNumbers: configuration.phoneNumbers || {},
    status: 'starting',
    updatedAt: new Date().toISOString(),
  };
  sessions.set(session.id, session);
  startSession(session).catch(error => logger.error({ error, session: session.id }, 'Could not restore session'));
}
app.listen(port, () => logger.info({ port }, 'Baileys bridge started'));
