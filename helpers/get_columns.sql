CREATE FUNCTION get_columns("reloid" OID)
    RETURNS TEXT[]
AS
$$
BEGIN
    -- https://postgrespro.ru/docs/postgresql/14/catalog-pg-attribute
    RETURN (SELECT array_agg(a."attname")
            FROM "pg_attribute" AS a
            WHERE "attrelid" = "reloid"
              AND a."attnum" > 0
              AND NOT a.attisdropped);
END
$$
    LANGUAGE plpgsql
    STABLE
    RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_columns (OID) IS '';
