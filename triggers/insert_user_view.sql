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

