CREATE DOMAIN LANGUAGE AS VARCHAR(3)
    CHECK (language(VALUE));

COMMENT ON TYPE LANGUAGE IS 'ISO 639';

