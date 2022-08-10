CREATE TABLE "lang_base" (
    "default_lang" @extschema@.LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "lang_base__insert" AS ON INSERT TO "lang_base"
    DO INSTEAD
    NOTHING;

