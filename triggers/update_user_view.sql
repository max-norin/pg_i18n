CREATE FUNCTION trigger_update_user_view ()
    RETURNS TRIGGER
    AS $$
DECLARE
    "old_record"                   JSONB NOT NULL    = to_jsonb(OLD);
    "new_record"                   JSONB NOT NULL    = to_jsonb(NEW);
    "changed_record"      CONSTANT JSONB             = "new_record" OPERATOR ( @extschema@.- ) "old_record";
    "changed_columns"     CONSTANT TEXT[] NOT NULL   = ARRAY(SELECT jsonb_object_keys("changed_record"));
    "lb_record"                    JSONB NOT NULL    = '{}';
    "lb_table"            CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    "lb_pk_columns"       CONSTANT TEXT[] NOT NULL   = @extschema@.get_primary_key("lb_table");
    "lb_pk_values"                 TEXT[];
    "lb_columns"          CONSTANT TEXT[] NOT NULL   = @extschema@.get_columns("lb_table", FALSE);
    "lb_changed_columns"  CONSTANT TEXT[] NOT NULL   = "lb_columns" OPERATOR ( @extschema@.& ) "changed_columns";
    "lb_values"                    TEXT[];
    "lbt_table"           CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    "lbt_pk_columns"      CONSTANT TEXT[] NOT NULL   = @extschema@.get_primary_key("lbt_table");
    "lbt_pk_values"                TEXT[];
    "lbt_columns"         CONSTANT TEXT[] NOT NULL   = @extschema@.get_columns("lbt_table", FALSE);
    "lbt_changed_columns" CONSTANT TEXT[] NOT NULL   = "lbt_columns" OPERATOR ( @extschema@.& ) "changed_columns";
    "lbt_values"                   TEXT[];
    "column"                       TEXT;
BEGIN
    IF array_length("lb_changed_columns", 1) IS NOT NULL THEN
        FOREACH "column" IN ARRAY "lb_pk_columns" LOOP
            "lb_pk_values" = array_append("lb_pk_values", format('%L', "old_record" ->> "column"));
        END LOOP;
        FOREACH "column" IN ARRAY "lb_changed_columns" LOOP
            "lb_values" = array_append("lb_values", format('%L', "new_record" ->> "column"));
        END LOOP;
        EXECUTE format('UPDATE %1s SET (%2s)=ROW(%3s) WHERE (%4s)=(%5s) RETURNING to_json(%4s.*);',
            "lb_table",
            array_to_string("lb_changed_columns", ','), array_to_string("lb_values", ','),
            array_to_string("lb_pk_columns", ','), array_to_string("lb_pk_values", ','),
            "lb_table"
        ) INTO "lb_record";
        "old_record" = "old_record" || "lb_record";
        "new_record" = "new_record" || "lb_record";
    END IF;
    IF array_length("lbt_changed_columns", 1) IS NOT NULL THEN
        FOREACH "column" IN ARRAY "lbt_pk_columns" LOOP
            "lbt_pk_values" = array_append("lbt_pk_values", format('%L', "old_record" ->> "column"));
        END LOOP;
        FOREACH "column" IN ARRAY "lbt_changed_columns" LOOP
            "lbt_values" = array_append("lbt_values", format('%L', "new_record" ->> "column"));
        END LOOP;
        EXECUTE format('UPDATE %1s SET (%2s)=ROW(%3s) WHERE (%4s)=(%5s);',
            "lbt_table",
            array_to_string("lbt_changed_columns", ','), array_to_string("lbt_values", ','),
            array_to_string("lbt_pk_columns", ','), array_to_string("lbt_pk_values", ',')
        );
    END IF;
    RETURN NEW;
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER;

