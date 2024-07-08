/*
=================== LANG ===================
*/
CREATE FUNCTION @extschema@.lang_rule ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
DECLARE
    "arr"          CONSTANT TEXT[]  = string_to_array("value", '-');
    "length"       CONSTANT INT     = array_length("arr", 1);
    "has_language" CONSTANT BOOLEAN = "arr"[1] IS NOT NULL;
    "has_script"   CONSTANT BOOLEAN = "arr"[2] IS NOT NULL;
    "has_region"   CONSTANT BOOLEAN = "arr"[3] IS NOT NULL;
BEGIN
    IF ("length" IS NULL OR "length" > 3) THEN
        RETURN FALSE;
    END IF;
    RETURN ("has_language" AND @extschema@.language_rule("arr"[1])) AND
           (NOT ("has_script") OR (@extschema@.script_rule("arr"[2]) OR (@extschema@.region_rule("arr"[2]) AND NOT "has_region"))) AND
           (NOT ("has_region") OR @extschema@.region_rule("arr"[3]));
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION @extschema@.lang_rule (TEXT) IS 'RFC 5646';

/*
=================== LANGUAGE ===================
*/
CREATE FUNCTION @extschema@.language_rule ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[a-z]{2,3}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION @extschema@.language_rule (TEXT) IS 'ISO 639';

/*
=================== REGION ===================
*/
CREATE FUNCTION @extschema@.region_rule ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[A-Z]{2}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION @extschema@.region_rule (TEXT) IS 'ISO 3166-1';

/*
=================== SCRIPT ===================
*/
CREATE FUNCTION @extschema@.script_rule ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[A-Z][a-z]{3}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION @extschema@.script_rule (TEXT) IS 'ISO 15924';

/*
=================== LANG ===================
*/
CREATE DOMAIN @extschema@.LANG AS VARCHAR(11)
CHECK (@extschema@.lang_rule (VALUE));

COMMENT ON DOMAIN @extschema@.LANG IS 'RFC 5646';

/*
=================== LANGUAGE ===================
*/
CREATE DOMAIN @extschema@.LANGUAGE AS VARCHAR(3)
CHECK (@extschema@.language_rule (VALUE));

COMMENT ON DOMAIN @extschema@.LANGUAGE IS 'ISO 639';

/*
=================== REGION ===================
*/
CREATE DOMAIN @extschema@.REGION AS VARCHAR(2)
CHECK (@extschema@.region_rule (VALUE));

COMMENT ON DOMAIN @extschema@.REGION IS 'ISO 3166-1';

/*
=================== SCRIPT ===================
*/
CREATE DOMAIN @extschema@.SCRIPT AS VARCHAR(4)
CHECK (@extschema@.script_rule (VALUE));

COMMENT ON DOMAIN @extschema@.SCRIPT IS 'ISO 15924';

/*
=================== LANGS ===================
*/
CREATE TABLE @extschema@."langs"
(
    "lang"      @extschema@.LANG PRIMARY KEY
                GENERATED ALWAYS AS (
                    "language" ||
                    CASE WHEN ("script" IS NULL) THEN '' ELSE ('-' || "script") END ||
                    CASE WHEN ("region" IS NULL) THEN '' ELSE ('-' || "region") END
                    ) STORED,
    "language"  @extschema@.LANGUAGE NOT NULL,
    "script"    @extschema@.SCRIPT,
    "region"    @extschema@.REGION,
    "is_active" BOOLEAN         NOT NULL DEFAULT FALSE,
    "title"     VARCHAR(50)     NOT NULL UNIQUE
);

COMMENT ON TABLE @extschema@."langs" IS 'RFC 5646';

/*
=================== TRANS ===================
*/


