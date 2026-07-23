-- CIRKADIAN Booth · Supabase schema
-- Run this once in the Supabase SQL editor (Project > SQL Editor > New query).

-- 1) research_responses: full anonymous survey data, for later research use.
--    No name, no device/IP, no session id is stored here — only survey
--    answers and derived sleep metrics. Insert-only from the public app;
--    only the Supabase service_role (dashboard / service key) can read it.
create table if not exists research_responses (
  id                  uuid primary key default gen_random_uuid(),
  created_at          timestamptz not null default now(),

  wd_bed_min          int     not null,  -- weekday bedtime, minutes after 00:00 (0-1439)
  wd_wake_min         int     not null,
  we_bed_min          int     not null,
  we_wake_min         int     not null,
  wd_duration_min     int     not null,
  we_duration_min     int     not null,
  avg_sleep_min       numeric not null,
  weekday_midsleep_min int    not null,
  social_jetlag_min   numeric not null,

  chronotype          text    not null,
  sleep_score         int     not null,

  q_latency           smallint not null,  -- survey answer indices (0-based), see QS in cirkadian_jetlag_test.html
  q_night             smallint not null,
  q_morning           smallint not null,
  q_phone             smallint not null,
  q_caffeine          smallint not null,
  q_sleepy            smallint not null,

  city_key            text    not null
);

alter table research_responses enable row level security;

create policy "anon can insert research responses"
  on research_responses for insert
  to anon
  with check (true);

-- Deliberately no select policy for anon/authenticated: raw research
-- data is only readable via the Supabase dashboard or service_role key.

-- 2) board_events: the subset of data shown live on the booth monitor.
--    Public, non-identifying (city + jetlag amount only) so it can be
--    read and subscribed to in realtime by the big-screen display.
create table if not exists board_events (
  id                 uuid primary key default gen_random_uuid(),
  created_at         timestamptz not null default now(),
  city_key           text    not null,
  social_jetlag_min  numeric not null
);

alter table board_events enable row level security;

create policy "anon can insert board events"
  on board_events for insert
  to anon
  with check (true);

create policy "anyone can read board events"
  on board_events for select
  to anon
  using (true);

-- Enable realtime (Database > Replication in the dashboard must also have
-- this table toggled on for the "supabase_realtime" publication).
alter publication supabase_realtime add table board_events;
