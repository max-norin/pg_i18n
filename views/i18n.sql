-- создание представления c возможность редактирования
CREATE PROCEDURE public.create_i18n_view("baserel" REGCLASS, "tranrel" REGCLASS) AS
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
    "tran_new_query"               TEXT;
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
    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( public.- ) "tran_columns")) OPERATOR ( public.<< ) 'b.%1$I';
    -- добавление колонок из таблицы переводов
    FOREACH "column" IN ARRAY "tran_columns" OPERATOR ( public.- ) "tran_pk_columns"
        LOOP
            -- если колонка есть среди колонок таблицы baserel, то использовать особую вставку CASE
            "select" = array_append("select", CASE
                                                  WHEN "column" = ANY ("base_columns")
                                                      THEN format('CASE WHEN (t.*) IS NULL THEN b.%1$I ELSE t.%1$I END AS %1$I', "column")
                                                  ELSE format('t.%1$I', "column") END);
        END LOOP;

    -- создание представления с записями языка по-умолчанию
    -- %s - вставляется как простая строка
    -- %I - вставляется как идентификатора SQL, экранируется при необходимости
    -- LEFT JOIN tranrel - соединяем с имеющимися переводами
    "query" = format('SELECT %1$s FROM %2$s b LEFT JOIN %3$s t ON %4$s AND b."default_lang" = t."lang"',
                     array_to_string("select", ', '),
                     "baserel"::REGCLASS,
                     "tranrel"::REGCLASS,
                     array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'b.%1$I = t.%1$I', ' AND '));
    EXECUTE format('CREATE VIEW %1$s AS %2$s;', "default_view_name", "query");

    -- создание i18n_view
    -- далее d - таблица дефолтных значений, t - таблица переводов, l - таблица языков

    -- установка select, повторяет то, что выше
    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( public.- ) "tran_columns")) OPERATOR ( public.<< ) 'd.%1$I';
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
    "query" = format('SELECT %1$s FROM %2$s d CROSS JOIN public."langs" l LEFT JOIN %3$s t ON %4$s AND l."lang" = t."lang"',
                     array_to_string("select", ', '),
                     "default_view_name"::REGCLASS,
                     "tranrel"::REGCLASS,
                     array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'd.%1$I = t.%1$I', ' AND '));
    EXECUTE format('CREATE VIEW %1$s AS %2$s;', "view_name", "query");

    -- создание триггеров

    -- создание запроса для вставки и обновления базовой таблицы

    -- set secondary key
    "un_columns" = public.get_columns("baserel", FALSE) OPERATOR ( public.- ) "base_pk_columns" OPERATOR ( public.- ) "sn_columns";

    "columns" = "base_pk_columns" || "sn_columns" || "un_columns";
    "base_insert_query" = format('INSERT INTO %1$s (%2$s) VALUES (%3$s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("columns" OPERATOR ( public.<< ) '%I', ', '), array_to_string("columns" OPERATOR ( public.<< ) 'NEW.%I', ', '));
    "columns" = "sn_columns" || "un_columns";
    "base_default_insert_query" = format('INSERT INTO %1$s (%2$s) VALUES (%3$s)',
                                         "baserel"::REGCLASS,
                                         array_to_string(("base_pk_columns" || "columns") OPERATOR ( public.<< ) '%I', ', '),
                                         array_to_string(array_fill('DEFAULT'::TEXT, ARRAY [array_length("base_pk_columns", 1)]) || ("columns" OPERATOR ( public.<< ) 'NEW.%I'), ', '));

    "columns" = "base_pk_columns" || "un_columns";
    "base_update_query" = format('UPDATE %1$s SET (%2$s) = ROW (%3$s) WHERE (%4$s) = (%5$s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("columns" OPERATOR ( public.<< ) '%I', ', '), array_to_string("columns" OPERATOR ( public.<< ) 'NEW.%I', ', '),
                                 array_to_string("base_pk_columns" OPERATOR ( public.<< ) '%I', ', '), array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'OLD.%I', ', '));

    -- создание запроса для вставки и обновления таблицы переводов

    -- set secondary key
    "un_columns" = public.get_columns("tranrel", FALSE) OPERATOR ( public.- ) "tran_pk_columns";

    "tran_new_query" = array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'TRAN_NEW.%1$I = base.%1$I;', '
    ');

    "columns" = "tran_pk_columns" || "un_columns";
    "tran_insert_query" = format('INSERT INTO %1$s (%2$s) VALUES (%3$s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string("columns" OPERATOR ( public.<< ) '%I', ', '),
                                 array_to_string("columns" OPERATOR ( public.<< ) 'TRAN_NEW.%I', ', '));
    "columns" = "base_pk_columns" || "un_columns";
    "tran_default_insert_query" = format('INSERT INTO %1$s (%2$s) VALUES (%3$s)',
                                         "tranrel"::REGCLASS,
                                         array_to_string(('{lang}'::TEXT[] || "columns") OPERATOR ( public.<< ) '%I', ', '),
                                         array_to_string('{DEFAULT}'::TEXT[] || ("columns" OPERATOR ( public.<< ) 'TRAN_NEW.%I'), ', '));

    "columns" = "tran_pk_columns" || "un_columns";
    "tran_update_query" = format('UPDATE %1$s SET (%2$s) = ROW (%3$s) WHERE (%4$s) = (%5$s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string("columns" OPERATOR ( public.<< ) '%I', ', '), array_to_string("columns" OPERATOR ( public.<< ) 'TRAN_NEW.%I', ', '),
                                 array_to_string("tran_pk_columns" OPERATOR ( public.<< ) '%I', ', '), array_to_string("tran_pk_columns" OPERATOR ( public.<< ) 'OLD.%I', ', '));

    EXECUTE format('
CREATE FUNCTION %1$s ()
    RETURNS TRIGGER
    AS $trigger$
/* pg_i18n:insert-trigger */
DECLARE
    base     RECORD;
    tran     RECORD;
    TRAN_NEW RECORD = NEW;
    result   RECORD;
BEGIN
    -- untrans
    IF %2$s THEN
        RAISE DEBUG USING MESSAGE = ''%3$s'';
        %3$s RETURNING * INTO base;
    ELSE
        RAISE DEBUG USING MESSAGE = ''%4$s'';
        %4$s RETURNING * INTO base;
    END IF;
    -- trans
    %5$s
    IF NEW.lang IS NULL THEN
        RAISE DEBUG USING MESSAGE = ''%6$s'';
        %6$s RETURNING * INTO tran;
    ELSE
        RAISE DEBUG USING MESSAGE = ''%7$s'';
        %7$s RETURNING * INTO tran;
    END IF;
    -- update result
    result = jsonb_populate_record(NULL::%8$s, to_jsonb(base) || to_jsonb(tran));
    result.is_tran = TRUE;
    result.is_default_lang = (result.default_lang = result.lang) IS TRUE;

    RETURN result;
END
$trigger$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER;
        ', "insert_trigger_name",
                   array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'NEW.%1$I IS NULL', ' AND '),
                   "base_default_insert_query", "base_insert_query",
                   "tran_new_query",
                   "tran_default_insert_query", "tran_insert_query",
                   "view_name");
    EXECUTE format('
            CREATE TRIGGER "i18n"
                INSTEAD OF INSERT
                ON %1$s FOR EACH ROW
            EXECUTE FUNCTION %2$s ();
        ', "view_name", "insert_trigger_name");

    EXECUTE format('
CREATE FUNCTION %1$s ()
    RETURNS TRIGGER
    AS $trigger$
/* pg_i18n:update-trigger */
DECLARE
    base     RECORD;
    tran     RECORD;
    TRAN_NEW RECORD = NEW;
    result   RECORD;
BEGIN
    -- check updating lang
    IF OLD.lang != NEW.lang THEN
        RAISE EXCEPTION USING
            MESSAGE = ''Updating `lang` is not supported.'',
            HINT = ''Remove change to column `lang` in query.'';
    END IF;
    -- untrans
    RAISE DEBUG USING MESSAGE = ''%2$s'';
    %2$s RETURNING * INTO base;
    -- check primary key
    IF %3$s THEN
        RAISE EXCEPTION USING
            MESSAGE = ''Updating table inherited from `untruns` does not return result'',
            HINT = ''Most likely query contains change to primary key in several rows. Primary key can only be changed in one row.'';
    END IF;
    -- trans
    %4$s
    IF OLD.is_tran THEN
        RAISE DEBUG USING MESSAGE = ''%5$s'';
        %5$s RETURNING * INTO tran;
    ELSE
        RAISE DEBUG USING MESSAGE = ''%6$s'';
        %6$s RETURNING * INTO tran;
    END IF;
    -- update result
    result = jsonb_populate_record(NULL::%7$s, to_jsonb(base) || to_jsonb(tran));
    result.is_tran = TRUE;
    result.is_default_lang = (result.default_lang = result.lang) IS TRUE;

    RETURN result;
END
$trigger$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER;
        ', "update_trigger_name",
                   "base_update_query",
                   array_to_string("base_pk_columns" OPERATOR ( public.<< ) 'base.%1$I IS NULL', ' AND '),
                   "tran_new_query",
                   "tran_update_query", "tran_insert_query",
                   "view_name");
    EXECUTE format('
            CREATE TRIGGER "update"
                INSTEAD OF UPDATE
                ON %1$s FOR EACH ROW
            EXECUTE FUNCTION %2$s ();
        ', "view_name", "update_trigger_name");
END
$$
    LANGUAGE plpgsql;
