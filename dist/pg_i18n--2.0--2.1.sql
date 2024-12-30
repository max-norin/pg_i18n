/*
=================== NAMES ===================
*/
DROP FUNCTION @extschema@.get_i18n_default_view_name (OID, OID);
CREATE OR REPLACE FUNCTION @extschema@.get_i18n_default_view_name ("baserel" REGCLASS, "tranrel" REGCLASS)
    RETURNS TEXT
    AS $$
BEGIN
    RETURN (
        SELECT format('%1I.%2I', n.nspname, 'i18n_default_' || c.relname)
        FROM pg_class c JOIN pg_namespace n on c.relnamespace = n.oid
        WHERE c.oid = "baserel");
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

DROP FUNCTION @extschema@.get_i18n_view_name (OID, OID);
CREATE OR REPLACE FUNCTION @extschema@.get_i18n_view_name ("baserel" REGCLASS, "tranrel" REGCLASS)
    RETURNS TEXT
    AS $$
BEGIN
    RETURN (
        SELECT format('%1I.%2I', n.nspname, 'i18n_' || c.relname)
        FROM pg_class c JOIN pg_namespace n on c.relnamespace = n.oid
        WHERE c.oid = "baserel");
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

DROP FUNCTION IF EXISTS @extschema@.get_i18n_trigger_name (TEXT);

CREATE FUNCTION @extschema@.get_i18n_insert_trigger_name ("viewname" TEXT)
    RETURNS TEXT
    AS $$
DECLARE
    "ident" TEXT[] = parse_ident("viewname");
BEGIN
    RETURN format('%1I.%2I', "ident"[1], "ident"[2] || '__insert');
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

CREATE FUNCTION @extschema@.get_i18n_update_trigger_name ("viewname" TEXT)
    RETURNS TEXT
    AS $$
DECLARE
    "ident" TEXT[] = parse_ident("viewname");
BEGIN
    RETURN format('%1I.%2I', "ident"[1], "ident"[2] || '__update');
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;
/*
=================== I18N ===================
*/
DROP FUNCTION @extschema@.create_i18n_view (OID, OID);
CREATE PROCEDURE @extschema@.create_i18n_view("baserel" REGCLASS, "tranrel" REGCLASS)
    AS $$
DECLARE
    "base_pk_columns"     CONSTANT TEXT[] = @extschema@.get_primary_key_columns("baserel");
    "base_columns"        CONSTANT TEXT[] = @extschema@.get_columns("baserel");
    "tran_pk_columns"     CONSTANT TEXT[] = "base_pk_columns" || '{lang}'::TEXT[];
    "tran_columns"        CONSTANT TEXT[] = @extschema@.get_columns("tranrel");
    "default_view_name"   CONSTANT TEXT   = @extschema@.get_i18n_default_view_name("baserel", "tranrel");
    "view_name"           CONSTANT TEXT   = @extschema@.get_i18n_view_name("baserel", "tranrel");
    "sn_columns"          CONSTANT TEXT[] = (@extschema@.get_columns("baserel", FALSE) OPERATOR ( @extschema@.& ) @extschema@.get_columns("tranrel", FALSE)) OPERATOR ( @extschema@.- ) "base_pk_columns";
    "un_columns"                   TEXT[];
    "base_insert_query"            TEXT;
    "base_default_insert_query"    TEXT;
    "base_update_query"            TEXT;
    "tran_new_query"               TEXT;
    "tran_insert_query"            TEXT;
    "tran_default_insert_query"    TEXT;
    "tran_update_query"            TEXT;
    "insert_trigger_name" CONSTANT TEXT   = @extschema@.get_i18n_insert_trigger_name("view_name");
    "update_trigger_name" CONSTANT TEXT   = @extschema@.get_i18n_update_trigger_name("view_name");
    "column"                       TEXT;
    "columns"                      TEXT[] = '{}';
    "select"                       TEXT[] = '{}';
    "query"                        TEXT;
