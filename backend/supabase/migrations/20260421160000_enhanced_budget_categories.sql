-- Add icon_code and color_hex to budget_categories
ALTER TABLE public.budget_categories 
ADD COLUMN IF NOT EXISTS icon_code INTEGER,
ADD COLUMN IF NOT EXISTS color_hex TEXT;

-- Update existing records with default values if needed
-- For example, setting default color to a greyish value and default icon to a generic one
UPDATE public.budget_categories 
SET color_hex = '#9E9E9E', icon_code = 58820 -- Icons.category code point
WHERE color_hex IS NULL OR icon_code IS NULL;
