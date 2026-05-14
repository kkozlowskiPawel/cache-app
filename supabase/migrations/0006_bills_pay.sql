-- Rachunki: dodanie powiazania z kontem + funkcja "zaplac rachunek"
-- (atomowo tworzy transakcje i oznacza rachunek jako zaplacony).

alter table public.bills
    add column if not exists account_id uuid references public.accounts(id) on delete set null;

create or replace function public.pay_bill(bill_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
declare
    b record;
begin
    if auth.uid() is null then
        raise exception 'not authenticated';
    end if;

    select * into b
      from public.bills
     where id = bill_id and user_id = auth.uid()
       for update;

    if not found then
        raise exception 'bill not found';
    end if;
    if b.paid then
        return;
    end if;

    insert into public.transactions
        (user_id, account_id, category_id, amount, description, date, is_recurring)
    values (
        b.user_id, b.account_id, b.category_id,
        -b.amount,
        'Rachunek: ' || b.name,
        current_date,
        false
    );

    update public.bills
       set paid = true
     where id = bill_id;
end;
$$;

revoke all on function public.pay_bill(uuid) from public;
grant execute on function public.pay_bill(uuid) to authenticated;
