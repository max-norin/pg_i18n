-- триггер события для добавление ограничений таблиц lang_base и lang_base_tran
-- на все наследуемые таблицы
-- в основом используется для создания REFERENCES
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
        -- описание значений переменной obj
        -- @see https://www.postgresql.org/docs/current/functions-event-triggers.html#PG-EVENT-TRIGGER-DDL-COMMAND-END-FUNCTIONS
            RAISE DEBUG 'objid = %', "obj".objid; -- OID самого объекта
            RAISE DEBUG 'command_tag = %', "obj".command_tag; -- Тег команды
            RAISE DEBUG 'schema_name = %', "obj".schema_name; -- Имя схемы, к которой относится объект
            RAISE DEBUG 'object_type = %', "obj".object_type; -- Тип объекта
            RAISE DEBUG 'object_identity = %', "obj".object_identity; -- Текстовое представление идентификатора объекта, включающее схему
            RAISE DEBUG 'in_extension = %', "obj".in_extension; -- True, если команда является частью скрипта расширения
            -- не обрабатывать запрос, если запрос внутри расширения
            IF "obj".in_extension = TRUE THEN
                CONTINUE;
            END IF;
            -- список родительских таблиц, наследование которых проверяется
            "parents" = ARRAY ['@extschema@."lang_base"'::REGCLASS, '@extschema@."lang_base_tran"'::REGCLASS];
            -- если создается таблица
            IF "obj".command_tag = 'CREATE TABLE' THEN
                -- обрабатываемая таблица в формате OID
                "tg_relid" = "obj".objid;
                RAISE DEBUG USING MESSAGE = (concat('command_tag: CREATE TABLE ', "obj".object_identity));
                -- parent tables of the created table
                -- получение массива родителей lang_base и lang_base_tran, если они есть у таблицы
                "relids" = (
                    SELECT array_agg(inhparent)
                    FROM pg_inherits
                    WHERE inhrelid = "tg_relid"
                      AND inhparent = ANY ("parents"));
                RAISE DEBUG USING MESSAGE = (concat('parents: ', COALESCE("relids", '{}')));
                -- обрабатываемая таблица в формате REGCLASS
                "table" = "tg_relid"::REGCLASS;
                -- get existing constraints
                -- получение ограничений таблицы tg_relid
                "tg_relid_constraints" = @extschema@.get_constraintdefs ("tg_relid");
                -- цикл по массиву relids
                FOREACH "relid" IN ARRAY COALESCE("relids", '{}')
                LOOP
                    -- except existing constraints from parent constraints
                    -- вычитание огранический текущей таблицы из ограничений родительской таблицы
                    "constraints" = @extschema@.get_constraintdefs ("relid") OPERATOR ( @extschema@.- ) "tg_relid_constraints";
                    -- цикл по массиву constraints
                    FOREACH "constraint" IN ARRAY COALESCE("constraints", '{}')
                    LOOP
                        RAISE NOTICE USING MESSAGE = (concat('FROM PARENT TABLE: ', "relid"::REGCLASS));
                        RAISE NOTICE USING MESSAGE = (concat('ADD CONSTRAINT: ', "constraint"));
                        -- добавление ограничения
                        EXECUTE format('ALTER TABLE %s ADD %s;', "table", "constraint");
                    END LOOP;
                END LOOP;
            -- если редактируется таблица
            ELSEIF "obj".command_tag = 'ALTER TABLE' THEN
                -- обрабатываемая таблица в формате OID
                "tg_relid" = "obj".objid;
                -- не обрабатывать, если это не таблица lang_base или lang_base_tran
                IF NOT ("tg_relid" = ANY ("parents")) THEN
                    CONTINUE;
                END IF;
                RAISE DEBUG USING MESSAGE = (concat('command_tag: ALTER TABLE ', "obj".object_identity));
                -- children tables of the altered table
                -- получить наследуемые таблицы от lang_base или lang_base_tran
                "relids" = (
                    SELECT array_agg(inhrelid)
                    FROM pg_inherits
                    WHERE inhparent = "tg_relid");
                RAISE DEBUG USING MESSAGE = (concat('children: ', COALESCE("relids", '{}')));
                -- get existing constraints
                -- получить ограничения таблицы tg_relid
                "tg_relid_constraints" = @extschema@.get_constraintdefs ("tg_relid");
                FOREACH "relid" IN ARRAY COALESCE("relids", '{}')
                LOOP
                    -- except existing constraints from parent constraints
                    -- вычитание ограничений наследуемой таблицы из огранический текущей таблицы
                    "constraints" = "tg_relid_constraints" OPERATOR ( @extschema@.- ) @extschema@.get_constraintdefs ("relid");
                    -- обрабатываемая таблица в формате REGCLASS
                    "table" = "relid"::REGCLASS;
                    RAISE NOTICE USING MESSAGE = (concat('TO CHILD TABLE: ', "table"));
                    -- цикл по массиву constraints
                    FOREACH "constraint" IN ARRAY COALESCE("constraints", '{}')
                    LOOP
                        RAISE NOTICE USING MESSAGE = (concat('ADD CONSTRAINT: ', "constraint"));
                        -- добавление ограничения
                        EXECUTE format('ALTER TABLE %s ADD %s;', "table", "constraint");
                    END LOOP;
                END LOOP;
            END IF;
        END LOOP;
END;
$$
LANGUAGE plpgsql
VOLATILE;

