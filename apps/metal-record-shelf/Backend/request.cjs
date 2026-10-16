'use strict';

const TIMEOUT_MS = 20_000;
const PAGE_SIZE = 200;
const MAX_ALBUMS = 2000;
const MAX_LIKED_SONGS = 100000;
const SONG_BATCH_SIZE = 200;

class PublicError extends Error {}

function fail(message) { throw new PublicError(message); }
function requiredString(value, message, max = 1024) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) fail(message);
  return value.trim();
}
function albumRecord(value) {
  if (!value || typeof value !== 'object' || !/^\d+$/.test(String(value.id))) {
    fail('网易云返回的专辑资料不完整，请稍后重试。');
  }
  const artists = Array.isArray(value.artists) ? value.artists :
    Array.isArray(value.artist) ? value.artist : value.artist ? [value.artist] : [];
  const artwork = typeof value.picUrl === 'string' && /^https?:\/\//i.test(value.picUrl) ? value.picUrl.replace(/^http:\/\//i, 'https://') : null;
  return {
    id: String(value.id),
    title: typeof value.name === 'string' ? value.name : '未命名专辑',
    artist: artists.map(x => typeof x?.name === 'string' ? x.name : '').filter(Boolean).join(' / ') || '未知音乐人',
    artwork,
  };
}
async function call(api, endpoint, args, allowedCodes = [200]) {
  if (typeof api[endpoint] !== 'function') fail('音乐连接组件不完整，请重新安装此应用。');
  let response;
  try {
    response = await api[endpoint]({ ...args, timeout: TIMEOUT_MS });
  } catch (error) {
    const code = error?.body?.code ?? error?.response?.data?.code;
    if (code === 301 || code === 302) fail('网易云登录已过期，请重新扫码连接。');
    fail('暂时无法连接网易云，请检查网络后重试。');
  }
  const body = response?.body;
  if (!body || typeof body !== 'object') fail('网易云暂时没有返回有效资料，请稍后重试。');
  if (body.code === 301 || body.code === 302) fail('网易云登录已过期，请重新扫码连接。');
  if (!allowedCodes.includes(body.code)) fail('网易云暂时无法完成此操作，请稍后重试。');
  return body;
}

function validID(value) { return /^\d{1,20}$/.test(String(value)) && !/^0+$/.test(String(value)); }
function requireCookie(request) { return requiredString(request.cookie, '请先扫码连接网易云。', 65536); }
async function subscribedPage(request, api) {
  const cookie = requireCookie(request);
  const rawOffset = request.offset ?? 0;
  const offset = typeof rawOffset === 'string' && /^\d+$/.test(rawOffset) ? Number(rawOffset) : rawOffset;
  if (!Number.isInteger(offset) || offset < 0 || offset >= MAX_ALBUMS || offset % PAGE_SIZE !== 0) fail('收藏专辑分页参数无效。');
  const body = await call(api, 'album_sublist', { cookie, limit: PAGE_SIZE, offset, timestamp: Date.now() });
  if (!Array.isArray(body.data) || body.data.length > PAGE_SIZE) fail('网易云返回的收藏列表不完整，请稍后重试。');
  const albums = [...new Map(body.data.map(source => { const record = albumRecord(source); return [record.id, record]; })).values()];
  const more = typeof body.hasMore === 'boolean' ? body.hasMore : typeof body.more === 'boolean' ? body.more :
    Number.isFinite(body.count) ? offset + body.data.length < body.count : body.data.length >= PAGE_SIZE;
  if (more && body.data.length === 0) fail('网易云收藏列表分页中断，请稍后重试。');
  const truncated = more && offset + PAGE_SIZE >= MAX_ALBUMS;
  return { albums, nextOffset: more && !truncated ? offset + PAGE_SIZE : null, truncated };
}

