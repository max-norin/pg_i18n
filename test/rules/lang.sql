-- TRUE
SELECT *
FROM unnest(ARRAY[lang ('ru'), lang ('rus'), lang ('ru-Russ'), lang ('ru-Russ-RU'), lang ('ru-RU')]);

-- FALSE
SELECT *
FROM unnest(ARRAY[lang (NULL), lang ('123'), lang ('asdgafs'), lang ('-'), lang ('ru--Russ'), lang ('ru--RU'), lang ('ru-'), lang ('ru-Russ-'), lang ('ru-Russ-RU-')]);