CREATE TABLE @extschema@."trans"
(
    "lang" @extschema@.LANG NOT NULL REFERENCES @extschema@."langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "insert" AS ON INSERT TO @extschema@."trans" DO INSTEAD NOTHING;
CREATE RULE "update" AS ON UPDATE TO @extschema@."trans" DO INSTEAD NOTHING;
CREATE RULE "delete" AS ON DELETE TO @extschema@."trans" DO INSTEAD NOTHING;
/*
=================== UNTRANS ===================
*/

CREATE TABLE @extschema@."untrans"
(
    "default_lang" @extschema@.LANG REFERENCES @extschema@."langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "insert" AS ON INSERT TO @extschema@."untrans" DO INSTEAD NOTHING;
CREATE RULE "update" AS ON UPDATE TO @extschema@."untrans" DO INSTEAD NOTHING;
CREATE RULE "delete" AS ON DELETE TO @extschema@."untrans" DO INSTEAD NOTHING;

/*
=================== ARRAY_EXCEPT ===================
*/

CREATE FUNCTION @extschema@.array_except ("a" ANYARRAY, "b" ANYARRAY)
    RETURNS ANYARRAY
    AS $$
DECLARE
    "length" CONSTANT INT = array_length("b", 1);
    "index" INT;
BEGIN
    IF "a" IS NULL THEN
        RETURN NULL;
    END IF;
    "index" = 1;
    WHILE "index" <= "length" LOOP
        "a" = array_remove("a","b"["index"]);
        "index" = "index" + 1;
    END LOOP;
    RETURN "a";
END;
$$
LANGUAGE plpgsql
IMMUTABLE;

COMMENT ON FUNCTION @extschema@.array_except (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

CREATE OPERATOR @extschema@.- (
    LEFTARG = ANYARRAY, RIGHTARG = ANYARRAY, FUNCTION = @extschema@.array_except
);

COMMENT ON OPERATOR @extschema@.- (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

/*
=================== ARRAY_FORMAT ===================
*/
CREATE FUNCTION  @extschema@.array_format ("textarray" TEXT[], "formatstr" TEXT)
    RETURNS TEXT[]
    AS $$
DECLARE
    "item"    TEXT;
    "result"  TEXT[];
BEGIN
    FOREACH "item" IN ARRAY "textarray" LOOP
        "result" = array_append("result", format("formatstr", "item"));
    END LOOP;

    RETURN "result";
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION  @extschema@.array_format (TEXT[], TEXT) IS 'formatting array elements';

CREATE OPERATOR @extschema@.<< (
    LEFTARG = TEXT[], RIGHTARG = TEXT, FUNCTION = @extschema@.array_format
    );

COMMENT ON OPERATOR @extschema@.<< (TEXT[], TEXT) IS 'formatting array elements';
/*
=================== ARRAY_INTERSECT ===================
*/

CREATE FUNCTION @extschema@.array_intersect ("a" ANYARRAY, "b" ANYARRAY)
    RETURNS ANYARRAY
    AS $$
BEGIN
    RETURN (SELECT ARRAY(SELECT UNNEST($1) INTERSECT SELECT UNNEST($2)));
END;
$$
LANGUAGE plpgsql
IMMUTABLE;

COMMENT ON FUNCTION @extschema@.array_intersect (ANYARRAY, ANYARRAY) IS '$1 INTERSECT $2';

CREATE OPERATOR @extschema@.& (
    LEFTARG = ANYARRAY, RIGHTARG = ANYARRAY, FUNCTION = @extschema@.array_intersect
);

COMMENT ON OPERATOR @extschema@.& (ANYARRAY, ANYARRAY) IS '$1 INTERSECT $2';

/*
=================== GET_COLUMNS ===================
*/


CREATE FUNCTION  @extschema@.get_columns ("relid" OID, "has_generated_column" BOOLEAN = TRUE, "rel" TEXT = '')
    RETURNS TEXT[]
    AS $$
BEGIN

    RETURN (
        SELECT array_agg(CASE WHEN length("rel") > 0 THEN format('%s.%I', "rel", a."attname") ELSE a."attname" END)
        FROM "pg_attribute" AS a
        WHERE "attrelid" = "relid"


            AND a."attnum" > 0

            AND ("has_generated_column" OR a.attgenerated = '')

            AND NOT a.attisdropped);
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION  @extschema@.get_columns (OID, BOOLEAN, TEXT) IS 'get table columns';

/*
=================== GET_PRIMARY_KEY_COLUMNS ===================
*/

CREATE FUNCTION @extschema@.get_primary_key_columns ("relid" OID)
    RETURNS TEXT
    AS $$
BEGIN


    RETURN (
        SELECT array_agg(a."attname")
        FROM "pg_index" i
            INNER JOIN "pg_attribute" a ON i."indrelid" = a."attrelid"
                AND a."attnum" = ANY (i."indkey")
        WHERE i."indrelid" = "relid"
            AND i."indisprimary");
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION @extschema@.get_primary_key_columns (OID) IS 'get table primary key columns';

/*
=================== NAMES ===================
*/
CREATE FUNCTION  @extschema@.get_i18n_default_view_name ("baserel" OID, "tranrel" OID)
    RETURNS TEXT
    AS $$
BEGIN
    RETURN (
        SELECT format('%1I.%2I', n.nspname, 'v_' || c.relname || '_default')
        FROM pg_class c JOIN pg_namespace n on c.relnamespace = n.oid
        WHERE c.oid = "baserel");
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;


CREATE FUNCTION  @extschema@.get_i18n_view_name ("baserel" OID, "tranrel" OID)
    RETURNS TEXT
    AS $$
BEGIN
    RETURN (
        SELECT format('%1I.%2I', n.nspname, 'v_' || c.relname)
        FROM pg_class c JOIN pg_namespace n on c.relnamespace = n.oid
        WHERE c.oid = "baserel");
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;


CREATE FUNCTION  @extschema@.get_i18n_trigger_name ("viewname" TEXT)
    RETURNS TEXT
    AS $$
DECLARE
    "ident" TEXT[] = parse_ident("viewname");
BEGIN
    RETURN format('%1I.%2I', "ident"[1], 'trigger_i18n_' || "ident"[2]);
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;
/*
=================== I18N ===================
*/

CREATE PROCEDURE @extschema@.create_i18n_view ("baserel" OID, "tranrel" OID)
    AS $$
DECLARE
    "base_pk_columns"  CONSTANT TEXT[] = @extschema@.get_primary_key_columns("baserel");
    "base_columns"     CONSTANT TEXT[] = @extschema@.get_columns("baserel");
    "tran_pk_columns"  CONSTANT TEXT[] = "base_pk_columns" || '{lang}'::TEXT[];
    "tran_columns"     CONSTANT TEXT[] = @extschema@.get_columns("tranrel");
    "default_view_name"CONSTANT TEXT = @extschema@.get_i18n_default_view_name ("baserel", "tranrel");
    "view_name"        CONSTANT TEXT = @extschema@.get_i18n_view_name ("baserel", "tranrel");

    "sn_columns"       CONSTANT TEXT[] = (@extschema@.get_columns("baserel", FALSE) OPERATOR ( @extschema@.& ) @extschema@.get_columns("tranrel", FALSE)) OPERATOR ( @extschema@.- ) "base_pk_columns";
    "un_columns"                TEXT[];
    "base_insert_query"         TEXT;
    "base_default_insert_query" TEXT;
    "base_update_query"         TEXT;
    "tran_insert_query"         TEXT;
    "tran_default_insert_query" TEXT;
    "tran_update_query"         TEXT;
    "trigger_name"     CONSTANT TEXT = @extschema@.get_i18n_trigger_name ("view_name");

    "column"                    TEXT;
    "columns"                   TEXT[] = '{}';
    "select"                    TEXT[] = '{}';
    "query"                     TEXT;
BEGIN

    IF ("baserel" IS NULL OR "tranrel" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" and "tranrel" table must be defined';
    END IF;

    IF ("base_pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"baserel" table must have primary keys';
    END IF;

    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( @extschema@.- ) "tran_columns")) OPERATOR ( @extschema@.<< ) 'b.%1I';
    FOREACH "column" IN ARRAY "tran_columns" OPERATOR ( @extschema@.- ) "tran_pk_columns" LOOP

        "select" = array_append("select", CASE WHEN "column" = ANY ("base_columns")
            THEN format('CASE WHEN (t.*) IS NULL THEN b.%1$I ELSE t.%1$I END AS %1$I', "column")
            ELSE format('t.%1I', "column") END);
    END LOOP;

    "query" = format('SELECT %1s FROM %2I b LEFT JOIN %3I t ON %4s AND b."default_lang" = t."lang"',
                   array_to_string("select", ','),
                   "baserel"::REGCLASS,
                   "tranrel"::REGCLASS,
                   array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'b.%1$I = t.%1$I', ' AND '));
    EXECUTE format('CREATE VIEW %1s AS %2s;', "default_view_name", "query");

    "select" = ("base_pk_columns" || ("base_columns" OPERATOR ( @extschema@.- ) "tran_columns")) OPERATOR ( @extschema@.<< ) 'd.%1I';
    "select" = "select" || (("tran_columns" OPERATOR ( @extschema@.- ) "tran_pk_columns") OPERATOR ( @extschema@.<< ) 'CASE WHEN (t.*) IS NULL THEN d.%1$I ELSE t.%1$I END AS %1$I');
    "select" = ARRAY['NOT ((t.*) IS NULL) AS "is_tran"', '(d."default_lang" = l."lang") IS TRUE AS "is_default_lang"', 'l."lang"'] || "select";
    "query" = format('SELECT %1s FROM %2I d CROSS JOIN @extschema@."langs" l LEFT JOIN %3I t ON %4s AND l."lang" = t."lang"',
                     array_to_string("select", ','),
                     "default_view_name"::REGCLASS,
                     "tranrel"::REGCLASS,
                     array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'd.%1$I = t.%1$I', ' AND '));
    EXECUTE format('CREATE VIEW %1s AS %2s;', "view_name", "query");

    "un_columns" = @extschema@.get_columns("baserel", FALSE) OPERATOR ( @extschema@.- ) "base_pk_columns" OPERATOR ( @extschema@.- ) "sn_columns";

    "columns" = "base_pk_columns" || "sn_columns" || "un_columns";
    "base_insert_query" = format('INSERT INTO %1I (%2s) VALUES (%3s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("columns", ','), array_to_string("columns" OPERATOR ( @extschema@.<< ) 'NEW.%I', ','));
    "columns" = "sn_columns" || "un_columns";
    "base_default_insert_query" = format('INSERT INTO %1I (%2s) VALUES (%3s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("base_pk_columns" || "columns", ','), array_to_string(array_fill('DEFAULT'::TEXT, ARRAY [array_length("base_pk_columns", 1)]) || ("columns" OPERATOR ( @extschema@.<< ) 'NEW.%I'), ','));

    "columns" = "base_pk_columns" || "un_columns";
    "base_update_query" = format('UPDATE %1I SET (%2s) = ROW(%3s) WHERE (%4s)=(%5s)',
                                 "baserel"::REGCLASS,
                                 array_to_string("columns", ','), array_to_string("columns" OPERATOR ( @extschema@.<< ) 'NEW.%I', ','),
                                 array_to_string("base_pk_columns", ','), array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'OLD.%I', ','));

    "un_columns" = @extschema@.get_columns("tranrel", FALSE) OPERATOR ( @extschema@.- ) "tran_pk_columns";

    "columns" = "tran_pk_columns" || "un_columns";
    "tran_insert_query" = format('INSERT INTO %1I (%2s) VALUES (%3s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string("columns", ','), array_to_string("columns" OPERATOR ( @extschema@.<< ) 'NEW.%I', ','));
    "columns" = "base_pk_columns" || "un_columns";
    "tran_default_insert_query" = format('INSERT INTO %1I (%2s) VALUES (%3s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string('{lang}'::TEXT[] || "columns" , ','), array_to_string('{DEFAULT}'::TEXT[] || ("columns" OPERATOR ( @extschema@.<< ) 'NEW.%I'), ','));

    "columns" = "tran_pk_columns" || "un_columns";
    "tran_update_query" = format('UPDATE %1I SET (%2s) = ROW(%3s) WHERE (%4s)=(%5s)',
                                 "tranrel"::REGCLASS,
                                 array_to_string("columns", ','), array_to_string("columns" OPERATOR ( @extschema@.<< ) 'NEW.%I', ','),
                                 array_to_string("tran_pk_columns", ','), array_to_string("tran_pk_columns" OPERATOR ( @extschema@.<< ) 'OLD.%I', ','));

    EXECUTE format('
            CREATE FUNCTION %1s ()
                RETURNS TRIGGER
                AS $trigger$
            /*pg_i18n:trigger*/
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
            array_to_string("base_pk_columns" OPERATOR ( @extschema@.<< ) 'NEW.%1I IS NULL', ' AND '),
            "base_default_insert_query", "base_insert_query",
            "base_update_query",
            "tran_default_insert_query", "tran_insert_query",
            "tran_update_query");

    EXECUTE format('
            CREATE TRIGGER "i18n"
                INSTEAD OF INSERT OR UPDATE
                ON %1s FOR EACH ROW
            EXECUTE FUNCTION %2s ();
        ', "view_name", "trigger_name");
END
$$
LANGUAGE plpgsql;
/*
=================== DROP ===================
*/
CREATE FUNCTION @extschema@.event_trigger_drop_i18n_triggers ()
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
            "name" = @extschema@.get_i18n_trigger_name ("rel");
            RAISE NOTICE USING MESSAGE = "name";

            "query" = format('DROP FUNCTION IF EXISTS %1s RESTRICT;', "name");
            RAISE NOTICE USING MESSAGE = "query";
            EXECUTE "query";
        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
/*
=================== INIT ===================
*/
CREATE EVENT TRIGGER "drop_i18n_triggers" ON sql_drop
    WHEN TAG IN ('DROP VIEW')
EXECUTE PROCEDURE @extschema@.event_trigger_drop_i18n_triggers ();
