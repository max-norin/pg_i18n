CREATE OR REPLACE PROCEDURE create_user_view("name" TEXT, "lb_table" REGCLASS, "lbt_table" REGCLASS)
AS
$$
DECLARE
    "normal_lang_base"    TEXT;
    "pk_columns" CONSTANT TEXT[] = get_primary_key("lb_table"::REGCLASS::OID);
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

    EXECUTE format('
        CREATE VIEW %1I AS
        SELECT (b."default_lang" = bt."lang") IS TRUE AS "is_default", *
            FROM %2s b
            LEFT JOIN %3I bt USING (%s);
    ', "name", "lb_table", "lbt_table", array_to_string("pk_columns", ','));

    EXECUTE format('
        CREATE TRIGGER "insert"
            INSTEAD OF INSERT
            ON %1I FOR EACH ROW
        EXECUTE FUNCTION trigger_insert_user_view(%2L, %3L);
    ', "name", "lb_table", "lbt_table");

    EXECUTE format('
        CREATE TRIGGER "update"
            INSTEAD OF UPDATE
            ON %1I FOR EACH ROW
        EXECUTE FUNCTION update_user_view(%2L, %3L);
    ', "name", "lb_table", "lbt_table");
END
$$
    LANGUAGE plpgsql;

COMMENT ON PROCEDURE create_user_view (TEXT, REGCLASS, REGCLASS) IS '';
