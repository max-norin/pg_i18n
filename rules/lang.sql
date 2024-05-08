CREATE FUNCTION @extschema@.lang_rule ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
DECLARE
    "arr"          CONSTANT TEXT[]  = string_to_array("value", '-');
    "length"       CONSTANT INT     = array_length("arr", 1);
    "has_language" CONSTANT BOOLEAN = "arr"[1] IS NOT NULL;
    "has_script"   CONSTANT BOOLEAN = "arr"[2] IS NOT NULL;
    "has_region"   CONSTANT BOOLEAN = "arr"[3] IS NOT NULL;
BEGIN
    IF ("length" IS NULL OR "length" > 3) THEN
        RETURN FALSE;
    END IF;
    RETURN ("has_language" AND @extschema@.language_rule("arr"[1])) AND
           (NOT ("has_script") OR (@extschema@.script_rule("arr"[2]) OR (@extschema@.region_rule("arr"[2]) AND NOT "has_region"))) AND
           (NOT ("has_region") OR @extschema@.region_rule("arr"[3]));
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION @extschema@.lang_rule (TEXT) IS 'RFC 5646';

