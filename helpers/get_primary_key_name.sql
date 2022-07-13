CREATE FUNCTION get_primary_key_name("reloid" OID)
    RETURNS TEXT
AS
$$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-index.html
    -- https://postgresql.org/docs/current/catalog-pg-class.html
    RETURN (
        SELECT c."relname"
            FROM "pg_class" c
            WHERE c."oid" = (
                SELECT i."indexrelid"
                           FROM "pg_index" i
                           WHERE i."indrelid" = "reloid"
                             AND i."indisprimary"
                )
            );
END
$$
    LANGUAGE plpgsql
    STABLE
    RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_primary_key_name (OID) IS 'get table primary key name';
