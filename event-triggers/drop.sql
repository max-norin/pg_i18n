CREATE FUNCTION public.event_trigger_drop_i18n_triggers ()
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
    -- описание значений переменной object
    -- https://www.postgresql.org/docs/current/functions-event-triggers.html#PG-EVENT-TRIGGER-SQL-DROP-FUNCTIONS
    SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        -- удаление представления i18n
        IF "object".object_type = 'view' THEN
            "schema" = "object".address_names[1];
            "table" = "object".address_names[2];
            -- получение названия удалённого представления
            "rel" = format('%1I.%2I', "schema", "table");

            -- получение названия удаляемого триггера insert
            "name" = public.get_i18n_insert_trigger_name ("rel");
            "query" = format('DROP FUNCTION IF EXISTS %1s RESTRICT;', "name");
            RAISE NOTICE USING MESSAGE = "query";
            EXECUTE "query";

            -- получение названия удаляемого триггера
            "name" = public.get_i18n_update_trigger_name ("rel");
            "query" = format('DROP FUNCTION IF EXISTS %1s RESTRICT;', "name");
            RAISE NOTICE USING MESSAGE = "query";
            EXECUTE "query";
        END IF;
    END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;
