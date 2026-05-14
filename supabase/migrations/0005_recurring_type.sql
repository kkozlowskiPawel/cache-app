-- Pozwalamy aby "subskrypcja" mogla byc rowniez przychodem cyklicznym (np. wyplata).
-- Wykorzystujemy istniejacy enum category_type ('income','expense').

alter table public.subscriptions
    add column if not exists type category_type not null default 'expense';

-- Aktualizujemy charge_due_subscriptions tak, by znak kwoty zalezal od typu:
--   expense -> transakcja z amount = -kwota (zmniejsza saldo)
--   income  -> transakcja z amount = +kwota (zwieksza saldo)
create or replace function public.charge_due_subscriptions()
returns int
language plpgsql
security definer set search_path = public
as $$
declare
    sub record;
    charged int := 0;
    new_next date;
    tx_amount numeric;
    tx_desc text;
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
            tx_amount := case sub.type
                when 'income' then sub.amount
                else -sub.amount
            end;
            tx_desc := case sub.type
                when 'income' then 'Przychód: ' || sub.name
                else 'Subskrypcja: ' || sub.name
            end;

            insert into public.transactions
                (user_id, account_id, category_id, amount, description, date, is_recurring)
            values (
                sub.user_id, sub.account_id, sub.category_id,
                tx_amount, tx_desc, new_next, true
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
