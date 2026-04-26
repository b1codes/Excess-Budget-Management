-- 1. Create junction table
CREATE TABLE IF NOT EXISTS public.goal_accounts (
    goal_id uuid REFERENCES public.goals(id) ON DELETE CASCADE,
    account_id uuid REFERENCES public.accounts(id) ON DELETE CASCADE,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    PRIMARY KEY (goal_id, account_id)
);

-- Enable RLS
ALTER TABLE public.goal_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own goal accounts"
ON public.goal_accounts FOR ALL USING (auth.uid() = user_id);

-- 2. Migrate existing data
INSERT INTO public.goal_accounts (goal_id, account_id, user_id)
SELECT id, account_id, user_id
FROM public.goals
WHERE account_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- 3. Update Sync Function
CREATE OR REPLACE FUNCTION public.sync_goal_progress_with_account()
RETURNS TRIGGER AS $$
BEGIN
    -- If an account balance changes, update all linked goals
    IF (TG_TABLE_NAME = 'accounts') THEN
        UPDATE public.goals
        SET current_amount = (
            SELECT COALESCE(SUM(a.balance), 0)
            FROM public.accounts a
            JOIN public.goal_accounts ga ON a.id = ga.account_id
            WHERE ga.goal_id = public.goals.id
        )
        WHERE id IN (
            SELECT goal_id FROM public.goal_accounts WHERE account_id = NEW.id
        );
        RETURN NEW;
    END IF;

    -- If a goal_accounts link is added or removed, sync the affected goal's progress
    IF (TG_TABLE_NAME = 'goal_accounts') THEN
        IF TG_OP = 'INSERT' THEN
            UPDATE public.goals
            SET current_amount = (
                SELECT COALESCE(SUM(a.balance), 0)
                FROM public.accounts a
                JOIN public.goal_accounts ga ON a.id = ga.account_id
                WHERE ga.goal_id = NEW.goal_id
            )
            WHERE id = NEW.goal_id;
            RETURN NEW;
        ELSIF TG_OP = 'DELETE' THEN
            UPDATE public.goals
            SET current_amount = (
                SELECT COALESCE(SUM(a.balance), 0)
                FROM public.accounts a
                JOIN public.goal_accounts ga ON a.id = ga.account_id
                WHERE ga.goal_id = OLD.goal_id
            )
            WHERE id = OLD.goal_id;
            RETURN OLD;
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Recreate Triggers
DROP TRIGGER IF EXISTS trigger_sync_goal_on_goal_upsert ON public.goals;

DROP TRIGGER IF EXISTS trigger_sync_goals_on_goal_accounts_change ON public.goal_accounts;
CREATE TRIGGER trigger_sync_goals_on_goal_accounts_change
AFTER INSERT OR DELETE ON public.goal_accounts
FOR EACH ROW EXECUTE FUNCTION public.sync_goal_progress_with_account();

-- 5. Drop old column
ALTER TABLE public.goals DROP COLUMN IF EXISTS account_id;
