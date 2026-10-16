'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { run } = require('./request.cjs');
const ok = body => ({ body: { code: 200, ...body } });
const album = id => ({ id, name: `Album ${id}`, artists: [{ name: 'Artist' }], picUrl: 'https://example.com/cover.jpg', cookie: 'private' });

test('public album is normalized to safe fields', async () => {
  const result = await run({ op: 'album', id: '12' }, { album: async q => { assert.equal(q.id, '12'); return ok({ album: album(12), token: 'private' }); } });
  assert.deepEqual(result, { album: { id: '12', title: 'Album 12', artist: 'Artist', artwork: 'https://example.com/cover.jpg' } });
});
test('invalid requests never call an endpoint', async () => {
  for (const request of [null, [], { op: 'anything' }, { op: 'album', id: '../1' }, { op: 'subscribed' }]) {
    assert.ok((await run(request, new Proxy({}, { get() { throw new Error('must not call'); } }))).error);
  }
});
test('QR key uses QR creation without image data', async () => {
  assert.deepEqual(await run({ op: 'qrKey' }, {
    login_qr_key: async () => ok({ data: { unikey: 'testkey', secret: 'private' } }),
    login_qr_create: async q => { assert.equal(q.qrimg, false); assert.equal(q.key, 'testkey'); return ok({ data: { qrurl: 'https://music.163.com/login?codekey=testkey', qrimg: 'private' } }); },
  }), { key: 'testkey', url: 'https://music.163.com/login?codekey=testkey' });
});
test('QR polling reveals cookie only after authorization', async () => {
  for (const code of [800, 801, 802, 803]) {
    const result = await run({ op: 'qrCheck', key: 'test' }, { login_qr_check: async () => ({ body: { code, message: 'raw sensitive response', cookie: 'secret-cookie', profile: { token: 'private' } } }) });
    assert.equal(result.code, code);
    assert.equal(Object.hasOwn(result, 'cookie'), code === 803);
    assert.equal(JSON.stringify(result).includes('raw sensitive'), false);
    assert.equal(JSON.stringify(result).includes('profile'), false);
  }
});
test('subscriptions paginate in order and remove duplicate IDs', async () => {
  const offsets = [];
  const result = await run({ op: 'subscribed', cookie: 'credential' }, { album_sublist: async q => {
    offsets.push(q.offset); assert.equal(q.limit, 200); assert.equal(q.cookie, 'credential');
    return ok({ data: q.offset ? [album(2), album(3)] : [album(1), album(2)], hasMore: q.offset === 0 });
  } });
  assert.deepEqual(offsets, [0, 200]); assert.deepEqual(result.albums.map(x => x.id), ['1', '2', '3']); assert.equal(result.truncated, false);
  assert.equal(JSON.stringify(result).includes('credential'), false);
});
test('subscriptions enforce 2000 item upper bound', async () => {
  const result = await run({ op: 'subscribed', cookie: 'secret' }, { album_sublist: async q => ok({ data: Array.from({ length: 200 }, (_, i) => album(q.offset + i + 1)), hasMore: true }) });
  assert.equal(result.albums.length, 2000); assert.equal(result.truncated, true);
});
test('errors are friendly and never reveal upstream details', async () => {
  for (const api of [
    { album: async () => { throw new Error('cookie=secret and raw body'); } },
    { album: async () => ({ body: { code: 500, message: 'secret' } }) },
    { album: async () => ok({ album: {} }) },
  ]) {
    const result = await run({ op: 'album', id: '1' }, api);
    assert.equal(typeof result.error, 'string'); assert.equal(JSON.stringify(result).includes('secret'), false);
  }
  const expired = await run({ op: 'subscribed', cookie: 'secret' }, { album_sublist: async () => ({ body: { code: 301 } }) });
  assert.match(expired.error, /过期/);
});
test('whole request timeout bounds hanging endpoints', async () => {
  const result = await run({ op: 'album', id: '1' }, { album: () => new Promise(() => {}) }, 10);
  assert.match(result.error, /超时/);
});

test('HTTP artwork is normalized to HTTPS for macOS ATS', async () => {
  const result = await run({ op: 'album', id: '12' }, { album: async () => ok({ album: { ...album(12), picUrl: 'http://p1.music.126.net/cover.jpg' } }) });
  assert.equal(result.album.artwork, 'https://p1.music.126.net/cover.jpg');
});

