-- создание представления для пользовательского способа
-- представление не только отображает данные, но даёт возможность редактирования
CREATE PROCEDURE create_user_view ("name" TEXT, "lb_table" REGCLASS, "lbt_table" REGCLASS, "select" TEXT[] = '{*}', "where" TEXT = NULL)
    AS $$
DECLARE
    -- имя будущей таблицы
    "name"       CONSTANT TEXT NOT NULL   = COALESCE(@extschema@.format_table_name("name"), @extschema@.format_table_name("lb_table"::TEXT, 'v_'));
    "columns"    CONSTANT TEXT[] NOT NULL = @extschema@.get_columns("lb_table");
    "pk_columns" CONSTANT TEXT[]          = @extschema@.get_primary_key("lb_table");
BEGIN
    -- проверка, что таблицы заданы
    IF ("lb_table" IS NULL) OR ("lbt_table" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" and "lbt_table" cannot be NULL';
    END IF;
    -- проверка, что pk_columns существуют
    IF ("pk_columns" IS NULL) THEN
        RAISE EXCEPTION USING MESSAGE = '"lb_table" table must have primary keys';
    END IF;

    -- add default_lang in select
    IF 'default_lang' = ANY ("columns") THEN
        "select" = array_prepend('(b."default_lang" = bt."lang") IS TRUE AS "lang_is_default"'::TEXT, "select");
    END IF;

    -- set where
    IF "where" IS NULL THEN
        "where" = 'TRUE';
    END IF;

    -- create view
    -- USING — это сокращённая запись условия, полезная в ситуации, когда с обеих сторон соединения столбцы имеют одинаковые имена
    EXECUTE format('
        CREATE VIEW %1s AS
        SELECT %2s
            FROM %3s b
            LEFT JOIN %4s bt USING (%5s)
            WHERE %6s;
    ', "name", array_to_string("select", ','), "lb_table", "lbt_table", array_to_string("pk_columns", ','), "where");
    -- создание triggers для редактиварония представления
    -- %L - равнозначно вызову quote_nullable. Переводит данное значение в текстовый вид и заключает в апострофы
    -- как текстовую строку, при этом для аргумента NULL возвращается строка NULL.
    -- Символы апостроф и обратная косая черта дублируются должным образом.
    EXECUTE format('
        CREATE TRIGGER "insert"
            INSTEAD OF INSERT
            ON %1s FOR EACH ROW
        EXECUTE FUNCTION @extschema@.trigger_insert_user_view(%2L, %3L);
    ', "name", "lb_table", "lbt_table");
    EXECUTE format('
        CREATE TRIGGER "update"
            INSTEAD OF UPDATE
            ON %1s FOR EACH ROW
        EXECUTE FUNCTION @extschema@.trigger_update_user_view(%2L, %3L);
    ', "name", "lb_table", "lbt_table");
END
$$
LANGUAGE plpgsql;

