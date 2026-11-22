-- Optional Phase N3: structured notification destinations.
-- Apply manually only after review. Existing notifications remain unchanged.
-- target_id is an identifier, never a URL. Recipients cannot write these fields.
alter table public.bizhunt_notifications
  add column if not exists target_type text,
  add column if not exists target_id uuid;

alter table public.bizhunt_notifications
  drop constraint if exists bizhunt_notifications_target_pair;
alter table public.bizhunt_notifications
  add constraint bizhunt_notifications_target_pair
  check (
    (target_type is null and target_id is null)
    or (target_type in ('business','community','reward') and target_id is not null)
  );

comment on column public.bizhunt_notifications.target_type is
  'Optional validated navigation target: business, community or reward. Populated only by trusted server-side notification producers.';
comment on column public.bizhunt_notifications.target_id is
  'Target record UUID. The client must still enforce the destination resource authorization.';
-- Existing recipient-only SELECT RLS and read-only authenticated grants remain intact.
-- This migration intentionally does not create automatic notifications or client INSERT permissions.
