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

