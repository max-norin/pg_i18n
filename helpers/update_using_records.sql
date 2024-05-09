-- обновление значения old в таблице table на new используя колонки ch_columns
CREATE FUNCTION @extschema@.update_using_records ("table" REGCLASS, "ch_columns" TEXT[], "old" RECORD, "new" RECORD)
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
    -- колонки и значения primary key
    "pk_columns"        CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("table");
    "pk_values"                  TEXT[];
    -- changed values
    -- колонки и значения changed key
    -- получения объединения columns и ch_columns, чтобы наверняка использовать колонки таблицы table
    "ch_columns"        CONSTANT TEXT[] NOT NULL = "columns" OPERATOR ( @extschema@.& ) "ch_columns";
    "ch_values"                  TEXT[];
    -- helpers
    "column"                     TEXT;
BEGIN
    -- если массив ch_columns имеет колонки
    IF array_length("ch_columns", 1) IS NOT NULL THEN
        -- set primary key values
        FOREACH "column" IN ARRAY "pk_columns" LOOP
            -- $1 - это old значения
            -- %I - равнозначно вызову quote_ident. Переданная строка оформляется для использования
            -- в качестве идентификатора в SQL -операторе. При необходимости идентификатор заключается в кавычки.
            "pk_values" = array_append("pk_values", format('$1.%I', "column"));
        END LOOP;
        -- set changed values
        FOREACH "column" IN ARRAY "ch_columns" LOOP
            -- $2 - это new значения
            -- %I - равнозначно вызову quote_ident. Переданная строка оформляется для использования
            -- в качестве идентификатора в SQL -операторе. При необходимости идентификатор заключается в кавычки.
            "ch_values" = array_append("ch_values", format('$2.%I', "column"));
        END LOOP;

        -- в USING формируют значения, которые будут вставлены в команду. Для этого используются символы $1 $2
        -- https://postgrespro.ru/docs/postgrespro/current/plpgsql-statements
        EXECUTE format(
                    'UPDATE %1s SET (%2s)=ROW(%3s) WHERE (%4s)=(%5s) RETURNING to_json(%6s.*);',
                    "table",
                    array_to_string("ch_columns", ','),
                    array_to_string("ch_values", ','),
                    array_to_string("pk_columns", ','),
                    array_to_string("pk_values", ','),
                    "table"
                )
            INTO "result" USING "old", "new";
    END IF;

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE -- может делать всё, что угодно, в том числе, модифицировать базу данных
SECURITY DEFINER  -- функция выполняется с правами пользователя, владеющего ей
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION @extschema@.update_using_records (REGCLASS, TEXT[], RECORD, RECORD) IS 'update table $1 using change columns $2 and OLD NEW records';
