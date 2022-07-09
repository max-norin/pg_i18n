CREATE FUNCTION array_except ("a" ANYARRAY, "b" ANYARRAY)
    RETURNS ANYARRAY
AS $$
BEGIN
    RETURN ARRAY (
                 SELECT *
                 FROM unnest("a")
                 EXCEPT
                 SELECT *
                 FROM unnest("b")
             );
END;
$$
    LANGUAGE plpgsql
    IMMUTABLE;

COMMENT ON FUNCTION array_except (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

CREATE OPERATOR - (
    LEFTARG = ANYARRAY, RIGHTARG = ANYARRAY, FUNCTION = array_except
    );

COMMENT ON OPERATOR - (ANYARRAY, ANYARRAY) IS '$1 EXCEPT $2';

