CREATE FUNCTION insert_or_update_using_arrays ("table" REGCLASS, "columns" TEXT[], "values" TEXT[], "ch_columns" TEXT[], "ch_values" TEXT[], "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    -- ch  - changed
    "result"              JSONB NOT NULL = '{}';
    "columns"    CONSTANT TEXT  NOT NULL = array_to_string("columns", ',');
    "values"     CONSTANT TEXT  NOT NULL = array_to_string("values", ',');
    "ch_columns" CONSTANT TEXT  NOT NULL = array_to_string("ch_columns", ',');
    "ch_values"  CONSTANT TEXT  NOT NULL = array_to_string("ch_values", ',');
    "pk_name"    CONSTANT TEXT  NOT NULL = @extschema@.get_primary_key_name("table");
BEGIN
    EXECUTE format('
        INSERT INTO %1s (%2s) VALUES (%3s)
            ON CONFLICT ON CONSTRAINT %4I
            DO UPDATE SET (%5s)=ROW(%6s)
            RETURNING to_json(%7s.*);',
                   "table", "columns", "values",
                   "pk_name",
                   "ch_columns", "ch_values",
                   "table")
        INTO "result" USING "new";

    RETURN "result";
END
$$
    LANGUAGE plpgsql
    VOLATILE
    SECURITY DEFINER
    RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION insert_or_update_using_arrays (REGCLASS, TEXT[], TEXT[], TEXT[], TEXT[], RECORD) IS 'insert or update table $1 using array of columns keys, array of values and NEW record';
