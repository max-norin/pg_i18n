CREATE FUNCTION language ("value" TEXT)
    RETURNS BOOLEAN
AS $$
BEGIN
    RETURN ("value" ~* '^[a-z]{2,3}$');
END
$$
    LANGUAGE plpgsql
    IMMUTABLE
    RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION language (TEXT) IS 'ISO 639';
