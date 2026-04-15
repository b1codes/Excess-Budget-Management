-- Phase 2 - Balanced Allocation Intelligence

-- 1. Update public.profiles to include default_savings_ratio for cold starts
ALTER TABLE public.profiles 
ADD COLUMN default_savings_ratio numeric(3, 2) DEFAULT 0.50 CHECK (default_savings_ratio >= 0 AND default_savings_ratio <= 1);

-- 2. Update public.goals to include category
ALTER TABLE public.goals 
ADD COLUMN category text DEFAULT 'savings' CHECK (category IN ('savings', 'purchase'));

-- 3. Create public.goal_allocations ledger
CREATE TABLE public.goal_allocations (
  id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  goal_id uuid REFERENCES public.goals(id) ON DELETE CASCADE NOT NULL,
  amount numeric(12, 2) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS for goal_allocations
ALTER TABLE public.goal_allocations ENABLE ROW LEVEL SECURITY;

-- goal_allocations RLS policies
CREATE POLICY "Users can view own goal allocations" ON public.goal_allocations FOR SELECT USING ( auth.uid() = user_id );
CREATE POLICY "Users can insert own goal allocations" ON public.goal_allocations FOR INSERT WITH CHECK ( auth.uid() = user_id );
CREATE POLICY "Users can update own goal allocations" ON public.goal_allocations FOR UPDATE USING ( auth.uid() = user_id );
CREATE POLICY "Users can delete own goal allocations" ON public.goal_allocations FOR DELETE USING ( auth.uid() = user_id );

-- 4. Create RPC function for recent allocation summary
CREATE OR REPLACE FUNCTION public.get_recent_allocation_summary(days int)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  SELECT jsonb_build_object(
    'totalSavings', COALESCE(SUM(amount) FILTER (WHERE g.category = 'savings'), 0),
    'totalPurchases', COALESCE(SUM(amount) FILTER (WHERE g.category = 'purchase'), 0)
  ) INTO result
  FROM public.goal_allocations ga
  JOIN public.goals g ON ga.goal_id = g.id
  WHERE ga.user_id = auth.uid()
    AND ga.created_at > now() - (days || ' days')::interval;

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
