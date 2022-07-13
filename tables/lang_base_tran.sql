CREATE TABLE "lang_base_tran"
(
    "lang" VARCHAR(6) NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE
);
CREATE RULE "lang_base_trans__insert" AS ON INSERT TO "lang_base_tran" DO INSTEAD NOTHING;
