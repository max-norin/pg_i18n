CREATE FUNCTION jsonb_object_fields ("value" JSONB, "paths" TEXT[])
    RETURNS JSONB
    AS $$
BEGIN
    RETURN "value" - (ARRAY (SELECT jsonb_object_keys("value")) OPERATOR ( @extschema@.- ) "paths");
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION jsonb_object_fields (JSONB, TEXT[]) IS 'get json object fields';

CREATE OPERATOR -> (
    LEFTARG = JSONB, RIGHTARG = TEXT[], FUNCTION = jsonb_object_fields
);

COMMENT ON OPERATOR -> (JSONB, TEXT[]) IS 'get json object fields';

