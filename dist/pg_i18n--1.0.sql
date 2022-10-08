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
=================== ARRAY_INTERSECT =================== 
*/
CREATE FUNCTION array_intersect ("a" ANYARRAY, "b" ANYARRAY)
    RETURNS ANYARRAY
    AS $$
BEGIN
    RETURN (SELECT ARRAY(SELECT UNNEST($1) INTERSECT SELECT UNNEST($2)));
END;
$$
LANGUAGE plpgsql
IMMUTABLE;

COMMENT ON FUNCTION array_intersect (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

CREATE OPERATOR & (
    LEFTARG = ANYARRAY, RIGHTARG = ANYARRAY, FUNCTION = array_intersect
);

COMMENT ON OPERATOR & (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

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
=================== GET_CONSTRAINTDEFS =================== 
*/
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
=================== INSERT_USING_ARRAYS =================== 
*/
CREATE OR REPLACE FUNCTION insert_using_arrays ("table" REGCLASS, "columns" TEXT[],  "values" TEXT[], "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    "result"           JSONB NOT NULL  = '{}';
    "columns" CONSTANT TEXT  NOT NULL  = array_to_string("columns", ',');
    "values"  CONSTANT TEXT  NOT NULL  = array_to_string("values", ',');
BEGIN
    EXECUTE format('INSERT INTO %1s (%2s) VALUES (%3s) RETURNING to_jsonb(%4s.*);', "table", "columns", "values", "table")
        INTO "result" USING "new";

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION insert_using_arrays (REGCLASS, TEXT[], TEXT[], RECORD) IS 'insert into table $1 using array of columns, array of values and NEW record';
/*
=================== INSERT_USING_RECORDS =================== 
*/
CREATE FUNCTION insert_using_records ("table" REGCLASS, "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    -- pk  - primary key
    -- sk  - secondary key
    -- main
    "result"              JSONB NOT NULL  = '{}';
    "record"              JSONB NOT NULL  = row_to_json(NEW);
    -- table
    "pk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("table");
    "pk_values"           TEXT[];
    "sk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("table", FALSE) OPERATOR ( @extschema@.- ) "pk_columns";
    "sk_values"           TEXT[];
    -- helpers
    "column"              TEXT;
BEGIN
    -- get primary key value for table
    FOREACH "column" IN ARRAY "pk_columns" LOOP
        -- all columns in primary key is not NULL, DEFAULT for sequence
        IF NOT ("record" ? "column") OR ("record" ->> "column" IS NULL) THEN
            "pk_values" = array_append("pk_values", 'DEFAULT');
        ELSE
            "pk_values" = array_append("pk_values", format('$1.%I', "column"));
        END IF;
    END LOOP;
    -- get other column values table
    FOREACH "column" IN ARRAY "sk_columns" LOOP
        "sk_values" = array_append("sk_values", format('$1.%I', "column"));
    END LOOP;
    -- insert and return record from table
    "result" = @extschema@.insert_using_arrays("table", "pk_columns" || "sk_columns", "pk_values"  || "sk_values", NEW);

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION insert_using_records (REGCLASS, RECORD) IS 'insert into table $1 using NEW record';
/*
=================== JSONB_EMPTY_BY_TABLE =================== 
*/
CREATE FUNCTION jsonb_empty_by_table ("relid" OID)
    RETURNS JSONB
    AS $$
DECLARE
    "columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("relid");
    "result"           JSONB           = '{}';
    "column"           TEXT;
BEGIN
    FOREACH "column" IN ARRAY "columns" LOOP
        "result" = jsonb_insert("result", ARRAY ["column"], 'null');
    END LOOP;

    RETURN "result";
END
$$
LANGUAGE plpgsql
IMMUTABLE;

COMMENT ON FUNCTION jsonb_empty_by_table (OID) IS 'get jsonb object with empty columns from table $1';
/*
=================== JSONB_EXCEPT =================== 
*/
CREATE FUNCTION jsonb_except ("a" JSONB, "b" JSONB)
    RETURNS JSONB
    AS $$
BEGIN
    RETURN (
        SELECT jsonb_object_agg(key, value)
            FROM (
                SELECT "key", "value"
                FROM jsonb_each_text("a")
                EXCEPT
                SELECT "key", "value"
                FROM jsonb_each_text("b")
                ) "table" ("key", "value"));
END;
$$
LANGUAGE plpgsql
IMMUTABLE;

COMMENT ON FUNCTION jsonb_except (JSONB, JSONB) IS '$1 EXCEPT $2';

CREATE OPERATOR - (
    LEFTARG = JSONB, RIGHTARG = JSONB, FUNCTION = jsonb_except
);

COMMENT ON OPERATOR - (JSONB, JSONB) IS '$1 EXCEPT $2';

/*
=================== JSONB_OBJECT_FIELDS =================== 
*/
CREATE FUNCTION jsonb_object_fields ("value" JSONB, "paths" TEXT[])
    RETURNS JSONB
    AS $$
BEGIN
    RETURN "value" - (ARRAY (SELECT jsonb_object_keys("value")) OPERATOR ( @extschema@.- ) "paths");
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
=================== JSONB_PK_TABLE_OBJECT =================== 
*/
CREATE FUNCTION jsonb_pk_table_object ("relid" OID, "record" JSONB)
    RETURNS JSONB
    AS $$
DECLARE
    -- main
    "result"              JSONB  NOT NULL  = '{}';
    -- primary keys
    "pk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("relid");
    -- helpers
    "column"              TEXT;
BEGIN
    FOREACH "column" IN ARRAY "pk_columns" LOOP
        "result" = jsonb_set("result", ARRAY ["column"], "record" -> "column");
    END LOOP;

    RETURN "result";
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION jsonb_pk_table_object (OID, JSONB) IS 'get jsonb object with primary key columns from table $1 and values from record $2';
/*
=================== UPDATE_USING_ARRAYS =================== 
*/
CREATE FUNCTION update_using_arrays ("table" REGCLASS, "pk_columns" TEXT[], "pk_values" TEXT[], "ch_columns" TEXT[], "ch_values" TEXT[], "old" RECORD, "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    -- pk  - primary key
    -- ch  - changed
    "result"              JSONB NOT NULL = '{}';
    "pk_columns" CONSTANT TEXT  NOT NULL = array_to_string("pk_columns", ',');
    "pk_values"  CONSTANT TEXT  NOT NULL = array_to_string("pk_values",  ',');
    "ch_columns" CONSTANT TEXT  NOT NULL = array_to_string("ch_columns", ',');
    "ch_values"  CONSTANT TEXT  NOT NULL = array_to_string("ch_values",  ',');
BEGIN
    EXECUTE format('UPDATE %1s SET (%2s)=ROW(%3s) WHERE (%4s)=(%5s) RETURNING to_json(%6s.*);', "table", "ch_columns", "ch_values", "pk_columns", "pk_values", "table")
        INTO "result" USING "old", "new";

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION update_using_arrays (REGCLASS, TEXT[], TEXT[], TEXT[], TEXT[], RECORD, RECORD) IS 'update table $1 using array of primary keys, array of values and OLD NEW records';
/*
=================== UPDATE_USING_RECORDS =================== 
*/
CREATE FUNCTION update_using_records ("table" REGCLASS, "ch_columns" TEXT[], "old" RECORD, "new" RECORD)
    RETURNS JSONB
    AS $$
DECLARE
    -- pk  - primary key
    -- ch  - changed
    -- main
    "result"                     JSONB  NOT NULL = '{}';
    -- table
    "columns"           CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("table", FALSE);
    -- primary keys
    "pk_columns"        CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("table");
    "pk_values"                  TEXT[];
    -- changed values
    "ch_columns"        CONSTANT TEXT[] NOT NULL = "columns" OPERATOR ( @extschema@.& ) "ch_columns";
    "ch_values"                  TEXT[];
    -- helpers
    "column"                     TEXT;
BEGIN
    IF array_length("ch_columns", 1) IS NOT NULL THEN
        -- set primary key values
        FOREACH "column" IN ARRAY "pk_columns" LOOP
            "pk_values" = array_append("pk_values", format('$1.%I', "column"));
        END LOOP;
        -- set changed values
        FOREACH "column" IN ARRAY "ch_columns" LOOP
            "ch_values" = array_append("ch_values", format('$2.%I', "column"));
        END LOOP;
        -- update and return record from table
        "result" = @extschema@.update_using_arrays("table", "pk_columns", "pk_values", "ch_columns", "ch_values", OLD, NEW);
    END IF;

    RETURN "result";
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION update_using_records (REGCLASS, TEXT[], RECORD, RECORD) IS 'update table $1 using change columns $2 and OLD NEW records';
/*
=================== LANG =================== 
*/
CREATE FUNCTION lang_rule ("value" TEXT)
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

COMMENT ON FUNCTION lang_rule (TEXT) IS 'RFC 5646';

/*
=================== LANGUAGE =================== 
*/
CREATE FUNCTION language_rule ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[a-z]{2,3}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION language_rule (TEXT) IS 'ISO 639';

/*
=================== REGION =================== 
*/
CREATE FUNCTION region_rule ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[A-Z]{2}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION region_rule (TEXT) IS 'ISO 3166-1';

/*
=================== SCRIPT =================== 
*/
CREATE FUNCTION script_rule ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[A-Z][a-z]{3}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION script_rule (TEXT) IS 'ISO 15924';

/*
=================== LANG =================== 
*/
CREATE DOMAIN LANG AS VARCHAR(11)
CHECK (@extschema@.lang_rule (VALUE));

COMMENT ON DOMAIN LANG IS 'RFC 5646';

/*
=================== LANGUAGE =================== 
*/
CREATE DOMAIN LANGUAGE AS VARCHAR(3)
CHECK (@extschema@.language_rule (VALUE));

COMMENT ON DOMAIN LANGUAGE IS 'ISO 639';

/*
=================== REGION =================== 
*/
CREATE DOMAIN REGION AS VARCHAR(2)
CHECK (@extschema@.region_rule (VALUE));

COMMENT ON DOMAIN REGION IS 'ISO 3166-1';

/*
=================== SCRIPT =================== 
*/
CREATE DOMAIN SCRIPT AS VARCHAR(4)
CHECK (@extschema@.script_rule (VALUE));

COMMENT ON DOMAIN SCRIPT IS 'ISO 15924';

/*
=================== LANGS =================== 
*/
CREATE TABLE "langs"
(
    "lang"      @extschema@.LANG PRIMARY KEY
                GENERATED ALWAYS AS (
                            "language" ||
                            CASE WHEN ("script" IS NULL) THEN '' ELSE ('-' || "script") END ||
                            CASE WHEN ("region" IS NULL) THEN '' ELSE ('-' || "region") END
                    ) STORED,
    "language"  @extschema@.LANGUAGE     NOT NULL,
    "script"    @extschema@.SCRIPT,
    "region"    @extschema@.REGION,
    "is_active" BOOLEAN      NOT NULL DEFAULT FALSE,
    "title"     VARCHAR(50) NOT NULL UNIQUE
);

COMMENT ON TABLE "langs" IS 'RFC 5646';

/*
=================== LANG_BASE =================== 
*/
CREATE TABLE "lang_base" (
    "default_lang" @extschema@.LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "lang_base__insert" AS ON INSERT TO "lang_base"
    DO INSTEAD
    NOTHING;

/*
=================== LANG_BASE_TRAN =================== 
*/
CREATE TABLE "lang_base_tran" (
    "lang" @extschema@.LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "lang_base_tran__insert" AS ON INSERT TO "lang_base_tran"
    DO INSTEAD
    NOTHING;

/*
=================== ADD_CONSTRAINTS_FROM_LANG_PARENT_TABLES =================== 
*/
CREATE FUNCTION event_trigger_add_constraints_from_lang_parent_tables ()
    RETURNS EVENT_TRIGGER
    AS $$
DECLARE
    "parents"              REGCLASS[];
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
            "parents" = ARRAY ['@extschema@."lang_base"'::REGCLASS, '@extschema@."lang_base_tran"'::REGCLASS];
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
                "tg_relid_constraints" = @extschema@.get_constraintdefs ("tg_relid");
                FOREACH "relid" IN ARRAY COALESCE("relids", '{}')
                LOOP
                    -- except existing constraints from parent constraints
                    "constraints" = @extschema@.get_constraintdefs ("relid") OPERATOR ( @extschema@.- ) "tg_relid_constraints";
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
                "tg_relid_constraints" = @extschema@.get_constraintdefs ("tg_relid");
                FOREACH "relid" IN ARRAY COALESCE("relids", '{}')
                LOOP
                    -- except existing constraints from parent constraints
                    "constraints" = "tg_relid_constraints" OPERATOR ( @extschema@.- ) @extschema@.get_constraintdefs ("relid");
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
CREATE PROCEDURE create_dictionary_view ("name" TEXT, "lb_table" REGCLASS, "lbt_table" REGCLASS, "select" TEXT[] = '{}', "where" TEXT = NULL)
    AS $$
DECLARE
    "name"        CONSTANT TEXT   NOT NULL = COALESCE(@extschema@.format_table_name("name"), @extschema@.format_table_name("lb_table"::TEXT, 'v_'));
    "pk_columns"  CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("lb_table");
    "lb_columns"  CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("lb_table");
    "lbt_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("lbt_table");
    "lb_column"               TEXT;
BEGIN
    IF ("lb_table" IS NULL) OR ("lbt_table" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" and "lbt_table" cannot be NULL';
    END IF;

    -- set select
    IF array_length("select", 1) IS NULL THEN
        "select" = array_append("select", '(bt.*) IS NULL AS "is_default"');
        "select" = array_append("select", '"langs"."lang"');
        FOREACH "lb_column" IN ARRAY "lb_columns" LOOP
            -- if the column is in "lbt_table"
            IF "lb_column" = ANY ("lbt_columns") THEN
                "select" = array_append("select", format('COALESCE(bt.%1$I, b.%1$I) AS %1$I', "lb_column"));
            ELSE
                "select" = array_append("select", format('b.%1$I', "lb_column"));
            END IF;
        END LOOP;
    END IF;
    -- set where
    IF "where" IS NULL THEN
        "where" = 'TRUE';
    END IF;

    -- create view
    EXECUTE format('
        CREATE VIEW %1s AS
        SELECT %2s
            FROM %3s b
            CROSS JOIN @extschema@."langs"
            LEFT JOIN %4s bt USING ("lang", %5s)
            WHERE %6s;
    ', "name", array_to_string("select", ','), "lb_table", "lbt_table", array_to_string("pk_columns", ','), "where");
    -- create trigger
    EXECUTE format('
        CREATE TRIGGER "update"
            INSTEAD OF UPDATE
            ON %1s FOR EACH ROW
        EXECUTE FUNCTION @extschema@.trigger_update_dictionary_view(%2L, %3L);
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
    "name"       CONSTANT TEXT NOT NULL   = COALESCE(@extschema@.format_table_name("name"), @extschema@.format_table_name("lb_table"::TEXT, 'v_'));
    "columns"    CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("lb_table");
    "pk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("lb_table");
BEGIN
    IF ("lb_table" IS NULL) OR ("lbt_table" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" and "lbt_table" cannot be NULL';
    END IF;

    -- add default_lang in select
    IF 'default_lang' = ANY ("columns") THEN
        "select" = array_prepend('(b."default_lang" = bt."lang") IS TRUE AS "lang_is_default"'::TEXT, "select");
    END IF;
    -- set where
    IF "where" IS NULL THEN
        "where" = 'TRUE';
    END IF;

    -- create view
    EXECUTE format('
        CREATE VIEW %1s AS
        SELECT %2s
            FROM %3s b
            LEFT JOIN %4s bt USING (%5s)
            WHERE %6s;
    ', "name", array_to_string("select", ','), "lb_table", "lbt_table", array_to_string("pk_columns", ','), "where");
    -- create triggers
    EXECUTE format('
        CREATE TRIGGER "insert"
            INSTEAD OF INSERT
            ON %1s FOR EACH ROW
        EXECUTE FUNCTION @extschema@.trigger_insert_user_view(%2L, %3L);
    ', "name", "lb_table", "lbt_table");
    EXECUTE format('
        CREATE TRIGGER "update"
            INSTEAD OF UPDATE
            ON %1s FOR EACH ROW
        EXECUTE FUNCTION @extschema@.trigger_update_user_view(%2L, %3L);
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
    -- lb  - language base
    -- lbt - lang base tran
    -- language base
    "lb_record"          JSONB;
    "lb_table"  CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    -- lang base tran
    "lbt_table" CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    -- helpers
    "record"             JSONB    NOT NULL ='{}';
BEGIN
    -- insert and return record from lb_table
    "lb_record" = @extschema@.insert_using_records("lb_table", NEW);
    -- join query result with target table record
    -- for the correctness of data types and adding the necessary data to lbt_table
    NEW = jsonb_populate_record(NEW, "lb_record");

    -- insert and return record from lbt_table
    PERFORM @extschema@.insert_using_records("lbt_table", NEW);

    -- change result new, empty object + pk object
    "record" = @extschema@.jsonb_empty_by_table(TG_RELID) || @extschema@.jsonb_pk_table_object("lb_table", to_jsonb(NEW));
    NEW = jsonb_populate_record(NEW, "record");

    -- returning record with primary keys only
    -- because this function does not know how the values of the target table are formed
    RETURN NEW;
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER;

COMMENT ON FUNCTION trigger_insert_user_view () IS 'DON''T USE DEFAULT WITH VIEWS';
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
    "lbt_pk_name"    CONSTANT TEXT NOT NULL     = @extschema@.get_primary_key_name("lbt_table");
    "lbt_pk_columns" CONSTANT TEXT[] NOT NULL   = @extschema@.get_primary_key("lbt_table");
    "lbt_pk_values"           TEXT[];
    "lbt_columns"    CONSTANT TEXT[] NOT NULL   = @extschema@.get_columns("lbt_table", FALSE) OPERATOR ( @extschema@.- ) "lbt_pk_columns";
    "lbt_values"              TEXT[];
    "lb_record"               JSONB NOT NULL    = '{}';
    "lb_table"       CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    "lb_pk_columns"  CONSTANT TEXT[] NOT NULL   = @extschema@.get_primary_key("lb_table");
    "lb_pk_values"            TEXT[];
    "lb_columns"     CONSTANT TEXT[] NOT NULL   = @extschema@.get_columns("lb_table", FALSE) OPERATOR ( @extschema@.- ) "lbt_columns";
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
    "new_record" = "new_record" || ("lb_record" OPERATOR ( @extschema@.-> ) ("lb_columns" || "lb_pk_columns"));
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
    -- lb  - lang base
    -- lbt - lang base tran
    -- ch  - changed
    -- main
    "ch_record"  CONSTANT JSONB             = to_jsonb(NEW) OPERATOR ( @extschema@.- ) to_jsonb(OLD);
    "ch_columns" CONSTANT TEXT[]   NOT NULL = ARRAY(SELECT jsonb_object_keys("ch_record"));
    -- lang base
    "lb_record"           JSONB    NOT NULL = '{}';
    "lb_table"   CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    -- lang base tran
    "lbt_table"  CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    -- helpers
    "record"              JSONB    NOT NULL ='{}';
BEGIN
    -- update and return record from lb_table
    "lb_record" = update_using_records("lb_table", "ch_columns", OLD, NEW);
    -- join query result with target table record
    -- for the correctness of data types and adding the necessary data to lbt_table
    NEW = jsonb_populate_record(NEW, "lb_record");

    -- update and return record from lbt_table
    PERFORM @extschema@.update_using_records("lbt_table", "ch_columns", NEW, NEW);

    -- change result new, empty object + pk object
    "record" = @extschema@.jsonb_empty_by_table(TG_RELID) || @extschema@.jsonb_pk_table_object("lb_table", to_jsonb(NEW));
    NEW = jsonb_populate_record(NEW, "record");

    -- returning record with primary keys only
    -- because this function does not know how the values of the target table are formed
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
        EXECUTE PROCEDURE @extschema@.event_trigger_add_constraints_from_lang_parent_tables ();

