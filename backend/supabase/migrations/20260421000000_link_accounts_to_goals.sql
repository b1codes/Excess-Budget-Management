-- 1. Add account_id to goal_allocations
ALTER TABLE public.goal_allocations 
ADD COLUMN account_id uuid REFERENCES public.accounts(id) ON DELETE SET NULL;

CREATE INDEX idx_goal_allocations_account_id ON public.goal_allocations(account_id);

-- 2. Create function to sync balances
CREATE OR REPLACE FUNCTION public.sync_allocation_balances()
RETURNS TRIGGER AS $$
BEGIN
  -- 1. If account_id is provided, deduct from account balance
  IF NEW.account_id IS NOT NULL THEN
    UPDATE public.accounts
    SET balance = balance - NEW.amount
    WHERE id = NEW.account_id;
  END IF;

  -- 2. Increment goal current_amount
  UPDATE public.goals
  SET current_amount = current_amount + NEW.amount
  WHERE id = NEW.goal_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create trigger
CREATE TRIGGER trigger_sync_allocation_balances
AFTER INSERT ON public.goal_allocations
FOR EACH ROW EXECUTE FUNCTION public.sync_allocation_balances();
