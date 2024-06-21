CALL create_i18n_view(NULL::regclass, NULL::regclass);

CALL create_i18n_view('public.words'::regclass, 'public.word_trans'::regclass);

CALL create_i18n_view('public.products'::regclass, 'public.product_trans'::regclass);


INSERT INTO public.v_dictionary (id, lang, active, title, old)
VALUES (DEFAULT, 'ru', 'v_dasha', 'v_dasha', 'v_dasha')
RETURNING *;

UPDATE public.v_dictionary
SET title = 'd_max1', lang = 'ru'
WHERE id = 5
  AND lang = 'en'
RETURNING *;
