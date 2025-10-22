alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.lists enable row level security;
alter table public.items enable row level security;

create or replace function public.is_member(hh uuid)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.household_members m
    where m.household_id = hh and m.user_id = auth.uid()
  );
$$;

create policy "profiles_self" on public.profiles for select using (id = auth.uid());

create policy "households_select" on public.households for select using (
  exists (
    select 1 from public.household_members m
    where m.household_id = id and m.user_id = auth.uid()
  )
);

create policy "households_insert" on public.households for insert with check (created_by = auth.uid());

create policy "households_update" on public.households for update using (
  exists (
    select 1 from public.household_members m
    where m.household_id = id and m.user_id = auth.uid() and m.role in ('owner','admin')
  )
);

create policy "households_delete_owner" on public.households for delete using (
  exists (
    select 1 from public.household_members m
    where m.household_id = id and m.user_id = auth.uid() and m.role = 'owner'
  )
);

create policy "members_select" on public.household_members for select using (
  public.is_member(household_id)
);

create policy "members_insert" on public.household_members for insert with check (
  exists (
    select 1 from public.household_members m
    where m.household_id = household_id and m.user_id = auth.uid() and m.role in ('owner','admin')
  )
);

create policy "members_update" on public.household_members for update using (
  exists (
    select 1 from public.household_members m
    where m.household_id = household_id and m.user_id = auth.uid() and m.role in ('owner','admin')
  )
);

create policy "members_delete" on public.household_members for delete using (
  exists (
    select 1 from public.household_members m
    where m.household_id = household_id and m.user_id = auth.uid() and m.role in ('owner','admin')
  )
);

create policy "lists_select" on public.lists for select using (public.is_member(household_id));
create policy "lists_write" on public.lists for all using (public.is_member(household_id)) with check (public.is_member(household_id));

create policy "items_select" on public.items for select using (
  public.is_member((select household_id from public.lists l where l.id = list_id))
);

create policy "items_write" on public.items for all using (
  public.is_member((select household_id from public.lists l where l.id = list_id))
) with check (
  public.is_member((select household_id from public.lists l where l.id = list_id))
);
