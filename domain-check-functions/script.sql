CREATE FUNCTION public.script ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[A-Z][a-z]{3}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION public.script (TEXT) IS 'ISO 15924';

