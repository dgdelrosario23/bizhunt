-- Roll back Phase N3 destination metadata (loses destination data, not notifications).
alter table public.bizhunt_notifications drop constraint if exists bizhunt_notifications_target_pair;
alter table public.bizhunt_notifications drop column if exists target_id;
alter table public.bizhunt_notifications drop column if exists target_type;
