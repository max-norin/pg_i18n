CREATE FUNCTION get_columns ("relid" OID, "has_generated_column" BOOLEAN = TRUE, "rel" TEXT = '')
    RETURNS TEXT[]
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-attribute.html
    RETURN (
        SELECT array_agg(CASE WHEN length("rel") > 0 THEN format('%s.%I', "rel", a."attname") ELSE a."attname" END)
        FROM "pg_attribute" AS a
        WHERE "attrelid" = "relid"
            AND a."attnum" > 0
            AND ("has_generated_column" OR a.attgenerated = '')
            AND NOT a.attisdropped);
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_columns (OID, BOOLEAN, TEXT) IS 'get table columns';

