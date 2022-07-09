CREATE TABLE "langs"
(
    "lang"      LANG PRIMARY KEY
                GENERATED ALWAYS AS (
                            "language" ||
                            CASE WHEN ("script" IS NULL) THEN '' ELSE ('-' || "script") END ||
                            CASE WHEN ("region" IS NULL) THEN '' ELSE ('-' || "region") END
                    ) STORED,
    "language"  LANGUAGE     NOT NULL,
    "script"    SCRIPT,
    "region"    REGION,
    "is_active" BOOLEAN      NOT NULL DEFAULT FALSE,
    "title"     VARCHAR(255) NOT NULL UNIQUE
);

COMMENT ON TABLE "langs" IS 'RFC 5646';


-- Может сделать через perform !? функцию, чтобы можно было добавлять?
