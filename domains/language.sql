CREATE DOMAIN public.LANGUAGE AS VARCHAR(3)
CHECK (public.language (VALUE));

COMMENT ON DOMAIN public.LANGUAGE IS 'ISO 639';

