CREATE TABLE "dictionary" (
    "id" SERIAL PRIMARY KEY,
    "title" VARCHAR(255) NOT NULL,
    "is_active" BOOLEAN DEFAULT TRUE
);

CREATE TABLE "dictionary_trans" (
    "id" INTEGER NOT NULL REFERENCES "dictionary" ("id") ON UPDATE CASCADE,
    "title" VARCHAR(255), PRIMARY KEY ("lang", "id")
)
INHERITS ("lang_base_tran");

CALL create_dictionary_view (NULL::TEXT, 'dictionary'::REGCLASS, 'dictionary_trans'::REGCLASS);

SELECT *
FROM "v_dictionary";
