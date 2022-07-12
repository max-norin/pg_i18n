CREATE OR REPLACE PROCEDURE create_dictionary_view("name" TEXT, "lb_table" REGCLASS, "lbt_table" REGCLASS)
AS
$$
DECLARE
    "normal_lang_base"    TEXT;
    "lb_columns"          TEXT[];
    "lbt_columns"         TEXT[];
    "columns"             TEXT[];
    "pk_columns" CONSTANT TEXT[] = get_primary_key("lb_table"::REGCLASS::OID);
    "column"              TEXT;
BEGIN
    IF "lb_table" IS NULL THEN
        RAISE EXCEPTION USING MESSAGE = 'NOT lb_table';
    END IF;

    "name" = COALESCE("name", 'v_' || "lb_table"::TEXT);
    IF "lbt_table" IS NULL THEN
        "normal_lang_base" = "lb_table"::TEXT;
        "normal_lang_base" = regexp_replace("normal_lang_base", 'ies$', 'y');
        "normal_lang_base" = regexp_replace("normal_lang_base", 'es$', '');
        "normal_lang_base" = regexp_replace("normal_lang_base", 's$', '');
        "lbt_table" = "normal_lang_base" || '_trans';
    END IF;

    "lb_columns" = get_columns("lb_table");
    "lbt_columns" = get_columns("lbt_table");

    FOREACH "column" IN ARRAY "lb_columns"
        LOOP
            IF "column" = ANY ("lbt_columns") THEN
                "columns" = array_append("columns", format('COALESCE(bt.%1$I, b.%1$I) AS %1$I', "column"));
            ELSE
                "columns" = array_append("columns", format('b.%1$I', "column"));
            END IF;
        END LOOP;

    EXECUTE format('
        CREATE VIEW %I AS
        SELECT (bt.*) IS NULL AS "is_default", "langs"."lang", %s
            FROM %I b
            CROSS JOIN "langs"
            LEFT JOIN %I bt USING ("lang", %s);
    ', "name", array_to_string("columns", ','), "lb_table", "lbt_table", array_to_string("pk_columns", ','));

    EXECUTE format('
        CREATE TRIGGER "update"
            INSTEAD OF UPDATE
            ON %I FOR EACH ROW
        EXECUTE FUNCTION trigger_update_dictionary_view(%L, %L);
    ', "name", "lb_table", "lbt_table");
END
$$
    LANGUAGE plpgsql;

COMMENT ON PROCEDURE create_dictionary_view (TEXT, REGCLASS, REGCLASS) IS '';
