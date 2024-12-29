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

-- ## ok / INSERT (id, lang) = (DEFAULT, 'en-US')
INSERT INTO public.i18n_words (is_tran, is_default_lang, lang, id, default_lang, original, title, description)
VALUES (NULL, NULL, 'en-US', DEFAULT, NULL, 'te', 'tea', 'a drink made by pouring hot water onto')
RETURNING *;
-- ## ok / INSERT (id, lang) = (100, 'en-US')
INSERT INTO public.i18n_words (is_tran, is_default_lang, lang, id, default_lang, original, title, description)
VALUES (NULL, NULL, 'en-US', 100, NULL, 'te', 'tea', 'a drink made by pouring hot water onto')
RETURNING *;
-- ## error / INSERT (id, lang) = (100, 'en-US') / Key (id)=(100) already exists.
INSERT INTO public.i18n_words (is_tran, is_default_lang, lang, id, default_lang, original, title, description)
VALUES (NULL, NULL, 'en-US', 100, NULL, 'te', 'tea', 'a drink made by pouring hot water onto')
RETURNING *;
-- ## error / INSERT (id, lang) = (100, 'it') / Key (id)=(100) already exists.
INSERT INTO public.i18n_words (is_tran, is_default_lang, lang, id, default_lang, original, title, description)
VALUES (NULL, NULL, 'it', 100, NULL, 'te /it', 'tè', 'le foglie opportunamente trattate della pianta')
RETURNING *;
-- ## ok / INSERT `untans`
INSERT INTO public.word_trans (lang, id, title, description)
VALUES ('it', 100, 'tè', 'le foglie opportunamente trattate della pianta')
RETURNING *;
/*
    # check
    SELECT * FROM public.i18n_words WHERE id = 100;
    # check
    SELECT * FROM public.i18n_default_words WHERE id = 100;
*/


-- # UPDATE

-- ## ok / UPDATE (title) WHERE (id) = (-100) / not exists
UPDATE public.i18n_words
SET title = ('update (title) where (id) = (-100): ' || title)
WHERE id = -100
RETURNING *;
-- ## ok / UPDATE (title) WHERE (id) = (100) / update column of `trans` / will 4 rows in `untrans`
UPDATE public.i18n_words
SET title = ('update (title) where (id) = (100): ' || title)
WHERE id = 100
RETURNING *;
/*
    # check
    SELECT * FROM public.words WHERE id = 100;
    # check
    SELECT * FROM public.word_trans WHERE id = 100;
    # rollback
    DELETE FROM public.word_trans WHERE id = 100 AND lang IN ('ru', 'udm');
*/
-- ## ok / UPDATE (description) WHERE (id) = (100) / update namesake column of `trans` and `untrans` / will 4 rows in `untrans`
UPDATE public.i18n_words
SET description = ('update (description) where (id) = (100): ' || COALESCE(description, 'null'))
WHERE id = 100
RETURNING *;
/*
    # check
    SELECT * FROM public.words WHERE id = 100;
    # check
    SELECT * FROM public.word_trans WHERE id = 100;
    # rollback
    DELETE FROM public.word_trans WHERE id = 100 AND lang IN ('ru', 'udm');
*/
-- ## ok / UPDATE (original) WHERE (id) = (100) / update column of `untrans` / will 4 rows in `untrans`
UPDATE public.i18n_words
SET original = ('update (original)  where (id) = (100): ' || original)
WHERE id = 100
RETURNING *;
/*
    # check
    SELECT * FROM public.words WHERE id = 100;
    # check
    SELECT * FROM public.word_trans WHERE id = 100;
    # rollback
    DELETE FROM public.word_trans WHERE id = 100 AND lang IN ('ru', 'udm');
*/
-- ## error / UPDATE (lang) WHERE (id, lang) = (100, 'en-US') / language change is not supported
UPDATE public.i18n_words
SET lang = 'ru'
WHERE id = 100
  AND lang = 'en-US'
RETURNING *;
-- ## error / UPDATE (id, lang) WHERE (id, lang) = (100, 'en-US') / language change is not supported
UPDATE public.i18n_words
SET id   = -100,
    lang = 'en'
WHERE id = 100
  AND lang = 'en-US'
RETURNING *;
-- ## ok / UPDATE (id) WHERE (id, lang) = (100, 'en-US') / id change
UPDATE public.i18n_words
SET id = -100
WHERE id = 100
  AND lang = 'en-US'
RETURNING *;
/*
    # check
    SELECT * FROM public.i18n_words WHERE id = 100;
*/
-- ## ?????????????? / UPDATE (id) WHERE (id) = (100) / id change
-- TODO проблема
UPDATE public.i18n_words
SET id = 100
WHERE id = -100
RETURNING *;
-- ## ok / UPDATE (title, description) WHERE (id, lang) = (100, 'en-US') / update when there is record in `trans`
UPDATE public.i18n_words
SET title       = ('update (title, description) where (id, lang) = (100, ''en-US''): ' || title),
    description = ('update (title, description) where (id, lang) = (100, ''en-US''): ' || description)
WHERE id = 100
  AND lang = 'en-US'
RETURNING *;
/*
    # check
    SELECT *
    FROM public.word_trans
    WHERE id = 100;
*/
-- ## ok / UPDATE (title, description) WHERE (id, lang) = (100, 'ru') / update when there is not record in `trans`
UPDATE public.i18n_words
SET title       = ('update (title, description) where (id, lang) = (100, ''ru''): ' || COALESCE(title, 'null')),
    description = ('update (title, description) where (id, lang) = (100, ''ru''): ' || COALESCE(description, 'null'))
WHERE id = 100
  AND lang = 'ru'
RETURNING *;
/*
    # check
    SELECT *
    FROM public.word_trans
    WHERE id = 100;
*/
-- ## ok / UPDATE (is_tran, is_default_lang) WHERE (id, lang) = (100, 'ru') / not edit
UPDATE public.i18n_words
SET is_tran         = FALSE, -- no edit
    is_default_lang = TRUE   -- no edit
WHERE id = 100
  AND lang = 'ru'
RETURNING *;
/*
    # check
    SELECT *
    FROM public.i18n_words
    WHERE id = 100;
*/
-- ## ok / UPDATE (default_lang) WHERE (id) = (100)
UPDATE public.i18n_words
SET default_lang = 'en-US'
WHERE id = 100
RETURNING *;
/*
    # check
    SELECT *
    FROM public.i18n_words
    WHERE id = 100;
*/


-- # DROP

-- 1.
-- ## ok
DROP VIEW public.i18n_words;
-- ## error / not exists
DROP FUNCTION public.i18n_words__insert();
-- ## error / not exists
DROP FUNCTION public.i18n_words__update();
-- ## ok
DROP VIEW public.i18n_default_words;
-- 2.
-- ## create i18n_words
CALL create_i18n_view('public.words'::REGCLASS, 'public.word_trans'::REGCLASS);
-- ## ok
DROP TABLE public.words CASCADE;
-- ## error / not exists
DROP FUNCTION public.i18n_words__insert();
-- ## error / not exists
DROP FUNCTION public.i18n_words__update();
-- ## ok
DROP TABLE public.word_trans CASCADE;
