const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
require('../assets/business-address.js');
const address = globalThis.BizHuntAddress;
const form = values => new Map(Object.entries(values));
const input = {address_line:'18 Jesus St., Santo Rosario',address_city:' Angeles City ',address_province:'Pampanga'};

test('new addresses retain commas in street and store city and province independently', () => {
  const payload = address.read(form(input));
  assert.deepEqual(payload,{...input,address_city:'Angeles City',location:'18 Jesus St., Santo Rosario, Angeles City, Pampanga'});
  assert.deepEqual(address.parts(payload),['18 Jesus St., Santo Rosario','Angeles City','Pampanga']);
});
test('legacy address is unchanged on unrelated edits, even if incomplete or irregularly spaced', () => {
  for (const location of ['Angeles City, Pampanga','18 Jesus St, Angeles City, Pampanga','No commas','Old street,  Angeles City, Pampanga']) {
    const data = form(Object.fromEntries(address.keys.map((key,i)=>[key,address.parts({location})[i]])));
    assert.deepEqual(address.read(data,{location}),{location});
  }
});
test('changed and new addresses require complete components; city and province cannot contain commas', () => {
  assert.throws(()=>address.read(form({...input,address_province:''})),/separate fields/);
  assert.throws(()=>address.read(form({...input,address_city:'Angeles, Pampanga'})),/separate fields/);
  assert.throws(()=>address.read(form({...input,address_line:'x'.repeat(141)})),/field limits/);
  const old={location:'Old address'};
  assert.throws(()=>address.read(form({address_line:'Changed address'}),old),/separate fields/);
});
test('rendered input values are escaped and new forms make all three fields required', () => {
  const html=address.fields({address_line:'<img src=x>',address_city:'Angeles City',address_province:'Pampanga'},{required:true});
  assert.ok(html.includes('&lt;img src=x&gt;'));
  assert.equal((html.match(/ required/g)||[]).length,3);
  for(const key of address.keys)assert.ok(html.includes(`name="${key}"`));
});
test('weekly summary derives from saved hours, including closed days and legacy short keys', () => {
  const hours={monday:{open:'09:00',close:'18:00'},tue:{closed:true},wednesday:{open:'11:00',close:'20:00'}};
  assert.equal(address.hoursSummary(hours),'Mon 09:00–18:00 · Tue Closed · Wed 11:00–20:00');
  assert.equal(address.hoursSummary({}),'');
  const everyDay=Object.fromEntries(['monday','tuesday','wednesday','thursday','friday','saturday','sunday'].map(day=>[day,{open:'09:00',close:'18:00'}]));
  assert.ok(address.hoursSummary(everyDay).length<=160);
});
test('all four updated pages still parse and load the shared address helper', () => {
  for(const file of ['account/index.html','app/index.html','hub/index.html','founder/index.html']) {
    const page=fs.readFileSync(require('node:path').join(__dirname,'..',file),'utf8');
    assert.ok(page.includes('../assets/business-address.js'));
    for(const match of page.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi))if(match[1].trim())new vm.Script(match[1],{filename:file});
  }
});
test('customer weekly-hours UI ignores legacy description and lists the seven days', () => {
  const page=fs.readFileSync(require('node:path').join(__dirname,'../app/index.html'),'utf8');
  const start=page.indexOf('function businessHoursUI(b)'),end=page.indexOf('function followStats(b)',start);
  const ctx=vm.createContext({todayBusinessHours:b=>b.weekly_hours?.monday,trustBadges:()=>'',esc:String});
  vm.runInContext(page.slice(start,end),ctx);
  const html=vm.runInContext('businessHoursUI({weekly_hours:{monday:{closed:true},tuesday:{open:"09:00",close:"18:00"}},opening_hours:"Stale text"})',ctx);
  assert.ok(html.includes('Closed today'));assert.ok(html.includes('Weekly hours'));assert.ok(html.includes('Sunday'));assert.ok(!html.includes('Stale text'));
});
