-- получение имен ограничения primary key
CREATE FUNCTION get_primary_key_name ("relid" OID)
    RETURNS TEXT
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-index.html
    -- https://postgresql.org/docs/current/catalog-pg-class.html
    RETURN (
        SELECT c."relname"
        FROM "pg_class" c
        WHERE c."oid" = (
                SELECT i."indexrelid"
                FROM "pg_index" i
                WHERE i."indrelid" = "relid"
                    AND i."indisprimary"));
END
$$
LANGUAGE plpgsql
STABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION get_primary_key_name (OID) IS 'get table primary key name';

