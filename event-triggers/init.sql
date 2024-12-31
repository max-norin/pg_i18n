-- DROP EVENT TRIGGER "drop_i18n_triggers";
CREATE EVENT TRIGGER "drop_i18n_triggers" ON sql_drop
    WHEN TAG IN ('DROP TABLE', 'DROP VIEW')
EXECUTE PROCEDURE public.event_trigger_drop_i18n_triggers ();
