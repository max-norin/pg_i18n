-- создание представления словарного или пользовательского способа
-- представление не только отображает данные, но даёт возможность редактирования
CREATE OR REPLACE PROCEDURE public.create_i18n_view ("baserel" OID, "tranrel" OID)
    AS $$
DECLARE
    -- для создания представлений
    "base_pk_columns"  CONSTANT TEXT[] = public.get_primary_key_columns("baserel");
    "base_columns"     CONSTANT TEXT[] = public.get_columns("baserel");
    "tran_pk_columns"  CONSTANT TEXT[] = "base_pk_columns" || '{lang}'::TEXT[];
    "tran_columns"     CONSTANT TEXT[] = public.get_columns("tranrel");
    -- для создания триггера
    -- same name, одноименные
    "sn_columns"       CONSTANT TEXT[] = (public.get_columns("baserel", FALSE) OPERATOR ( public.& ) public.get_columns("tranrel", FALSE)) OPERATOR ( public.- ) "base_pk_columns";
    -- unique, уникальные
    "un_columns"                TEXT[];
    "base_insert_query"         TEXT;
    "base_default_insert_query" TEXT;
    "base_update_query"         TEXT;
    "tran_insert_query"         TEXT;
    "tran_default_insert_query" TEXT;
    "tran_update_query"         TEXT;
    -- вспомогательные
    "view_name"                 TEXT;
    "trigger_name"              TEXT;
    "column"                    TEXT;
    "columns"                   TEXT[] = '{}';
    "select"                    TEXT[] = '{}';
    "query"                     TEXT = '';
