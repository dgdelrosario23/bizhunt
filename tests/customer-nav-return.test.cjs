const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Run the live navigation helpers in an isolated context, without app startup or a network.
const page = fs.readFileSync(path.join(__dirname,'../app/index.html'),'utf8');
function sourceBetween(first,next){
  const start=page.indexOf(first),end=page.indexOf(next,start);
  assert.ok(start>=0&&end>start,`Missing navigation source: ${first}`);
  return page.slice(start,end);
}
function harness(overrides={}){
  const events=[], frames=[], location={href:'https://example.invalid/app/?section=discover'};
  const window={scrollY:100,scrollTo:(...args)=>{
    window.scrollY=typeof args[0]==='object'?args[0].top:(args[1]??0);
    events.push(['scroll',window.scrollY]);
  }};
  const interactive={};
  let expanded=false;
  const ctx=vm.createContext({
    URL, location, window,
    history:{replaceState:(_state,_title,url)=>{location.href=new URL(url,location.href).href;events.push(['url',url]);}},
    requestAnimationFrame:fn=>{frames.push(fn);},
    document:{querySelector:()=>expanded?{}:null,querySelectorAll:()=>[],getElementById:id=>interactive[id]??null},
    $:id=>interactive[id]??null,
    tab:'discover',detailId:null,businessDetailTab:'gallery',discoverScrollRestore:200,
    dealsReturnFromProfile:false,profileSectionOpen:null,explorerOpen:false,
    activityFilter:'all',communityTarget:null,communityListId:null,profileReturnFromCommunity:false,
    category:'Café',neighborhood:'All',sortMode:'recommended',openOnly:true,mobileOnly:false,nearbyOnly:false,
    discoverMapOpen:false,discoverGalleryOpen:true,discoverRadius:5,moreFiltersOpen:true,
    walletView:'vouchers',walletLoyaltySort:'closest',dealsView:'community',dealsFilter:'all',dealsSort:'ending',
    user:{id:'demo'},customerCacheUserId:'demo',customerCacheUpdatedAt:Date.now(),
    qr:null,expires:null,qrCampaignId:'',qrAction:'stamp',notificationFocus:null,
    render:()=>{events.push(['render']);expanded=false;ctx.syncBusinessUrl();},
    load:async()=>{events.push(['load']);ctx.render();},
    clear:()=>events.push(['clear']),
    stopStampQrWatch:()=>events.push(['stop-watch']),
    ...overrides
  });
  vm.runInContext(sourceBetween('let discoverSearch=','const customerPerfEnabled'),ctx);
  vm.runInContext(sourceBetween('function syncBusinessUrl(','function render('),ctx);
  return {ctx,window,location,events,interactive,run:code=>vm.runInContext(code,ctx),
    flush:()=>{while(frames.length)frames.shift()();},setExpanded:value=>{expanded=value;}};
}
const section=h=>new URL(h.location.href).searchParams.get('section');
const count=(h,type)=>h.events.filter(e=>e[0]===type).length;

