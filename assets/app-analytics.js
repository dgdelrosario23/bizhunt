(() => {
  "use strict";
  // This integration deliberately uses the GA4 Google tag, not the general-purpose GTM container.
  const consentKey = "bh_analytics_consent_v2", previousKey = "bh_analytics_consent_v1";
  const measurementId = "G-KDF528M1Z6", origin = "https://bizhunt.app";
  const routes = {
    "/account/": ["BizHunt Accounts", ["login", "sign_up", "sign_up_request", "merchant_registration"]],
    "/app/": ["BizHunt Customer App", ["discover_view", "business_view", "deals_view", "wallet_view", "profile_view", "merchant_registration"]],
    "/hub/": ["BizHunt Merchant Hub", ["merchant_overview_view", "merchant_campaign_view", "merchant_promos_view", "merchant_business_view", "merchant_registration"]],
    "/communities/": ["BizHunt Communities", ["communities_view", "community_view"]],
    "/townhall/": ["BizHunt Town Hall", []]
  };
  const route = location.pathname, config = routes[route];
  if (location.origin !== origin || !config) return;
  // No hash or unknown query parameter is allowed at entry, including authentication callbacks,
  // record IDs, invite links, QR values or reset tokens.
  const sections = route === "/app/" ? ["discover","deals","profile","wallet"] :
    route === "/hub/" ? ["overview","campaigns","promos","business"] : [];
  const entrySafe = !location.hash && [...new URLSearchParams(location.search)].every(([k,v]) =>
    (k === "section" && sections.includes(v)) || (route === "/app/" && k === "welcome" && v === "1"));
  const [title, names] = config;
  const allowedEvents = new Set(names);
  const screenEvents = new Set(names.filter(x => x.endsWith("_view")));
  const canonical = origin + route;
  // Use only an origin, never the referring URL's path, query, fragment or user information.
  let referrer = "";
  try { const ref = new URL(document.referrer); if (["https:", "http:"].includes(ref.protocol)) referrer = ref.origin + "/"; } catch {}
  const fields = Object.freeze({page_location:canonical,page_referrer:referrer,page_title:title});
  let loaded = false, allowed = false, currentScreen = "", lastScreen = "";
  function read() {
    try { return localStorage.getItem(consentKey) ?? (localStorage.getItem(previousKey) === "no" ? "no" : null); }
    catch { return null; }
  }
  function save(value) { try { localStorage.setItem(consentKey,value); } catch {} }
  function gtag() { window.dataLayer.push(arguments); }
  function event(name) {
    if (!loaded || !allowed || read() === "no" || !allowedEvents.has(name) || screenEvents.has(name)) return;
    gtag("event", name, {...fields, send_to:measurementId});
  }
  function screen(name) {
    if (!screenEvents.has(name)) { currentScreen = ""; lastScreen = ""; return; }
    currentScreen = name;
    if (!loaded || !allowed || read() === "no" || lastScreen === name) return;
    lastScreen = name;
    gtag("event", name, {...fields, send_to:measurementId});
  }
  window.bizhuntAnalytics = Object.freeze({event,screen});
  function start() {
    if (loaded || !allowed || !entrySafe) return;
    loaded = true;
    window.dataLayer = window.dataLayer || [];
    gtag("consent","default",{analytics_storage:"granted",ad_storage:"denied",ad_user_data:"denied",ad_personalization:"denied"});
    gtag("js",new Date());
    // Fixed route metadata for automatic as well as explicitly dispatched events.
    gtag("set",fields);
    gtag("config",measurementId,{...fields,send_page_view:false,allow_google_signals:false,allow_ad_personalization_signals:false});
    gtag("event","page_view",{...fields,send_to:measurementId});
    if (currentScreen) screen(currentScreen);
    const tag=document.createElement("script");
    tag.async=true; tag.src="https://www.googletagmanager.com/gtag/js?id="+measurementId;
    tag.referrerPolicy="no-referrer"; document.head.append(tag);
  }
  // Allow preferences to be changed even when the current entry is excluded.
  const panel=document.createElement("dialog");
  panel.setAttribute("aria-label","Analytics preferences");
  panel.style.cssText="border:1px solid #dce4f4;border-radius:16px;padding:24px;max-width:min(420px,90vw);color:#101a35;background:#fff";
  panel.innerHTML='<h2 style="margin:0 0 12px;font-size:20px">Analytics preferences</h2><p>Allow optional Google Analytics to measure visits, general app screens and successful actions. We do not send account details, form values, QR codes or record IDs in our analytics events.</p><div style="display:flex;gap:10px;flex-wrap:wrap"><button type="button" style="background:#273880;color:white;border:0;border-radius:10px;padding:10px 14px;cursor:pointer" data-choice="yes">Allow analytics</button><button type="button" style="background:#eef2ff;color:#273880;border:0;border-radius:10px;padding:10px 14px;cursor:pointer" data-choice="no">Decline</button></div>';
  document.body.append(panel);
  const button=document.createElement("button");
  button.type="button"; button.textContent="Analytics preferences"; button.id="bhAppAnalyticsPreferences";
  button.style.cssText="display:block;margin:16px auto 110px;padding:6px 10px;color:#273880;background:transparent;border:0;font:12px system-ui;cursor:pointer;text-decoration:underline";
  document.body.append(button);
  button.addEventListener("click",()=>{if(!panel.open)panel.showModal()});
  function revoke() {
    allowed=false;
    if (loaded) { gtag("consent","update",{analytics_storage:"denied"}); location.reload(); }
  }
  panel.addEventListener("click",e=>{
    const value=e.target.closest("[data-choice]")?.dataset.choice;
    if (!["yes","no"].includes(value)) return;
    save(value); panel.close();
    if (value==="no") revoke(); else {allowed=true; start();}
  });
  window.addEventListener("storage",e=>{if(e.key===consentKey && e.newValue!=="yes") revoke()});
  allowed=read()==="yes";
  if(allowed) start(); else if(read()===null && entrySafe) panel.showModal();
})();
