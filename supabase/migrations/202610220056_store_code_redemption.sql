-- 056: A single redemption endpoint. Eligibility and privileged checks remain server-side.
begin;
do $rename$ begin
 if to_regprocedure('public._claim_gift_before056(text)') is null then
  alter function public.claim_gift_code(text) rename to _claim_gift_before056;
 end if;
end $rename$;
create or replace function public.claim_gift_code(p_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare normalized text:=upper(btrim(coalesce(p_code,'')));result jsonb;
begin
 perform public._assert_account_active();
 if auth.uid() is null then raise exception 'Entre para resgatar um código.';end if;
 perform public._security_rpc_gate('claim_gift_code',20);
 if length(normalized) not between 1 and 64 then raise exception 'Digite um código válido.';end if;
 if length(normalized)=39 then
  result:=public.redeem_admin_role_code(normalized);
  if not coalesce((result->>'ok')::boolean,false) then
   return jsonb_build_object('ok',false,'message','Código inválido, expirado ou indisponível para esta conta.');
  end if;
  return jsonb_build_object('ok',true,'rewards',jsonb_build_array(jsonb_build_object('kind','account','name','Acesso da conta atualizado','amount',1)));
 end if;
 return public._claim_gift_before056(normalized);
end $$;
revoke all on function public._claim_gift_before056(text),public.redeem_admin_role_code(text),public.claim_gift_code(text) from public,anon,authenticated;
grant execute on function public.claim_gift_code(text) to authenticated;
-- The related management form is delivered only after server authorization.
create or replace function public.get_account_toolkit()
returns jsonb language plpgsql security definer set search_path='' as $$
declare overview jsonb;rows jsonb;form jsonb;
begin
 perform public._assert_account_active();
 if auth.uid() is null or not public.is_site_admin() then raise exception 'Acesso restrito.' using errcode='42501';end if;
 perform public._security_rpc_gate('account_toolkit',30);
 overview:=public.admin_role_overview();
 select coalesce(jsonb_agg(jsonb_build_object('name',entry->>'nickname','email',entry->>'email','label',case when coalesce((entry->>'founder')::boolean,false) then 'Conta principal' else 'Administrador' end)),'[]'::jsonb) into rows from jsonb_array_elements(coalesce(overview->'administrators','[]'::jsonb)) entry;
 if coalesce((overview->>'can_manage')::boolean,false) then
  form:=jsonb_build_object('label','E-mail da conta destinatária','submit','Gerar código de uso único','action','admin_create_role_code','parameter','p_email','after','O titular deve resgatar este código na Loja. Válido por 24 horas, para uma única conta e um único uso.','resultFields',jsonb_build_array(jsonb_build_object('key','code','label','Código'),jsonb_build_object('key','email','label','Conta destinatária'),jsonb_build_object('key','expires_at','label','Validade')));
 end if;
 return jsonb_build_object('title','Administradores','description',case when form is null then 'Somente a conta principal gerencia os acessos.' else 'Gere um código vinculado à conta destinatária. O resgate é feito pelo campo comum da Loja.' end,'form',form,'rows',rows);
end $$;
revoke all on function public.get_account_toolkit() from public,anon,authenticated;
grant execute on function public.get_account_toolkit() to authenticated;
notify pgrst,'reload schema';
commit;
