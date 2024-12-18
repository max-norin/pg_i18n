CALL create_i18n_view(NULL::regclass, NULL::regclass);

CALL create_i18n_view('public.words'::regclass, 'public.word_trans'::regclass);

CALL create_i18n_view('public.products'::regclass, 'public.product_trans'::regclass);


INSERT INTO public.i18n_words (is_tran, is_default_lang, lang, id, default_lang, original, title, slang)
VALUES (null, null, 'ru', 5, null, '0', '0', '0')
RETURNING *;

INSERT INTO public.i18n_dictionary (id, lang, active, title, old)
VALUES (DEFAULT, 'ru', 'v_dasha', 'v_dasha', 'v_dasha')
RETURNING *;

UPDATE public.i18n_words
SET original = '1',
    title    = '1',
    slang    = '1'
WHERE id = 5
  AND lang = 'ru'
RETURNING *;

UPDATE public.i18n_dictionary
SET title = 'd_max1',
    lang  = 'ru'
WHERE id = 5
  AND lang = 'en'
RETURNING *;

DROP VIEW public.i18n_dictionary;
DROP VIEW public.i18n_words;
DROP VIEW public.i18n_default_words;
DROP FUNCTION IF EXISTS public.i18n_words__insert RESTRICT;
DROP FUNCTION IF EXISTS public.i18n_words__update RESTRICT;
DROP VIEW public.i18n_products;
