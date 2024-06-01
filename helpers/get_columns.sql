-- получить колонки таблицы с указанием таблицы rel
-- rel - используется во внешних функциях, вне данного расширения
CREATE FUNCTION  public.get_columns ("relid" OID, "has_generated_column" BOOLEAN = TRUE, "rel" TEXT = '')
    RETURNS TEXT[]
    AS $$
BEGIN
    -- https://postgresql.org/docs/current/catalog-pg-attribute.html
    RETURN (
        SELECT array_agg(CASE WHEN length("rel") > 0 THEN format('%s.%I', "rel", a."attname") ELSE a."attname" END)
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
STABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION  public.get_columns (OID, BOOLEAN, TEXT) IS 'get table columns';

