CREATE FUNCTION update_using_arrays ("table" REGCLASS, "pk_columns" TEXT[], "pk_values" TEXT[], "ch_columns" TEXT[], "ch_values" TEXT[], "old" RECORD, "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    -- pk  - primary key
    -- ch  - changed
    "result"              JSONB NOT NULL = '{}';
    "pk_columns" CONSTANT TEXT  NOT NULL = array_to_string("pk_columns", ',');
    "pk_values"  CONSTANT TEXT  NOT NULL = array_to_string("pk_values",  ',');
    "ch_columns" CONSTANT TEXT  NOT NULL = array_to_string("ch_columns", ',');
    "ch_values"  CONSTANT TEXT  NOT NULL = array_to_string("ch_values",  ',');
BEGIN
    EXECUTE format('UPDATE %1s SET (%2s)=ROW(%3s) WHERE (%4s)=(%5s) RETURNING to_json(%6s.*);', "table", "ch_columns", "ch_values", "pk_columns", "pk_values", "table")
        INTO "result" USING "old", "new";

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION update_using_arrays (REGCLASS, TEXT[], TEXT[], TEXT[], TEXT[], RECORD, RECORD) IS 'update table $1 using array of primary keys, array of values and OLD NEW records';
