CREATE FUNCTION public.language ("value" TEXT)
    RETURNS BOOLEAN
    AS $$
BEGIN
    RETURN ("value" ~ '^[a-z]{2,3}$');
END
$$
LANGUAGE plpgsql
IMMUTABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов

COMMENT ON FUNCTION public.language (TEXT) IS 'ISO 639';

