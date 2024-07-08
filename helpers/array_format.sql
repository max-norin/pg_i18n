CREATE FUNCTION  public.array_format ("textarray" TEXT[], "formatstr" TEXT)
    RETURNS TEXT[]
    AS $$
DECLARE
    "item"    TEXT;
    "result"  TEXT[];
BEGIN
    FOREACH "item" IN ARRAY "textarray" LOOP
        "result" = array_append("result", format("formatstr", "item"));
    END LOOP;

    RETURN "result";
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION  public.array_format (TEXT[], TEXT) IS 'formatting array elements';

CREATE OPERATOR public.<< (
    LEFTARG = TEXT[], RIGHTARG = TEXT, FUNCTION = public.array_format
    );

COMMENT ON OPERATOR public.<< (TEXT[], TEXT) IS 'formatting array elements';