test('library start identifies signed-in account and returns all distinct liked IDs, not first nine', async () => {
  const result = await run({ op: 'libraryStart', cookie: 'private-cookie' }, {
    user_account: async q => { assert.equal(q.cookie, 'private-cookie'); return ok({ account: { id: 42 }, profile: { userId: 99 }, secret: 'private-cookie' }); },
    likelist: async q => { assert.equal(q.uid, '42'); return ok({ ids: [...Array.from({ length: 401 }, (_, i) => i + 1), 1], cookie: 'private-cookie' }); },
  });
  assert.equal(result.likedSongCount, 401); assert.equal(result.likedSongIDs.length, 401); assert.equal(result.likedSongIDs.at(-1), '401');
  assert.equal(result.truncated, false); assert.equal(JSON.stringify(result).includes('private-cookie'), false);
});
test('empty likes is a valid complete library; unknown identity and invalid IDs fail explicitly', async () => {
  assert.deepEqual(await run({ op: 'libraryStart', cookie: 'secret' }, {
    user_account: async () => ok({ profile: { userId: 1 } }), likelist: async () => ok({ ids: [] }),
  }), { likedSongIDs: [], likedSongCount: 0, truncated: false });
  for (const ids of [undefined, [1, null], ['oops']]) {
    const result = await run({ op: 'libraryStart', cookie: 'secret' }, { user_account: async () => ok({ account: { id: 1 } }), likelist: async () => ok({ ids }) });
    assert.match(result.error, /不完整/);
  }
  assert.match((await run({ op: 'libraryStart', cookie: 'secret' }, { user_account: async () => ok({}) })).error, /账户/);
});
test('liked song batches resolve more than nine albums across batches and merge with subscriptions by album ID', async () => {
  const all = Array.from({ length: 401 }, (_, i) => String(i + 1));
  const api = { song_detail: async q => {
    assert.equal(q.cookie, 'secret'); const ids = q.ids.split(','); assert.ok(ids.length <= 200);
    return ok({ songs: ids.map(id => ({ id: Number(id), al: { id: Math.ceil(Number(id) / 2), name: `Album ${Math.ceil(Number(id) / 2)}`, picUrl: 'http://example.com/a.jpg' }, ar: [{ name: 'Artist' }], secret: 'secret' })) });
  } };
  const batches = [];
  for (let i = 0; i < all.length; i += 200) batches.push(await run({ op: 'likedAlbums', cookie: 'secret', ids: all.slice(i, i + 200).join(',') }, api));
  assert.deepEqual(batches.map(x => x.requestedCount), [200, 200, 1]);
  assert.ok(batches.every(x => x.missingSongCount === 0 && x.skippedAlbumCount === 0));
  const subscribed = await run({ op: 'subscribedPage', cookie: 'secret', offset: '0' }, { album_sublist: async () => ok({ data: [album(1), album(999)], hasMore: false }) });
  const merged = new Map([...subscribed.albums, ...batches.flatMap(x => x.albums)].map(a => [a.id, a]));
  assert.equal(merged.size, 202); assert.equal(merged.get('201').artwork, 'https://example.com/a.jpg');
  assert.equal(JSON.stringify(batches).includes('secret'), false);
});
test('liked album batches explicitly count missing songs and invalid albums without inventing records', async () => {
  const result = await run({ op: 'likedAlbums', cookie: 'secret', ids: ['1', '2', '3', '4'] }, { song_detail: async () => ok({ songs: [
    { id: 1, al: { id: 10, name: 'One' }, ar: [{ name: 'A' }] },
    { id: 1, al: { id: 10, name: 'One' } },
    { id: 2, al: { id: 0, name: '' } },
    { id: 3, al: { id: 11 } },
    { id: 99, al: { id: 99, name: 'Unrequested' } },
  ] }) });
  assert.equal(result.requestedCount, 4); assert.equal(result.resolvedSongCount, 3); assert.equal(result.missingSongCount, 1); assert.equal(result.skippedAlbumCount, 2);
  assert.deepEqual(result.albums.map(x => x.id), ['10']);
});
test('liked batches enforce strict limit and IDs, with zero calls for empty batch', async () => {
  const api = new Proxy({}, { get() { throw new Error('no calls'); } });
  assert.deepEqual(await run({ op: 'likedAlbums', cookie: 'secret', ids: '' }, api), { albums: [], requestedCount: 0, resolvedSongCount: 0, missingSongCount: 0, skippedAlbumCount: 0 });
  for (const ids of [Array(201).fill('1'), '1,', '1,2x', ['0'], null]) assert.ok((await run({ op: 'likedAlbums', cookie: 'secret', ids }, api)).error);
});
test('liked endpoint failure and malformed body remain failures rather than an empty successful sync', async () => {
  for (const endpoint of [async () => { throw new Error('secret-cookie'); }, async () => ok({ songs: null }), async () => ({ body: { code: 301, cookie: 'secret-cookie' } })]) {
    const result = await run({ op: 'likedAlbums', cookie: 'secret-cookie', ids: '1' }, { song_detail: endpoint });
    assert.ok(result.error); assert.equal(Object.hasOwn(result, 'albums'), false); assert.equal(JSON.stringify(result).includes('secret-cookie'), false);
  }
});
test('subscription page exposes continuation, validates pagination, and signals truncation', async () => {
  const api = { album_sublist: async q => ok({ data: [album(q.offset + 1)], hasMore: true }) };
  assert.equal((await run({ op: 'subscribedPage', cookie: 'secret', offset: '0' }, api)).nextOffset, 200);
  const final = await run({ op: 'subscribedPage', cookie: 'secret', offset: 1800 }, api);
  assert.equal(final.truncated, true); assert.equal(final.nextOffset, null);
  for (const offset of [-1, 'oops', 1, 2000]) assert.ok((await run({ op: 'subscribedPage', cookie: 'secret', offset }, api)).error);
  assert.ok((await run({ op: 'subscribedPage', cookie: 'secret' }, { album_sublist: async () => ok({ data: [], hasMore: true }) })).error);
});
test('very large likes signal truncation rather than pretending all IDs were fetched', async () => {
  const result = await run({ op: 'libraryStart', cookie: 'secret' }, {
    user_account: async () => ok({ account: { id: 1 } }), likelist: async () => ok({ ids: Array.from({ length: 100001 }, (_, i) => i + 1) }),
  });
  assert.equal(result.truncated, true); assert.equal(result.likedSongCount, 100001); assert.equal(result.likedSongIDs.length, 100000);
});
test('subscription count pagination ends at exact and partial boundaries without dropping or inventing a page', async () => {
  for (const count of [0, 199, 200, 201, 400, 401, 2000, 2001]) {
    const offsets = [], records = []; let offset = 0, truncated = false;
    while (offset !== null) {
      offsets.push(offset);
      const page = await run({ op: 'subscribedPage', cookie: 'secret', offset: String(offset) }, {
        album_sublist: async q => ok({ count, data: Array.from({ length: Math.min(200, Math.max(0, count - q.offset)) }, (_, i) => album(q.offset + i + 1)) }),
      });
      assert.equal(page.error, undefined); records.push(...page.albums); offset = page.nextOffset; truncated = page.truncated;
    }
    assert.equal(records.length, Math.min(count, 2000)); assert.equal(new Set(records.map(x => x.id)).size, records.length);
    assert.equal(offsets.length, Math.max(1, Math.ceil(Math.min(count, 2000) / 200))); assert.equal(truncated, count > 2000);
  }
});
test('subscription explicit completion flags override heuristic full-page continuation', async () => {
  for (const completion of [{ hasMore: false }, { more: false }]) {
    const result = await run({ op: 'subscribedPage', cookie: 'secret' }, { album_sublist: async () => ok({ data: Array.from({ length: 200 }, (_, i) => album(i + 1)), ...completion }) });
    assert.equal(result.nextOffset, null); assert.equal(result.truncated, false);
  }
});
test('play target returns only the real first track ID and title from the requested album', async () => {
  const result = await run({ op: 'playTarget', id: '12' }, { album: async q => {
    assert.equal(q.id, '12'); assert.equal(Object.hasOwn(q, 'cookie'), false);
    return ok({ songs: [{ id: 347230, name: 'First song', secret: 'private' }, { id: 88, name: 'Second' }], cookie: 'secret' });
  } });
  assert.deepEqual(result, { songID: '347230', title: 'First song' });
  assert.equal(JSON.stringify(result).includes('secret'), false);
});
test('play target supports explicit session, rejects invalid or empty first tracks and never downloads audio', async () => {
  const calls = [];
  const api = { album: async q => { calls.push('album'); assert.equal(q.cookie, 'secret'); return ok({ songs: [{ id: 23, name: 'Real song' }] }); }, song_url: async () => { throw new Error('must not resolve audio'); } };
  assert.equal((await run({ op: 'playTarget', id: '1', cookie: 'secret' }, api)).songID, '23'); assert.deepEqual(calls, ['album']);
  for (const songs of [undefined, [], [{ id: 0, name: 'Invalid' }], [{ id: 1 }]]) assert.ok((await run({ op: 'playTarget', id: '1' }, { album: async () => ok({ songs }) })).error);
  assert.ok((await run({ op: 'playTarget', id: '../1' }, {})).error);
});
