CREATE OR REPLACE FUNCTION trigger_update_dictionary_view()
    RETURNS TRIGGER
AS
$$
DECLARE
    "record"     CONSTANT JSONB NOT NULL    = to_jsonb(NEW);
    "table"      CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    "pk_name"    CONSTANT TEXT NOT NULL     = get_primary_key_name("table");
    "pk_columns" CONSTANT TEXT[] NOT NULL   = get_primary_key("table");
    "pk_values"           TEXT[];
    "columns"    CONSTANT TEXT[] NOT NULL   = array_except(get_columns("table"), "pk_columns");
    "values"              TEXT[];
    "column"              TEXT;
BEGIN
    FOREACH "column" IN ARRAY "pk_columns"
        LOOP
            "pk_values" = array_append("pk_values", format('%L', "record" ->> "column"));
        END LOOP;

    FOREACH "column" IN ARRAY "columns"
        LOOP
            "values" = array_append("values", format('%L', "record" ->> "column"));
        END LOOP;

    EXECUTE format('
        INSERT INTO %s (%s) VALUES (%s)
            ON CONFLICT ON CONSTRAINT %I
            DO UPDATE SET (%s)=ROW(%s);
        ', "table", array_to_string("pk_columns" || "columns", ','), array_to_string("pk_values" || "values", ','),
                   "pk_name",
                   array_to_string("columns", ','), array_to_string("values", ',')
        );

    RETURN NEW;
END
$$
    LANGUAGE plpgsql;
