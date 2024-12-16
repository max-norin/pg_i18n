-- создание представления c возможность редактирования
CREATE OR REPLACE PROCEDURE public.create_i18n_view("baserel" OID, "tranrel" OID) AS
$$
DECLARE
    -- для создания представлений
    "base_pk_columns"     CONSTANT TEXT[] = public.get_primary_key_columns("baserel");
    "base_columns"        CONSTANT TEXT[] = public.get_columns("baserel");
    "tran_pk_columns"     CONSTANT TEXT[] = "base_pk_columns" || '{lang}'::TEXT[];
    "tran_columns"        CONSTANT TEXT[] = public.get_columns("tranrel");
    "default_view_name"   CONSTANT TEXT   = public.get_i18n_default_view_name("baserel", "tranrel");
    "view_name"           CONSTANT TEXT   = public.get_i18n_view_name("baserel", "tranrel");
    -- для создания триггера
    -- same name, одноименные колонки
    "sn_columns"          CONSTANT TEXT[] = (public.get_columns("baserel", FALSE) OPERATOR ( public.& ) public.get_columns("tranrel", FALSE)) OPERATOR ( public.- ) "base_pk_columns";
    -- unique, уникальные колонки
    "un_columns"                   TEXT[];
    "base_insert_query"            TEXT;
    "base_default_insert_query"    TEXT;
    "base_update_query"            TEXT;
    "tran_insert_query"            TEXT;
    "tran_default_insert_query"    TEXT;
    "tran_update_query"            TEXT;
    "insert_trigger_name" CONSTANT TEXT   = public.get_i18n_insert_trigger_name("view_name");
    "update_trigger_name" CONSTANT TEXT   = public.get_i18n_update_trigger_name("view_name");
    -- вспомогательные
    "column"                       TEXT;
    "columns"                      TEXT[] = '{}';
    "select"                       TEXT[] = '{}';
    "query"                        TEXT;
