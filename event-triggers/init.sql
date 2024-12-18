CREATE EVENT TRIGGER "drop_i18n_triggers" ON sql_drop
    WHEN TAG IN ('DROP VIEW')
EXECUTE PROCEDURE public.event_trigger_drop_i18n_triggers ();
