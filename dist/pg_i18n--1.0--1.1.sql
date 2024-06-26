/*
=================== ARRAY_INTERSECT ===================
*/
COMMENT ON FUNCTION @extschema@.array_intersect (ANYARRAY, ANYARRAY) IS '$1 INTERSECT $2';

COMMENT ON OPERATOR @extschema@.& (ANYARRAY, ANYARRAY) IS '$1 INTERSECT $2';

/*
=================== INSERT_OR_UPDATE_USING_RECORDS ===================
*/
CREATE OR REPLACE FUNCTION @extschema@.insert_or_update_using_records ("table" REGCLASS, "new" RECORD)
    RETURNS JSONB
AS $$
DECLARE
    "result"              JSONB NOT NULL = '{}';
    -- pk - primary key
    -- sk - secondary key
    "pk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_primary_key("table");
    "pk_values"           TEXT[];
    "sk_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("table", FALSE) OPERATOR ( dictionaries.- ) "pk_columns";
    "sk_values"           TEXT[];
    --helpers
    "column"              TEXT;
    "pk_name"    CONSTANT TEXT  NOT NULL = @extschema@.get_primary_key_name("table");
BEGIN
    -- set primary key
    FOREACH "column" IN ARRAY "pk_columns" LOOP
            "pk_values" = array_append("pk_values", format('$1.%I', "column"));
        END LOOP;
    -- set secondary key
    FOREACH "column" IN ARRAY "sk_columns" LOOP
            "sk_values" = array_append("sk_values", format('$1.%I', "column"));
        END LOOP;

    EXECUTE format('
        INSERT INTO %1s (%2s) VALUES (%3s)
            ON CONFLICT ON CONSTRAINT %4I
            DO UPDATE SET (%5s)=ROW(%6s)
            RETURNING to_json(%7s.*);',
                   "table", array_to_string("pk_columns" || "sk_columns", ','), array_to_string("pk_values" || "sk_values", ','),
                   "pk_name",
                   array_to_string("sk_columns", ','), array_to_string("sk_values", ','),
                   "table")
        INTO "result" USING "new";

    RETURN "result";
END
$$
    LANGUAGE plpgsql
    VOLATILE
    SECURITY DEFINER
    RETURNS NULL ON NULL INPUT;

/*
=================== INSERT_OR_UPDATE_USING_ARRAYS ===================
*/
DROP FUNCTION @extschema@.insert_or_update_using_arrays ("table" REGCLASS, "columns" TEXT[], "values" TEXT[], "ch_columns" TEXT[], "ch_values" TEXT[], "new" RECORD);

/*
=================== INSERT_USING_RECORDS ===================
*/
CREATE OR REPLACE FUNCTION @extschema@.insert_using_records ("table" REGCLASS, "new" RECORD)
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
    EXECUTE format(
            'INSERT INTO %1s (%2s) VALUES (%3s) RETURNING to_jsonb(%4s.*);',
            "table",
            array_to_string("pk_columns" || "sk_columns", ','),
            array_to_string("pk_values"  || "sk_values", ','),
            "table"
            )
        INTO "result" USING "new";

    RETURN "result";
END
$$
    LANGUAGE plpgsql
    VOLATILE
    SECURITY DEFINER
    RETURNS NULL ON NULL INPUT;

/*
=================== INSERT_USING_ARRAYS ===================
*/
DROP FUNCTION @extschema@.insert_using_arrays ("table" REGCLASS, "columns" TEXT[],  "values" TEXT[], "new" RECORD);

/*
=================== UPDATE_USING_RECORDS ===================
*/
CREATE OR REPLACE FUNCTION @extschema@.update_using_records ("table" REGCLASS, "ch_columns" TEXT[], "old" RECORD, "new" RECORD)
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
                EXECUTE format(
                    'UPDATE %1s SET (%2s)=ROW(%3s) WHERE (%4s)=(%5s) RETURNING to_json(%6s.*);',
                    "table",
                    array_to_string("ch_columns", ','),
                    array_to_string("ch_values", ','),
                    array_to_string("pk_columns", ','),
                    array_to_string("pk_values", ','),
                    "table"
                )
            INTO "result" USING "old", "new";
    END IF;

    RETURN "result";
END
$$
    LANGUAGE plpgsql
    VOLATILE
    SECURITY DEFINER
    RETURNS NULL ON NULL INPUT;

/*
=================== UPDATE_USING_ARRAYS ===================
*/
DROP FUNCTION @extschema@.update_using_arrays ("table" REGCLASS, "pk_columns" TEXT[], "pk_values" TEXT[], "ch_columns" TEXT[], "ch_values" TEXT[], "old" RECORD, "new" RECORD);

/*
=================== LANG_BASE ===================
*/
CREATE RULE "update" AS ON UPDATE TO @extschema@."lang_base" DO INSTEAD NOTHING;
CREATE RULE "delete" AS ON DELETE TO @extschema@."lang_base" DO INSTEAD NOTHING;

/*
=================== LANG_BASE_TRAN ===================
*/
CREATE RULE "update" AS ON UPDATE TO @extschema@."lang_base_tran" DO INSTEAD NOTHING;
CREATE RULE "delete" AS ON DELETE TO @extschema@."lang_base_tran" DO INSTEAD NOTHING;

/*
=================== DICTINARY ===================
*/
CREATE OR REPLACE PROCEDURE @extschema@.create_dictionary_view ("name" TEXT, "lb_table" REGCLASS, "lbt_table" REGCLASS, "select" TEXT[] = '{}', "where" TEXT = NULL)
AS $$
DECLARE
    "name"        CONSTANT TEXT   NOT NULL = COALESCE(@extschema@.format_table_name("name"), @extschema@.format_table_name("lb_table"::TEXT, 'v_'));
    "pk_columns"  CONSTANT TEXT[]          = @extschema@.get_primary_key("lb_table");
    "lb_columns"  CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("lb_table");
    "lbt_columns" CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("lbt_table");
    "lb_column"               TEXT;
BEGIN
    IF ("lb_table" IS NULL) OR ("lbt_table" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" and "lbt_table" cannot be NULL';
    END IF;
    IF ("pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" table must have primary keys';
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
CREATE OR REPLACE PROCEDURE @extschema@.create_user_view ("name" TEXT, "lb_table" REGCLASS, "lbt_table" REGCLASS, "select" TEXT[] = '{*}', "where" TEXT = NULL)
AS $$
DECLARE
    "name"       CONSTANT TEXT NOT NULL   = COALESCE(@extschema@.format_table_name("name"), @extschema@.format_table_name("lb_table"::TEXT, 'v_'));
    "columns"    CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("lb_table");
    "pk_columns" CONSTANT TEXT[]          = @extschema@.get_primary_key("lb_table");
BEGIN
    IF ("lb_table" IS NULL) OR ("lbt_table" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" and "lbt_table" cannot be NULL';
    END IF;
    IF ("pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" table must have primary keys';
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
