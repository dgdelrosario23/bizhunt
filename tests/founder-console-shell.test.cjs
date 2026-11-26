const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const page = fs.readFileSync(path.join(__dirname,'../founder/index.html'),'utf8');
const sectionKeys=['overview','users','businesses','listings','moderation','logs'];
const panelIds=['content','recordManagement','curatedEditor','moderation','claimQueue','missingPlaceModeration'];
const expectedPanels={overview:['content'],users:['recordManagement'],businesses:['recordManagement'],listings:['curatedEditor'],moderation:['moderation','claimQueue','missingPlaceModeration'],logs:['recordManagement']};
const expectedLoads={overview:['overview'],users:['records:users'],businesses:['records:businesses'],listings:['listings'],moderation:['moderation','claims','missing'],logs:['logs']};

// Lightweight mock DOM: run real navigation code without executing page startup or network calls.
function harness(initial='overview'){
  const nodes=new Map(),events=[],listeners={},classes=new Set(),location={href:`https://example.invalid/founder/?section=${initial}`,search:`?section=${initial}`};
  const attrList=raw=>Object.fromEntries([...raw.matchAll(/([\w-]+)\s*=\s*["']([^"']*)["']/g)].map(m=>[m[1],m[2]]));
  function node(id){
    if(nodes.has(id))return nodes.get(id);
    const attrs=new Map(),obj={id,hidden:false,textContent:'',markup:'',buttons:[],dataset:{},
      setAttribute:(key,value)=>attrs.set(key,String(value)),
      getAttribute:key=>attrs.get(key)??null,
      focus:()=>events.push('focus:'+id),
      querySelectorAll:selector=>selector.includes('data-founder-section')?obj.buttons.filter(b=>b.dataset.founderSection):[],
      classList:{toggle:(key,force)=>{if(force===undefined)force=!classes.has(key);if(force)classes.add(key);else classes.delete(key);return force;},contains:key=>classes.has(key),add:(...keys)=>keys.forEach(key=>classes.add(key)),remove:(...keys)=>keys.forEach(key=>classes.delete(key))}
    };
    Object.defineProperty(obj,'innerHTML',{get:()=>obj.markup,set:markup=>{
      obj.markup=markup;obj.buttons=[];
      for(const match of markup.matchAll(/<button\b([^>]*)>/g)){
        const attrs=attrList(match[1]),button=attrs.id?node(attrs.id):{dataset:{},attrs:{},setAttribute(k,v){this.attrs[k]=String(v)},getAttribute(k){return this.attrs[k]??null}};
        if(attrs['data-founder-section'])button.dataset.founderSection=attrs['data-founder-section'];
        for(const [key,value] of Object.entries(attrs))button.setAttribute(key,value);
        obj.buttons.push(button);
      }
      if(markup.includes('id="founderMoreMenu"'))node('founderMoreMenu').hidden=true;
    }});
    nodes.set(id,obj);return obj;
  }
  [...panelIds,'founderSidebar','founderMobileNav','founderPageTitle','founderPageSubtitle','founderSidebarToggle','founderSidebarLinks','founderMoreMenu','founderMoreButton'].forEach(node);
  const document={body:node('body'),getElementById:node,addEventListener:(name,fn)=>listeners[name]=fn,querySelectorAll:selector=>selector.includes('data-founder-section')?['founderSidebar','founderMobileNav'].flatMap(id=>node(id).buttons.filter(b=>b.dataset.founderSection)):[]};
  const history={pushState:(_state,_title,url)=>{const next=new URL(url,location.href);location.href=next.href;location.search=next.search;events.push('history');}};
  const ctx=vm.createContext({document,$:node,URL,URLSearchParams,history,location,window:{addEventListener:(name,fn)=>listeners[name]=fn},
    managementType:'users',managementOffset:50,managementSearch:'prior',
    loadFounderOverview:async()=>events.push('overview'),
    loadModeration:async()=>events.push('moderation'),loadClaims:async()=>events.push('claims'),
    loadMissingPlaceModeration:async()=>events.push('missing'),loadCuratedEditor:async()=>events.push('listings'),
    loadFounderLogs:async()=>events.push('logs'),loadRecordManagement:async()=>events.push('records:'+ctx.managementType)
  });
  const start=page.indexOf('const founderSections=['),end=page.indexOf('async function loadClaims()',start);
  assert.ok(start>=0&&end>start,'Missing founder navigation source');
  vm.runInContext(page.slice(start,end),ctx);
  const visible=()=>panelIds.filter(id=>!node(id).hidden);
  return {ctx,node,events,classes,location,listeners,visible,run:code=>vm.runInContext(code,ctx)};
}
function routeButtons(h,where){return h.node(where).buttons.filter(b=>b.dataset.founderSection);}
function buttonFor(h,where,key){const result=routeButtons(h,where).find(b=>b.dataset.founderSection===key);assert.ok(result,`${key} missing from ${where}`);return result;}

