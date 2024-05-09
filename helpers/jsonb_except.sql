CREATE FUNCTION @extschema@.jsonb_except ("a" JSONB, "b" JSONB)
    RETURNS JSONB
    AS $$
BEGIN
    RETURN (
        SELECT jsonb_object_agg(key, value)
            FROM (
                SELECT "key", "value"
                FROM jsonb_each_text("a")
                EXCEPT
                SELECT "key", "value"
                FROM jsonb_each_text("b")
                ) "table" ("key", "value"));
END;
$$
LANGUAGE plpgsql
IMMUTABLE; -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов

COMMENT ON FUNCTION @extschema@.jsonb_except (JSONB, JSONB) IS '$1 EXCEPT $2';

CREATE OPERATOR @extschema@.- (
    LEFTARG = JSONB, RIGHTARG = JSONB, FUNCTION = @extschema@.jsonb_except
);

COMMENT ON OPERATOR @extschema@.- (JSONB, JSONB) IS '$1 EXCEPT $2';

