CREATE OR REPLACE FUNCTION format_table_name("name" TEXT, "prefix" TEXT = '')
    RETURNS TEXT
AS
$$
DECLARE
    "arr" TEXT[];
BEGIN
    "arr" = string_to_array("name", '.');
    CASE array_length("arr", 1)
        WHEN 1 THEN RETURN format('%I', "prefix" || trim(BOTH '"' FROM "arr"[1]));
        WHEN 2 THEN RETURN format('%I.%I', trim(BOTH '"' FROM "arr"[1]), "prefix" || trim(BOTH '"' FROM "arr"[2]));
        ELSE RAISE EXCEPTION USING MESSAGE = 'invalid table name';
        END CASE;
END
$$
    LANGUAGE plpgsql
    STABLE
    RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION format_table_name (TEXT) IS '';

