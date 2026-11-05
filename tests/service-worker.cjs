const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = readFileSync(__dirname + '/../service-worker.js', 'utf8');
function setup({offline=false, status=200, putFails=false, cached}={}) {
  const handlers = {}, writes = [], deleted = [], fetched = [];
  const cache = {addAll: async () => {}, put: async (req, res) => {
    if(putFails) throw Error('quota');
    writes.push(req.url);
  }, match: async () => cached};
  vm.runInNewContext(source, {
    URL, Set,
    self: {registration:{scope:'https://example.com/PadulGestion/'},
      addEventListener:(type, fn) => handlers[type]=fn,
      skipWaiting(){}, clients:{claim:async()=>{}}},
    caches:{open:async()=>cache, keys:async()=>['amr-pro-v4','amr-pro-v5','other-app'],
      delete:async key=>deleted.push(key)},
    fetch:async req=>{fetched.push(req.url); if(offline) throw Error('offline');
      return new Response('asset', {status});},
  });
  async function request(url, method='GET') {
    let response;
    const waits=[];
    handlers.fetch({request:{url,method}, waitUntil:p=>waits.push(p), respondWith:p=>response=p});
    try {return response ? await response : undefined;}
    finally {await Promise.all(waits);}
  }
  return {handlers,writes,deleted,fetched,request};
}
(async()=>{
  const asset='https://example.com/PadulGestion/app.js';
  let t=setup();
  for(const url of ['https://project.supabase.co/rest/v1/pacientes','https://example.com/PadulGestion/api/pacientes'])
    assert.equal(await t.request(url),undefined);
  assert.equal(await t.request(asset,'POST'),undefined);
  assert.equal(t.fetched.length,0);
  assert.equal((await t.request(asset)).status,200);
  assert.deepEqual(t.writes,[asset]);
  console.log('PASS: only listed GET assets intercepted and cached');
  t=setup({status:500});
  assert.equal((await t.request(asset)).status,500);
  assert.equal(t.writes.length,0);
  console.log('PASS: HTTP errors never overwrite cached assets');
  const fallback=new Response('cached');
  t=setup({offline:true,cached:fallback});
  assert.equal(await t.request(asset),fallback);
  t=setup({offline:true});
  await assert.rejects(t.request(asset),/offline/);
  console.log('PASS: offline fallback and uncached network failure');
  t=setup({putFails:true});
  assert.equal((await t.request(asset)).status,200);
  console.log('PASS: storage failure does not break network response');
  t=setup();
  let activation;
  t.handlers.activate({waitUntil:p=>activation=p});
  await activation;
  assert.deepEqual(t.deleted,['amr-pro-v4']);
  console.log('PASS: activation preserves current and unrelated caches');
})().catch(error=>{console.error(error);process.exitCode=1;});

