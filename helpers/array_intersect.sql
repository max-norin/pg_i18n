-- функция возвращает пересечение массивов a и b
CREATE FUNCTION @extschema@.array_intersect ("a" ANYARRAY, "b" ANYARRAY)
    RETURNS ANYARRAY
    AS $$
BEGIN
    RETURN (SELECT ARRAY(SELECT UNNEST($1) INTERSECT SELECT UNNEST($2)));
END;
$$
LANGUAGE plpgsql
IMMUTABLE; -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов

COMMENT ON FUNCTION @extschema@.array_intersect (ANYARRAY, ANYARRAY) IS '$1 INTERSECT $2';

CREATE OPERATOR @extschema@.& (
    LEFTARG = ANYARRAY, RIGHTARG = ANYARRAY, FUNCTION = @extschema@.array_intersect
);

COMMENT ON OPERATOR @extschema@.& (ANYARRAY, ANYARRAY) IS '$1 INTERSECT $2';

