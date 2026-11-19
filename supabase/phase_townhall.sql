-- Apply in Supabase SQL Editor before enabling Town Hall.
create table if not exists public.townhall_posts (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references auth.users(id) on delete cascade,
 title text not null check (char_length(trim(title)) between 5 and 140),
 body text not null check (char_length(trim(body)) between 10 and 3000),
 category text not null default 'Feature request' check (category in ('Feature request','Improvement','Bug report')),
 created_at timestamptz not null default now()
);
create table if not exists public.townhall_votes (
 post_id uuid not null references public.townhall_posts(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key(post_id,user_id)
);
create table if not exists public.townhall_comments (
 id uuid primary key default gen_random_uuid(),
 post_id uuid not null references public.townhall_posts(id) on delete cascade,
 author_id uuid not null references auth.users(id) on delete cascade,
 body text not null check (char_length(trim(body)) between 2 and 1500),
 created_at timestamptz not null default now()
);
create index if not exists townhall_posts_created_idx on public.townhall_posts(created_at desc);
create index if not exists townhall_comments_post_idx on public.townhall_comments(post_id,created_at);
alter table public.townhall_posts enable row level security;
alter table public.townhall_votes enable row level security;
alter table public.townhall_comments enable row level security;
drop policy if exists "townhall posts read" on public.townhall_posts;
create policy "townhall posts read" on public.townhall_posts for select to authenticated using (true);
drop policy if exists "townhall posts create" on public.townhall_posts;
create policy "townhall posts create" on public.townhall_posts for insert to authenticated with check (author_id = (select auth.uid()));
drop policy if exists "townhall posts delete own" on public.townhall_posts;
create policy "townhall posts delete own" on public.townhall_posts for delete to authenticated using (author_id = (select auth.uid()));
drop policy if exists "townhall votes read" on public.townhall_votes;
create policy "townhall votes read" on public.townhall_votes for select to authenticated using (true);
drop policy if exists "townhall votes create" on public.townhall_votes;
create policy "townhall votes create" on public.townhall_votes for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists "townhall votes delete own" on public.townhall_votes;
create policy "townhall votes delete own" on public.townhall_votes for delete to authenticated using (user_id = (select auth.uid()));
drop policy if exists "townhall comments read" on public.townhall_comments;
create policy "townhall comments read" on public.townhall_comments for select to authenticated using (true);
drop policy if exists "townhall comments create" on public.townhall_comments;
create policy "townhall comments create" on public.townhall_comments for insert to authenticated with check (author_id = (select auth.uid()));
drop policy if exists "townhall comments delete own" on public.townhall_comments;
create policy "townhall comments delete own" on public.townhall_comments for delete to authenticated using (author_id = (select auth.uid()));
