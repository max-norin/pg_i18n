/*
=================== NAMES ===================
*/

DROP FUNCTION public.get_i18n_trigger_name (TEXT);

CREATE FUNCTION  public.get_i18n_insert_trigger_name ("viewname" TEXT)
    RETURNS TEXT
    AS $$
DECLARE
    "ident" TEXT[] = parse_ident("viewname");
BEGIN
    RETURN format('%1I.%2I', "ident"[1], 'trigger_i18n_' || "ident"[2]);
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

CREATE FUNCTION  public.get_i18n_update_trigger_name ("viewname" TEXT)
    RETURNS TEXT
    AS $$
DECLARE
    "ident" TEXT[] = parse_ident("viewname");
BEGIN
    RETURN format('%1I.%2I', "ident"[1], 'trigger_i18n_' || "ident"[2]);
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;
