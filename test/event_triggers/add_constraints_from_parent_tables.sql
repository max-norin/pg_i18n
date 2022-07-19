CREATE TABLE "users" (
    "id" SERIAL PRIMARY KEY
)
INHERITS (
    "lang_base", "lang_base_tran"
);

CREATE TABLE "dictionaries" (
    "id" SERIAL PRIMARY KEY
)
INHERITS (
    "lang_base"
);

ALTER TABLE "lang_base"
    ADD COLUMN "delete" LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE;

-- DO NOT WORK
ALTER TABLE "dictionaries" INHERIT "lang_base_tran";

