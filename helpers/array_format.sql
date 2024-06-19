CREATE FUNCTION  public.array_format ("textarray" TEXT[], "formatstr" TEXT, VARIADIC "formatarg" TEXT[])
    RETURNS TEXT[]
    AS $$
DECLARE
    "item"    TEXT;
    "result"  TEXT[];
BEGIN
    FOREACH "item" IN ARRAY "textarray" LOOP
        "result" = array_append("result", format("formatstr", "item", VARIADIC "formatarg"));
    END LOOP;

    RETURN "result";
END
$$
LANGUAGE plpgsql
STABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

-- TODO написать
COMMENT ON FUNCTION  public.array_format (TEXT[], TEXT, VARIADIC TEXT[]) IS '';

-- TODO тут точно должен быть STABLE ????
