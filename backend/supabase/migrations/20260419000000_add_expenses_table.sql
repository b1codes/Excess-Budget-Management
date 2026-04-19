-- backend/supabase/migrations/20260419000000_add_expenses_table.sql
CREATE TABLE public.expenses (
  id uuid DEFAULT extensions.uuid_generate_v4() PRIMARY KEY,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  budget_category_id uuid REFERENCES public.budget_categories(id) ON DELETE CASCADE NOT NULL,
  amount numeric(12, 2) NOT NULL,
  description text,
  date date NOT NULL DEFAULT current_date,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own expenses" ON public.expenses FOR SELECT USING ( auth.uid() = user_id );
CREATE POLICY "Users can insert own expenses" ON public.expenses FOR INSERT WITH CHECK ( auth.uid() = user_id );
CREATE POLICY "Users can update own expenses" ON public.expenses FOR UPDATE USING ( auth.uid() = user_id );
CREATE POLICY "Users can delete own expenses" ON public.expenses FOR DELETE USING ( auth.uid() = user_id );

-- Also create a trigger to update the budget_categories spent_amount
CREATE OR REPLACE FUNCTION public.update_budget_spent_amount()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.budget_categories 
    SET spent_amount = spent_amount + NEW.amount 
    WHERE id = NEW.budget_category_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.budget_categories 
    SET spent_amount = spent_amount - OLD.amount 
    WHERE id = OLD.budget_category_id;
  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.budget_categories 
    SET spent_amount = spent_amount - OLD.amount + NEW.amount 
    WHERE id = NEW.budget_category_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_update_budget_spent
AFTER INSERT OR UPDATE OR DELETE ON public.expenses
FOR EACH ROW EXECUTE FUNCTION public.update_budget_spent_amount();
