CREATE FUNCTION jsonb_pk_table_object ("relid" OID, "record" JSONB)
    RETURNS JSONB
    AS $$
DECLARE
    -- main
    "result"              JSONB  NOT NULL  = '{}';
    -- primary keys
    "pk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("relid");
    -- helpers
    "column"              TEXT;
BEGIN
    FOREACH "column" IN ARRAY "pk_columns" LOOP
        "result" = jsonb_set("result", ARRAY ["column"], "record" -> "column");
    END LOOP;

    RETURN "result";
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION jsonb_pk_table_object (OID, JSONB) IS 'get jsonb object with primary key columns from table $1 and values from record $2';
