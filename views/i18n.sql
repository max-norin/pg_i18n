-- создание представления словарного или пользовательского способа
-- представление не только отображает данные, но даёт возможность редактирования
CREATE OR REPLACE PROCEDURE public.create_i18n_view ("baserel" OID, "tranrel" OID)
    AS $$
DECLARE
    "pk_columns"    CONSTANT TEXT[] = public.get_primary_key("baserel");
    -- массив для составления выражения JOIN ON <...> с primary_key, нет возможности использовать USING
    "pk_join_on"             TEXT[] = '{}';
    "base_columns"  CONSTANT TEXT[] = public.get_columns("baserel");
    "tran_columns"  CONSTANT TEXT[] = public.get_columns("tranrel");
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

    -- установка выражения сравнения для JOIN ON <...>
    FOREACH "column" IN ARRAY "pk_columns" LOOP
        "pk_join_on" = array_append("pk_join_on", format('b.%1$I = t.%1$I', "column"));
    END LOOP;

    -- установка имени представления
    "name" = 'v_dictionary_default';

    -- установка select
    -- добавление колонок базовой таблицы, включая первичные ключи, но без одноименных колонок таблицы переводов
    FOREACH "column" IN ARRAY "pk_columns" || ("base_columns" OPERATOR ( public.- ) "tran_columns") LOOP
        "select" = array_append("select", format('b.%1I', "column"));
    END LOOP;
    -- добавление колонок из таблицы переводов
    FOREACH "column" IN ARRAY "tran_columns" OPERATOR ( public.- ) '{lang}'::TEXT[] OPERATOR ( public.- ) "pk_columns" LOOP
        -- если колонка есть среди колонок таблицы baserel, то использовать особую вставку CASE
        "select" = array_append("select", CASE WHEN "column" = ANY ("base_columns")
            THEN format('CASE WHEN (t.*) IS NULL THEN b.%1$I ELSE t.%1$I END AS %1$I', "column")
            ELSE format('t.%1I', "column") END);
    END LOOP;

    -- создание представления с записями языка по-умолчанию
    -- %s - вставляется как простая строка
    -- %I - вставляется как идентификатора SQL, экранируется при необходимости
    -- LEFT JOIN tranrel - соединяем с имеющимися переводами
    "query" = format('SELECT %1s FROM %2I b LEFT JOIN %3I t ON %4s AND b."default_lang" = t."lang"',
                   array_to_string("select", ','),
                   "baserel"::REGCLASS,
                   "tranrel"::REGCLASS,
                   array_to_string("pk_join_on", ' AND '));
    EXECUTE format('CREATE VIEW %1I AS %2s;', "name", "query");

    -- далее b - таблица дефолтных значений, t - таблица переводов, l - таблица языков

    -- установка имени представления
    "name" = 'v_dictionary';

    -- установка select
    -- колонка - lang из таблицы langs, используется из объединения CROSS JOIN "langs"
    "select" = array_prepend('l."lang"', "select");
    -- колонка - запись с дефолтным языком
    "select" = array_prepend('(b."default_lang" = l."lang") IS TRUE AS "is_default_lang"', "select");
    -- колонка - является переводом
    "select" = array_prepend('NOT ((t.*) IS NULL) AS "is_tran"', "select");

    -- создание представления с записями по всем языкам
    -- %s - вставляется как простая строка
    -- %I - вставляется как идентификатора SQL, экранируется при необходимости
    -- WITH - общее табличное выражение с представлением из предыдущего запроса
    -- CROSS JOIN "langs" - соединение значения со всеми языками
    -- LEFT JOIN tranrel - соединение с имеющимися переводами
    "query" = format('WITH b AS (%1s) SELECT %2s FROM b CROSS JOIN public."langs" l LEFT JOIN %3I t ON %4s AND l."lang" = t."lang"',
                     "query", -- предыдущий запрос
                     array_to_string("select", ','),
                     "tranrel"::REGCLASS,
                     array_to_string("pk_join_on", ' AND '));
    EXECUTE format('CREATE VIEW %1I AS %2s;', "name", "query");
END
$$
LANGUAGE plpgsql;

-- TODO проверить, что если отправить null в параметры, то работать не будет
