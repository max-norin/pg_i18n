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
-- ok / INSERT `untans`
INSERT INTO public.word_trans (lang, id, title, description)
VALUES ('it', 100, 'tè', 'le foglie opportunamente trattate della pianta')
RETURNING *;
SELECT *
FROM public.i18n_words;


-- # UPDATE

-- ok / UPDATE (title) WHERE (id) = (-100) / not exists
UPDATE public.i18n_words
SET title = ('update (title) where (id) = (-100): ' || title)
WHERE id = -100
RETURNING *;
-- ok / UPDATE (title) WHERE (id) = (100) / update column of `trans`
UPDATE public.i18n_words
SET title = ('update (title) where (id) = (100): ' || title)
WHERE id = 100
RETURNING *;
-- ok / UPDATE (description) WHERE (id) = (100) / update namesake column of `trans` and `untrans`
UPDATE public.i18n_words
SET description = ('update (description) where (id) = (100): ' || description)
WHERE id = 100
RETURNING *;
-- ok / UPDATE (original) WHERE (id) = (100) / update column of `untrans`
UPDATE public.i18n_words
SET original = ('update (original)  where (id) = (100): ' || original)
WHERE id = 100
RETURNING *;
-- error / UPDATE (lang) WHERE (id, lang) = (100, 'en-US') / language change is not supported
UPDATE public.i18n_words
SET lang = 'en'
WHERE id = 100
  AND lang = 'en-US'
RETURNING *;
-- error / UPDATE (id, lang) WHERE (id, lang) = (100, 'en-US') / language change is not supported
UPDATE public.i18n_words
SET id   = -100,
    lang = 'en'
WHERE id = 100
  AND lang = 'en-US'
RETURNING *;
-- ok / UPDATE (id) WHERE (id, lang) = (100, 'en-US') / id change
UPDATE public.i18n_words
SET id = -100
WHERE id = 100
  AND lang = 'en-US'
RETURNING *;
-- ?????????????? / UPDATE (id) WHERE (id) = (100) / id change
UPDATE public.i18n_words
SET id = 100
WHERE id = -100
RETURNING *;
-- ok / UPDATE (title, description) WHERE (id, lang) = (100, 'en-US') / update when there is record in `trans`
UPDATE public.i18n_words
SET title       = ('update (title, description) where (id, lang) = (100, ''en-US''): ' || title),
    description = ('update (title, description) where (id, lang) = (100, ''en-US''): ' || description)
WHERE id = 100
  AND lang = 'en-US';
-- ok / UPDATE (title, description) WHERE (id, lang) = (100, 'ru') / update when there is not record in `trans`
UPDATE public.i18n_words
SET title       = ('update (title, description) where (id, lang) = (100, ''ru''): ' || title),
    description = ('update (title, description) where (id, lang) = (100, ''ru''): ' || description)
WHERE id = 100
  AND lang = 'ru';
-- ok / UPDATE (is_tran, is_default_lang) WHERE (id, lang) = (100, 'ru') / not edit
UPDATE public.i18n_words
SET is_tran         = FALSE, -- no edit
    is_default_lang = FALSE  -- no edit
WHERE id = 100
  AND lang = 'ru'
RETURNING *;


-- # DROP

-- ok
DROP VIEW public.i18n_words;
-- error / not exists
DROP FUNCTION public.i18n_words__insert();
-- error / not exists
DROP FUNCTION public.i18n_words__update();
-- ok
DROP VIEW public.i18n_default_words;
