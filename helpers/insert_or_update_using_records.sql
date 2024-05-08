CREATE FUNCTION insert_or_update_using_records ("table" REGCLASS, "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    -- pk - primary key
    -- sk - secondary key
    "pk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("table");
    "pk_values"           TEXT[];
    "sk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("table", FALSE) OPERATOR ( dictionaries.- ) "pk_columns";
    "sk_values"           TEXT[];
    --helpers
    "column"              TEXT;
BEGIN
    -- set primary key
    FOREACH "column" IN ARRAY "pk_columns" LOOP
            "pk_values" = array_append("pk_values", format('$1.%I', "column"));
        END LOOP;
    -- set secondary key
    FOREACH "column" IN ARRAY "sk_columns" LOOP
            "sk_values" = array_append("sk_values", format('$1.%I', "column"));
        END LOOP;

    RETURN @extschema@.insert_or_update_using_arrays("table", "pk_columns" || "sk_columns", "pk_values" || "sk_values", "sk_columns", "sk_values", NEW);
END
$$
    LANGUAGE plpgsql
    VOLATILE
    SECURITY DEFINER
    RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION insert_or_update_using_records (REGCLASS, RECORD) IS 'insert or update table using NEW record';
