CREATE FUNCTION public.insert_using_records ("table" REGCLASS, "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    -- pk  - primary key
    -- sk  - secondary key
    -- main
    "result"              JSONB NOT NULL  = '{}';
    "record"              JSONB NOT NULL  = row_to_json(NEW);
    -- table
    "pk_columns" CONSTANT TEXT[] NOT NULL = public.get_primary_key("table");
    "pk_values"           TEXT[];
    "sk_columns" CONSTANT TEXT[] NOT NULL = public.get_columns("table", FALSE) OPERATOR ( public.- ) "pk_columns";
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
    EXECUTE format(
                'INSERT INTO %1s (%2s) VALUES (%3s) RETURNING to_jsonb(%4s.*);',
                "table",
                array_to_string("pk_columns" || "sk_columns", ','),
                array_to_string("pk_values"  || "sk_values", ','),
                "table"
            )
        INTO "result" USING "new";

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE -- может делать всё, что угодно, в том числе, модифицировать базу данных
SECURITY DEFINER -- функция выполняется с правами пользователя, владеющего ей
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION public.insert_using_records (REGCLASS, RECORD) IS 'insert into table $1 using NEW record';
