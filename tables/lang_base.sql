CREATE TABLE "lang_base"
(
    "default_lang" LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE
);
CREATE RULE "lang_base__insert" AS ON INSERT TO "lang_base" DO INSTEAD NOTHING;

-- REFERENCES "langs" ("lang") ON UPDATE CASCADE - ничего не дает

-- такая иерархия позволяет сделать быстрое присвоение всем наследникам новый столбец
-- ALTER TABLE "lang_base" ADD COLUMN "lang" LANG NOT NULL;
