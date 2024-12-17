/*
=================== NAMES ===================
*/
CREATE OR REPLACE FUNCTION  public.get_i18n_default_view_name ("baserel" OID, "tranrel" OID)
    RETURNS TEXT
    AS $$
BEGIN
    RETURN (
        SELECT format('%1I.%2I', n.nspname, 'i18n_default_' || c.relname)
        FROM pg_class c JOIN pg_namespace n on c.relnamespace = n.oid
        WHERE c.oid = "baserel");
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

CREATE OR REPLACE FUNCTION  public.get_i18n_view_name ("baserel" OID, "tranrel" OID)
    RETURNS TEXT
    AS $$
BEGIN
    RETURN (
        SELECT format('%1I.%2I', n.nspname, 'i18n_' || c.relname)
        FROM pg_class c JOIN pg_namespace n on c.relnamespace = n.oid
        WHERE c.oid = "baserel");
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;

DROP FUNCTION IF EXISTS public.get_i18n_trigger_name (TEXT);

CREATE FUNCTION  public.get_i18n_insert_trigger_name ("viewname" TEXT)
    RETURNS TEXT
    AS $$
DECLARE
    "ident" TEXT[] = parse_ident("viewname");
BEGIN
    RETURN format('%1I.%2I', "ident"[1], "ident"[2] || '__insert');
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
    RETURN format('%1I.%2I', "ident"[1], "ident"[2] || '__update');
END
$$
LANGUAGE plpgsql
STABLE
RETURNS NULL ON NULL INPUT;