test('tapping the current root is a true no-op',async()=>{
  const h=harness();
  h.run('discoverSearch="coffee"');
  await h.ctx.navigateMainSection('discover');h.flush();
  assert.deepEqual(h.events,[]);
  assert.equal(h.window.scrollY,100);
  assert.equal(h.run('discoverSearch'),'coffee');
});
test('Discover detail returns to list with prior scroll, filters, and search preserved',async()=>{
  const h=harness({detailId:'demo-business',businessDetailTab:'menu'});
  h.location.href='https://example.invalid/app/?section=discover&business=demo-business&businessTab=menu';
  h.run('discoverSearch="coffee";mainNavScroll.discover=420');
  await h.ctx.navigateMainSection('discover');h.flush();
  assert.equal(h.ctx.detailId,null);
  assert.equal(h.ctx.businessDetailTab,'gallery');
  assert.equal(h.run('discoverSearch'),'coffee');
  assert.equal(h.ctx.category,'Café');assert.equal(h.ctx.openOnly,true);assert.equal(h.ctx.discoverGalleryOpen,true);
  assert.equal(h.ctx.discoverRadius,5);assert.equal(h.ctx.moreFiltersOpen,true);
  assert.equal(h.window.scrollY,420);
  assert.equal(section(h),'discover');
  assert.equal(new URL(h.location.href).searchParams.has('business'),false);
  assert.equal(new URL(h.location.href).searchParams.has('businessTab'),false);
  assert.equal(count(h,'render'),1);assert.equal(count(h,'load'),0);
});
test('Profile and explorer child screens close without changing the parent section',async()=>{
  for(const child of [{profileSectionOpen:'settings'},{explorerOpen:true}]){
    const h=harness({tab:'profile',...child});
    h.location.href='https://example.invalid/app/?section=profile';
    h.run('mainNavScroll.profile=180');
    await h.ctx.navigateMainSection('profile');h.flush();
    assert.equal(h.ctx.profileSectionOpen,null);assert.equal(h.ctx.explorerOpen,false);
    assert.equal(h.ctx.tab,'profile');assert.equal(h.window.scrollY,180);
    assert.equal(count(h,'render'),1);assert.equal(count(h,'load'),0);
  }
});
test('Wallet activity history returns to Wallet and preserves the selected view and sort',async()=>{
  const h=harness({tab:'activity',activityFilter:'reward'});
  h.run('activityReturnSection="wallet";mainNavScroll.wallet=380');
  assert.equal(h.ctx.mainNavSection(),'wallet');
  await h.ctx.navigateMainSection('wallet');h.flush();
  assert.equal(h.ctx.tab,'wallet');assert.equal(section(h),'wallet');
  assert.equal(h.ctx.walletView,'vouchers');assert.equal(h.ctx.walletLoyaltySort,'closest');
  assert.equal(h.window.scrollY,380);assert.equal(count(h,'render'),1);assert.equal(count(h,'load'),0);
});
test('Profile community child returns to Profile rather than a stale Discover detail',async()=>{
  const h=harness({tab:'community',communityListId:'test-list',communityTarget:'test-member',profileReturnFromCommunity:true});
  h.run('communityReturnSection="profile";mainNavScroll.profile=96');
  assert.equal(h.ctx.mainNavSection(),'profile');
  await h.ctx.navigateMainSection('profile');h.flush();
  assert.equal(h.ctx.tab,'profile');assert.equal(h.ctx.communityListId,null);assert.equal(h.ctx.communityTarget,null);
  assert.equal(h.window.scrollY,96);assert.equal(section(h),'profile');
});
test('switching roots remembers independent scroll positions and preserves section choices',async()=>{
  const h=harness();h.window.scrollY=380;
  h.run('mainNavScroll.deals=640;discoverSearch="coffee"');
  await h.ctx.navigateMainSection('deals');h.flush();
  assert.equal(h.ctx.tab,'deals');assert.equal(h.window.scrollY,640);assert.equal(section(h),'deals');
  assert.equal(h.run('mainNavScroll.discover'),380);assert.equal(h.ctx.dealsView,'community');
  h.window.scrollY=690;
  await h.ctx.navigateMainSection('discover');h.flush();
  assert.equal(h.ctx.tab,'discover');assert.equal(h.window.scrollY,380);assert.equal(section(h),'discover');
  assert.equal(h.run('mainNavScroll.deals'),690);assert.equal(h.run('discoverSearch'),'coffee');
});
test('leaving My QR stops the stamp watcher without changing an issued code or requesting a new one',async()=>{
  const h=harness({tab:'qr',qr:'mock-code',expires:'2099-01-01',qrCampaignId:'mock-campaign',qrAction:'stamp'});
  await h.ctx.navigateMainSection('profile');h.flush();
  assert.equal(count(h,'stop-watch'),1);assert.equal(h.ctx.qr,'mock-code');assert.equal(h.ctx.expires,'2099-01-01');
  assert.equal(h.ctx.qrCampaignId,'mock-campaign');assert.equal(h.ctx.qrAction,'stamp');assert.equal(h.ctx.tab,'profile');
  assert.equal(count(h,'load'),0);
});
test('entering Wallet from a different root still refreshes data',async()=>{
  const h=harness();
  await h.ctx.navigateMainSection('wallet');h.flush();
  assert.equal(h.ctx.tab,'wallet');assert.equal(count(h,'load'),1);assert.equal(h.ctx.walletView,'vouchers');
});
test('an expanded inline deal returns to collapsed root at its recorded pre-expansion scroll',async()=>{
  const h=harness({tab:'deals'});h.window.scrollY=270;h.ctx.rememberMainScroll('deals');
  h.setExpanded(true);h.window.scrollY=430;
  await h.ctx.navigateMainSection('deals');h.flush();
  assert.equal(h.ctx.tab,'deals');assert.equal(count(h,'render'),1);assert.equal(count(h,'load'),0);
  assert.equal(h.ctx.dealsView,'community');assert.equal(h.window.scrollY,270);
});
test('a business opened from Deals returns to Deals root with previous scroll',async()=>{
  const h=harness({detailId:'deal-business',businessDetailTab:'promos',dealsReturnFromProfile:true});
  h.run('mainNavScroll.deals=530');
  await h.ctx.navigateMainSection('deals');h.flush();
  assert.equal(h.ctx.tab,'deals');assert.equal(h.ctx.detailId,null);assert.equal(h.ctx.dealsReturnFromProfile,false);
  assert.equal(h.ctx.dealsView,'community');assert.equal(h.window.scrollY,530);
});
test('rapid navigation ignores obsolete scroll restoration',async()=>{
  const h=harness();h.run('mainNavScroll.profile=200;mainNavScroll.deals=600');
  await h.ctx.navigateMainSection('profile');
  await h.ctx.navigateMainSection('deals');
  h.flush();
  assert.equal(h.ctx.tab,'deals');assert.equal(h.window.scrollY,600);
  assert.equal(h.events.filter(e=>e[0]==='scroll'&&e[1]===200).length,0);
});