async function perform(request, api) {
  if (!request || typeof request !== 'object' || Array.isArray(request)) fail('请求格式不正确。');
  switch (request.op) {
    case 'album': {
      const id = String(request.id ?? '');
      if (!/^\d{1,20}$/.test(id)) fail('请输入有效的网易云专辑编号。');
      const body = await call(api, 'album', { id });
      return { album: albumRecord(body.album) };
    }
    case 'playTarget': {
      const id = String(request.id ?? '');
      if (!validID(id)) fail('请输入有效的网易云专辑编号。');
      const cookie = request.cookie === undefined ? undefined : requireCookie(request);
      const body = await call(api, 'album', { id, ...(cookie ? { cookie } : {}), timestamp: Date.now() });
      if (!Array.isArray(body.songs)) fail('暂时无法读取专辑曲目，请稍后重试。');
      const first = body.songs[0];
      if (!first || !validID(first.id) || typeof first.name !== 'string' || !first.name.trim()) fail('这张专辑暂时没有可交给客户端播放的首曲。');
      return { songID: String(first.id), title: first.name };
    }
    case 'qrKey': {
      const keyBody = await call(api, 'login_qr_key', { timestamp: Date.now() });
      const key = requiredString(keyBody.data?.unikey, '暂时无法生成登录二维码，请重试。', 512);
      const qrBody = await call(api, 'login_qr_create', { key, qrimg: false });
      const url = requiredString(qrBody.data?.qrurl, '暂时无法生成登录二维码，请重试。', 4096);
      if (!/^https?:\/\//i.test(url)) fail('网易云返回了无效的登录二维码，请重试。');
      return { key, url };
    }
    case 'qrCheck': {
      const key = requiredString(request.key, '登录二维码无效，请重新生成。', 512);
      const body = await call(api, 'login_qr_check', { key, timestamp: Date.now() }, [800, 801, 802, 803]);
      const messages = { 800: '二维码已过期，请重新生成。', 801: '等待扫码', 802: '请在网易云音乐中确认登录', 803: '连接成功' };
      const result = { code: body.code, message: messages[body.code] };
      if (body.code === 803) result.cookie = requiredString(body.cookie, '登录确认尚未完成，请重新扫码。', 65536);
      return result;
    }
    case 'libraryStart': {
      const cookie = requireCookie(request);
      const account = await call(api, 'user_account', { cookie, timestamp: Date.now() });
      const uid = account.account?.id ?? account.profile?.userId;
      if (!validID(uid)) fail('无法确认网易云登录账户，请重新扫码连接。');
      const likes = await call(api, 'likelist', { cookie, uid: String(uid), timestamp: Date.now() });
      if (!Array.isArray(likes.ids) || likes.ids.some(id => !validID(id))) fail('网易云返回的喜欢歌曲列表不完整，请稍后重试。');
      const ids = [...new Set(likes.ids.map(String))];
      return { likedSongIDs: ids.slice(0, MAX_LIKED_SONGS), likedSongCount: ids.length, truncated: ids.length > MAX_LIKED_SONGS };
    }
    case 'subscribedPage': return subscribedPage(request, api);
    case 'likedAlbums': {
      const cookie = requireCookie(request);
      const sourceIDs = typeof request.ids === 'string' ? (request.ids ? request.ids.split(',') : []) : request.ids;
      if (!Array.isArray(sourceIDs) || sourceIDs.length > SONG_BATCH_SIZE || sourceIDs.some(id => !validID(id))) fail('喜欢歌曲批次无效，每批最多200首。');
      const ids = [...new Set(sourceIDs.map(String))];
      if (!ids.length) return { albums: [], requestedCount: 0, resolvedSongCount: 0, missingSongCount: 0, skippedAlbumCount: 0 };
      const body = await call(api, 'song_detail', { cookie, ids: ids.join(','), timestamp: Date.now() });
      if (!Array.isArray(body.songs)) fail('网易云返回的歌曲资料不完整，请稍后重试。');
      const requested = new Set(ids), resolved = new Set(), albums = new Map();
      let skippedAlbumCount = 0;
      for (const song of body.songs) {
        const id = String(song?.id);
        if (!requested.has(id) || resolved.has(id)) continue;
        resolved.add(id);
        if (!validID(song.al?.id) || typeof song.al?.name !== 'string' || !song.al.name.trim()) { skippedAlbumCount++; continue; }
        const record = albumRecord({ ...song.al, artists: song.ar });
        if (!albums.has(record.id)) albums.set(record.id, record);
      }
      return { albums: [...albums.values()], requestedCount: ids.length, resolvedSongCount: resolved.size,
        missingSongCount: ids.length - resolved.size, skippedAlbumCount };
    }
    case 'subscribed': {
      const cookie = requiredString(request.cookie, '请先扫码连接网易云。', 65536);
      const albums = [];
      const seen = new Set();
      let truncated = false;
      for (let offset = 0; offset < MAX_ALBUMS; offset += PAGE_SIZE) {
        const body = await call(api, 'album_sublist', { cookie, limit: PAGE_SIZE, offset, timestamp: Date.now() });
        if (!Array.isArray(body.data)) fail('网易云返回的收藏列表不完整，请稍后重试。');
        for (const source of body.data) {
          const record = albumRecord(source);
          if (!seen.has(record.id) && albums.length < MAX_ALBUMS) {
            seen.add(record.id);
            albums.push(record);
          }
        }
        const more = typeof body.hasMore === 'boolean' ? body.hasMore :
          typeof body.more === 'boolean' ? body.more :
          Number.isFinite(body.count) ? offset + body.data.length < body.count : body.data.length >= PAGE_SIZE;
        if (!more || body.data.length === 0) break;
        if (offset + PAGE_SIZE >= MAX_ALBUMS) truncated = true;
      }
      return { albums, truncated };
    }
    default:
      fail('不支持此音乐操作。');
  }
}

async function run(request, api, timeoutMs = TIMEOUT_MS) {
  let timer;
  try {
    return await Promise.race([
      perform(request, api),
      new Promise((_, reject) => { timer = setTimeout(() => reject(new PublicError('连接网易云超时，请检查网络后重试。')), timeoutMs); }),
    ]);
  } catch (error) {
    return { error: error instanceof PublicError ? error.message : '音乐资料处理失败，请稍后重试。' };
  } finally {
    clearTimeout(timer);
  }
}

module.exports = { run };

if (require.main === module) {
  // The bridge has a strict one-request/one-JSON contract. Third-party diagnostic
  // logs are suppressed so neither stdout nor stderr can expose API responses.
  for (const name of ['log', 'info', 'debug', 'warn', 'error', 'trace']) console[name] = () => {};
  let input = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => {
    input += chunk;
    if (input.length > 131072) {
      process.stdout.write(JSON.stringify({ error: '请求内容过大。' }), () => process.exit(0));
      process.stdin.destroy();
    }
  });
  process.stdin.on('end', async () => {
    let result;
    try {
      const request = JSON.parse(input);
      const api = require('@neteasecloudmusicapienhanced/api');
      result = await run(request, api);
    } catch {
      result = { error: '音乐连接组件无法启动，或请求格式不正确。' };
    }
    process.stdout.write(JSON.stringify(result), () => process.exit(0));
  });
}
