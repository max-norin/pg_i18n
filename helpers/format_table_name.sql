-- возвращает имя таблицы в корректном формате с prefix
CREATE FUNCTION format_table_name ("name" TEXT, "prefix" TEXT = '')
    RETURNS TEXT
    AS $$
DECLARE
    "arr" TEXT[];
BEGIN
    "arr" = string_to_array("name", '.');
    CASE array_length("arr", 1)
    WHEN 1 THEN
        -- вариант когда не указана схема
        -- %I - равнозначно вызову quote_ident Переданная строка оформляется для использования
        -- в качестве идентификатора в SQL -операторе. При необходимости идентификатор заключается в кавычки.
        -- Если переданная строка содержит кавычки, они дублируются.
        RETURN format('%I', "prefix" || trim(BOTH '"' FROM "arr"[1]));
    WHEN 2 THEN
        -- вариант когда указана схема
        -- %I - равнозначно вызову quote_ident Переданная строка оформляется для использования
        -- в качестве идентификатора в SQL -операторе. При необходимости идентификатор заключается в кавычки.
        -- Если переданная строка содержит кавычки, они дублируются.
        RETURN format('%I.%I', trim(BOTH '"' FROM "arr"[1]), "prefix" || trim(BOTH '"' FROM "arr"[2]));
    ELSE
        RAISE EXCEPTION USING MESSAGE = 'invalid table name';
    END CASE;
    END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

