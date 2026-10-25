-- Relax the original phone check to permit standard Philippine mobile numbers.
-- Normalize submitted numbers in the app to 09XXXXXXXXX before storage.
alter table public.bizhunt_user_details drop constraint if exists bizhunt_user_details_mobile_number_check;
alter table public.bizhunt_user_details add constraint bizhunt_user_details_mobile_number_check check(mobile_number is null or mobile_number ~ '^09[0-9]{9}$');
