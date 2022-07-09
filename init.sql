-- Триггеры событий - https://postgrespro.ru/docs/postgresql/14/event-triggers
-- Функции событийных триггеров - https://postgrespro.ru/docs/postgresql/14/functions-event-triggers.html
-- Матрица срабатывания триггеров событий - https://postgrespro.ru/docs/postgresql/14/event-trigger-matrix
CREATE EVENT TRIGGER "add_constraints_from_parent_tables"
    ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'ALTER TABLE')
EXECUTE PROCEDURE trigger_add_constraints_from_parent_tables();
