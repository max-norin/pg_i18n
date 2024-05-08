CREATE DOMAIN @extschema@.SCRIPT AS VARCHAR(4)
CHECK (@extschema@.script_rule (VALUE));

COMMENT ON DOMAIN @extschema@.SCRIPT IS 'ISO 15924';