test('all six founder routes keep their existing visible panels, loaders, and URL keys',async()=>{
  for(const key of sectionKeys){
    const h=harness();await h.ctx.openFounderSection(key);
    assert.equal(new URL(h.location.href).searchParams.get('section'),key);
    assert.deepEqual(h.visible().sort(),expectedPanels[key].slice().sort());
    assert.deepEqual(h.events.filter(x=>x!=='history').sort(),expectedLoads[key].slice().sort());
    assert.ok(h.node('founderPageTitle').textContent);assert.ok(h.node('founderPageSubtitle').textContent);
  }
});
test('known section deep links work and invalid values fall back to Overview',async()=>{
  for(const key of sectionKeys){const h=harness(key);assert.equal(h.ctx.founderSectionFromUrl(),key);}
  const h=harness('unknown');assert.equal(h.ctx.founderSectionFromUrl(),'overview');
  await h.ctx.openFounderSection('unknown');assert.deepEqual(h.visible(),['content']);
});
test('desktop grouped navigation retains all six actions and accessible labels',async()=>{
  const h=harness();await h.ctx.openFounderSection('businesses');
  const sidebar=h.node('founderSidebar'),buttons=routeButtons(h,'founderSidebar');
  assert.deepEqual(buttons.map(b=>b.dataset.founderSection),sectionKeys);
  for(const label of ['Workspace','Management','Operations'])assert.ok(sidebar.markup.includes(label),label);
  assert.ok(sidebar.markup.includes('founder-nav-group'));
  for(const button of buttons){assert.ok(button.getAttribute('aria-label'));assert.ok(button.getAttribute('title'));}
  assert.ok(h.classes.has('founder-sidebar-ready'));
  assert.equal(buttonFor(h,'founderSidebar','businesses').getAttribute('aria-current'),'page');
  assert.equal(buttonFor(h,'founderSidebar','users').getAttribute('aria-current')==='page',false);
  await buttonFor(h,'founderSidebar','users').onclick();
  assert.deepEqual(h.visible(),['recordManagement']);assert.ok(h.events.includes('records:users'));
});
test('desktop collapse toggles layout and accessible button state, and survives route rerender',async()=>{
  const h=harness();await h.ctx.openFounderSection('overview');
  const toggle=h.node('founderSidebarToggle');
  assert.equal(toggle.getAttribute('aria-expanded'),'true');
  assert.equal(toggle.getAttribute('aria-controls'),'founderSidebarLinks');
  assert.equal(h.classes.has('founder-sidebar-collapsed'),false);
  toggle.onclick();assert.equal(h.classes.has('founder-sidebar-collapsed'),true);
  assert.equal(toggle.getAttribute('aria-expanded'),'false');
  assert.match(toggle.getAttribute('aria-label'),/expand/i);
  await h.ctx.openFounderSection('logs');
  assert.equal(h.classes.has('founder-sidebar-collapsed'),true);
  assert.equal(h.node('founderSidebarToggle').getAttribute('aria-expanded'),'false');
  h.node('founderSidebarToggle').onclick();
  assert.equal(h.classes.has('founder-sidebar-collapsed'),false);
  assert.equal(h.node('founderSidebarToggle').getAttribute('aria-expanded'),'true');
  assert.match(h.node('founderSidebarToggle').getAttribute('aria-label'),/collapse/i);
});
test('mobile navigation keeps four top-level buttons plus More, whose actions close after selecting',async()=>{
  const h=harness();await h.ctx.openFounderSection('overview');
  assert.deepEqual(routeButtons(h,'founderMobileNav').map(b=>b.dataset.founderSection),sectionKeys);
  const more=h.node('founderMoreButton'),menu=h.node('founderMoreMenu');
  assert.equal(menu.hidden,true);assert.equal(more.getAttribute('aria-expanded'),'false');
  assert.equal(more.getAttribute('aria-controls'),'founderMoreMenu');
  more.onclick();assert.equal(menu.hidden,false);assert.equal(more.getAttribute('aria-expanded'),'true');
  await buttonFor(h,'founderMobileNav','moderation').onclick();
  assert.deepEqual(h.visible().sort(),expectedPanels.moderation.slice().sort());
  assert.equal(menu.hidden,true);assert.equal(h.node('founderMoreButton').getAttribute('aria-expanded'),'false');
  assert.equal(buttonFor(h,'founderMobileNav','moderation').getAttribute('aria-current'),'page');
  assert.equal(buttonFor(h,'founderMobileNav','overview').getAttribute('aria-current')==='page',false);
});
test('Escape closes the mobile More menu and restores focus to its button',async()=>{
  const h=harness();await h.ctx.openFounderSection('overview');
  const more=h.node('founderMoreButton'),menu=h.node('founderMoreMenu');
  more.onclick();menu.onkeydown({key:'Enter'});assert.equal(menu.hidden,false);
  menu.onkeydown({key:'Escape'});assert.equal(menu.hidden,true);
  assert.equal(more.getAttribute('aria-expanded'),'false');assert.ok(h.events.includes('focus:founderMoreButton'));
});
test('responsive shell keeps collapse layout desktop-only and removes the empty sidebar before sign in',()=>{
  const css=page.match(/<style id="founder-console-shell-style">([\s\S]*?)<\/style>/)?.[1];
  assert.ok(css);
  assert.match(css,/body\.founder-sidebar-collapsed\{--founder-sidebar-width:76px\}/);
  assert.match(css,/\.founder-sidebar:empty,\.founder-mobile-nav:empty\{display:none\}/);
  const desktop=css.slice(css.indexOf('@media(min-width:801px){'),css.indexOf('@media(min-width:801px) and'));
  const mobile=css.slice(css.indexOf('@media(max-width:800px){'));
  assert.match(desktop,/\.founder-workspace\{margin-left:var\(--founder-sidebar-width\)/);
  assert.match(desktop,/body:not\(\.founder-sidebar-ready\) \.founder-workspace\{margin-left:auto/);
  assert.ok(desktop.includes('.founder-sidebar-collapsed .founder-nav-label'));
  assert.ok(!mobile.includes('--founder-sidebar-width'));
  assert.ok(!mobile.includes('.founder-sidebar-collapsed'));
  assert.match(page,/@media\(max-width:800px\)\{\s*\.founder-sidebar\{display:none\}/);
});
test('browser back/forward selects the URL section without adding another history entry',async()=>{
  const h=harness();await h.ctx.openFounderSection('users');
  h.location.search='?section=listings';h.location.href='https://example.invalid/founder/?section=listings';
  await h.listeners.popstate();assert.deepEqual(h.visible(),['curatedEditor']);
  assert.equal(h.events.filter(x=>x==='history').length,1);
});
test('management search and pagination reset only when switching user/business record types',async()=>{
  const h=harness();await h.ctx.openFounderSection('users');
  assert.equal(h.ctx.managementOffset,50);assert.equal(h.ctx.managementSearch,'prior');
  await h.ctx.openFounderSection('businesses');
  assert.equal(h.ctx.managementOffset,0);assert.equal(h.ctx.managementSearch,'');
  h.ctx.managementOffset=20;h.ctx.managementSearch='coffee';await h.ctx.openFounderSection('businesses');
  assert.equal(h.ctx.managementOffset,20);assert.equal(h.ctx.managementSearch,'coffee');
});
test('founder shell retains rendering surfaces, authorization and existing action wiring',()=>{
  for(const id of ['founderSidebar','founderMobileNav','founderPageTitle','founderPageSubtitle','content','recordManagement','curatedEditor','moderation','claimQueue','missingPlaceModeration'])assert.ok(page.includes(`id="${id}"`)||page.includes(`el.id="${id}"`),id);
  for(const rpc of ['founder_dashboard','bizhunt_founder_overview_v2','bizhunt_founder_records','bizhunt_founder_logs','bizhunt_founder_curated_records','bizhunt_founder_missing_queue','bizhunt_moderation_queue','founder_community_claims','bizhunt_founder_challenge','bizhunt_founder_mutate','bizhunt_founder_curated_challenge','bizhunt_founder_curated_mutate','bizhunt_founder_business_save','bizhunt_founder_curated_menu_save','founder_review_community_claim'])assert.ok(page.includes(`db.rpc("${rpc}"`),rpc);
  assert.ok(page.includes('db.auth.getUser()'));assert.ok(page.includes('Sign in required'));
  assert.ok(page.includes('href="../app/"'));assert.ok(page.includes('href="../vip/leads/"'));
  assert.ok(page.includes('aria-label="Founder sections"'));assert.ok(page.includes('aria-label="Founder mobile sections"'));
});
