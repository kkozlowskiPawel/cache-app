-- Subskrypcje: dodanie account_id + mechanizm automatycznego obciazenia konta
-- w dniu platnosci (i naprzod, gdy zaległe).

alter table public.subscriptions
    add column if not exists account_id uuid references public.accounts(id) on delete set null;

-- Funkcja: dla biezacego usera, przeleci wszystkie aktywne subskrypcje z
-- next_billing_date <= dzisiaj, utworzy transakcje (po jednej na kazdy minely cykl)
-- i przesunie next_billing_date naprzod. Istniejacy trigger
-- apply_transaction_to_balance automatycznie zaktualizuje saldo konta.
create or replace function public.charge_due_subscriptions()
returns int
language plpgsql
security definer set search_path = public
as $$
declare
    sub record;
    charged int := 0;
    new_next date;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;

    for sub in
        select * from public.subscriptions
        where active = true
          and user_id = auth.uid()
          and next_billing_date <= current_date
        for update
    loop
        new_next := sub.next_billing_date;
        while new_next <= current_date loop
            insert into public.transactions
                (user_id, account_id, category_id, amount, description, date, is_recurring)
            values (
                sub.user_id, sub.account_id, sub.category_id,
                -sub.amount,
                'Subskrypcja: ' || sub.name,
                new_next, true
            );
            charged := charged + 1;

            new_next := (new_next + (case sub.billing_cycle
                when 'weekly'    then interval '1 week'
                when 'monthly'   then interval '1 month'
                when 'quarterly' then interval '3 months'
                when 'yearly'    then interval '1 year'
            end))::date;
        end loop;

        update public.subscriptions
           set next_billing_date = new_next
         where id = sub.id;
    end loop;

    return charged;
end;
$$;

revoke all on function public.charge_due_subscriptions() from public;
grant execute on function public.charge_due_subscriptions() to authenticated;
