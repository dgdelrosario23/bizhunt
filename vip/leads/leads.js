(async () => {
  "use strict";
  const $ = id => document.getElementById(id);
  const note = text => { $("message").textContent = text; };
  if (!window.supabase) { note("Unable to load the inquiry service."); return; }
  const db = window.supabase.createClient("https://cjvcqdlwadmuktxtdxcz.supabase.co", "sb_publishable_V1lSJqiAyQtSgo0T3gY1Cg_tU4xYCsx");
  const statuses = ["New", "Contacted", "In Discussion", "Onboarded"];
  let offset = 0;
  const {data,error} = await db.auth.getUser();
  if (error || !data.user) {
    note("Sign in using your approved BizHunt founder account.");
    const link = document.createElement("a"); link.href = "/account/"; link.textContent = " Sign in"; $("message").append(link);
    return;
  }
  const cell = (row, ...lines) => {
    const td = row.insertCell();
    lines.forEach((line,index) => { if(index) td.append(document.createElement("br")); td.append(document.createTextNode(String(line ?? ""))); });
    return td;
  };
  async function load() {
    $("table").hidden = $("controls").hidden = true;
    $("rows").replaceChildren();
    note("Loading inquiries…");
    const result = await db.rpc("bizhunt_founder_vip_inquiries", {p_offset:offset});
    if (result.error) { note("Access denied or inquiry service unavailable."); return; }
    const rows = result.data || [];
    note(rows.length ? "Review inquiries and update their contact status." : "No inquiries on this page.");
    rows.forEach(item => {
      const row = $("rows").insertRow();
      cell(row,item.business_name,item.full_name);
      cell(row,item.email,item.mobile);
      cell(row,new Date(item.created_at).toLocaleString("en-PH",{timeZone:"Asia/Manila"}));
      const td = row.insertCell(), select = document.createElement("select"), button = document.createElement("button");
      select.setAttribute("aria-label","Lead status");
      statuses.forEach(status => {const option = new Option(status,status); option.selected = status===item.status; select.add(option);});
      button.type="button";button.textContent="Save";td.append(select," ",button);
      button.addEventListener("click",async () => {
        button.disabled = select.disabled = true;
        try {
          const result = await db.rpc("bizhunt_founder_vip_inquiry_status",{p_id:item.id,p_status:select.value});
          if(result.error) throw result.error;
          note("Status saved.");
        } catch {note("Unable to save the status. Try again.");}
        finally { button.disabled = select.disabled = false; }
      });
    });
    $("page").textContent = "Page "+(offset/50+1);
    $("prev").disabled = offset===0;
    $("next").disabled = rows.length<50;
    $("table").hidden = $("controls").hidden = false;
  }
  $("prev").onclick = () => {offset=Math.max(0,offset-50);load();};
  $("next").onclick = () => {offset+=50;load();};
  await load();
})();
