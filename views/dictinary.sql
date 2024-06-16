-- создание представления для словарного способа
-- представление не только отображает данные, но даёт возможность редактирования
CREATE PROCEDURE public.create_dictionary_view ("name" TEXT, "baserel" OID, "tranrel" OID)
    AS $$
DECLARE
    -- имя будущей таблицы
    "name"        CONSTANT TEXT   NOT NULL = COALESCE("name", 'v_' || "baserel"::REGCLASS::TEXT);
    "pk_columns"  CONSTANT TEXT[] = public.get_primary_key("baserel");
    "b_columns"   CONSTANT TEXT[] NOT NULL = public.get_columns("baserel");
    "t_columns"   CONSTANT TEXT[] NOT NULL = public.get_columns("tranrel");
    "column"               TEXT;
    "select"               TEXT[] = '{}';
BEGIN
    -- проверка, что таблицы заданы
    IF ("baserel" IS NULL) OR ("tranrel" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" and "tranrel" cannot be NULL';
    END IF;
    -- проверка, что pk_columns существуют
    IF ("pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" table must have primary keys';
    END IF;

    -- далее b - базовая таблица, t - таблица переводов

    -- установка select
    -- если в таблице переводов нет записей, то это строка взята из таблицы по умолчанию - свойство is_default
    "select" = array_append("select", '(t.*) IS NULL AS "is_default"');
    -- свойство язык из таблицы langs, используется из слияния CROSS JOIN "langs"
    "select" = array_append("select", '"langs"."lang"');
    FOREACH "column" IN ARRAY "b_columns" LOOP
        -- если колонка column есть среди колонок в таблице tranrel,
        -- то тогда использовать особую вставку с использованием COALESCE
        IF "column" = ANY ("t_columns") THEN
            "select" = array_append("select", format('COALESCE(t.%1$I, b.%1$I) AS %1$I', "column"));
        ELSE
            "select" = array_append("select", format('b.%1$I', "column"));
        END IF;
    END LOOP;

    -- create view
    -- CROSS JOIN "langs", чтобы в представлении были указанны все языки из таблицы "langs"
    -- USING — это сокращённая запись условия, полезная в ситуации,
    -- когда с обеих сторон соединения столбцы имеют одинаковые имена
    -- %s - вставляется как простая строка
    -- https://postgrespro.ru/docs/postgrespro/current/functions-string#FUNCTIONS-STRING-FORMAT
    EXECUTE format('
        CREATE VIEW %1s AS
        SELECT %2s
            FROM %3s b
            CROSS JOIN public."langs"
            LEFT JOIN %4s t USING ("lang", %5s)
            WHERE TRUE;
    ', "name", array_to_string("select", ','), "baserel"::REGCLASS, "tranrel"::REGCLASS, array_to_string("pk_columns", ','));

    -- создание trigger для редактиварония представления
    -- использует %L так как тут необходимо передавать текстовые значения
    -- %L - равнозначно вызову quote_nullable. Переводит данное значение в текстовый вид и заключает в апострофы
    -- https://postgrespro.ru/docs/postgrespro/current/functions-string#FUNCTIONS-STRING-FORMAT
    -- EXECUTE format('
    --     CREATE TRIGGER "update"
    --         INSTEAD OF UPDATE
    --         ON %1s FOR EACH ROW
    --     EXECUTE FUNCTION public.trigger_update_dictionary_view(%2L, %3L);
    -- ', "name", "baserel", "tranrel");
END
$$
LANGUAGE plpgsql;

