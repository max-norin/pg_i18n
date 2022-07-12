CREATE FUNCTION get_primary_key("reloid" OID)
    RETURNS TEXT[]
AS
$$
BEGIN
    -- https://postgrespro.ru/docs/postgresql/14/catalog-pg-index
    -- https://postgrespro.ru/docs/postgresql/14/catalog-pg-attribute
    RETURN (
        SELECT array_agg(a."attname")
            FROM "pg_index" i
                     INNER JOIN "pg_attribute" a ON i."indrelid" = a."attrelid" AND a."attnum" = ANY (i."indkey")
            WHERE i."indrelid" = "reloid" AND i."indisprimary"
            );
END
$$
    LANGUAGE plpgsql
    STABLE
    RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_primary_key (OID) IS '';
