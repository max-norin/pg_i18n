CREATE FUNCTION trigger_update_user_view ()
    RETURNS TRIGGER
    AS $$
DECLARE
    -- lb  - lang base
    -- lbt - lang base tran
    -- ch  - changed
    -- main
    "ch_record"  CONSTANT JSONB             = to_jsonb(NEW) OPERATOR ( @extschema@.- ) to_jsonb(OLD);
    "ch_columns" CONSTANT TEXT[]   NOT NULL = ARRAY(SELECT jsonb_object_keys("ch_record"));
    -- lang base
    "lb_record"           JSONB    NOT NULL = '{}';
    "lb_table"   CONSTANT REGCLASS NOT NULL = TG_ARGV[0];
    -- lang base tran
    "lbt_table"  CONSTANT REGCLASS NOT NULL = TG_ARGV[1];
    -- helpers
    "record"              JSONB    NOT NULL ='{}';
BEGIN
    -- update and return record from lb_table
    "lb_record" = update_using_records("lb_table", "ch_columns", OLD, NEW);
    -- join query result with target table record
    -- for the correctness of data types and adding the necessary data to lbt_table
    NEW = jsonb_populate_record(NEW, "lb_record");

    -- update and return record from lbt_table
    PERFORM @extschema@.update_using_records("lbt_table", "ch_columns", NEW, NEW);

    -- change result new, empty object + pk object
    "record" = @extschema@.jsonb_empty_by_table(TG_RELID) || @extschema@.jsonb_pk_table_object("lb_table", to_jsonb(NEW));
    NEW = jsonb_populate_record(NEW, "record");

    -- returning record with primary keys only
    -- because this function does not know how the values of the target table are formed
    RETURN NEW;
END
$$
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER;

