CREATE FUNCTION jsonb_object_fields ("value" JSONB, "paths" TEXT[])
    RETURNS JSONB
    AS $$
BEGIN
    RETURN "value" - (ARRAY (SELECT jsonb_object_keys("value")) OPERATOR ( @extschema@.- ) "paths");
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION jsonb_object_fields (JSONB, TEXT[]) IS 'get json object fields';

CREATE OPERATOR -> (
    LEFTARG = JSONB, RIGHTARG = TEXT[], FUNCTION = jsonb_object_fields
);

COMMENT ON OPERATOR -> (JSONB, TEXT[]) IS 'get json object fields';

