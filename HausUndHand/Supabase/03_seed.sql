-- Minimal seed data for development
do $$
begin
  if not exists (select 1 from auth.users where email = 'demo@hausundhand.app') then
    insert into auth.users (id, email) values (gen_random_uuid(), 'demo@hausundhand.app');
  end if;
end $$;

insert into public.households (id, name, created_by)
select gen_random_uuid(), 'Testhaushalt', id from auth.users where email = 'demo@hausundhand.app'
on conflict do nothing;

insert into public.household_members (household_id, user_id, role)
select h.id, u.id, 'owner'
from public.households h
join auth.users u on u.email = 'demo@hausundhand.app'
on conflict do nothing;

insert into public.lists (household_id, name, is_default)
select h.id, 'Zu kaufen', true from public.households h
on conflict do nothing;
