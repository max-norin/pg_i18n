CREATE TABLE @extschema@."langs"
(
    "lang"      @extschema@.LANG PRIMARY KEY
                GENERATED ALWAYS AS (
                            "language" ||
                            CASE WHEN ("script" IS NULL) THEN '' ELSE ('-' || "script") END ||
                            CASE WHEN ("region" IS NULL) THEN '' ELSE ('-' || "region") END
                    ) STORED,
    "language"  @extschema@.LANGUAGE     NOT NULL,
    "script"    @extschema@.SCRIPT,
    "region"    @extschema@.REGION,
    "is_active" BOOLEAN      NOT NULL DEFAULT FALSE,
    "title"     VARCHAR(50) NOT NULL UNIQUE
);

COMMENT ON TABLE @extschema@."langs" IS 'RFC 5646';

