-- https://www.postgresql.org/docs/current/sql-execute.html
-- https://www.postgresql.org/docs/current/sql-prepare.html
CREATE FUNCTION get_constraintdefs ("relid" OID)
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
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_constraintdefs (OID) IS 'get table constraint definitions';

