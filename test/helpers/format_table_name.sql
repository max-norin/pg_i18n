SELECT format_table_name('user');
SELECT format_table_name('public.user');
SELECT format_table_name('"user"');
SELECT format_table_name('public."user"');
SELECT format_table_name('"public".user');
SELECT format_table_name('"public"."user"');

SELECT format_table_name('public."user"', 'v_');

-- ERROR
SELECT format_table_name('public.bv.user');
