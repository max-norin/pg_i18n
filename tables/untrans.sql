-- Пользовательский способ - выдаются только переведенные данные.
CREATE TABLE public."untrans"
(
    "default_lang" public.LANG NOT NULL REFERENCES public."langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "insert" AS ON INSERT TO public."untrans" DO INSTEAD NOTHING;
CREATE RULE "update" AS ON UPDATE TO public."untrans" DO INSTEAD NOTHING;
CREATE RULE "delete" AS ON DELETE TO public."untrans" DO INSTEAD NOTHING;

