SELECT ARRAY['s', 'f', 'w']::TEXT[] - ARRAY['s']::TEXT[];

SELECT ARRAY['s', 'f', 'w']::TEXT[] - NULL::TEXT[];

SELECT NULL::TEXT[] - ARRAY['s']::TEXT[];

SELECT NULL::TEXT[] - NULL::TEXT[];

