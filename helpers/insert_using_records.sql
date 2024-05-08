CREATE FUNCTION insert_using_records ("table" REGCLASS, "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    -- pk  - primary key
    -- sk  - secondary key
    -- main
    "result"              JSONB NOT NULL  = '{}';
    "record"              JSONB NOT NULL  = row_to_json(NEW);
    -- table
    "pk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("table");
    "pk_values"           TEXT[];
    "sk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("table", FALSE) OPERATOR ( @extschema@.- ) "pk_columns";
    "sk_values"           TEXT[];
    -- helpers
    "column"              TEXT;
BEGIN
    -- get primary key value for table
    FOREACH "column" IN ARRAY "pk_columns" LOOP
        -- all columns in primary key is not NULL, DEFAULT for sequence
        IF NOT ("record" ? "column") OR ("record" ->> "column" IS NULL) THEN
            "pk_values" = array_append("pk_values", 'DEFAULT');
        ELSE
            "pk_values" = array_append("pk_values", format('$1.%I', "column"));
        END IF;
    END LOOP;
    -- get other column values table
    FOREACH "column" IN ARRAY "sk_columns" LOOP
        "sk_values" = array_append("sk_values", format('$1.%I', "column"));
    END LOOP;
    -- insert and return record from table
    "result" = @extschema@.insert_using_arrays("table", "pk_columns" || "sk_columns", "pk_values"  || "sk_values", NEW);

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION insert_using_records (REGCLASS, RECORD) IS 'insert into table $1 using NEW record';
