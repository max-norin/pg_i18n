CREATE FUNCTION public.jsonb_object_fields ("value" JSONB, "paths" TEXT[])
    RETURNS JSONB
    AS $$
BEGIN
    RETURN "value" - (ARRAY (SELECT jsonb_object_keys("value")) OPERATOR ( public.- ) "paths");
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION public.jsonb_object_fields (JSONB, TEXT[]) IS 'get json object fields';

CREATE OPERATOR public.-> (
    LEFTARG = JSONB, RIGHTARG = TEXT[], FUNCTION = public.jsonb_object_fields
);

COMMENT ON OPERATOR public.-> (JSONB, TEXT[]) IS 'get json object fields';

