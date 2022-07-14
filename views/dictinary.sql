CREATE PROCEDURE create_dictionary_view("name" TEXT, "lb_table" REGCLASS, "lbt_table" REGCLASS)
AS
$$
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

    FOREACH "column" IN ARRAY "lb_columns"
        LOOP
            -- if the column is in "lbt_table"
            IF "column" = ANY ("lbt_columns") THEN
                "columns" = array_append("columns", format('COALESCE(bt.%1$I, b.%1$I) AS %1$I', "column"));
            ELSE
                "columns" = array_append("columns", format('b.%1$I', "column"));
            END IF;
        END LOOP;

    EXECUTE format('
        CREATE VIEW %1s AS
        SELECT (bt.*) IS NULL AS "is_default", "langs"."lang", %2s
            FROM %3s b
            CROSS JOIN "langs"
            LEFT JOIN %4s bt USING ("lang", %5s);
    ', "name", array_to_string("columns", ','), "lb_table", "lbt_table", array_to_string("pk_columns", ','));

    EXECUTE format('
        CREATE TRIGGER "update"
            INSTEAD OF UPDATE
            ON %1s FOR EACH ROW
        EXECUTE FUNCTION trigger_update_dictionary_view(%2L, %3L);
    ', "name", "lb_table", "lbt_table");
END
$$
    LANGUAGE plpgsql;
