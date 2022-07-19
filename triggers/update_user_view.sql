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
    "lb_columns"     CONSTANT TEXT[] NOT NULL   = get_columns("lb_table");
    "lb_values"               TEXT[];
    "lbt_table"      CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    "lbt_pk_columns" CONSTANT TEXT[] NOT NULL   = get_primary_key("lbt_table");
    "lbt_pk_values"           TEXT[];
    "lbt_columns"    CONSTANT TEXT[] NOT NULL   = get_columns("lbt_table");
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