BEGIN
    -- проверка, что pk_columns существуют
    IF ("base_pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" table must have primary keys';
    END IF;

    -- далее b - базовая таблица, t - таблица переводов

    -- установка имени представления
    "view_name" = 'v_dictionary_default';

    -- установка select
    -- добавление колонок базовой таблицы, включая первичные ключи, но без одноименных колонок таблицы переводов
    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( public.- ) "tran_columns")) OPERATOR ( public.<< ) 'b.%1I';
    -- добавление колонок из таблицы переводов
    FOREACH "column" IN ARRAY "tran_columns" OPERATOR ( public.- ) "tran_pk_columns" LOOP
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
                   array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'b.%1$I = t.%1$I', ' AND '));
    EXECUTE format('CREATE VIEW %1I AS %2s;', "view_name", "query");

    -- далее d - таблица дефолтных значений, t - таблица переводов, l - таблица языков

    -- установка имени представления
    "view_name" = 'v_dictionary';

    -- установка select, повторяет то, что выше
    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( public.- ) "tran_columns")) OPERATOR ( public.<< ) 'd.%1I';
    "select" = "select" || (("tran_columns" OPERATOR ( public.- ) "tran_pk_columns") OPERATOR ( public.<< ) 'CASE WHEN (t.*) IS NULL THEN d.%1$I ELSE t.%1$I END AS %1$I');
    -- lang - lang из таблицы langs, используется из объединения CROSS JOIN "langs"
    -- default_lang - запись с дефолтным языком
    -- is_tran - является переводом
    "select" = ARRAY['NOT ((t.*) IS NULL) AS "is_tran"', '(d."default_lang" = l."lang") IS TRUE AS "is_default_lang"', 'l."lang"'] || "select";

    -- создание представления с записями по всем языкам
    -- %s - вставляется как простая строка
    -- %I - вставляется как идентификатора SQL, экранируется при необходимости
    -- WITH - общее табличное выражение с представлением из предыдущего запроса
    -- CROSS JOIN "langs" - соединение значения со всеми языками
    -- LEFT JOIN tranrel - соединение с имеющимися переводами
    "query" = format('WITH d AS (%1s) SELECT %2s FROM d CROSS JOIN public."langs" l LEFT JOIN %3I t ON %4s AND l."lang" = t."lang"',
                     "query", -- предыдущий запрос
                     array_to_string("select", ','),
                     "tranrel"::REGCLASS,
                     array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'd.%1$I = t.%1$I', ' AND '));
    EXECUTE format('CREATE VIEW %1I AS %2s;', "view_name", "query");

    -- создание триггеров

    -- создание запроса для вставки и обновления базовой таблицы

    -- set secondary key
    "un_columns" = public.get_columns("baserel", FALSE) OPERATOR ( public.- ) "base_pk_columns" OPERATOR ( public.- ) "sn_columns";

    "columns" = "base_pk_columns" || "sn_columns" || "un_columns";
    "base_insert_query" = format('INSERT INTO %1I (%2s) VALUES (%3s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("columns", ','), array_to_string("columns" OPERATOR ( public.<< ) 'NEW.%I', ','));
    "columns" = "sn_columns" || "un_columns";
    "base_default_insert_query" = format('INSERT INTO %1I (%2s) VALUES (%3s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("base_pk_columns" || "columns", ','), array_to_string(array_fill('DEFAULT'::TEXT, ARRAY [array_length("base_pk_columns", 1)]) || ("columns" OPERATOR ( public.<< ) 'NEW.%I'), ','));

    "columns" = "base_pk_columns" || "un_columns";
    "base_update_query" = format('UPDATE %1I SET (%2s) = ROW(%3s) WHERE (%4s)=(%5s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("columns", ','), array_to_string("columns" OPERATOR ( public.<< ) 'NEW.%I', ','),
                                 array_to_string("base_pk_columns", ','), array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'OLD.%I', ','));

    -- создание запроса для вставки и обновления таблицы переводов

    -- set secondary key
    "un_columns" = public.get_columns("tranrel", FALSE) OPERATOR ( public.- ) "tran_pk_columns";

    "columns" = "tran_pk_columns" || "un_columns";
    "tran_insert_query" = format('INSERT INTO %1I (%2s) VALUES (%3s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string("columns", ','), array_to_string("columns" OPERATOR ( public.<< ) 'NEW.%I', ','));
    "columns" = "base_pk_columns" || "un_columns";
    "tran_default_insert_query" = format('INSERT INTO %1I (%2s) VALUES (%3s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string('{lang}'::TEXT[] || "columns" , ','), array_to_string('{DEFAULT}'::TEXT[] || ("columns" OPERATOR ( public.<< ) 'NEW.%I'), ','));

    "columns" = "tran_pk_columns" || "un_columns";
    "tran_update_query" = format('UPDATE %1I SET (%2s) = ROW(%3s) WHERE (%4s)=(%5s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string("columns", ','), array_to_string("columns" OPERATOR ( public.<< ) 'NEW.%I', ','),
                                 array_to_string("tran_pk_columns", ','), array_to_string("tran_pk_columns" OPERATOR ( public.<< ) 'OLD.%I', ','));

    "trigger_name" = 'public.trigger_i18n_view';
    EXECUTE format('
            CREATE FUNCTION %1s ()
                RETURNS TRIGGER
                AS $trigger$
            DECLARE
                "base_new"  RECORD;
                "tran_new"  RECORD;
            BEGIN
                IF TG_OP = ''INSERT'' THEN
                    IF %2s THEN %3s RETURNING * INTO "base_new";
                    ELSE %4s RETURNING * INTO "base_new"; END IF;
                ELSE %5s RETURNING * INTO "base_new"; END IF;
                NEW = jsonb_populate_record(NEW, to_jsonb("base_new"));

                IF TG_OP = ''INSERT'' THEN
                    IF NEW.lang IS NULL THEN %6s RETURNING * INTO "tran_new";
                    ELSE %7s RETURNING * INTO "tran_new"; END IF;
                ELSE %8s RETURNING * INTO "tran_new"; END IF;
                NEW = jsonb_populate_record(NEW, to_jsonb("tran_new"));

                NEW.is_tran = TRUE;
                NEW.is_default_lang = (NEW."default_lang" = NEW."lang") IS TRUE;

                RETURN NEW;
            END
            $trigger$
            LANGUAGE plpgsql
            VOLATILE
            SECURITY DEFINER;
        ',  "trigger_name",
            array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'NEW.%1I IS NULL', ' AND '),
            "base_default_insert_query", "base_insert_query",
            "base_update_query",
            "tran_default_insert_query", "tran_insert_query",
            "tran_update_query");

    EXECUTE format('
            CREATE TRIGGER "table"
                INSTEAD OF INSERT OR UPDATE
                ON %1I FOR EACH ROW
            EXECUTE FUNCTION %2s ();
        ', "view_name", "trigger_name");
END
$$
LANGUAGE plpgsql;

-- TODO проверить, что если отправить null в параметры, то работать не будет
-- TODO проверить какие были бы массивы и код, если использовать курсоры
