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
    "lb_record" = @extschema@.insert_using_records("lb_table", NEW);
    -- join query result with target table record
    -- for the correctness of data types and adding the necessary data to lbt_table
    NEW = jsonb_populate_record(NEW, "lb_record");

    -- insert and return record from lbt_table
    PERFORM @extschema@.insert_using_records("lbt_table", NEW);

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

COMMENT ON FUNCTION trigger_insert_user_view (OID) IS 'DON''T USE DEFAULT WITH VIEWS';
