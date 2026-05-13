-- Trigger: automatycznie aktualizuje accounts.balance po insert/update/delete transakcji.
-- Konwencja: amount < 0 = wydatek (zmniejsza saldo), amount > 0 = przychod (zwieksza saldo).
-- Transakcje bez account_id NIE wplywaja na zadne saldo.

create or replace function public.apply_transaction_to_balance()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
    if (tg_op = 'INSERT') then
        if (new.account_id is not null) then
            update public.accounts
               set balance = balance + new.amount
             where id = new.account_id;
        end if;
        return new;

    elsif (tg_op = 'UPDATE') then
        -- odejmij stara wartosc ze starego konta
        if (old.account_id is not null) then
            update public.accounts
               set balance = balance - old.amount
             where id = old.account_id;
        end if;
        -- dodaj nowa wartosc do nowego konta
        if (new.account_id is not null) then
            update public.accounts
               set balance = balance + new.amount
             where id = new.account_id;
        end if;
        return new;

    elsif (tg_op = 'DELETE') then
        if (old.account_id is not null) then
            update public.accounts
               set balance = balance - old.amount
             where id = old.account_id;
        end if;
        return old;
    end if;
    return null;
end;
$$;

drop trigger if exists trg_transactions_balance on public.transactions;

create trigger trg_transactions_balance
    after insert or update or delete on public.transactions
    for each row execute function public.apply_transaction_to_balance();
