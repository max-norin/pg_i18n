CREATE FUNCTION get_primary_key_name("reloid" OID)
    RETURNS TEXT
AS
$$
BEGIN
    -- https://postgrespro.ru/docs/postgresql/14/catalog-pg-index
    -- https://postgrespro.ru/docs/postgresql/14/catalog-pg-class
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

COMMENT ON FUNCTION get_primary_key_name (OID) IS '';
