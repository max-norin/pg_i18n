-- триггер для обновления данных в словарном представлении
CREATE FUNCTION trigger_update_dictionary_view ()
    RETURNS TRIGGER
    AS $$
DECLARE
    -- lang base tran
    "lbt_record"              JSONB    NOT NULL = '{}';
    "lbt_table"      CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    "lbt_pk_columns" CONSTANT TEXT[]   NOT NULL = @extschema@.get_primary_key("lbt_table");
    -- все колонки кроме primary_key (secondary key)
    "lbt_sk_columns" CONSTANT TEXT[]   NOT NULL = @extschema@.get_columns("lbt_table", FALSE) OPERATOR ( @extschema@.- ) "lbt_pk_columns";
    -- lang base
    "lb_record"               JSONB    NOT NULL = '{}';
    "lb_table"       CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    -- все колонки lb_table отличные от колонок в таблице lbt_table
    "lb_ch_columns"  CONSTANT TEXT[]   NOT NULL = @extschema@.get_columns("lb_table", FALSE) OPERATOR ( @extschema@.- ) "lbt_sk_columns";
BEGIN
    -- insert or update and return record from lb_table
    "lb_record" = @extschema@.update_using_records("lb_table", "lb_ch_columns", OLD, NEW);
    -- insert or update and return record from lbt_table
    "lbt_record" = @extschema@.insert_or_update_using_records("lbt_table", NEW);

    -- change NEW using changed records
    -- Используется, чтобы при испольовании RETURNING вернулся объект,
    -- который будет соответствовать данным в таблицах,
    -- это используется, так как данные из NEW могут не примениться или быть изменены триггерами.
    -- jsonb_populate_record(base anyelement, from_json jsonb) -
    -- Разворачивает объект из from_json в табличную строку,
    -- в которой столбцы соответствуют типу строки, заданному параметром base.
    NEW = jsonb_populate_record(NEW, "lb_record");
    NEW = jsonb_populate_record(NEW, "lbt_record");

    RETURN NEW;
END
$$
    LANGUAGE plpgsql
    VOLATILE -- может делать всё, что угодно, в том числе, модифицировать базу данных
    SECURITY DEFINER;  -- функция выполняется с правами пользователя, владеющего ей

