-- Пользовательский способ - выдаются только переведенные данные.
CREATE TABLE public."lang_base"
(
    "default_lang" public.LANG NOT NULL REFERENCES public."langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "insert" AS ON INSERT TO public."lang_base" DO INSTEAD NOTHING;
CREATE RULE "update" AS ON UPDATE TO public."lang_base" DO INSTEAD NOTHING;
CREATE RULE "delete" AS ON DELETE TO public."lang_base" DO INSTEAD NOTHING;

