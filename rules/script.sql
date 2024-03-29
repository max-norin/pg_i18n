CREATE FUNCTION script_rule ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[A-Z][a-z]{3}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION script_rule (TEXT) IS 'ISO 15924';

