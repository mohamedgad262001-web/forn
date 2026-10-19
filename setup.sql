-- ============================================================
-- نجيب سليم — تسجيل التجار
-- شغّلي الملف ده مرة واحدة في Supabase → SQL Editor
-- ============================================================

-- 1) جدول التجار
create table if not exists public.merchants (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(trim(name)) between 2 and 80),
  phone       text not null check (phone ~ '^01[0125][0-9]{8}$'),
  governorate text not null check (governorate in (
    'القاهرة','الجيزة','الإسكندرية','القليوبية','الدقهلية','الشرقية','الغربية','المنوفية',
    'البحيرة','كفر الشيخ','دمياط','بورسعيد','الإسماعيلية','السويس','الفيوم','بني سويف',
    'المنيا','أسيوط','سوهاج','قنا','الأقصر','أسوان','البحر الأحمر','الوادي الجديد',
    'مطروح','شمال سيناء','جنوب سيناء')),
  shop_name   text not null check (char_length(trim(shop_name)) between 2 and 100),
  created_at  timestamptz not null default now()
);
create index if not exists merchants_created_at_idx on public.merchants (created_at desc);

-- 2) الصلاحيات: الزوار يضيفوا بس، ومحدش يقرا الجدول مباشرة
alter table public.merchants enable row level security;
drop policy if exists "public can register" on public.merchants;
drop policy if exists "admins can read"     on public.merchants;
drop policy if exists "admins can delete"   on public.merchants;
create policy "public can register" on public.merchants
  for insert to anon, authenticated with check (true);

-- 3) مفتاح لوحة التحكم (/admin) — نفس المفتاح موجود في admin/index.html
--    لو غيّرتيه هنا غيّريه هناك كمان
create or replace function public.ns_admin_key() returns text
language sql immutable as $$ select 'VgOFgIrhmNPqfcevyXZniZ9Fu4utQJe1'::text $$;
revoke all on function public.ns_admin_key() from public, anon, authenticated;

-- قراءة كل التسجيلات (للوحة التحكم بس)
create or replace function public.ns_list_merchants(p_key text)
returns setof public.merchants
language plpgsql stable security definer set search_path = public as $$
begin
  if p_key is distinct from public.ns_admin_key() then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  return query select * from public.merchants order by created_at desc;
end $$;

-- حذف تسجيل
create or replace function public.ns_delete_merchant(p_key text, p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_key is distinct from public.ns_admin_key() then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  delete from public.merchants where id = p_id;
end $$;

revoke all on function public.ns_list_merchants(text)        from public;
revoke all on function public.ns_delete_merchant(text, uuid) from public;
grant execute on function public.ns_list_merchants(text)        to anon, authenticated;
grant execute on function public.ns_delete_merchant(text, uuid) to anon, authenticated;

-- (تنظيف لو كنتي شغّلتي النسخة القديمة اللي فيها login)
drop function if exists public.is_admin();
drop table if exists public.admins;
