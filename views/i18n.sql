-- создание представления словарного или пользовательского способа
-- представление не только отображает данные, но даёт возможность редактирования
CREATE OR REPLACE PROCEDURE public.create_i18n_view ("baserel" OID, "tranrel" OID)
    AS $$
DECLARE
    "pk_columns"     CONSTANT TEXT[] = public.get_primary_key("baserel");
    "pk_columns_on"           TEXT[] = '{}';
    "base_columns"   CONSTANT TEXT[] = public.get_columns("baserel");
    "tran_columns"   CONSTANT TEXT[] = public.get_columns("tranrel");
    "column"                 TEXT;
    "name"                   TEXT;
    "select"                 TEXT[] = '{}';
BEGIN
    -- проверка, что pk_columns существуют
    IF ("pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" table must have primary keys';
    END IF;

    "name" = 'v_default_dictionary';
    -- далее b - базовая таблица, t - таблица переводов

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
    -- установить pk_columns_on
    FOREACH "column" IN ARRAY "pk_columns" LOOP
        "pk_columns_on" = array_append("pk_columns_on", format('b.%1$I = t.%1$I', "column"));
    END LOOP;


    -- create view
    -- CROSS JOIN "langs", чтобы в представлении были указанны все языки из таблицы "langs"
    -- USING — это сокращённая запись условия, полезная в ситуации,
    -- когда с обеих сторон соединения столбцы имеют одинаковые имена
    -- %s - вставляется как простая строка
    -- https://postgrespro.ru/docs/postgrespro/current/functions-string#FUNCTIONS-STRING-FORMAT
    RAISE NOTICE USING MESSAGE = format('
        CREATE VIEW %1s AS
        SELECT %2s
            FROM %3s b
            LEFT JOIN %4s t ON %5s AND b.default_lang = t.lang
            WHERE TRUE;
    ', "name", array_to_string("select", ','), "baserel"::REGCLASS, "tranrel"::REGCLASS, array_to_string("pk_columns_on", ' AND '));
    EXECUTE format('
        CREATE VIEW %1s AS
        SELECT %2s
            FROM %3s b
            LEFT JOIN %4s t ON %5s AND b.default_lang = t.lang
            WHERE TRUE;
    ', "name", array_to_string("select", ','), "baserel"::REGCLASS, "tranrel"::REGCLASS, array_to_string("pk_columns_on", ' AND '));


/**

    -- установка select
    -- если в таблице переводов нет записей, то это строка взята из таблицы по умолчанию - свойство is_default
    "select" = array_append("select", '(t.*) IS NULL AS "is_not_tran"');
    -- свойство lang из таблицы langs, используется из объединения CROSS JOIN "langs"
    "select" = array_append("select", '"langs"."lang"');
    -- добавление колонок базовой таблицы, включая первичные ключи, но без повторяющихся колонок bp таблицы переводов
    FOREACH "column" IN ARRAY "base_columns" OPERATOR ( public.- ) "tran_columns" LOOP
        "select" = array_append("select", format('b.%1I', "column"));
    END LOOP;
    -- добавление колонок из таблицы переводов
    FOREACH "column" IN ARRAY "tran_columns" OPERATOR ( public.- ) '{lang}'::TEXT[] LOOP
        -- если колонка column есть среди колонок таблицы baserel, то использовать особую вставку с использованием CASE
        IF "column" = ANY ("base_columns") THEN
            "select" = array_append("select", format('CASE WHEN (t.*) IS NULL THEN b.%1I ELSE t.%1I END AS %1I', "column"));
        ELSE
            "select" = array_append("select", format('t.%1I', "column"));
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
 */
END
$$
LANGUAGE plpgsql;

-- TODO проверить, что если отправить null в параметры, то работать не будет
