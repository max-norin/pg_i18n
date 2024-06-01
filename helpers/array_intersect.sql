-- функция возвращает пересечение массивов a и b
CREATE FUNCTION public.array_intersect ("a" ANYARRAY, "b" ANYARRAY)
    RETURNS ANYARRAY
    AS $$
BEGIN
    RETURN (SELECT ARRAY(SELECT UNNEST($1) INTERSECT SELECT UNNEST($2)));
END;
$$
LANGUAGE plpgsql
IMMUTABLE; -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов

COMMENT ON FUNCTION public.array_intersect (ANYARRAY, ANYARRAY) IS '$1 INTERSECT $2';

CREATE OPERATOR public.& (
    LEFTARG = ANYARRAY, RIGHTARG = ANYARRAY, FUNCTION = public.array_intersect
);

COMMENT ON OPERATOR public.& (ANYARRAY, ANYARRAY) IS '$1 INTERSECT $2';

