CREATE DOMAIN @extschema@.LANGUAGE AS VARCHAR(3)
CHECK (@extschema@.language_rule (VALUE));

COMMENT ON DOMAIN @extschema@.LANGUAGE IS 'ISO 639';

