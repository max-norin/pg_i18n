CREATE FUNCTION get_columns ("reloid" OID, "has_generated_column" BOOLEAN = TRUE)
    RETURNS TEXT[]
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-attribute.html
    RETURN (
        SELECT array_agg(a."attname")
        FROM "pg_attribute" AS a
        WHERE "attrelid" = "reloid"
            AND a."attnum" > 0
            AND ("has_generated_column" OR a.attgenerated = '')
            AND NOT a.attisdropped);
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_columns (OID) IS 'get table columns';

