(()=>{"use strict";
const key="bh_analytics_consent_v2", previousKey="bh_analytics_consent_v1", id="GTM-56V7CC35";
// Public routes only. Authenticated routes must remain off until the GTM privacy review is complete.
const routes=new Set(["/","/vip/"]);
const events=new Set(["get_started_click","join_bizhunt_click","explore_bizhunt_click","grow_business_click","vip_explore_click","vip_inquiry_submit"]);
let loaded=false, allowed=false;
function read(){try{return localStorage.getItem(key)??(localStorage.getItem(previousKey)==="no"?"no":null)}catch{return null}}
function save(v){try{localStorage.setItem(key,v)}catch{}}
function start(){if(loaded||location.origin!=="https://bizhunt.app"||!routes.has(location.pathname)||location.hash||location.search)return;
loaded=true;window.dataLayer=window.dataLayer||[];function consent(){window.dataLayer.push(arguments)}consent("consent","default",{analytics_storage:"granted",ad_storage:"denied",ad_user_data:"denied",ad_personalization:"denied"});window.dataLayer.push({"gtm.start":Date.now(),event:"gtm.js"});const s=document.createElement("script");s.async=true;s.src="https://www.googletagmanager.com/gtm.js?id="+id;s.referrerPolicy="no-referrer";document.head.append(s)}
function event(name){if(allowed&&loaded&&read()!=="no"&&routes.has(location.pathname)&&!location.search&&events.has(name))window.dataLayer.push({event:name})}
window.bizhuntAnalytics=Object.freeze({event});
if(location.origin!=="https://bizhunt.app"||!routes.has(location.pathname))return;
window.addEventListener("storage",e=>{if(e.key===key&&e.newValue!=="yes"){allowed=false;if(loaded)location.reload()}});
const panel=document.createElement("dialog");panel.setAttribute("aria-label","Analytics preferences");panel.style.cssText="border:1px solid #dce4f4;border-radius:16px;padding:24px;max-width:min(420px,90vw);color:#101a35";panel.innerHTML='<h2 style="margin-top:0">Analytics preferences</h2><p>Allow optional Google Analytics to measure visits, general app screens and successful actions. We do not send account details, form values, QR codes or record IDs in our analytics events. You can change your choice anytime.</p><div style="display:flex;gap:10px;flex-wrap:wrap"><button type="button" class="btn" data-choice="yes">Allow analytics</button><button type="button" class="btn light" data-choice="no">Decline</button></div>';document.body.append(panel);
const button=document.getElementById("bhAnalyticsPreferences");button?.addEventListener("click",()=>{if(!panel.open)panel.showModal()});
panel.addEventListener("click",e=>{const v=e.target.closest("[data-choice]")?.dataset.choice;if(!v)return;save(v);allowed=v==="yes";panel.close();if(allowed)start();else if(loaded){window.dataLayer.push(["consent","update",{analytics_storage:"denied"}]);location.reload()}});
document.addEventListener("click",e=>{const a=e.target.closest("a[data-analytics-event]");if(a)event(a.dataset.analyticsEvent)});
allowed=read()==="yes";if(allowed)start();else if(read()===null)panel.showModal();
})();
