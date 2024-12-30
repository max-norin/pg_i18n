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




/*
=================== DROP ===================
*/
CREATE OR REPLACE FUNCTION public.event_trigger_drop_i18n_triggers ()
    RETURNS EVENT_TRIGGER
    AS $$
DECLARE
    "object"               RECORD;
    "rel"                  TEXT;
    "name"                 TEXT;
    "query"                TEXT;
    "schema"               TEXT;
    "table"                TEXT;
BEGIN
    FOR "object" IN
    SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        IF "object".object_type = 'view' THEN
            "schema" = "object".address_names[1];
            "table" = "object".address_names[2];
            "rel" = format('%1I.%2I', "schema", "table");

            "name" = public.get_i18n_insert_trigger_name ("rel");
            IF (position('/* pg_i18n:insert-trigger */' IN lower(pg_get_functiondef(to_regproc("name"))))) > 0 THEN
                "query" = format('DROP FUNCTION IF EXISTS %1s RESTRICT;', "name");
                RAISE NOTICE USING MESSAGE = "query";
                EXECUTE "query";
            END IF;

            "name" = public.get_i18n_update_trigger_name ("rel");
            IF (position('/* pg_i18n:update-trigger */' IN lower(pg_get_functiondef(to_regproc("name"))))) > 0 THEN
                "query" = format('DROP FUNCTION IF EXISTS %1s RESTRICT;', "name");
                RAISE NOTICE USING MESSAGE = "query";
                EXECUTE "query";
            END IF;
        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
/*
=================== INIT ===================
*/
DROP EVENT TRIGGER "drop_i18n_triggers";
CREATE EVENT TRIGGER "drop_i18n_triggers" ON sql_drop
    WHEN TAG IN ('DROP TABLE', 'DROP VIEW')
EXECUTE PROCEDURE public.event_trigger_drop_i18n_triggers ();
