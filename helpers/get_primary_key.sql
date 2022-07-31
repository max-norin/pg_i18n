CREATE FUNCTION get_primary_key ("relid" OID)
    RETURNS TEXT[]
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-index.html
    -- https://postgresql.org/docs/current/catalog-pg-attribute.html
    RETURN (
        SELECT array_agg(a."attname")
        FROM "pg_index" i
            INNER JOIN "pg_attribute" a ON i."indrelid" = a."attrelid"
                AND a."attnum" = ANY (i."indkey")
        WHERE i."indrelid" = "relid"
            AND i."indisprimary");
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_primary_key (OID) IS 'get table primary key columns';

