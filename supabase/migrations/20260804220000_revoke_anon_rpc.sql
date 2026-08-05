-- Harden SECURITY DEFINER RPCs: no anon/public execute
revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.create_partner_invite() from public, anon;
revoke all on function public.accept_partner_invite(text) from public, anon;
grant execute on function public.create_partner_invite() to authenticated;
grant execute on function public.accept_partner_invite(text) to authenticated;
