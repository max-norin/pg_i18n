CREATE DOMAIN @extschema@.LANG AS VARCHAR(11)
CHECK (@extschema@.lang_rule (VALUE));

COMMENT ON DOMAIN @extschema@.LANG IS 'RFC 5646';

