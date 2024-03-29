CREATE FUNCTION event_trigger_add_constraints_from_lang_parent_tables ()
    RETURNS EVENT_TRIGGER
    AS $$
DECLARE
    "parents"              REGCLASS[];
    "tg_relid"             OID;
    "tg_relid_constraints" TEXT[];
    "relid"                OID;
    "relids"               OID[];
    "constraints"          TEXT[];
    "table"                TEXT;
    "obj"                  RECORD;
    "constraint"           TEXT;
BEGIN
    FOR "obj" IN
    SELECT *
    FROM pg_event_trigger_ddl_commands ()
        LOOP
            RAISE DEBUG 'objid = %', "obj".objid;
            RAISE DEBUG 'command_tag = %', "obj".command_tag;
            RAISE DEBUG 'schema_name = %', "obj".schema_name;
            RAISE DEBUG 'object_type = %', "obj".object_type;
            RAISE DEBUG 'object_identity = %', "obj".object_identity;
            RAISE DEBUG 'in_extension = %', "obj".in_extension;
            IF "obj".in_extension = TRUE THEN
                CONTINUE;
            END IF;
            "parents" = ARRAY ['@extschema@."lang_base"'::REGCLASS, '@extschema@."lang_base_tran"'::REGCLASS];
            IF "obj".command_tag = 'CREATE TABLE' THEN
                "tg_relid" = "obj".objid;
                RAISE DEBUG USING MESSAGE = (concat('command_tag: CREATE TABLE ', "obj".object_identity));
                -- parent tables of the created table
                "relids" = (
                    SELECT array_agg(p.oid)
                    FROM pg_inherits
                        JOIN pg_class AS c ON (inhrelid = c.oid)
                        JOIN pg_class AS p ON (inhparent = p.oid)
                    WHERE c.oid = "tg_relid"
                        AND p.oid = ANY ("parents"));
                RAISE DEBUG USING MESSAGE = (concat('parents: ', COALESCE("relids", '{}')));
                "table" = "tg_relid"::REGCLASS;
                -- get existing constraints
                "tg_relid_constraints" = @extschema@.get_constraintdefs ("tg_relid");
                FOREACH "relid" IN ARRAY COALESCE("relids", '{}')
                LOOP
                    -- except existing constraints from parent constraints
                    "constraints" = @extschema@.get_constraintdefs ("relid") OPERATOR ( @extschema@.- ) "tg_relid_constraints";
                    FOREACH "constraint" IN ARRAY COALESCE("constraints", '{}')
                    LOOP
                        RAISE NOTICE USING MESSAGE = (concat('FROM PARENT TABLE: ', "relid"::REGCLASS));
                        RAISE NOTICE USING MESSAGE = (concat('ADD CONSTRAINT: ', "constraint"));
                        EXECUTE format('ALTER TABLE %s ADD %s;', "table", "constraint");
                    END LOOP;
                END LOOP;
                ELSEIF "obj".command_tag = 'ALTER TABLE' THEN
                "tg_relid" = "obj".objid;
                IF NOT ("tg_relid" = ANY ("parents")) THEN
                    CONTINUE;
                END IF;
                RAISE DEBUG USING MESSAGE = (concat('command_tag: ALTER TABLE ', "obj".object_identity));
                -- children tables of the altered table
                "relids" = (
                    SELECT array_agg(c.oid)
                    FROM pg_inherits
                        JOIN pg_class AS c ON (inhrelid = c.oid)
                        JOIN pg_class AS p ON (inhparent = p.oid)
                    WHERE p.oid = "tg_relid");
                RAISE DEBUG USING MESSAGE = (concat('children: ', COALESCE("relids", '{}')));
                -- get existing constraints
                "tg_relid_constraints" = @extschema@.get_constraintdefs ("tg_relid");
                FOREACH "relid" IN ARRAY COALESCE("relids", '{}')
                LOOP
                    -- except existing constraints from parent constraints
                    "constraints" = "tg_relid_constraints" OPERATOR ( @extschema@.- ) @extschema@.get_constraintdefs ("relid");
                    "table" = "relid"::REGCLASS;
                    RAISE NOTICE USING MESSAGE = (concat('TO CHILD TABLE: ', "table"));
                    FOREACH "constraint" IN ARRAY COALESCE("constraints", '{}')
                    LOOP
                        RAISE NOTICE USING MESSAGE = (concat('ADD CONSTRAINT: ', "constraint"));
                        EXECUTE format('ALTER TABLE %s ADD %s;', "table", "constraint");
                    END LOOP;
                END LOOP;
            END IF;
        END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;

