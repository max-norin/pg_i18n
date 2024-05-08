CREATE TABLE "lang_base_tran" (
    "lang" @extschema@.LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "insert" AS ON INSERT TO "lang_base_tran" DO INSTEAD NOTHING;
CREATE RULE "update" AS ON UPDATE TO "lang_base_tran" DO INSTEAD NOTHING;
CREATE RULE "delete" AS ON DELETE TO "lang_base_tran" DO INSTEAD NOTHING;
