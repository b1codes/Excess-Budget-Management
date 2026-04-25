-- Create enum for category type
DO $$ BEGIN
    CREATE TYPE public.category_type AS ENUM ('expense', 'income');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add category_type to budget_categories
ALTER TABLE public.budget_categories 
ADD COLUMN IF NOT EXISTS category_type public.category_type DEFAULT 'expense';

-- Ensure category_type is not null after initialization
UPDATE public.budget_categories SET category_type = 'expense' WHERE category_type IS NULL;
ALTER TABLE public.budget_categories ALTER COLUMN category_type SET NOT NULL;

-- Add budget_category_id to extra_income
ALTER TABLE public.extra_income 
ADD COLUMN IF NOT EXISTS budget_category_id uuid REFERENCES public.budget_categories(id) ON DELETE SET NULL;

-- Update existing update_budget_spent_amount function (from 20260419000000) to respect category_type
CREATE OR REPLACE FUNCTION public.update_budget_spent_amount()
RETURNS TRIGGER AS $$
DECLARE
    v_cat_type public.category_type;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = NEW.budget_category_id;
        IF v_cat_type = 'income' THEN
            -- For income categories, an expense REDUCES the spent_amount (balance)
            UPDATE public.budget_categories SET spent_amount = spent_amount - NEW.amount WHERE id = NEW.budget_category_id;
        ELSE
            -- For expense categories, an expense INCREASES the spent_amount
            UPDATE public.budget_categories SET spent_amount = spent_amount + NEW.amount WHERE id = NEW.budget_category_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = OLD.budget_category_id;
        IF v_cat_type = 'income' THEN
            UPDATE public.budget_categories SET spent_amount = spent_amount + OLD.amount WHERE id = OLD.budget_category_id;
        ELSE
            UPDATE public.budget_categories SET spent_amount = spent_amount - OLD.amount WHERE id = OLD.budget_category_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Handle potential category change or amount change
        IF OLD.budget_category_id = NEW.budget_category_id THEN
            SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = NEW.budget_category_id;
            IF v_cat_type = 'income' THEN
                UPDATE public.budget_categories SET spent_amount = spent_amount + OLD.amount - NEW.amount WHERE id = NEW.budget_category_id;
            ELSE
                UPDATE public.budget_categories SET spent_amount = spent_amount - OLD.amount + NEW.amount WHERE id = NEW.budget_category_id;
            END IF;
        ELSE
            -- Old category cleanup
            SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = OLD.budget_category_id;
            IF v_cat_type = 'income' THEN
                UPDATE public.budget_categories SET spent_amount = spent_amount + OLD.amount WHERE id = OLD.budget_category_id;
            ELSE
                UPDATE public.budget_categories SET spent_amount = spent_amount - OLD.amount WHERE id = OLD.budget_category_id;
            END IF;
            -- New category application
            SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = NEW.budget_category_id;
            IF v_cat_type = 'income' THEN
                UPDATE public.budget_categories SET spent_amount = spent_amount - NEW.amount WHERE id = NEW.budget_category_id;
            ELSE
                UPDATE public.budget_categories SET spent_amount = spent_amount + NEW.amount WHERE id = NEW.budget_category_id;
            END IF;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger function to update budget balance from income (Optimized)
CREATE OR REPLACE FUNCTION public.handle_income_budget_update()
RETURNS TRIGGER AS $$
DECLARE
    v_cat_type public.category_type;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.budget_category_id IS NOT NULL THEN
            SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = NEW.budget_category_id;
            IF v_cat_type = 'income' THEN
                UPDATE public.budget_categories SET spent_amount = spent_amount + NEW.amount WHERE id = NEW.budget_category_id;
            ELSE
                UPDATE public.budget_categories SET spent_amount = spent_amount - NEW.amount WHERE id = NEW.budget_category_id;
            END IF;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.budget_category_id IS NOT NULL THEN
            SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = OLD.budget_category_id;
            IF v_cat_type = 'income' THEN
                UPDATE public.budget_categories SET spent_amount = spent_amount - OLD.amount WHERE id = OLD.budget_category_id;
            ELSE
                UPDATE public.budget_categories SET spent_amount = spent_amount + OLD.amount WHERE id = OLD.budget_category_id;
            END IF;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        -- Check if category remains the same to perform a single delta update
        IF OLD.budget_category_id = NEW.budget_category_id THEN
            IF NEW.budget_category_id IS NOT NULL THEN
                SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = NEW.budget_category_id;
                IF v_cat_type = 'income' THEN
                    UPDATE public.budget_categories SET spent_amount = spent_amount - OLD.amount + NEW.amount WHERE id = NEW.budget_category_id;
                ELSE
                    UPDATE public.budget_categories SET spent_amount = spent_amount + OLD.amount - NEW.amount WHERE id = NEW.budget_category_id;
                END IF;
            END IF;
        ELSE
            -- Handle category change
            IF OLD.budget_category_id IS NOT NULL THEN
                SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = OLD.budget_category_id;
                IF v_cat_type = 'income' THEN
                    UPDATE public.budget_categories SET spent_amount = spent_amount - OLD.amount WHERE id = OLD.budget_category_id;
                ELSE
                    UPDATE public.budget_categories SET spent_amount = spent_amount + OLD.amount WHERE id = OLD.budget_category_id;
                END IF;
            END IF;
            IF NEW.budget_category_id IS NOT NULL THEN
                SELECT category_type INTO v_cat_type FROM public.budget_categories WHERE id = NEW.budget_category_id;
                IF v_cat_type = 'income' THEN
                    UPDATE public.budget_categories SET spent_amount = spent_amount + NEW.amount WHERE id = NEW.budget_category_id;
                ELSE
                    UPDATE public.budget_categories SET spent_amount = spent_amount - NEW.amount WHERE id = NEW.budget_category_id;
                END IF;
            END IF;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for extra_income
DROP TRIGGER IF EXISTS trigger_income_budget_update ON public.extra_income;
CREATE TRIGGER trigger_income_budget_update
AFTER INSERT OR UPDATE OR DELETE ON public.extra_income
FOR EACH ROW EXECUTE FUNCTION public.handle_income_budget_update();
