/* Shared Discover and merchant profile scoring. */
(function(root){
"use strict";
const has=v=>typeof v==="string"&&v.trim().length>0;
const time=v=>typeof v==="string"&&/^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(v);
const days=["monday","tuesday","wednesday","thursday","friday","saturday","sunday"];
const number=v=>Math.max(0,Number(v)||0);
function profile(b,metrics={}){
 const mobile=!!b.mobile_service,service=b.business_type==="service"||mobile;
 const pin=[b.latitude,b.longitude].every(v=>v!==null&&v!==undefined&&v!==""&&Number.isFinite(Number(v)))&&Math.abs(Number(b.latitude))<=90&&Math.abs(Number(b.longitude))<=180;
 const hours=days.every(d=>{const h=b.weekly_hours?.[d]||b.weekly_hours?.[d.slice(0,3)];return h&&(h.closed===true||(time(h.open)&&time(h.close)&&h.open!==h.close))});
 const photos=number(metrics.gallery_count)>0,menu=number(metrics.menu_count)>0;
 const items=[
 {label:"Business logo",weight:20,done:has(b.logo_path),target:"profile"},
 {label:"Cover photo",weight:10,done:has(b.cover_path),target:"profile"},
 {label:mobile?"Service coverage area":"Storefront address and map pin",weight:15,done:mobile?has(b.service_area):has(b.location)&&pin,target:"location"},
 {label:"Weekly operating hours",weight:15,done:hours,target:"hours"},
 {label:"Business description",weight:10,done:has(b.description),target:"profile"},
 {label:"Public contact method",weight:10,done:has(b.phone)||has(b.website)||has(b.instagram),target:"contact"},
 {label:"Gallery photos",weight:10,done:photos,target:"media"},
 {label:service?"Services described":"Menu or service information",weight:10,done:menu||(service&&has(b.description)),target:service&&!menu?"profile":"media"}
 ];
 const score=items.reduce((sum,x)=>sum+(x.done?x.weight:0),0);
 return {score,items,missing:items.filter(x=>!x.done)};
}
function rank(b,m={}){
 const completeness=profile(b,m).score;
 const count=number(m.review_count),followers=number(m.follower_count);
 const avg=Math.min(5,Math.max(1,Number(m.average_rating)||3.5));
 // Prior equivalent to five reviews at 3.5 stars. No reviews are neutral, not five stars.
 const rating=(avg*count+3.5*5)/(count+5);
 const saturate=(n,cap)=>Math.min(1,Math.log1p(n)/Math.log1p(cap));
 const score=completeness*.5+rating/5*25+saturate(followers,100)*15+saturate(count,50)*10;
 return {score,completeness,tier:completeness>=80?2:completeness>=50?1:0,rating};
}
function sort(list,metrics){
 return list.map(b=>({b,...rank(b,metrics(b))})).sort((a,b)=>b.tier-a.tier||b.score-a.score||b.completeness-a.completeness||String(a.b.name).localeCompare(String(b.b.name))||String(a.b.id).localeCompare(String(b.b.id))).map(x=>x.b);
}
const api={profile,rank,sort};
if(typeof module==="object"&&module.exports)module.exports=api;else root.BizHuntRanking=api;
})(typeof globalThis!=="undefined"?globalThis:this);
