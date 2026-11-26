const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const page=fs.readFileSync(path.join(__dirname,'../founder/index.html'),'utf8');
const slice=(first,next)=>{
  const start=page.indexOf(first),end=page.indexOf(next,start);
  assert.ok(start>=0&&end>start,`Missing founder UI source: ${first}`);return page.slice(start,end);
};
const escapeHtml=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]);
const flush=()=>new Promise(resolve=>setImmediate(resolve));

// Run existing management render functions against synthetic records only; no application init.
function harness(records=[],section='users'){
  const nodes=new Map(),calls=[],events=[],location={href:'https://example.invalid/founder/?section='+section};
  const response={data:records,error:null},queued=[];
  function element(attrs={}){
    const el={attrs:{...attrs},dataset:{},children:[],hidden:'hidden' in attrs,disabled:'disabled' in attrs,value:attrs.value||'',markup:'',textContent:'',
      querySelectorAll(selector){return this.children.filter(x=>matches(x,selector));},querySelector(selector){return this.querySelectorAll(selector)[0]??null;},
      setAttribute(key,value){this.attrs[key]=String(value)},getAttribute(key){return this.attrs[key]??null;},
      scrollIntoView(){events.push(['scroll',attrs.id]);},focus(){events.push(['focus',attrs.id]);},classList:{toggle(){},add(){},remove(){}}
    };
    for(const [key,value] of Object.entries(attrs))if(key.startsWith('data-'))el.dataset[key.slice(5).replace(/-([a-z])/g,(_,c)=>c.toUpperCase())]=value;
    Object.defineProperty(el,'innerHTML',{get:()=>el.markup,set:markup=>{
      el.markup=markup;el.children=[];
      for(const match of markup.matchAll(/<(?:button|form|select|input|div|section|details|span|label)\b([^>]*)>/gi)){
        const parsed={},raw=match[1];
        for(const a of raw.matchAll(/([\w-]+)\s*=\s*["']([^"']*)["']/g))parsed[a[1]]=a[2];
        for(const key of ['hidden','disabled'])if(new RegExp('(?:^|\\s)'+key+'(?:\\s|$)').test(raw))parsed[key]='';
        const child=element(parsed);el.children.push(child);if(parsed.id)nodes.set(parsed.id,child);
      }
    }});return el;
  }
  function matches(el,selector){return selector.split(',').some(part=>{const match=part.match(/\[([\w-]+)(?:=["']([^"']*)["'])?\]/);return match&&match[1] in el.attrs&&(match[2]===undefined||el.attrs[match[1]]===match[2]);});}
  function node(id){if(!nodes.has(id))nodes.set(id,element({id}));return nodes.get(id);}
  const ctx=vm.createContext({
    $:node,esc:escapeHtml,URL,location,history:{pushState:(_state,_title,url)=>events.push(['history',String(url)])},
    document:{getElementById:node},navigator:{clipboard:{writeText:async value=>events.push(['copy',value])}},
    FormData:class {constructor(target){this.fields=target.fields||{};}get(key){return this.fields[key]??null;}},
    db:{rpc:async(name,args)=>{calls.push({name,args});return queued.length?queued.shift():response;},from:name=>({select:fields=>({range:(start,end)=>({order:async column=>{calls.push({name,args:{fields,start,end,column}});return {data:[],error:null};}})})}),storage:{from:()=>({getPublicUrl:p=>({data:{publicUrl:'https://example.invalid/'+p}})})}},
    founderNavigationToken:0,founderActiveSection:section,renderFounderNavigation:()=>events.push(['nav']),openFounderSection:async id=>events.push(['section',id]),
    openFounderBusinessEditor:record=>events.push(['business-editor',record.id]),
    confirmRecordAction:()=>{throw Error('Mutation not allowed in UI tests');},
    showCuratedEditor:id=>events.push(['listing-editor',id]),showCuratedCreate:()=>events.push(['create-listing']),
    notice:(message,bad)=>events.push(['notice',message,bad]),
  });
  vm.runInContext(slice('let managementType=','async function saveCuratedRecordWithPhotos('),ctx);
  vm.runInContext(slice('async function loadFounderLogs(','const curatedDays='),ctx);
  vm.runInContext(slice('const curatedDays=','function showCuratedCreate('),ctx);
  vm.runInContext(`managementType=${JSON.stringify(section==='businesses'?'businesses':'users')}`,ctx);
  return {ctx,node,calls,events,response,run:code=>vm.runInContext(code,ctx),setRecords:rows=>response.data=rows,queue:result=>queued.push(result)};
}
const user=(id,name)=>({id,display_name:name,email:`${id}@example.invalid`,username:id,bio:''});
const business=(id,name,extra={})=>({id,name,category:'Café',location:'Pampanga',owner_id:'owner',...extra});
const listing=(id,name,extra={})=>({id,name,category:'Café',location:'Pampanga',...extra});

