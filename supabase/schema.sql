-- CIRKADIAN Booth · Supabase schema
-- Run this once in the Supabase SQL editor (Project > SQL Editor > New query).

-- 1) research_responses: full anonymous survey data, for later research use.
--    No name, no device/IP, no session id is stored here — only survey
--    answers and derived sleep metrics. Insert-only from the public app;
--    only the Supabase service_role (dashboard / service key) can read it.
create table if not exists research_responses (
  id                  uuid primary key default gen_random_uuid(),
  created_at          timestamptz not null default now(),
  submission_id       uuid    not null,  -- shared with the matching board_events row, for correlated admin delete

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

drop policy if exists "anon can insert research responses" on research_responses;
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
  submission_id      uuid    not null,  -- shared with the matching research_responses row, for correlated admin delete
  city_key           text    not null,
  social_jetlag_min  numeric not null
);

alter table board_events enable row level security;

drop policy if exists "anon can insert board events" on board_events;
create policy "anon can insert board events"
  on board_events for insert
  to anon
  with check (true);

drop policy if exists "anyone can read board events" on board_events;
create policy "anyone can read board events"
  on board_events for select
  to anon
  using (true);

-- Enable realtime (Database > Replication in the dashboard must also have
-- this table toggled on for the "supabase_realtime" publication).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'board_events'
  ) then
    alter publication supabase_realtime add table board_events;
  end if;
end $$;

-- 3) Migration: submission_id links a research_responses row to its
--    matching board_events row (same submission), so the admin page can
--    delete one visitor's entry from both tables without ever needing to
--    read research_responses. Safe to re-run.
alter table research_responses add column if not exists submission_id uuid;
update research_responses set submission_id = gen_random_uuid() where submission_id is null;
alter table research_responses alter column submission_id set not null;

alter table board_events add column if not exists submission_id uuid;
update board_events set submission_id = gen_random_uuid() where submission_id is null;
alter table board_events alter column submission_id set not null;

-- 4) Admin dashboard (cirkadian_admin.html) reset + per-entry delete.
--    These let the anon key delete rows so the booth operator can wipe
--    today's/all data (or one selected entry) from the admin UI. Note:
--    the anon key is public (shipped in client-side HTML), so this delete
--    capability is only as protected as the admin page's own password
--    prompt — anyone with the key could call it directly. Acceptable for
--    this low-stakes booth tool, but don't reuse this pattern for
--    anything sensitive.
drop policy if exists "anon can delete research responses" on research_responses;
create policy "anon can delete research responses"
  on research_responses for delete
  to anon
  using (true);

drop policy if exists "anon can delete board events" on board_events;
create policy "anon can delete board events"
  on board_events for delete
  to anon
  using (true);

-- 5) Optional nickname for the monitor's TOP 3 podium display only.
--    Stored in board_events (already public/display data), never in
--    research_responses, so the research dataset stays fully anonymous.
alter table board_events add column if not exists nickname text;
