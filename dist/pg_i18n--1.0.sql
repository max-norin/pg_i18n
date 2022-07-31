/*
=================== ARRAY_EXCEPT =================== 
*/
CREATE FUNCTION array_except ("a" ANYARRAY, "b" ANYARRAY)
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

COMMENT ON FUNCTION array_except (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

CREATE OPERATOR - (
    LEFTARG = ANYARRAY, RIGHTARG = ANYARRAY, FUNCTION = array_except
);

COMMENT ON OPERATOR - (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

/*
=================== FORMAT_TABLE_NAME =================== 
*/
CREATE FUNCTION format_table_name ("name" TEXT, "prefix" TEXT = '')
    RETURNS TEXT
    AS $$
DECLARE
    "arr" TEXT[];
BEGIN
    "arr" = string_to_array("name", '.');
    CASE array_length("arr", 1)
    WHEN 1 THEN
        RETURN format('%I', "prefix" || trim(BOTH '"' FROM "arr"[1]));
    WHEN 2 THEN
        RETURN format('%I.%I', trim(BOTH '"' FROM "arr"[1]), "prefix" || trim(BOTH '"' FROM "arr"[2]));
    ELSE
        RAISE EXCEPTION USING MESSAGE = 'invalid table name';
    END CASE;
    END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

/*
=================== GET_COLUMNS =================== 
*/
CREATE FUNCTION get_columns ("relid" OID, "has_generated_column" BOOLEAN = TRUE, "rel" TEXT = '')
    RETURNS TEXT[]
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-attribute.html
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

COMMENT ON FUNCTION get_columns (OID, BOOLEAN, TEXT) IS 'get table columns';

/*
=================== GET_CONSTRAINTDEF =================== 
*/
-- https://www.postgresql.org/docs/current/sql-execute.html
-- https://www.postgresql.org/docs/current/sql-prepare.html
CREATE FUNCTION get_constraintdefs ("relid" OID)
    RETURNS TEXT[]
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-constraint.html
    RETURN (
        SELECT array_agg(pg_get_constraintdef("pg_constraint"."oid"::OID, TRUE))
        FROM "pg_constraint"
        WHERE "pg_constraint"."conrelid" = "relid"
            AND "pg_constraint"."contype" IN ('f', 'p', 'u'));
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_constraintdefs (OID) IS 'get table constraint definitions';

/*
=================== GET_PRIMARY_KEY =================== 
*/
CREATE FUNCTION get_primary_key ("relid" OID)
    RETURNS TEXT[]
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-index.html
    -- https://postgresql.org/docs/current/catalog-pg-attribute.html
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

COMMENT ON FUNCTION get_primary_key (OID) IS 'get table primary key columns';

/*
=================== GET_PRIMARY_KEY_NAME =================== 
*/
CREATE FUNCTION get_primary_key_name ("relid" OID)
    RETURNS TEXT
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-index.html
    -- https://postgresql.org/docs/current/catalog-pg-class.html
    RETURN (
        SELECT c."relname"
        FROM "pg_class" c
        WHERE c."oid" = (
                SELECT i."indexrelid"
                FROM "pg_index" i
                WHERE i."indrelid" = "relid"
                    AND i."indisprimary"));
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_primary_key_name (OID) IS 'get table primary key name';

/*
=================== JSONB_OBJECT_FIELDS =================== 
*/
CREATE FUNCTION jsonb_object_fields ("value" JSONB, "paths" TEXT[])
    RETURNS JSONB
    AS $$
BEGIN
    RETURN "value" - (ARRAY (
            SELECT jsonb_object_keys("value")) - "paths");
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION jsonb_object_fields (JSONB, TEXT[]) IS 'get json object fields';

CREATE OPERATOR -> (
    LEFTARG = JSONB, RIGHTARG = TEXT[], FUNCTION = jsonb_object_fields
);

COMMENT ON OPERATOR -> (JSONB, TEXT[]) IS 'get json object fields';

/*
=================== LANG =================== 
*/
CREATE FUNCTION lang ("value" TEXT)
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
    RETURN ("has_language" AND language("arr"[1])) AND
           (NOT ("has_script") OR (script("arr"[2]) OR (region("arr"[2]) AND NOT "has_region"))) AND
           (NOT ("has_region") OR region("arr"[3]));
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION lang (TEXT) IS 'RFC 5646';

/*
=================== LANGUAGE =================== 
*/
CREATE FUNCTION language ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[a-z]{2,3}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION language (TEXT) IS 'ISO 639';

/*
=================== REGION =================== 
*/
CREATE FUNCTION region ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[A-Z]{2}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION region (TEXT) IS 'ISO 3166-1';

/*
=================== SCRIPT =================== 
*/
CREATE FUNCTION script ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[A-Z][a-z]{3}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION script (TEXT) IS 'ISO 15924';

/*
=================== LANG =================== 
*/
CREATE DOMAIN LANG AS VARCHAR(11)
CHECK (lang (VALUE));

COMMENT ON DOMAIN LANG IS 'RFC 5646';

/*
=================== LANGUAGE =================== 
*/
CREATE DOMAIN LANGUAGE AS VARCHAR(3)
CHECK (language (VALUE));

COMMENT ON DOMAIN LANGUAGE IS 'ISO 639';

/*
=================== REGION =================== 
*/
CREATE DOMAIN REGION AS VARCHAR(2)
CHECK (region (VALUE));

COMMENT ON DOMAIN REGION IS 'ISO 3166-1';

/*
=================== SCRIPT =================== 
*/
CREATE DOMAIN SCRIPT AS VARCHAR(4)
CHECK (script (VALUE));

COMMENT ON DOMAIN SCRIPT IS 'ISO 15924';

/*
=================== LANG =================== 
*/
CREATE TABLE "langs"
(
    "lang"      LANG PRIMARY KEY
                GENERATED ALWAYS AS (
                            "language" ||
                            CASE WHEN ("script" IS NULL) THEN '' ELSE ('-' || "script") END ||
                            CASE WHEN ("region" IS NULL) THEN '' ELSE ('-' || "region") END
                    ) STORED,
    "language"  LANGUAGE     NOT NULL,
    "script"    SCRIPT,
    "region"    REGION,
    "is_active" BOOLEAN      NOT NULL DEFAULT FALSE,
    "title"     VARCHAR(50) NOT NULL UNIQUE
);

COMMENT ON TABLE "langs" IS 'RFC 5646';

/*
=================== LANG_BASE =================== 
*/
CREATE TABLE "lang_base" (
    "default_lang" LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "lang_base__insert" AS ON INSERT TO "lang_base"
    DO INSTEAD
    NOTHING;

/*
=================== LANG_BASE_TRAN =================== 
*/
CREATE TABLE "lang_base_tran" (
    "lang" LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "lang_base_trans__insert" AS ON INSERT TO "lang_base_tran"
    DO INSTEAD
    NOTHING;

/*
=================== ADD_CONSTRAINTS_FROM_LANG_PARENT_TABLES =================== 
*/
CREATE FUNCTION event_trigger_add_constraints_from_lang_parent_tables ()
    RETURNS EVENT_TRIGGER
    AS $$
DECLARE
    "parents" CONSTANT     REGCLASS[] = ARRAY ['"lang_base"'::REGCLASS, '"lang_base_tran"'::REGCLASS];
    "tg_relid"             OID;
    "tg_relid_constraints" TEXT[];
    "relid"                OID;
    "relids"               OID[];
    "constraints"          TEXT[];
    "table"                TEXT;
    "obj"                  RECORD;
    "constraint"           TEXT;
BEGIN
    FOR "obj" IN
    SELECT *
    FROM pg_event_trigger_ddl_commands ()
        LOOP
            RAISE DEBUG 'objid = %', "obj".objid;
            RAISE DEBUG 'command_tag = %', "obj".command_tag;
            RAISE DEBUG 'schema_name = %', "obj".schema_name;
            RAISE DEBUG 'object_type = %', "obj".object_type;
            RAISE DEBUG 'object_identity = %', "obj".object_identity;
            RAISE DEBUG 'in_extension = %', "obj".in_extension;
            IF "obj".in_extension = TRUE THEN
                CONTINUE;
            END IF;
            IF "obj".command_tag = 'CREATE TABLE' THEN
                "tg_relid" = "obj".objid;
                RAISE DEBUG USING MESSAGE = (concat('command_tag: CREATE TABLE ', "obj".object_identity));
                -- parent tables of the created table
                "relids" = (
                    SELECT array_agg(p.oid)
                    FROM pg_inherits
                        JOIN pg_class AS c ON (inhrelid = c.oid)
                        JOIN pg_class AS p ON (inhparent = p.oid)
                    WHERE c.oid = "tg_relid"
                        AND p.oid = ANY ("parents"));
                RAISE DEBUG USING MESSAGE = (concat('parents: ', COALESCE("relids", '{}')));
                "table" = "tg_relid"::REGCLASS;
                -- get existing constraints
                "tg_relid_constraints" = get_constraintdefs ("tg_relid");
                FOREACH "relid" IN ARRAY COALESCE("relids", '{}')
                LOOP
                    -- except existing constraints from parent constraints
                    "constraints" = get_constraintdefs ("relid") - "tg_relid_constraints";
                    FOREACH "constraint" IN ARRAY COALESCE("constraints", '{}')
                    LOOP
                        RAISE NOTICE USING MESSAGE = (concat('FROM PARENT TABLE: ', "relid"::REGCLASS));
                        RAISE NOTICE USING MESSAGE = (concat('ADD CONSTRAINT: ', "constraint"));
                        EXECUTE format('ALTER TABLE %s ADD %s;', "table", "constraint");
                    END LOOP;
                END LOOP;
                ELSEIF "obj".command_tag = 'ALTER TABLE' THEN
                "tg_relid" = "obj".objid;
                IF NOT ("tg_relid" = ANY ("parents")) THEN
                    CONTINUE;
                END IF;
                RAISE DEBUG USING MESSAGE = (concat('command_tag: ALTER TABLE ', "obj".object_identity));
                -- children tables of the altered table
                "relids" = (
                    SELECT array_agg(c.oid)
                    FROM pg_inherits
                        JOIN pg_class AS c ON (inhrelid = c.oid)
                        JOIN pg_class AS p ON (inhparent = p.oid)
                    WHERE p.oid = "tg_relid");
                RAISE DEBUG USING MESSAGE = (concat('children: ', COALESCE("relids", '{}')));
                -- get existing constraints
                "tg_relid_constraints" = get_constraintdefs ("tg_relid");
                FOREACH "relid" IN ARRAY COALESCE("relids", '{}')
                LOOP
                    -- except existing constraints from parent constraints
                    "constraints" = "tg_relid_constraints" - get_constraintdefs ("relid");
                    "table" = "relid"::REGCLASS;
                    RAISE NOTICE USING MESSAGE = (concat('TO CHILD TABLE: ', "table"));
                    FOREACH "constraint" IN ARRAY COALESCE("constraints", '{}')
                    LOOP
                        RAISE NOTICE USING MESSAGE = (concat('ADD CONSTRAINT: ', "constraint"));
                        EXECUTE format('ALTER TABLE %s ADD %s;', "table", "constraint");
                    END LOOP;
                END LOOP;
            END IF;
        END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;

/*
=================== DICTINARY =================== 
*/
CREATE PROCEDURE create_dictionary_view ("name" TEXT, "lb_table" REGCLASS, "lbt_table" REGCLASS, "where" TEXT = NULL)
    AS $$
DECLARE
    "name"        CONSTANT TEXT NOT NULL   = COALESCE(format_table_name("name"), format_table_name("lb_table"::TEXT, 'v_'));
    "lb_columns"  CONSTANT TEXT[] NOT NULL = get_columns("lb_table");
    "lbt_columns" CONSTANT TEXT[] NOT NULL = get_columns("lbt_table");
    "pk_columns"  CONSTANT TEXT[] NOT NULL = get_primary_key("lb_table");
    "columns"              TEXT[];
    "column"               TEXT;
BEGIN
    IF ("lb_table" IS NULL) OR ("lbt_table" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" and "lbt_table" cannot be NULL';
    END IF;
    FOREACH "column" IN ARRAY "lb_columns" LOOP
        -- if the column is in "lbt_table"
        IF "column" = ANY ("lbt_columns") THEN
            "columns" = array_append("columns", format('COALESCE(bt.%1$I, b.%1$I) AS %1$I', "column"));
        ELSE
            "columns" = array_append("columns", format('b.%1$I', "column"));
        END IF;
    END LOOP;
    IF "where" IS NULL THEN
        "where" = 'TRUE';
    END IF;
    EXECUTE format('
        CREATE VIEW %1s AS
        SELECT (bt.*) IS NULL AS "is_default", "langs"."lang", %2s
            FROM %3s b
            CROSS JOIN "langs"
            LEFT JOIN %4s bt USING ("lang", %5s)
            WHERE %6s;
    ', "name", array_to_string("columns", ','), "lb_table", "lbt_table", array_to_string("pk_columns", ','), "where");
    EXECUTE format('
        CREATE TRIGGER "update"
            INSTEAD OF UPDATE
            ON %1s FOR EACH ROW
        EXECUTE FUNCTION trigger_update_dictionary_view(%2L, %3L);
    ', "name", "lb_table", "lbt_table");
END
$$
LANGUAGE plpgsql;

/*
=================== USER =================== 
*/
CREATE PROCEDURE create_user_view ("name" TEXT, "lb_table" REGCLASS, "lbt_table" REGCLASS, "select" TEXT[] = '{*}', "where" TEXT = NULL)
    AS $$
DECLARE
    "name"       CONSTANT TEXT NOT NULL   = COALESCE(format_table_name("name"), format_table_name("lb_table"::TEXT, 'v_'));
    "pk_columns" CONSTANT TEXT[] NOT NULL = get_primary_key("lb_table");
BEGIN
    IF ("lb_table" IS NULL) OR ("lbt_table" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" and "lbt_table" cannot be NULL';
    END IF;
    IF "where" IS NULL THEN
        "where" = 'TRUE';
    END IF;
    EXECUTE format('
        CREATE VIEW %1s AS
        SELECT (b."default_lang" = bt."lang") IS TRUE AS "is_default", %2s
            FROM %3s b
            LEFT JOIN %4s bt USING (%5s)
            WHERE %6s;
    ', "name", array_to_string("select", ','), "lb_table", "lbt_table", array_to_string("pk_columns", ','), "where");
    EXECUTE format('
        CREATE TRIGGER "insert"
            INSTEAD OF INSERT
            ON %1s FOR EACH ROW
        EXECUTE FUNCTION trigger_insert_user_view(%2L, %3L);
    ', "name", "lb_table", "lbt_table");
    EXECUTE format('
        CREATE TRIGGER "update"
            INSTEAD OF UPDATE
            ON %1s FOR EACH ROW
        EXECUTE FUNCTION trigger_update_user_view(%2L, %3L);
    ', "name", "lb_table", "lbt_table");
END
$$
LANGUAGE plpgsql;

/*
=================== INSERT_USER_VIEW =================== 
*/
CREATE FUNCTION trigger_insert_user_view ()
    RETURNS TRIGGER
    AS $$
DECLARE
    "record"                 JSONB NOT NULL    = to_jsonb(NEW);
    "lb_record"              JSONB NOT NULL    = '{}';
    "lb_table"      CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    "lb_pk_columns" CONSTANT TEXT[] NOT NULL   = get_primary_key("lb_table");
    "lb_columns"    CONSTANT TEXT[] NOT NULL   = get_columns("lb_table", FALSE) - "lb_pk_columns";
    "lb_values"              TEXT[];
    "lbt_table"     CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    "lbt_columns"   CONSTANT TEXT[] NOT NULL   = get_columns("lbt_table", FALSE);
    "lbt_values"             TEXT[];
    "column"                 TEXT;
BEGIN
    FOREACH "column" IN ARRAY "lb_pk_columns" LOOP
        -- all columns in primary key is not NULL, DEFAULT for sequence
        IF NOT ("record" ? "column") OR ("record" ->> "column" IS NULL) THEN
            "lb_values" = array_append("lb_values", 'DEFAULT');
        ELSE
            "lb_values" = array_append("lb_values", format('%L', "record" ->> "column"));
        END IF;
    END LOOP;
    FOREACH "column" IN ARRAY "lb_columns" LOOP
        "lb_values" = array_append("lb_values", format('%L', "record" ->> "column"));
    END LOOP;
    EXECUTE format('INSERT INTO %1s (%2s) VALUES (%3s) RETURNING to_json(%4s.*);',
        "lb_table",
        array_to_string("lb_pk_columns" || "lb_columns", ','), array_to_string("lb_values", ','),
        "lb_table"
    ) INTO "lb_record";
    "record" = "record" || "lb_record";
    FOREACH "column" IN ARRAY "lbt_columns" LOOP
        "lbt_values" = array_append("lbt_values", format('%L', "record" ->> "column"));
    END LOOP;
    EXECUTE format('INSERT INTO %1s (%2s) VALUES (%3s);',
        "lbt_table",
        array_to_string("lbt_columns", ','), array_to_string("lbt_values", ',')
    );
    RETURN NEW;
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER;

/*
=================== UPDATE_DICTIONARY_VIEW =================== 
*/
CREATE FUNCTION trigger_update_dictionary_view ()
    RETURNS TRIGGER
    AS $$
DECLARE
    "old_record"              JSONB NOT NULL    = to_jsonb(OLD);
    "new_record"              JSONB NOT NULL    = to_jsonb(NEW);
    "lbt_table"      CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    "lbt_pk_name"    CONSTANT TEXT NOT NULL     = get_primary_key_name("lbt_table");
    "lbt_pk_columns" CONSTANT TEXT[] NOT NULL   = get_primary_key("lbt_table");
    "lbt_pk_values"           TEXT[];
    "lbt_columns"    CONSTANT TEXT[] NOT NULL   = get_columns("lbt_table", FALSE) - "lbt_pk_columns";
    "lbt_values"              TEXT[];
    "lb_record"               JSONB NOT NULL    = '{}';
    "lb_table"       CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    "lb_pk_columns"  CONSTANT TEXT[] NOT NULL   = get_primary_key("lb_table");
    "lb_pk_values"            TEXT[];
    "lb_columns"     CONSTANT TEXT[] NOT NULL   = get_columns("lb_table", FALSE) - "lbt_columns";
    "lb_values"               TEXT[];
    "column"                  TEXT;
BEGIN
    FOREACH "column" IN ARRAY "lb_pk_columns" LOOP
        "lb_pk_values" = array_append("lb_pk_values", format('%L', "old_record" ->> "column"));
    END LOOP;
    FOREACH "column" IN ARRAY "lb_columns" LOOP
        "lb_values" = array_append("lb_values", format('%L', "new_record" ->> "column"));
    END LOOP;
    EXECUTE format('UPDATE %1s SET (%2s)=ROW(%3s) WHERE (%4s)=(%5s) RETURNING to_json(%4s.*);',
        "lb_table", array_to_string("lb_columns", ','),
        array_to_string("lb_values", ','), array_to_string("lb_pk_columns", ','),
        array_to_string("lb_pk_values", ','), "lb_table"
    ) INTO "lb_record";
    "new_record" = "new_record" || ("lb_record" -> ("lb_columns" || "lb_pk_columns"));
    FOREACH "column" IN ARRAY "lbt_pk_columns" LOOP
        "lbt_pk_values" = array_append("lbt_pk_values", format('%L', "new_record" ->> "column"));
    END LOOP;
    FOREACH "column" IN ARRAY "lbt_columns" LOOP
        "lbt_values" = array_append("lbt_values", format('%L', "new_record" ->> "column"));
    END LOOP;
    EXECUTE format('
        INSERT INTO %1s (%2s) VALUES (%3s)
            ON CONFLICT ON CONSTRAINT %4I
            DO UPDATE SET (%5s)=ROW(%6s);',
        "lbt_table",
        array_to_string("lbt_pk_columns" || "lbt_columns", ','), array_to_string("lbt_pk_values" || "lbt_values", ','),
        "lbt_pk_name",
        array_to_string("lbt_columns", ','), array_to_string("lbt_values", ',')
    );
    RETURN NEW;
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER;

/*
=================== UPDATE_USER_VIEW =================== 
*/
CREATE FUNCTION trigger_update_user_view ()
    RETURNS TRIGGER
    AS $$
DECLARE
    "old_record"              JSONB NOT NULL    = to_jsonb(OLD);
    "new_record"              JSONB NOT NULL    = to_jsonb(NEW);
    "lb_record"               JSONB NOT NULL    = '{}';
    "lb_table"       CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    "lb_pk_columns"  CONSTANT TEXT[] NOT NULL   = get_primary_key("lb_table");
    "lb_pk_values"            TEXT[];
    "lb_columns"     CONSTANT TEXT[] NOT NULL   = get_columns("lb_table", FALSE);
    "lb_values"               TEXT[];
    "lbt_table"      CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    "lbt_pk_columns" CONSTANT TEXT[] NOT NULL   = get_primary_key("lbt_table");
    "lbt_pk_values"           TEXT[];
    "lbt_columns"    CONSTANT TEXT[] NOT NULL   = get_columns("lbt_table", FALSE);
    "lbt_values"              TEXT[];
    "column"                  TEXT;
BEGIN
    FOREACH "column" IN ARRAY "lb_pk_columns" LOOP
        "lb_pk_values" = array_append("lb_pk_values", format('%L', "old_record" ->> "column"));
    END LOOP;
    FOREACH "column" IN ARRAY "lb_columns" LOOP
        "lb_values" = array_append("lb_values", format('%L', "new_record" ->> "column"));
    END LOOP;
    EXECUTE format('UPDATE %1s SET (%2s)=ROW(%3s) WHERE (%4s)=(%5s) RETURNING to_json(%4s.*);',
        "lb_table",
        array_to_string("lb_columns", ','), array_to_string("lb_values", ','),
        array_to_string("lb_pk_columns", ','), array_to_string("lb_pk_values", ','),
        "lb_table"
    ) INTO "lb_record";
    "old_record" = "old_record" || "lb_record";
    "new_record" = "new_record" || "lb_record";
    FOREACH "column" IN ARRAY "lbt_pk_columns" LOOP
        "lbt_pk_values" = array_append("lbt_pk_values", format('%L', "old_record" ->> "column"));
    END LOOP;
    FOREACH "column" IN ARRAY "lbt_columns" LOOP
        "lbt_values" = array_append("lbt_values", format('%L', "new_record" ->> "column"));
    END LOOP;
    EXECUTE format('UPDATE %1s SET (%2s)=ROW(%3s) WHERE (%4s)=(%5s);',
        "lbt_table",
        array_to_string("lbt_columns", ','), array_to_string("lbt_values", ','),
        array_to_string("lbt_pk_columns", ','), array_to_string("lbt_pk_values", ',')
    );
    RETURN NEW;
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER;

/*
=================== INIT =================== 
*/
-- Chapter 40. Event Triggers - https://postgresql.org/docs/current/event-triggers.html
-- Event Trigger Functions - https://postgresql.org/docs/current/functions-event-triggers.html
-- Event Trigger Firing Matrix - https://postgresql.org/docs/current/event-trigger-matrix.html
CREATE EVENT TRIGGER "add_constraints_from_lang_parent_tables" ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE')
        EXECUTE PROCEDURE event_trigger_add_constraints_from_lang_parent_tables ();

