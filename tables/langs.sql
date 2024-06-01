CREATE TABLE public."langs"
(
    "lang"      public.LANG PRIMARY KEY
                GENERATED ALWAYS AS (
                    "language" ||
                    CASE WHEN ("script" IS NULL) THEN '' ELSE ('-' || "script") END ||
                    CASE WHEN ("region" IS NULL) THEN '' ELSE ('-' || "region") END
                    ) STORED,
    "language"  public.LANGUAGE NOT NULL,
    "script"    public.SCRIPT,
    "region"    public.REGION,
    "is_active" BOOLEAN         NOT NULL DEFAULT FALSE,
    "title"     VARCHAR(50)     NOT NULL UNIQUE
);

COMMENT ON TABLE public."langs" IS 'RFC 5646';

