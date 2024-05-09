CREATE FUNCTION @extschema@.get_constraintdefs ("relid" OID)
    RETURNS TEXT[]
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-constraint.html
    RETURN (
        SELECT array_agg(pg_get_constraintdef("pg_constraint"."oid"::OID, TRUE))
        FROM "pg_constraint"
        WHERE "pg_constraint"."conrelid" = "relid"
            AND "pg_constraint"."contype" IN ('f', 'p', 'u'));
END
$$
LANGUAGE plpgsql
STABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION @extschema@.get_constraintdefs (OID) IS 'get table constraint definitions';

