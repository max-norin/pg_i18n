-- создание представления словарного или пользовательского способа
-- представление не только отображает данные, но даёт возможность редактирования
CREATE OR REPLACE PROCEDURE public.create_i18n_view ("baserel" OID, "tranrel" OID)
    AS $$
DECLARE
    "pk_columns"     CONSTANT TEXT[] = public.get_primary_key("baserel");
    -- массив для составления выражения JOIN ON <...>
    "pk_columns_on"           TEXT[] = '{}';
    "base_columns"   CONSTANT TEXT[] = public.get_columns("baserel");
    "tran_columns"   CONSTANT TEXT[] = public.get_columns("tranrel");
    "column"                 TEXT;
    "name"                   TEXT;
    "select"                 TEXT[] = '{}';
    "query"                  TEXT = '';
BEGIN
    -- проверка, что pk_columns существуют
    IF ("pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" table must have primary keys';
    END IF;

    -- далее b - базовая таблица, t - таблица переводов

    "name" = 'v_dictionary_default';
    -- установка select
    -- добавление колонок базовой таблицы, включая первичные ключи, но без повторяющихся колонок таблицы переводов
    FOREACH "column" IN ARRAY "pk_columns" || ("base_columns" OPERATOR ( public.- ) "tran_columns") LOOP
        "select" = array_append("select", format('b.%1I', "column"));
    END LOOP;
    -- добавление колонок из таблицы переводов
    FOREACH "column" IN ARRAY "tran_columns" OPERATOR ( public.- ) '{lang}'::TEXT[] OPERATOR ( public.- ) "pk_columns" LOOP
        -- если колонка column есть среди колонок таблицы baserel, то использовать особую вставку с использованием CASE
        IF "column" = ANY ("base_columns") THEN
            "select" = array_append("select", format('CASE WHEN (t.*) IS NULL THEN b.%1$I ELSE t.%1$I END AS %1$I', "column"));
        ELSE
            "select" = array_append("select", format('t.%1I', "column"));
        END IF;
    END LOOP;
    -- установить выражение сравнения для JOIN ON <...>
    FOREACH "column" IN ARRAY "pk_columns" LOOP
        "pk_columns_on" = array_append("pk_columns_on", format('b.%1$I = t.%1$I', "column"));
    END LOOP;

    -- создание представления
    -- %s - вставляется как простая строка
    -- %I - вставляется как идентификатора SQL, экранируется при необходимости
    "query" = format('SELECT %1s FROM %2I b LEFT JOIN %3I t ON %4s AND b.default_lang = t.lang WHERE TRUE',
                   array_to_string("select", ','),
                   "baserel"::REGCLASS,
                   "tranrel"::REGCLASS,
                   array_to_string("pk_columns_on", ' AND '));
    RAISE NOTICE USING MESSAGE = "query";
    EXECUTE format('CREATE VIEW %1I AS %2s;', "name", "query");

    "name" = 'v_dictionary';
    -- установка select
    -- свойство lang из таблицы langs, используется из объединения CROSS JOIN "langs"
    "select" = array_prepend('"langs"."lang"', "select");
    "select" = array_prepend('(b.default_lang = langs.lang) IS TRUE AS is_default_lang', "select");
    "select" = array_prepend('NOT ((t.*) IS NULL) AS "is_tran"', "select");

    -- создание представления
    -- %s - вставляется как простая строка
    -- %I - вставляется как идентификатора SQL, экранируется при необходимости
    -- CROSS JOIN "langs", чтобы в представлении были указанны все языки из таблицы "langs"
    "query" = format('WITH b AS (%1s) SELECT %2s FROM b CROSS JOIN public."langs" LEFT JOIN %3I t ON %4s AND langs.lang = t.lang',
                     "query",
                     array_to_string("select", ','),
                     "tranrel"::REGCLASS,
                     array_to_string("pk_columns_on", ' AND '));
    RAISE NOTICE USING MESSAGE = "query";
    EXECUTE format('CREATE VIEW %1I AS %2s;', "name", "query");
END
$$
LANGUAGE plpgsql;

-- TODO проверить, что если отправить null в параметры, то работать не будет
