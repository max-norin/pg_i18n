CREATE FUNCTION update_using_records ("table" REGCLASS, "ch_columns" TEXT[], "old" RECORD, "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    -- pk  - primary key
    -- ch  - changed
    -- main
    "result"                     JSONB  NOT NULL = '{}';
    -- table
    "columns"           CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("table", FALSE);
    -- primary keys
    "pk_columns"        CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("table");
    "pk_values"                  TEXT[];
    -- changed values
    "ch_columns"        CONSTANT TEXT[] NOT NULL = "columns" OPERATOR ( @extschema@.& ) "ch_columns";
    "ch_values"                  TEXT[];
    -- helpers
    "column"                     TEXT;
BEGIN
    IF array_length("ch_columns", 1) IS NOT NULL THEN
        -- set primary key values
        FOREACH "column" IN ARRAY "pk_columns" LOOP
            "pk_values" = array_append("pk_values", format('$1.%I', "column"));
        END LOOP;
        -- set changed values
        FOREACH "column" IN ARRAY "ch_columns" LOOP
            "ch_values" = array_append("ch_values", format('$2.%I', "column"));
        END LOOP;
        -- update and return record from table
        "result" = @extschema@.update_using_arrays("table", "pk_columns", "pk_values", "ch_columns", "ch_values", OLD, NEW);
    END IF;

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION update_using_records (REGCLASS, TEXT[], RECORD, RECORD) IS 'update table $1 using change columns $2 and OLD NEW records';
