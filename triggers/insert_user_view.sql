-- триггер для вставки данных в пользовательском представлении
CREATE FUNCTION trigger_insert_user_view ()
    RETURNS TRIGGER
    AS $$
DECLARE
    -- lb  - language base
    -- lbt - lang base tran
    -- language base
    "lb_record"          JSONB;
    "lb_table"  CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    -- lang base tran
    "lbt_table" CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    -- helpers
    "record"             JSONB    NOT NULL ='{}';
BEGIN
    -- insert and return record from lb_table
    "lb_record" = public.insert_using_records("lb_table", NEW);
    -- join query result with target table record
    -- for the correctness of data types and adding the necessary data to lbt_table
    -- Используется, чтобы данные были корректные для lbt_table,
    -- это используется, так как данные из NEW могут не примениться или быть изменены триггерами.
    -- jsonb_populate_record(base anyelement, from_json jsonb) -
    -- Разворачивает объект из from_json в табличную строку,
    -- в которой столбцы соответствуют типу строки, заданному параметром base.
    NEW = jsonb_populate_record(NEW, "lb_record");

    -- insert and return record from lbt_table
    PERFORM public.insert_using_records("lbt_table", NEW);

    -- change result new, empty object + pk object
    -- изменяется результат триггера, пустой объект текущего представления + primary key
    "record" = public.jsonb_empty_by_table(TG_RELID) || public.jsonb_pk_table_object("lb_table", to_jsonb(NEW));
    NEW = jsonb_populate_record(NEW, "record");

    -- returning record with primary keys only
    -- because this function does not know how the values of the target table are formed
    -- возвращаются только первичные ключи
    -- TODO почему так?
    RETURN NEW;
END
$$
LANGUAGE plpgsql
VOLATILE -- может делать всё, что угодно, в том числе, модифицировать базу данных
SECURITY DEFINER;  -- функция выполняется с правами пользователя, владеющего ей

COMMENT ON FUNCTION trigger_insert_user_view () IS 'DON''T USE DEFAULT WITH VIEWS';
