-- функция вычитания значений массива b из массива a
CREATE FUNCTION public.array_except ("a" ANYARRAY, "b" ANYARRAY)
    RETURNS ANYARRAY
    AS $$
DECLARE
    "length" CONSTANT INT = array_length("b", 1);
    "index" INT;
BEGIN
    IF "a" IS NULL THEN
        RETURN NULL;
    END IF;
    "index" = 1;
    WHILE "index" <= "length" LOOP
        "a" = array_remove("a","b"["index"]);
        "index" = "index" + 1;
    END LOOP;
    RETURN "a";
END;
$$
LANGUAGE plpgsql
IMMUTABLE; -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов

COMMENT ON FUNCTION public.array_except (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

CREATE OPERATOR public.- (
    LEFTARG = ANYARRAY, RIGHTARG = ANYARRAY, FUNCTION = public.array_except
);

COMMENT ON OPERATOR public.- (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

