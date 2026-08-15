-- Run this in the Supabase SQL Editor for the BookingDemoLite project,
-- AFTER running schema.sql once first.
--
-- Adds a reset_demo_data() function that wipes bookings/settings back to a
-- clean seeded state, callable two ways:
--   1. Manually — the Dashboard's "Reset Demo Data" button calls
--      supabase.rpc('reset_demo_data') directly, no Edge Function needed.
--   2. Automatically — pg_cron runs it every 24 hours as a safety net.

create or replace function reset_demo_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Wipe anything a prospect clicked around and created.
  delete from bookings;
  delete from booking_blocked_dates;

  -- Reset settings to a clean default (keeps the row, just blanks it out).
  update booking_settings set
    business_name = 'Sample Business',
    phone = '(555) 123-4567',
    venmo_handle = null,
    zelle_handle = null,
    cashapp_handle = null,
    default_price = null;

  -- Reset hours to a normal Mon–Sat 9–5 default.
  update booking_hours set
    is_open = (day_of_week between 1 and 6),
    start_time = '09:00',
    end_time = '17:00';

  -- Seed a few sample bookings so the calendar/list isn't empty for demos.
  insert into bookings (customer_name, customer_phone, booking_date, booking_time, status)
  values
    ('Jamie Rivera', '(555) 010-2231', current_date + 1, '10:00', 'confirmed'),
    ('Sam Alvarez', '(555) 010-7742', current_date + 2, '13:00', 'confirmed'),
    ('Taylor Chen', '(555) 010-9910', current_date + 4, '09:00', 'confirmed');
end;
$$;

-- Only a logged-in owner can trigger a reset from the Dashboard button —
-- not the public booking page.
revoke all on function reset_demo_data() from public;
grant execute on function reset_demo_data() to authenticated;

-- Auto-reset every 24 hours as a safety net for whenever the manual button
-- doesn't get clicked before the next demo.
create extension if not exists pg_cron;

select cron.schedule(
  'reset-demo-data-daily',
  '0 4 * * *', -- 04:00 UTC = 11:00 Bangkok time, ~before demos start
  $$select reset_demo_data();$$
);
