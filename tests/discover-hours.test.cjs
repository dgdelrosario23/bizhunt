const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {rank,sort} = require('../assets/discover-ranking.js');

// Execute only the relevant pure UI functions; never initialize the customer app.
const page = fs.readFileSync(path.join(__dirname,'../app/index.html'),'utf8');
const sliceFunctions = (first,next) => {
  const start=page.indexOf(`function ${first}(`),end=page.indexOf(`function ${next}(`,start);
  assert.ok(start>=0 && end>start,`Missing source functions: ${first}, ${next}`);
  return page.slice(start,end);
};
const mockDate = {day:'monday',date:'2026-11-23',minute:600};
const ctx = vm.createContext({
  localBusinessDate:()=>mockDate,
  campaigns:[],
  esc:v=>String(v).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;'),
  shopEmoji:()=> '☕',
  photoURL:p=>p,
  discoverImageAttrs:()=> '',
  ratingSummary:()=> 'No reviews yet'
});
vm.runInContext(sliceFunctions('todayBusinessHours','trustBadges'),ctx);
vm.runInContext(sliceFunctions('compactShopHours','shopUI'),ctx);

const basic = {id:'sample',name:'Sample café',location:'Angeles City',business_type:'place'};
const shop = (hours,overrides={})=>({...basic,weekly_hours:{monday:hours},...overrides});
const normalize = v=>v.replace(/[\u00a0\u202f]/g,' ');
const display = business => normalize(ctx.compactShopUI(business));
function expectHours(business,status,label){
  const html=display(business);
  const [word,range] = label.split(' · ');
  const expected=`<span class="compact-shop-line compact-shop-hours">🕒 <span class="compact-shop-hours--${status}">${word}</span>${range?' · '+range:''}</span>`;
  assert.ok(html.includes(expected),html);
  assert.ok(!html.includes('Invalid Date'),html);
  assert.ok(html.includes('No reviews yet'));
  assert.ok(html.includes('data-business="sample"'));
}

test('open store shows a readable 12-hour schedule and textual open status',()=>{
  expectHours(shop({open:'09:30',close:'17:00'}),'open','Open now · 9:30 AM–5:00 PM');
});
test('outside operating hours displays a visible closed status and schedule',()=>{
  expectHours(shop({open:'11:00',close:'20:00'}),'closed','Closed now · 11:00 AM–8:00 PM');
  expectHours(shop({open:'06:00',close:'10:00'}),'closed','Closed now · 6:00 AM–10:00 AM');
});
test('explicit closed day remains closed today without an invented time range',()=>{
  expectHours(shop({closed:true}),'closed','Closed today');
});
test('unknown hours remain neutral and do not fall back to stale descriptions',()=>{
  const business={...basic,opening_hours:'Open from 24 hours daily'};
  expectHours(business,'unknown','Hours unavailable');
  assert.ok(!display(business).includes('24 hours daily'));
});
test('service without a schedule asks customers to contact for availability',()=>{
  expectHours({...basic,business_type:'service'},'unknown','Contact for availability');
  expectHours(shop({open:'oops',close:'17:00'},{business_type:'service'}),'unknown','Contact for availability');
  expectHours(shop({open:'09:30',close:'17:00'},{business_type:'service'}),'open','Open now · 9:30 AM–5:00 PM');
});
test('midnight and noon have distinct AM and PM labels',()=>{
  expectHours(shop({open:'00:00',close:'12:00'}),'open','Open now · 12:00 AM–12:00 PM');
});
test('partial, malformed, out-of-range, and equal schedules do not claim a closed status',()=>{
  for(const hours of [{open:'09:00'},{open:'24:00',close:'17:00'},{open:'09:60',close:'17:00'},{open:'oops',close:'17:00'},{open:'09:00',close:'09:00'}]){
    expectHours(shop(hours),'unknown','Hours unavailable');
  }
});
test('short day keys and special-date overrides retain existing precedence',()=>{
  expectHours({...basic,weekly_hours:{mon:{open:'09:30',close:'17:00'}}},'open','Open now · 9:30 AM–5:00 PM');
  expectHours(shop({open:'09:30',close:'17:00'},{special_hours:{[mockDate.date]:{closed:true}}}),'closed','Closed today');
});
test('rendering hours does not mutate businesses or affect ranking',()=>{
  const a=shop({open:'09:30',close:'17:00'}),b={...basic,id:'other',name:'Another café'};
  const metrics={review_count:3,average_rating:4,follower_count:7};
  const snapshot=structuredClone([a,b]);
  const before=rank(a,metrics),order=sort([a,b],()=>metrics).map(x=>x.id);
  display(a);display(b);
  assert.deepEqual([a,b],snapshot);
  assert.deepEqual(rank(a,metrics),before);
  assert.deepEqual(sort([a,b],()=>metrics).map(x=>x.id),order);
});
