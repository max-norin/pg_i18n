CREATE FUNCTION  public.get_i18n_default_view_name ("baserel" OID, "tranrel" OID)
    RETURNS TEXT
    AS $$
BEGIN
    RETURN (
        SELECT format('%1I.%2I', n.nspname, 'v_' || c.relname || '_default')
        FROM pg_class c JOIN pg_namespace n on c.relnamespace = n.oid
        WHERE c.oid = "baserel");
END
$$
LANGUAGE plpgsql
STABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов


CREATE FUNCTION  public.get_i18n_view_name ("baserel" OID, "tranrel" OID)
    RETURNS TEXT
    AS $$
BEGIN
    RETURN (
        SELECT format('%1I.%2I', n.nspname, 'v_' || c.relname)
        FROM pg_class c JOIN pg_namespace n on c.relnamespace = n.oid
        WHERE c.oid = "baserel");
END
$$
LANGUAGE plpgsql
STABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов


CREATE FUNCTION  public.get_i18n_trigger_name ("viewname" TEXT)
    RETURNS TEXT
    AS $$
DECLARE
    "ident" TEXT[] = parse_ident("viewname");
BEGIN
    RETURN format('%1I.%2I', "ident"[1], 'trigger_i18n_' || "ident"[2]);
END
$$
LANGUAGE plpgsql
STABLE -- функция не может модифицировать базу данных и всегда возвращает один и тот же результат при определённых значениях аргументов внутри одного SQL запроса
RETURNS NULL ON NULL INPUT; -- функция всегда возвращает NULL, получив NULL в одном из аргументов