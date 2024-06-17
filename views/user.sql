-- создание представления для пользовательского способа
-- представление не только отображает данные, но даёт возможность редактирования
CREATE PROCEDURE public.create_user_view ("name" TEXT, "baserel" REGCLASS, "tranrel" REGCLASS)
    AS $$
DECLARE
    -- имя будущей таблицы
    "name"       CONSTANT TEXT NOT NULL   = COALESCE(public.format_table_name("name"), public.format_table_name("baserel"::TEXT, 'v_'));
    "columns"    CONSTANT TEXT[] NOT NULL = public.get_columns("baserel");
    "pk_columns" CONSTANT TEXT[]          = public.get_primary_key("baserel");
    "select"              TEXT[] = '{}';
BEGIN
    -- проверка, что таблицы заданы
    IF ("baserel" IS NULL) OR ("tranrel" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" and "tranrel" cannot be NULL';
    END IF;
    -- проверка, что pk_columns существуют
    IF ("pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" table must have primary keys';
    END IF;

    -- добавить колонку lang_is_default
    "select" = array_append('(b."default_lang" = bt."lang") IS TRUE AS "lang_is_default"'::TEXT, "select");

    -- create view
    -- USING — это сокращённая запись условия, полезная в ситуации, когда с обеих сторон соединения столбцы имеют одинаковые имена
    -- %s - вставляется как простая строка
    -- https://postgrespro.ru/docs/postgrespro/current/functions-string#FUNCTIONS-STRING-FORMAT
    EXECUTE format('
        CREATE VIEW %1s AS
        SELECT %2s
            FROM %3s b
            LEFT JOIN %4s bt USING (%5s)
            WHERE TRUE;
    ', "name", array_to_string("select", ','), "baserel", "tranrel", array_to_string("pk_columns", ','));

    -- создание triggers для редактиварония представления
    -- %L - равнозначно вызову quote_nullable. Переводит данное значение в текстовый вид и заключает в апострофы
    -- https://postgrespro.ru/docs/postgrespro/current/functions-string#FUNCTIONS-STRING-FORMAT
    -- EXECUTE format('
    --     CREATE TRIGGER "insert"
    --         INSTEAD OF INSERT
    --         ON %1s FOR EACH ROW
    --     EXECUTE FUNCTION public.trigger_insert_user_view(%2L, %3L);
    -- ', "name", "baserel", "tranrel");
    -- EXECUTE format('
    --     CREATE TRIGGER "update"
    --         INSTEAD OF UPDATE
    --         ON %1s FOR EACH ROW
    --     EXECUTE FUNCTION public.trigger_update_user_view(%2L, %3L);
    -- ', "name", "baserel", "tranrel");
END
$$
LANGUAGE plpgsql;

