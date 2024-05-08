CREATE TABLE @extschema@."lang_base" (
    "default_lang" @extschema@.LANG NOT NULL REFERENCES @extschema@."langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "insert" AS ON INSERT TO @extschema@."lang_base" DO INSTEAD NOTHING;
CREATE RULE "update" AS ON UPDATE TO @extschema@."lang_base" DO INSTEAD NOTHING;
CREATE RULE "delete" AS ON DELETE TO @extschema@."lang_base" DO INSTEAD NOTHING;

