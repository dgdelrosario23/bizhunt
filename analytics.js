(()=>{"use strict";
const key="bh_analytics_consent_v1", id="GTM-56V7CC35";
let loaded=false, allowed=false;
function read(){try{return localStorage.getItem(key)}catch{return null}}
function save(v){try{localStorage.setItem(key,v)}catch{}}
function start(){if(loaded||location.pathname!=="/"||location.hash||location.search)return;
loaded=true;window.dataLayer=window.dataLayer||[];function consent(){window.dataLayer.push(arguments)}consent("consent","default",{analytics_storage:"granted",ad_storage:"denied",ad_user_data:"denied",ad_personalization:"denied"});window.dataLayer.push({"gtm.start":Date.now(),event:"gtm.js"});const s=document.createElement("script");s.async=true;s.src="https://www.googletagmanager.com/gtm.js?id="+id;s.referrerPolicy="no-referrer";document.head.append(s)}
function event(name){if(allowed&&loaded&&["join_bizhunt_click","grow_business_click"].includes(name))window.dataLayer.push({event:name})}
const panel=document.createElement("dialog");panel.setAttribute("aria-label","Analytics preferences");panel.style.cssText="border:1px solid #dce4f4;border-radius:16px;padding:24px;max-width:min(420px,90vw);color:#101a35";panel.innerHTML='<h2 style="margin-top:0">Analytics preferences</h2><p>Allow optional Google analytics to help us understand website visits and improve BizHunt. You can change your choice anytime.</p><div style="display:flex;gap:10px;flex-wrap:wrap"><button type="button" class="btn" data-choice="yes">Allow analytics</button><button type="button" class="btn light" data-choice="no">Decline</button></div>';document.body.append(panel);
const button=document.getElementById("bhAnalyticsPreferences");button.addEventListener("click",()=>panel.showModal());
panel.addEventListener("click",e=>{const v=e.target.closest("[data-choice]")?.dataset.choice;if(!v)return;save(v);allowed=v==="yes";panel.close();if(allowed)start();else if(loaded)location.reload()});
document.addEventListener("click",e=>{const a=e.target.closest("a");if(!a)return;const t=a.textContent.trim();if(/Join BizHunt/i.test(t))event("join_bizhunt_click");else if(/Grow Your Business/i.test(t))event("grow_business_click")});
allowed=read()==="yes";if(allowed)start();else if(read()===null)panel.showModal();
})();