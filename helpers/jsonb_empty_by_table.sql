CREATE FUNCTION jsonb_empty_by_table ("relid" OID)
    RETURNS JSONB
    AS $$
DECLARE
    "columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("relid");
    "result"           JSONB           = '{}';
    "column"           TEXT;
BEGIN
    FOREACH "column" IN ARRAY "columns" LOOP
        "result" = jsonb_insert("result", ARRAY ["column"], 'null');
    END LOOP;

    RETURN "result";
END
$$
LANGUAGE plpgsql
IMMUTABLE;

COMMENT ON FUNCTION jsonb_empty_by_table (OID) IS 'get jsonb object with empty columns from table $1';