BEGIN
    -- проверка, что pk_columns существуют
    IF ("baserel" IS NULL OR "tranrel" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" and "tranrel" table must be defined';
    END IF;
    -- проверка, что pk_columns существуют
    IF ("base_pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" table must have primary keys';
    END IF;

    -- создание i18n_default_view
    -- далее b - базовая таблица, t - таблица переводов

    -- установка массива select
    -- добавление колонок базовой таблицы, включая первичные ключи, но без одноименных колонок таблицы переводов
    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( public.- ) "tran_columns")) OPERATOR ( public.<< ) 'b.%1I';
    -- добавление колонок из таблицы переводов
    FOREACH "column" IN ARRAY "tran_columns" OPERATOR ( public.- ) "tran_pk_columns"
        LOOP
            -- если колонка есть среди колонок таблицы baserel, то использовать особую вставку CASE
            "select" = array_append("select", CASE
                                                  WHEN "column" = ANY ("base_columns")
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
    EXECUTE format('CREATE VIEW %1s AS %2s;', "default_view_name", "query");

    -- создание i18n_view
    -- далее d - таблица дефолтных значений, t - таблица переводов, l - таблица языков

    -- установка select, повторяет то, что выше
    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( public.- ) "tran_columns")) OPERATOR ( public.<< ) 'd.%1I';
    "select" = "select" || (("tran_columns" OPERATOR ( public.- ) "tran_pk_columns") OPERATOR ( public.<< ) 'CASE WHEN (t.*) IS NULL THEN d.%1$I ELSE t.%1$I END AS %1$I');
    -- lang - lang из таблицы langs, используется из объединения CROSS JOIN "langs"
    -- default_lang - запись с дефолтным языком
    -- is_tran - является переводом
    "select" = ARRAY ['NOT ((t.*) IS NULL) AS "is_tran"', '(d."default_lang" = l."lang") IS TRUE AS "is_default_lang"', 'l."lang"'] || "select";

    -- создание представления с записями по всем языкам
    -- %s - вставляется как простая строка
    -- %I - вставляется как идентификатора SQL, экранируется при необходимости
    -- WITH - общее табличное выражение с представлением из предыдущего запроса
    -- CROSS JOIN "langs" - соединение значения со всеми языками
    -- LEFT JOIN tranrel - соединение с имеющимися переводами
    "query" = format('SELECT %1s FROM %2I d CROSS JOIN public."langs" l LEFT JOIN %3I t ON %4s AND l."lang" = t."lang"',
                     array_to_string("select", ','),
                     "default_view_name"::REGCLASS,
                     "tranrel"::REGCLASS,
                     array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'd.%1$I = t.%1$I', ' AND '));
    EXECUTE format('CREATE VIEW %1s AS %2s;', "view_name", "query");

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
                                         array_to_string("base_pk_columns" || "columns", ','),
                                         array_to_string(array_fill('DEFAULT'::TEXT, ARRAY [array_length("base_pk_columns", 1)]) || ("columns" OPERATOR ( public.<< ) 'NEW.%I'), ','));

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
                                         array_to_string('{lang}'::TEXT[] || "columns", ','), array_to_string('{DEFAULT}'::TEXT[] || ("columns" OPERATOR ( public.<< ) 'NEW.%I'), ','));

    "columns" = "tran_pk_columns" || "un_columns";
    "tran_update_query" = format('UPDATE %1I SET (%2s) = ROW(%3s) WHERE (%4s)=(%5s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string("columns", ','), array_to_string("columns" OPERATOR ( public.<< ) 'NEW.%I', ','),
                                 array_to_string("tran_pk_columns", ','), array_to_string("tran_pk_columns" OPERATOR ( public.<< ) 'OLD.%I', ','));

    EXECUTE format('
            CREATE FUNCTION %s ()
                RETURNS TRIGGER
                AS $trigger$
            /*pg_i18n:insert-trigger*/
            DECLARE
                "base_new"  RECORD;
                "tran_new"  RECORD;
            BEGIN
                IF %s THEN %s RETURNING * INTO "base_new";
                ELSE %s RETURNING * INTO "base_new"; END IF;
                IF NEW.lang IS NULL THEN %s RETURNING * INTO "tran_new";
                ELSE %s RETURNING * INTO "tran_new"; END IF;

                NEW = jsonb_populate_record(NEW, to_jsonb("base_new"));
                NEW = jsonb_populate_record(NEW, to_jsonb("tran_new"));

                RETURN NEW;
            END
            $trigger$
            LANGUAGE plpgsql
            VOLATILE
            SECURITY DEFINER;
        ', "insert_trigger_name",
                   array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'NEW.%1I IS NULL', ' AND '),
                   "base_default_insert_query", "base_insert_query",
                   "tran_default_insert_query", "tran_insert_query");
    EXECUTE format('
            CREATE TRIGGER "i18n"
                INSTEAD OF INSERT
                ON %1s FOR EACH ROW
            EXECUTE FUNCTION %2s ();
        ', "view_name", "insert_trigger_name");

    EXECUTE format('
            CREATE FUNCTION %s ()
                RETURNS TRIGGER
                AS $trigger$
            /*pg_i18n:update-trigger*/
            DECLARE
                "base_new"  RECORD;
                "tran_new"  RECORD;
            BEGIN
                %s RETURNING * INTO "base_new";
                %s RETURNING * INTO "tran_new";

                NEW = jsonb_populate_record(NEW, to_jsonb("base_new"));
                NEW = jsonb_populate_record(NEW, to_jsonb("tran_new"));

                RETURN NEW;
            END
            $trigger$
            LANGUAGE plpgsql
            VOLATILE
            SECURITY DEFINER;
        ', "update_trigger_name",
                   "base_update_query",
                   "tran_update_query");
    EXECUTE format('
            CREATE TRIGGER "update"
                INSTEAD OF UPDATE
                ON %1s FOR EACH ROW
            EXECUTE FUNCTION %2s ();
        ', "view_name", "update_trigger_name");
END
$$
    LANGUAGE plpgsql;
