CREATE TABLE public."dictionary"
(
    "id"     SERIAL PRIMARY KEY,
    "title"  VARCHAR(255) NOT NULL, -- default value
    "active" VARCHAR(255)
) INHERITS (public."untrans");
CREATE TABLE public."dictionary_trans"
(
    "id"    INTEGER NOT NULL REFERENCES public."dictionary" ("id") ON UPDATE CASCADE,
    "title" VARCHAR(255), -- translation of "title" into language "lang"
    "old"   VARCHAR(255),
    PRIMARY KEY ("lang", "id")
) INHERITS (public."trans");


CALL create_i18n_view('public.dictionary'::regclass, 'public.dictionary_trans'::regclass);


INSERT INTO public.v_dictionary (id, lang, active, title, old)
VALUES (DEFAULT, 'ru', 'v_dasha', 'v_dasha', 'v_dasha')
RETURNING *;

UPDATE public.v_dictionary
SET title = 'd_max1', lang = 'ru'
WHERE id = 5
  AND lang = 'en'
RETURNING *;
