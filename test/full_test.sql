-- insert languages
INSERT INTO langs (language, script, region, is_active, title)
VALUES ('ru', NULL, NULL, TRUE, 'Русский'),
       ('udm', NULL, NULL, TRUE, 'Удмурт'),
       ('en', NULL, 'US', TRUE, 'English'),
       ('it', NULL, NULL, TRUE, 'Italiano');

-- error
CALL create_i18n_view(NULL::regclass, NULL::regclass);

-- create i18n_words
CREATE TABLE public.words
(
    id       SERIAL PRIMARY KEY,
    title    VARCHAR(255) NOT NULL, -- default value
    original VARCHAR(255)
) INHERITS (public.untrans);
CREATE TABLE public.word_trans
(
    id          INTEGER NOT NULL REFERENCES public.words (id) ON UPDATE CASCADE,
    PRIMARY KEY (id, lang),
    title       VARCHAR(255), -- translation of title into language lang
    description VARCHAR(255)
) INHERITS (public.trans);
CALL create_i18n_view('public.words'::REGCLASS, 'public.word_trans'::REGCLASS);

-- # INSERT

-- ok / INSERT (id, lang) = (DEFAULT, 'en-US')
INSERT INTO public.i18n_words (is_tran, is_default_lang, lang, id, default_lang, original, title, description)
VALUES (NULL, NULL, 'en-US', DEFAULT, NULL, 'te', 'tea', 'a drink made by pouring hot water onto')
RETURNING *;
-- ok / INSERT (id, lang) = (100, 'en-US')
INSERT INTO public.i18n_words (is_tran, is_default_lang, lang, id, default_lang, original, title, description)
VALUES (NULL, NULL, 'en-US', 100, NULL, 'te', 'tea', 'a drink made by pouring hot water onto')
RETURNING *;
-- error / INSERT (id, lang) = (100, 'en-US')
INSERT INTO public.i18n_words (is_tran, is_default_lang, lang, id, default_lang, original, title, description)
VALUES (NULL, NULL, 'en-US', 100, NULL, 'te', 'tea', 'a drink made by pouring hot water onto')
RETURNING *;
-- error / INSERT (id, lang) = (100, 'it')
INSERT INTO public.i18n_words (is_tran, is_default_lang, lang, id, default_lang, original, title, description)
VALUES (NULL, NULL, 'it', 100, NULL, 'te /it', 'tè', 'le foglie opportunamente trattate della pianta')
RETURNING *;


-- # UPDATE


-- # DROP

-- ok
DROP VIEW public.i18n_words;
-- error / not exists
DROP FUNCTION public.i18n_words__insert();
-- error / not exists
DROP FUNCTION public.i18n_words__update();
-- ok
DROP VIEW public.i18n_default_words;
