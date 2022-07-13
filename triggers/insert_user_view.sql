CREATE OR REPLACE FUNCTION trigger_insert_user_view()
    RETURNS TRIGGER
AS
$$
DECLARE
    "record"      CONSTANT JSONB NOT NULL    = to_jsonb(NEW);
    "lb_table"    CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    "lb_columns"  CONSTANT TEXT[] NOT NULL   = get_columns("lb_table");
    "lb_values"            TEXT[];
    "lbt_table"   CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    "lbt_columns" CONSTANT TEXT[] NOT NULL   = get_columns("lbt_table");
    "lbt_values"           TEXT[];
    "column"               TEXT;
BEGIN
    FOREACH "column" IN ARRAY "lb_columns"
        LOOP
            "lb_values" = array_append("lb_values", format('%L', "record" ->> "column"));
        END LOOP;

    FOREACH "column" IN ARRAY "lbt_columns"
        LOOP
            "lbt_values" = array_append("lbt_values", format('%L', "record" ->> "column"));
        END LOOP;

    EXECUTE format('INSERT INTO %s (%s) VALUES (%s);', "lb_table", array_to_string("lb_columns", ','), array_to_string("lb_values", ','));
    EXECUTE format('INSERT INTO %s (%s) VALUES (%s);', "lbt_table", array_to_string("lbt_columns", ','), array_to_string("lbt_values", ','));

    RETURN NEW;
END
$$
    LANGUAGE plpgsql;
