-- получить колонки таблицы
CREATE FUNCTION get_columns ("relid" OID, "has_generated_column" BOOLEAN = TRUE)
    RETURNS TEXT[]
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-attribute.html
    RETURN (
        SELECT array_agg(a."attname")
        FROM "pg_attribute" AS a
        WHERE "attrelid" = "relid"
          -- Системные столбцы, такие как ctid, имеют (произвольные) отрицательные числа,
          -- поэтому a."attnum" > 0
            AND a."attnum" > 0
          -- включать генерируемые колонки или нет
            AND ("has_generated_column" OR a.attgenerated = '')
          -- не является удаленной колонкой
            AND NOT a.attisdropped);
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION get_columns (OID, BOOLEAN) IS 'get table columns';

