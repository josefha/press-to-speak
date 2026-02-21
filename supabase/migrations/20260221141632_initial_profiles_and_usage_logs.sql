
  create table "public"."profiles" (
    "id" uuid not null,
    "display_name" text,
    "plan" text not null default 'free'::text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now()
      );


alter table "public"."profiles" enable row level security;


  create table "public"."usage_logs" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "action" text not null,
    "duration_ms" integer,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."usage_logs" enable row level security;

CREATE INDEX idx_usage_logs_user_id_created_at ON public.usage_logs USING btree (user_id, created_at DESC);

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);

CREATE UNIQUE INDEX usage_logs_pkey ON public.usage_logs USING btree (id);

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY using index "profiles_pkey";

alter table "public"."usage_logs" add constraint "usage_logs_pkey" PRIMARY KEY using index "usage_logs_pkey";

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" validate constraint "profiles_id_fkey";

alter table "public"."profiles" add constraint "profiles_plan_check" CHECK ((plan = ANY (ARRAY['free'::text, 'pro'::text]))) not valid;

alter table "public"."profiles" validate constraint "profiles_plan_check";

alter table "public"."usage_logs" add constraint "usage_logs_action_check" CHECK ((action = ANY (ARRAY['transcription'::text, 'rewrite'::text]))) not valid;

alter table "public"."usage_logs" validate constraint "usage_logs_action_check";

alter table "public"."usage_logs" add constraint "usage_logs_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."usage_logs" validate constraint "usage_logs_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.profiles (id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$function$
;

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."usage_logs" to "anon";

grant insert on table "public"."usage_logs" to "anon";

grant references on table "public"."usage_logs" to "anon";

grant select on table "public"."usage_logs" to "anon";

grant trigger on table "public"."usage_logs" to "anon";

grant truncate on table "public"."usage_logs" to "anon";

grant update on table "public"."usage_logs" to "anon";

grant delete on table "public"."usage_logs" to "authenticated";

grant insert on table "public"."usage_logs" to "authenticated";

grant references on table "public"."usage_logs" to "authenticated";

grant select on table "public"."usage_logs" to "authenticated";

grant trigger on table "public"."usage_logs" to "authenticated";

grant truncate on table "public"."usage_logs" to "authenticated";

grant update on table "public"."usage_logs" to "authenticated";

grant delete on table "public"."usage_logs" to "service_role";

grant insert on table "public"."usage_logs" to "service_role";

grant references on table "public"."usage_logs" to "service_role";

grant select on table "public"."usage_logs" to "service_role";

grant trigger on table "public"."usage_logs" to "service_role";

grant truncate on table "public"."usage_logs" to "service_role";

grant update on table "public"."usage_logs" to "service_role";


  create policy "profiles_insert_own"
  on "public"."profiles"
  as permissive
  for insert
  to public
with check ((auth.uid() = id));



  create policy "profiles_select_own"
  on "public"."profiles"
  as permissive
  for select
  to public
using ((auth.uid() = id));



  create policy "profiles_update_own"
  on "public"."profiles"
  as permissive
  for update
  to public
using ((auth.uid() = id))
with check ((auth.uid() = id));



  create policy "usage_logs_insert_service"
  on "public"."usage_logs"
  as permissive
  for insert
  to public
with check ((auth.role() = 'service_role'::text));



  create policy "usage_logs_select_own"
  on "public"."usage_logs"
  as permissive
  for select
  to public
using ((auth.uid() = user_id));


CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


