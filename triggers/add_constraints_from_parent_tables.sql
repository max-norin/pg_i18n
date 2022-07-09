CREATE OR REPLACE FUNCTION trigger_add_constraints_from_parent_tables()
    RETURNS EVENT_TRIGGER
AS
$$
DECLARE
    "reloid"             OID;
    "reloid_constraints" TEXT[];
    "table"              OID;
    "tables"             OID[];
    "constraint"         TEXT;
    "constraints"        TEXT[];
    "obj"                RECORD;
BEGIN
    FOR "obj" IN SELECT * FROM pg_event_trigger_ddl_commands()
        LOOP
            RAISE DEBUG 'objid = %', "obj".objid;
            RAISE DEBUG 'command_tag = %', "obj".command_tag;
            RAISE DEBUG 'schema_name = %', "obj".schema_name;
            RAISE DEBUG 'object_type = %', "obj".object_type;
            RAISE DEBUG 'object_identity = %', "obj".object_identity;
            RAISE DEBUG 'in_extension = %', "obj".in_extension;

            IF obj.command_tag = 'CREATE TABLE' THEN
                "reloid" = "obj".objid;
                RAISE DEBUG USING MESSAGE = (concat('command_tag: CREATE TABLE ', "obj".object_identity));

                "tables" = (SELECT array_agg(p.oid)
                            FROM pg_inherits
                                     JOIN pg_class AS c ON (inhrelid = c.oid)
                                     JOIN pg_class as p ON (inhparent = p.oid)
                            WHERE c.oid = "reloid");
                RAISE DEBUG USING MESSAGE = (concat('parents: ', COALESCE("tables", '{}')));

                "reloid_constraints" = get_constraintdefs("reloid");
                FOREACH "table" IN ARRAY COALESCE("tables", '{}')
                    LOOP
                        "constraints" = array_except(get_constraintdefs("table"), "reloid_constraints");
                        FOREACH "constraint" IN ARRAY COALESCE("constraints", '{}')
                            LOOP
                                RAISE NOTICE USING MESSAGE = (concat('FROM PARENT TABLE: ', "table"::REGCLASS));
                                RAISE NOTICE USING MESSAGE = (concat('ADD CONSTRAINT: ', "constraint"));
                                EXECUTE format('ALTER TABLE %s ADD %s;', "reloid"::REGCLASS, "constraint");
                            END LOOP;
                    END LOOP;
            ELSEIF obj.command_tag = 'ALTER TABLE' THEN
                "reloid" = "obj".objid;
                RAISE DEBUG USING MESSAGE = (concat('command_tag: ALTER TABLE ', "obj".object_identity));

                "tables" = (SELECT array_agg(c.oid)
                            FROM pg_inherits
                                     JOIN pg_class AS c ON (inhrelid = c.oid)
                                     JOIN pg_class as p ON (inhparent = p.oid)
                            WHERE p.oid = "reloid");
                RAISE DEBUG USING MESSAGE = (concat('children: ', COALESCE("tables", '{}')));

                "reloid_constraints" = get_constraintdefs("reloid");
                FOREACH "table" IN ARRAY COALESCE("tables", '{}')
                    LOOP
                        "constraints" = array_except("reloid_constraints", get_constraintdefs("table"));
                        RAISE NOTICE USING MESSAGE = (concat('TO CHILD TABLE: ', "table"::REGCLASS));
                        FOREACH "constraint" IN ARRAY COALESCE("constraints", '{}')
                            LOOP
                                RAISE NOTICE USING MESSAGE = (concat('ADD CONSTRAINT: ', "constraint"));
                                EXECUTE format('ALTER TABLE %s ADD %s;', "table"::REGCLASS, "constraint");
                            END LOOP;
                    END LOOP;
            END IF;
        END LOOP;
END;
$$ LANGUAGE plpgsql;
