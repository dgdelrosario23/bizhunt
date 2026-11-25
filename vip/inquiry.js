(() => {
  "use strict";
  const form = document.getElementById("vip-inquiry");
  const feedback = form.querySelector("[data-feedback]");
  const button = form.querySelector("button[type=submit]");
  const show = (message) => { feedback.textContent = message; feedback.hidden = false; };
  if (!window.supabase) {
    show("The inquiry service is temporarily unavailable. Please refresh and try again.");
    return;
  }
  const db = window.supabase.createClient("https://cjvcqdlwadmuktxtdxcz.supabase.co", "sb_publishable_V1lSJqiAyQtSgo0T3gY1Cg_tU4xYCsx", {auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}});
  button.disabled = false;
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!form.reportValidity() || button.disabled) return;
    const data = new FormData(form);
    if (data.get("website")) return;
    const read = key => String(data.get(key) || "").trim();
    const mobile = read("mobile");
    if (!/^[+\d\s().-]{7,32}$/.test(mobile) || !/^\d{7,15}$/.test(mobile.replace(/\D/g, ""))) {
      show("Please enter a valid mobile number.");
      return;
    }
    button.disabled = true;
    button.textContent = "Submitting…";
    try {
      const result = await db.rpc("bizhunt_submit_vip_inquiry", {
        p_name: read("name"), p_business: read("business"),
        p_email: read("email"), p_mobile: mobile,
        p_consent: data.get("consent") === "yes"
      });
      if (result.error) throw result.error;
      form.reset();
      show("Thank you. Your inquiry has been received. We'll be in touch soon.");
    } catch {
      show("We couldn't save your inquiry right now. Please try again in a moment.");
    } finally {
      button.disabled = false;
      button.textContent = "Request a Private Demo";
    }
  });
})();