test('user records retain search, page size, layout, ID copy and edit/delete controls',async()=>{
  const h=harness([{...user('u1','Test User'),email_confirmed_at:'2026-01-01'}]);await h.ctx.loadRecordManagement();
  const html=h.node('recordManagement').innerHTML;
  assert.ok(html.includes('Test User'));assert.ok(html.includes('u1@example.invalid'));
  assert.ok(html.includes('Email confirmed'));assert.match(html,/manage-records-list/);assert.equal(h.run('curatedView'),'list');
  for(const id of ['manageSearch','manageView','managePageSize','manageRows'])assert.ok(html.includes(`id="${id}"`),id);
  for(const attr of ['data-copy-record-id','data-record-edit','data-record-delete','data-record-form','data-record-cancel'])assert.ok(html.includes(`${attr}="u1"`),attr);
  const copy=h.node('recordManagement').querySelector('[data-copy-record-id]');await copy.onclick();
  assert.ok(h.events.some(event=>event[0]==='copy'&&event[1]==='u1'));
  const edit=h.node('recordManagement').querySelector('[data-record-edit]'),form=h.node('recordManagement').querySelector('[data-record-form]');
  assert.equal(form.hidden,true);edit.onclick();assert.equal(form.hidden,false);
  h.node('recordManagement').querySelector('[data-record-cancel]').onclick();assert.equal(form.hidden,true);
});
test('management search and page-size changes reset offset while retaining submitted criteria',async()=>{
  const h=harness([user('u1','Test User')]);h.run('managementOffset=20');await h.ctx.loadRecordManagement();
  const form=h.node('manageSearch');form.fields={search:'  Darwin  '};form.onsubmit({preventDefault(){},target:form});await flush();
  let req=h.calls.at(-1);assert.equal(req.args.p_search,'Darwin');assert.equal(req.args.p_offset,0);
  h.run('managementOffset=20');h.node('managePageSize').onchange({target:{value:'20'}});await flush();
  req=h.calls.at(-1);assert.equal(req.args.p_limit,20);assert.equal(req.args.p_offset,0);assert.equal(req.args.p_search,'Darwin');
  h.node('manageView').onchange({target:{value:'list'}});await flush();
  assert.equal(h.run('managementView'),'list');assert.ok(h.node('recordManagement').innerHTML.includes('manage-records-list'));
});
test('registered businesses keep claimed/unclaimed statuses and open the existing editor',async()=>{
  const h=harness([business('b1','Claimed Café'),business('b2','Unclaimed Café',{owner_id:null,is_unclaimed:true})],'businesses');
  await h.ctx.loadRecordManagement();const html=h.node('recordManagement').innerHTML;
  assert.match(html,/founder-record-badge[^>]*>Claimed/);assert.match(html,/founder-record-badge[^>]*>Unclaimed/);
  h.node('recordManagement').querySelector('[data-business-open="b1"]').onclick();
  assert.ok(h.events.some(event=>event[0]==='business-editor'&&event[1]==='b1'));
  const unclaimed=h.node('recordManagement').querySelector('[data-management="unclaimed_businesses"]');unclaimed.onclick();await flush();
  assert.equal(h.calls.at(-1).args.p_type,'unclaimed_businesses');assert.equal(h.calls.at(-1).args.p_offset,0);
});
test('status badges reflect explicit existing fields only and do not invent missing statuses',()=>{
  const h=harness(),badge=(row,type)=>h.ctx.founderRecordStatusUI(row,type);
  assert.match(badge({email_confirmed_at:'2026-01-01'},'users'),/Email confirmed/);
  assert.match(badge({email_confirmed_at:null},'users'),/Email not confirmed/);
  assert.equal(badge({email:'u@example.invalid'},'users'),'');
  assert.match(badge({owner_id:'owner',verification_status:'verified'},'businesses'),/Claimed[\s\S]*Verified business/);
  assert.match(badge({owner_id:null,verification_status:'unverified'},'businesses'),/Unclaimed[\s\S]*Not verified/);
  assert.match(badge({is_unclaimed:true},'unclaimed_businesses'),/Unclaimed/);
  assert.equal(badge({},'businesses'),'');
  assert.match(badge({archived_at:'2026-01-01'},'curated'),/Archived/);
  assert.match(badge({archived_at:null},'curated'),/Not archived/);
  assert.equal(badge({},'curated'),'');
});
test('record pagination uses the selected page size and keeps Previous/Next controls',async()=>{
  const h=harness(Array.from({length:10},(_,i)=>user(`u${i}`,`User ${i}`)));await h.ctx.loadRecordManagement();
  assert.equal(h.node('managePrev').disabled,true);assert.equal(h.node('manageNext').disabled,false);
  h.node('manageNext').onclick();await flush();assert.equal(h.calls.at(-1).args.p_offset,10);
  h.node('managePrev').onclick();await flush();assert.equal(h.calls.at(-1).args.p_offset,0);
});
test('management loading state, filtered-empty state, and read failure are distinct',async()=>{
  const h=harness();let resolve;h.queue(new Promise(done=>{resolve=done}));
  const loading=h.ctx.loadRecordManagement();let html=h.node('recordManagement').innerHTML;
  assert.match(html,/founder-management-state/);assert.match(html,/role="status"/);assert.match(html,/loading/i);
  resolve({data:[],error:null});await loading;html=h.node('recordManagement').innerHTML;
  assert.match(html,/founder-management-state/);assert.match(html,/no .*record|no .*user|no .*account/i);
  const baseline=html;
  h.run('managementSearch="nonexistent"');await h.ctx.loadRecordManagement();html=h.node('recordManagement').innerHTML;
  assert.match(html,/no .*match/i);assert.notEqual(html,baseline);assert.ok(html.includes('manageSearch'));
  h.run('managementOffset=10');await h.ctx.loadRecordManagement();html=h.node('recordManagement').innerHTML;
  assert.match(html,/No records on this page/);assert.equal(h.node('managePrev').disabled,false);
  h.response.error={message:'Synthetic read unavailable'};await h.ctx.loadRecordManagement();html=h.node('recordManagement').innerHTML;
  assert.ok(html.includes('Synthetic read unavailable'));assert.ok(!html.includes('Loading'));
});
test('server paginated records show the current range without fabricating a total',async()=>{
  const h=harness([user('u21','User 21'),user('u22','User 22')]);h.run('managementOffset=20');await h.ctx.loadRecordManagement();
  const html=h.node('recordManagement').innerHTML;
  assert.match(html,/founder-management-toolbar/);assert.match(html,/founder-management-summary/);
  assert.match(html,/21\s*[–-]\s*22/);assert.match(html,/Page 3/);assert.doesNotMatch(html,/21\s*[–-]\s*22\s+of\s+\d/);
  assert.equal(h.node('managePrev').disabled,false);assert.equal(h.node('manageNext').disabled,true);
});
test('newer ordinary search results win over older pending requests',async()=>{
  const h=harness();let resolveOlder;
  h.queue(new Promise(resolve=>{resolveOlder=resolve}));h.run('managementSearch="old"');
  const oldRequest=h.ctx.loadRecordManagement();
  h.queue({data:[user('new','New Result')],error:null});h.run('managementSearch="new"');await h.ctx.loadRecordManagement();
  assert.ok(h.node('recordManagement').innerHTML.includes('New Result'));
  resolveOlder({data:[user('old','Old Result')],error:null});await oldRequest;
  assert.ok(h.node('recordManagement').innerHTML.includes('New Result'));assert.ok(!h.node('recordManagement').innerHTML.includes('Old Result'));
});
test('a stale management response cannot overwrite another section after navigation',async()=>{
  const h=harness();let finish;h.queue(new Promise(resolve=>{finish=resolve}));const pending=h.ctx.loadRecordManagement();
  h.ctx.founderNavigationToken++;h.ctx.founderActiveSection='logs';h.node('recordManagement').innerHTML='Synthetic log section';
  finish({data:[user('old','Old User')],error:null});await pending;
  assert.equal(h.node('recordManagement').innerHTML,'Synthetic log section');
});
test('curated listing search matches category/name/location and keeps selected entry and editor action',()=>{
  const h=harness();h.ctx.fixture=[listing('a','Mango Café'),listing('b','Luna Restaurant',{category:'Restaurant',location:'Angeles'}),listing('c','Old Café',{archived_at:'2026-01-01'})];
  h.run('curatedEditorRecords=fixture;curatedEditorActive=fixture[0];curatedSearch="mango";renderCuratedListings()');
  let html=h.node('curatedListingResults').innerHTML;
  assert.ok(html.includes('Mango Café'));assert.ok(!html.includes('Luna Restaurant'));assert.ok(html.includes('is-selected'));
  h.node('curatedListingResults').querySelector('[data-curated-id="a"]').onclick();
  assert.ok(h.events.some(event=>event[0]==='listing-editor'&&event[1]==='a'));
  h.run('curatedSearch="angeles";renderCuratedListings()');html=h.node('curatedListingResults').innerHTML;
  assert.ok(html.includes('Luna Restaurant'));assert.ok(!html.includes('Mango Café'));
  h.run('curatedSearch="café";curatedEditorActive=null;renderCuratedListings()');html=h.node('curatedListingResults').innerHTML;
  assert.ok(html.includes('Archived'));assert.ok(!html.includes('Luna Restaurant'));
});
test('curated listing toolbar preserves Add listing, search, view and page size handlers',async()=>{
  const h=harness([listing('l1','Café 1'),listing('l2','Restaurant 2',{category:'Restaurant'})]);await h.ctx.loadCuratedEditor();
  const toolbar=h.node('curatedEditorBody').innerHTML;
  for(const id of ['newCuratedListing','curatedSearch','curatedView','curatedPageSize'])assert.ok(toolbar.includes(`id="${id}"`),id);
  h.node('newCuratedListing').onclick();assert.ok(h.events.some(event=>event[0]==='create-listing'));
  h.node('curatedSearch').oninput({target:{value:'restaurant'}});
  let html=h.node('curatedListingResults').innerHTML;assert.ok(html.includes('Restaurant 2'));assert.ok(!html.includes('Café 1'));
  h.node('curatedView').onchange({target:{value:'tiles'}});
  assert.match(h.node('curatedListingResults').innerHTML,/curated-results-tiles/);
  h.node('curatedPageSize').onchange({target:{value:'20'}});assert.equal(h.run('curatedPageSize'),20);assert.equal(h.run('curatedPage'),0);
  assert.equal(h.run('curatedSearch'),'restaurant');
});
test('curated pagination clamps to available pages and list/tiles changes preserve filters',()=>{
  const h=harness();h.ctx.fixture=Array.from({length:15},(_,i)=>listing(`l${i}`,`Café ${i}`));
  h.run('curatedEditorRecords=fixture;curatedPageSize=10;curatedPage=99;curatedSearch="café";renderCuratedListings()');
  assert.equal(h.run('curatedPage'),1);assert.equal(h.node('curatedNext').disabled,true);
  let html=h.node('curatedListingResults').innerHTML;assert.ok(html.includes('11–15 of 15 listings'));assert.ok(html.includes('Page 2 of 2'));
  h.node('curatedPrev').onclick();assert.equal(h.run('curatedPage'),0);
  h.run('curatedView="list";renderCuratedListings()');html=h.node('curatedListingResults').innerHTML;
  assert.ok(html.includes('curated-results-list'));assert.equal(h.run('curatedSearch'),'café');
});
test('curated no-result state avoids a fictitious page and keeps paging controls unavailable',()=>{
  const h=harness();h.ctx.fixture=[listing('l1','Café')];h.run('curatedEditorRecords=fixture;curatedSearch="no match";renderCuratedListings()');
  const html=h.node('curatedListingResults').innerHTML;assert.match(html,/founder-management-state/);assert.match(html,/no .*match/i);
  assert.doesNotMatch(html,/Page 1 of 1/);assert.equal(h.node('curatedPrev').hidden,true);assert.equal(h.node('curatedNext').hidden,true);
});
test('audit log snapshots remain read-only and retain Back to records navigation',async()=>{
  const h=harness([{action:'update',entity_type:'businesses',created_at:'2026-01-01',actor_id:'sample-admin',entity_id:'sample-record',before_data:{name:'Before'},after_data:{name:'After'}}],'logs');
  await h.ctx.loadFounderLogs();const html=h.node('recordManagement').innerHTML;
  assert.equal(h.calls.at(-1).name,'bizhunt_founder_logs');assert.equal(h.calls.at(-1).args.p_limit,50);
  assert.match(html,/UPDATE/);assert.match(html,/Before/);assert.match(html,/After/);
  assert.doesNotMatch(html,/data-record-(edit|delete)/);h.node('backRecords').onclick();
  assert.ok(h.events.some(event=>event[0]==='section'&&event[1]==='users'));
});