BEGIN
    IF ("baserel" IS NULL OR "tranrel" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" and "tranrel" table must be defined';
    END IF;
    IF ("base_pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" table must have primary keys';
    END IF;

    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( @extschema@.- ) "tran_columns")) OPERATOR ( @extschema@.<< ) 'b.%1$I';
    FOREACH "column" IN ARRAY "tran_columns" OPERATOR ( @extschema@.- ) "tran_pk_columns"
        LOOP
            "select" = array_append("select", CASE
                                                  WHEN "column" = ANY ("base_columns")
                                                      THEN format('CASE WHEN (t.*) IS NULL THEN b.%1$I ELSE t.%1$I END AS %1$I', "column")
                                                  ELSE format('t.%1$I', "column") END);
        END LOOP;

    "query" = format('SELECT %1$s FROM %2$I b LEFT JOIN %3$I t ON %4$s AND b."default_lang" = t."lang"',
                     array_to_string("select", ', '),
                     "baserel"::REGCLASS,
                     "tranrel"::REGCLASS,
                     array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'b.%1$I = t.%1$I', ' AND '));
    EXECUTE format('CREATE VIEW %1$s AS %2$s;', "default_view_name", "query");

    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( @extschema@.- ) "tran_columns")) OPERATOR ( @extschema@.<< ) 'd.%1$I';
    "select" = "select" || (("tran_columns" OPERATOR ( @extschema@.- ) "tran_pk_columns") OPERATOR ( @extschema@.<< ) 'CASE WHEN (t.*) IS NULL THEN d.%1$I ELSE t.%1$I END AS %1$I');
    "select" = ARRAY ['NOT ((t.*) IS NULL) AS "is_tran"', '(d."default_lang" = l."lang") IS TRUE AS "is_default_lang"', 'l."lang"'] || "select";

    "query" = format('SELECT %1$s FROM %2$I d CROSS JOIN @extschema@."langs" l LEFT JOIN %3$I t ON %4$s AND l."lang" = t."lang"',
                     array_to_string("select", ', '),
                     "default_view_name"::REGCLASS,
                     "tranrel"::REGCLASS,
                     array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'd.%1$I = t.%1$I', ' AND '));
    EXECUTE format('CREATE VIEW %1$s AS %2$s;', "view_name", "query");

    "un_columns" = @extschema@.get_columns("baserel", FALSE) OPERATOR ( @extschema@.- ) "base_pk_columns" OPERATOR ( @extschema@.- ) "sn_columns";

    "columns" = "base_pk_columns" || "sn_columns" || "un_columns";
    "base_insert_query" = format('INSERT INTO %1$I (%2$s) VALUES (%3$s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("columns" OPERATOR ( @extschema@.<< ) '%I', ', '), array_to_string("columns" OPERATOR ( @extschema@.<< ) 'NEW.%I', ', '));
    "columns" = "sn_columns" || "un_columns";
    "base_default_insert_query" = format('INSERT INTO %1$I (%2$s) VALUES (%3$s)',
                                         "baserel"::REGCLASS,
                                         array_to_string(("base_pk_columns" || "columns") OPERATOR ( @extschema@.<< ) '%I', ', '),
                                         array_to_string(array_fill('DEFAULT'::TEXT, ARRAY [array_length("base_pk_columns", 1)]) || ("columns" OPERATOR ( @extschema@.<< ) 'NEW.%I'), ', '));

    "columns" = "base_pk_columns" || "un_columns";
    "base_update_query" = format('UPDATE %1$I SET (%2$s) = ROW (%3$s) WHERE (%4$s) = (%5$s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("columns" OPERATOR ( @extschema@.<< ) '%I', ', '), array_to_string("columns" OPERATOR ( @extschema@.<< ) 'NEW.%I', ', '),
                                 array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) '%I', ', '), array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'OLD.%I', ', '));

    "un_columns" = @extschema@.get_columns("tranrel", FALSE) OPERATOR ( @extschema@.- ) "tran_pk_columns";

    "tran_new_query" = array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'TRAN_NEW.%1$I = base.%1$I;', '
    ');

    "columns" = "tran_pk_columns" || "un_columns";
    "tran_insert_query" = format('INSERT INTO %1$I (%2$s) VALUES (%3$s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string("columns" OPERATOR ( @extschema@.<< ) '%I', ', '),
                                 array_to_string("columns" OPERATOR ( @extschema@.<< ) 'TRAN_NEW.%I', ', '));
    "columns" = "base_pk_columns" || "un_columns";
    "tran_default_insert_query" = format('INSERT INTO %1$I (%2$s) VALUES (%3$s)',
                                         "tranrel"::REGCLASS,
                                         array_to_string(('{lang}'::TEXT[] || "columns") OPERATOR ( @extschema@.<< ) '%I', ', '),
                                         array_to_string('{DEFAULT}'::TEXT[] || ("columns" OPERATOR ( @extschema@.<< ) 'TRAN_NEW.%I'), ', '));

    "columns" = "tran_pk_columns" || "un_columns";
    "tran_update_query" = format('UPDATE %1$I SET (%2$s) = ROW (%3$s) WHERE (%4$s) = (%5$s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string("columns" OPERATOR ( @extschema@.<< ) '%I', ', '), array_to_string("columns" OPERATOR ( @extschema@.<< ) 'TRAN_NEW.%I', ', '),
                                 array_to_string("tran_pk_columns" OPERATOR ( @extschema@.<< ) '%I', ', '), array_to_string("tran_pk_columns" OPERATOR ( @extschema@.<< ) 'OLD.%I', ', '));

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
                   array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'NEW.%1$I IS NULL', ' AND '),
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
                   array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'base.%1$I IS NULL', ' AND '),
                   "tran_new_query",
                   "tran_update_query", "tran_insert_query",
                   "view_name");
    EXECUTE format('
            CREATE TRIGGER "update"
                INSTEAD OF UPDATE
                ON %1$s FOR EACH ROW
            EXECUTE FUNCTION %2$s ();
        ', "view_name", "update_trigger_name");
END;
$$
LANGUAGE plpgsql;
/*
=================== DROP ===================
*/
CREATE OR REPLACE FUNCTION @extschema@.event_trigger_drop_i18n_triggers ()
    RETURNS EVENT_TRIGGER
    AS $$
DECLARE
    "object"               RECORD;
    "rel"                  TEXT;
    "name"                 TEXT;
    "query"                TEXT;
    "schema"               TEXT;
    "table"                TEXT;
BEGIN
    FOR "object" IN
    SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        IF "object".object_type = 'view' THEN
            "schema" = "object".address_names[1];
            "table" = "object".address_names[2];
            "rel" = format('%1I.%2I', "schema", "table");

            "name" = @extschema@.get_i18n_insert_trigger_name ("rel");
            IF (position('/* pg_i18n:insert-trigger */' IN lower(pg_get_functiondef(to_regproc("name"))))) > 0 THEN
                "query" = format('DROP FUNCTION IF EXISTS %1s RESTRICT;', "name");
                RAISE NOTICE USING MESSAGE = "query";
                EXECUTE "query";
            END IF;

            "name" = @extschema@.get_i18n_update_trigger_name ("rel");
            IF (position('/* pg_i18n:update-trigger */' IN lower(pg_get_functiondef(to_regproc("name"))))) > 0 THEN
                "query" = format('DROP FUNCTION IF EXISTS %1s RESTRICT;', "name");
                RAISE NOTICE USING MESSAGE = "query";
                EXECUTE "query";
            END IF;
        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
/*
=================== INIT ===================
*/
DROP EVENT TRIGGER "drop_i18n_triggers";
CREATE EVENT TRIGGER "drop_i18n_triggers" ON sql_drop
    WHEN TAG IN ('DROP TABLE', 'DROP VIEW')
EXECUTE PROCEDURE @extschema@.event_trigger_drop_i18n_triggers ();
