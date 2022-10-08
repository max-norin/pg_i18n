CREATE OR REPLACE FUNCTION insert_using_arrays ("table" REGCLASS, "columns" TEXT[],  "values" TEXT[], "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    "result"           JSONB NOT NULL  = '{}';
    "columns" CONSTANT TEXT  NOT NULL  = array_to_string("columns", ',');
    "values"  CONSTANT TEXT  NOT NULL  = array_to_string("values", ',');
BEGIN
    EXECUTE format('INSERT INTO %1s (%2s) VALUES (%3s) RETURNING to_jsonb(%4s.*);', "table", "columns", "values", "table")
        INTO "result" USING "new";

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION insert_using_arrays (REGCLASS, TEXT[], TEXT[], RECORD) IS 'insert into table $1 using array of columns, array of values and NEW record';
