-- Disable the new entry points without deleting any collected leads.
begin;
revoke execute on function public.bizhunt_submit_vip_inquiry(text,text,text,text,boolean) from anon, authenticated;
revoke execute on function public.bizhunt_founder_vip_inquiries(integer) from authenticated;
revoke execute on function public.bizhunt_founder_vip_inquiry_status(uuid,text) from authenticated;
commit;
