CREATE FUNCTION public.insert_or_update_using_records ("table" REGCLASS, "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    "result"              JSONB NOT NULL = '{}';
    -- pk - primary key
    -- sk - secondary key
    "pk_columns" CONSTANT TEXT[] NOT NULL = public.get_primary_key("table");
    "pk_values"           TEXT[];
    "sk_columns" CONSTANT TEXT[] NOT NULL = public.get_columns("table", FALSE) OPERATOR ( dictionaries.- ) "pk_columns";
    "sk_values"           TEXT[];
    --helpers
    "column"              TEXT;
    "pk_name"    CONSTANT TEXT  NOT NULL = public.get_primary_key_name("table");
BEGIN
    -- set primary key
    FOREACH "column" IN ARRAY "pk_columns" LOOP
            "pk_values" = array_append("pk_values", format('$1.%I', "column"));
        END LOOP;
    -- set secondary key
    FOREACH "column" IN ARRAY "sk_columns" LOOP
            "sk_values" = array_append("sk_values", format('$1.%I', "column"));
        END LOOP;

    EXECUTE format('
        INSERT INTO %1s (%2s) VALUES (%3s)
            ON CONFLICT ON CONSTRAINT %4I
            DO UPDATE SET (%5s)=ROW(%6s)
            RETURNING to_json(%7s.*);',
                   "table", array_to_string("pk_columns" || "sk_columns", ','), array_to_string("pk_values" || "sk_values", ','),
                   "pk_name",
                   array_to_string("sk_columns", ','), array_to_string("sk_values", ','),
                   "table")
        INTO "result" USING "new";

    RETURN "result";
END
$$
    LANGUAGE plpgsql
    VOLATILE -- может делать всё, что угодно, в том числе, модифицировать базу данных
    SECURITY DEFINER -- функция выполняется с правами пользователя, владеющего ей
    RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION public.insert_or_update_using_records (REGCLASS, RECORD) IS 'insert or update table using NEW record';
