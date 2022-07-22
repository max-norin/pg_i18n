SELECT get_columns ('"user"'::REGCLASS);

SELECT get_columns ('dictionary'::REGCLASS, TRUE);

SELECT get_columns ('dictionary'::REGCLASS, FALSE);
