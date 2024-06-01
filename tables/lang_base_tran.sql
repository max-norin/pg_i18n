-- Словарный способ - на каждый языковой тег будет предоставлен перевод.
-- Если перевода нет в таблице переводов, то будет представлено значение по умолчанию из основной таблицы.
CREATE TABLE public."lang_base_tran"
(
    "lang" public.LANG NOT NULL REFERENCES public."langs" ("lang") ON UPDATE CASCADE
);

CREATE RULE "insert" AS ON INSERT TO public."lang_base_tran" DO INSTEAD NOTHING;
CREATE RULE "update" AS ON UPDATE TO public."lang_base_tran" DO INSTEAD NOTHING;
CREATE RULE "delete" AS ON DELETE TO public."lang_base_tran" DO INSTEAD NOTHING;
