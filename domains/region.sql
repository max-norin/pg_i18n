CREATE DOMAIN @extschema@.REGION AS VARCHAR(2)
CHECK (@extschema@.region_rule (VALUE));

COMMENT ON DOMAIN @extschema@.REGION IS 'ISO 3166-1';

