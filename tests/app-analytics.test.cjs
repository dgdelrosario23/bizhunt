const {test}=require("node:test");
const assert=require("node:assert/strict");
const fs=require("node:fs");
const vm=require("node:vm");
const path=require("node:path");
const source=fs.readFileSync(path.join(__dirname,"../assets/app-analytics.js"),"utf8");
function simulate({route="/app/",search="",hash="",origin="https://bizhunt.app",consent=null,oldConsent=null,referrer="https://bizhunt.app/account/?email=private@example.com#secret"}={}){
 const values={"bh_analytics_consent_v2":consent,"bh_analytics_consent_v1":oldConsent},scripts=[];let panel,reloads=0;const listeners={};
 function node(){return{style:{},setAttribute(){},addEventListener(n,cb){this[n]=cb},showModal(){this.open=true},close(){this.open=false}}}
 const window={addEventListener(n,cb){listeners[n]=cb}},location={origin,pathname:route,search,hash,reload(){reloads++}};
 const document={referrer,createElement(n){const o=node();if(n==="dialog")panel=o;return o},body:{append(){}},head:{append(s){scripts.push(s)}}};
 const localStorage={getItem(k){return values[k]??null},setItem(k,v){values[k]=v}};
 vm.runInNewContext(source,{window,location,document,localStorage,URL,URLSearchParams});
 return{window,location,values,scripts,panel,choose(v){panel.click({target:{closest(){return{dataset:{choice:v}}}}})},storageEvent(v){values.bh_analytics_consent_v2=v;listeners.storage({key:"bh_analytics_consent_v2",newValue:v})},get reloads(){return reloads},get commands(){return (window.dataLayer||[]).map(x=>Array.from(x))}};
}
for(const route of ["/account/","/app/","/hub/","/communities/","/townhall/"])test("allowed "+route,()=>{const t=simulate({route,consent:"yes"});assert.equal(t.scripts.length,1);assert.match(t.scripts[0].src,/G-KDF528M1Z6$/);assert.equal(t.commands.filter(x=>x[0]==="event"&&x[1]==="page_view").length,1);assert.ok(t.commands.some(x=>x[0]==="config"&&x[2].send_page_view===false));assert.equal(t.commands.find(x=>x[0]==="event")[2].page_location,"https://bizhunt.app"+route)});
for(const route of ["/founder/","/vip/leads/","/communities/verify.html","/emergency/","/","/vip/"])test("excluded "+route,()=>assert.equal(simulate({route,consent:"yes"}).scripts.length,0));
for(const search of ["?token=x","?code=x","?business=uuid","?email=x@y","?access_token=secret"])test("unsafe entry "+search,()=>assert.equal(simulate({search,consent:"yes"}).scripts.length,0));
test("no fragments or nonproduction requests",()=>{assert.equal(simulate({hash:"#access_token=secret",consent:"yes"}).scripts.length,0);assert.equal(simulate({origin:"https://test.example.com",consent:"yes"}).scripts.length,0)});
test("allow only enumerated clean navigation values",()=>{assert.equal(simulate({search:"?section=wallet",consent:"yes"}).scripts.length,1);assert.equal(simulate({search:"?welcome=1",consent:"yes"}).scripts.length,1);assert.equal(simulate({search:"?section=scanner",route:"/hub/",consent:"yes"}).scripts.length,0)});
test("no consent or declined consent means no network",()=>{for(const consent of [null,"no"]){const t=simulate({consent});t.window.bizhuntAnalytics.event("merchant_registration");assert.equal(t.scripts.length,0);assert.equal(t.commands.length,0)}});
test("legacy no retained and legacy yes requires fresh consent",()=>{assert.equal(simulate({oldConsent:"no"}).scripts.length,0);const t=simulate({oldConsent:"yes"});assert.equal(t.scripts.length,0);assert.ok(t.panel.open);t.window.bizhuntAnalytics.screen("wallet_view");t.choose("yes");assert.equal(t.scripts.length,1);assert.equal(t.commands.filter(x=>x[1]==="wallet_view").length,1)});
test("screen events deduplicate and never include record IDs or URL data",()=>{const t=simulate({consent:"yes"});t.window.bizhuntAnalytics.screen("discover_view");t.window.bizhuntAnalytics.screen("discover_view");t.window.bizhuntAnalytics.screen("business_view");t.location.search="?business=PRIVATE-ID";t.window.bizhuntAnalytics.screen("deals_view");t.window.bizhuntAnalytics.event("private@example.com");t.window.bizhuntAnalytics.event("discover_view");assert.equal(t.commands.filter(x=>x[1]==="discover_view").length,1);assert.doesNotMatch(JSON.stringify(t.commands),/PRIVATE-ID|private@example.com|secret/);assert.ok(t.commands.filter(x=>x[0]==="event").every(x=>x[2].page_location==="https://bizhunt.app/app/"))});
test("private parameters cannot be supplied to event API",()=>{const t=simulate({route:"/account/",consent:"yes"});t.window.bizhuntAnalytics.event("login",{email:"secret@example.com"});assert.ok(t.commands.some(x=>x[1]==="login"));assert.doesNotMatch(JSON.stringify(t.commands),/secret@example.com/)});
test("revocation and cross-tab revocation reload",()=>{const t=simulate({consent:"yes"});t.choose("no");assert.equal(t.reloads,1);assert.ok(t.commands.some(x=>x[0]==="consent"&&x[1]==="update"));assert.equal(t.scripts.length,1);const b=simulate({consent:"yes"});b.storageEvent("no");assert.equal(b.reloads,1)});
