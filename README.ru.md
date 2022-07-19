# pg_i18n

> Расширение позволяет легко и просто создавать мультиязычные базы данных.

## Основное

### Установка

Скачайте себе в папку `extension` PostgreSQL файлы из [dist](./dist) и выполните следующие команды.

Создайте новую схему для удобства.

```postgresql
CREATE SCHEMA "dictionaries";
ALTER ROLE "postgres" SET search_path TO "public", "dictionaries";
```

Установите расширение.

```postgresql
CREATE EXTENSION "pg_i18n"
    SCHEMA "dictionaries"
    VERSION '1.0';
```

### Использование

Расширение создает таблицу `"langs"`, где хранятся используемые языковые теги. Нужно
наполнить таблицу данными. Например:

```postgresql
INSERT INTO "dictionaries"."langs"("language", "script", "region", "is_active", "title")
VALUES ('ru', NULL, NULL, TRUE, 'Русский'),
       ('udm', NULL, NULL, TRUE, 'Удмурт'),
       ('en', NULL, 'US', TRUE, 'English');

```

Далее есть два способа реализации мультиязычных таблиц.

#### 1. Словарный способ

> _Словарный способ_ - на каждый языковой тег будет предоставлен перевод. Если перевода нет
> в таблице переводов, то будет представлено значение по умолчанию из основной таблицы.

Процедура `create_dictionary_view` создаст представление, где на каждый языковой тег будет
предоставлен перевод, если он есть в таблице переводов, в противном случае значение по умолчанию.
Данные в представлении можно обновлять.

```postgresql
-- основная таблица
CREATE TABLE "dictionary"
(
    "id"        SERIAL PRIMARY KEY,
    "title"     VARCHAR(255) NOT NULL, -- значение по умолчанию
    "is_active" BOOLEAN DEFAULT TRUE
);
-- таблица переводов. обратите внимание, что она наследуется от "lang_base_tran" 
CREATE TABLE "dictionary_trans"
(
    "id"    INTEGER NOT NULL REFERENCES "dictionary" ("id") ON UPDATE CASCADE,
    "title" VARCHAR(255), -- перевод "title" на язык "lang"
    PRIMARY KEY ("lang", "id")
) INHERITS ("lang_base_tran");
-- создание представления
CALL create_dictionary_view('v_dictionary'::TEXT, 'dictionary'::REGCLASS, 'dictionary_trans'::REGCLASS);
```

#### 2. Пользовательский способ

> _Пользовательский способ_ - выдаются только переведенные данные.

Процедура `create_user_view` создаст представление, где выдаются результаты только при наличии
перевода.
Данные в представлении можно вставлять и обновлять.

```postgresql
-- основная таблица. обратите внимание, что она наследуется от "lang_base"
CREATE TABLE "user"
(
    "id"       SERIAL PRIMARY KEY,
    "nickname" VARCHAR(100) NOT NULL UNIQUE
    -- отсутствует "title"
) INHERITS ("lang_base");
-- таблица переводов. обратите внимание, что она наследуется от "lang_base_tran"
CREATE TABLE "user_trans"
(
    "id"    BIGINT NOT NULL REFERENCES "user" ("id") ON UPDATE CASCADE,
    "title" VARCHAR(255),
    PRIMARY KEY ("id", "lang")
) INHERITS ("lang_base_tran");
-- создание представления
CALL create_user_view('v_user'::TEXT, '"user"'::REGCLASS, 'user_trans'::REGCLASS);
```

## Домены

Расширение имеет домены используемые для определения таблицы `"langs"`.

- [lang](./domains/lang.sql) - языковой тег / `RFC 5646`
- [language](./domains/language.sql) - язык / `ISO 639`
- [region](./domains/region.sql) - регион / `ISO 3166-1`
- [script](./domains/script.sql) - письменность / `ISO 15924`

## Архитектура

Архитектура построена согласно высокой нормализации. Имеется таблица языков, на которую ссылаются
таблицы с переводами. Таблица с переводами имеет только переводимую информацию, непереводимая
информация (например email) хранится в отдельной таблице, на которую указывает ссылка. Простой
пример:

```postgresql
-- таблица языков
CREATE TABLE "languages"
(
    "id"    SERIAL PRIMARY KEY,
    "code"  VARCHAR(11) NOT NULL UNIQUE,
    "title" VARCHAR(50) NOT NULL UNIQUE
);
-- основная таблица
CREATE TABLE "user"
(
    "id"       SERIAL PRIMARY KEY,
    "email"    VARCHAR(255) NOT NULL UNIQUE,
    "nickname" VARCHAR(100) NOT NULL UNIQUE
);
-- таблица переводов
CREATE TABLE "user_trans"
(
    "id"    INT         NOT NULL REFERENCES "user" ("id") ON UPDATE CASCADE,
    "lang"  VARCHAR(11) NOT NULL REFERENCES "languages" ("code") ON UPDATE CASCADE,
    "title" VARCHAR(255),
    PRIMARY KEY ("id", "lang")
);
```

В качестве таблицы языков в расширении есть таблица языковых тегов `"langs"` на основе `RFC 5646`.

Таблица переводов имеет определённую
структуру `"lang" LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE`.
Чтобы не копировать это определение для каждой новой таблицы воспользуемся наследованием.
Это поможет избежать ошибок и даст гибкость (если возникнет необходимость всем наследуемым таблицам
добавить новый столбец или новое ограничение).
Единственная проблема наследования, что в дочернюю таблицу не копируются внешние ключи.
Поэтому в расширении был создан событийный триггер `add_constraints_from_lang_parent_tables`,
который добавляет внешние ключи и другие ограничения
от наследуемых таблиц `"lang_base"` `"lang_base_tran"`.

Таблица `"lang_base"` имеет столбец `"default_lang"`.

Таблица `"lang_base_tran"` имеет столбец `"lang"`.

При желании триггер можно отключить или удалить из расширения.

```postgresql
ALTER EVENT TRIGGER add_constraints_from_lang_parent_tables DISABLE;
-- https://postgresql.org/docs/current/sql-altereventtrigger.html 
ALTER EXTENSION pg_i18n DROP EVENT TRIGGER add_constraints_from_lang_parent_tables;
-- https://postgresql.org/docs/current/sql-alterextension.html
```

Для удобства получения информации можно создать представления. В расширении есть две процедуры
позволяющие это выполнить, они были упомянуты в разделе Использование: `create_dictionary_view`
и `create_user_view`.

Параметры процедур:

- Первый параметр - название будущего представления, может быть опущен.
- Второй параметр - таблица с основными данными.
- Третий параметр - таблица с переводимыми данными.

В процедурах создается представление и назначаются триггеры.
В `create_dictionary_view` триггер на обновление,
в `create_user_view` триггер на вставку и обновление.

## Использование языкового индекса

В таблице с переводами не предполагается, что есть колонка с названием языка, как в `postgresql`.
Поэтому нельзя создать языковой индекс, как показано ниже, так как он будет не корректный.

```postgresql
CREATE INDEX user_trans_title_idx ON "user_trans" USING GIN (to_tsvector("lang", "title"));
```

Есть обходной пусть - создать копии уже готовых конфигураций на используемый языковой тег.
После чего будет корректное использование индекса, указанного выше.

```postgresql
CREATE TEXT SEARCH CONFIGURATION public."ru" ( COPY = pg_catalog.russian );
CREATE TEXT SEARCH CONFIGURATION public."en-US" ( COPY = pg_catalog.english );
```

## Рекомендуемое использование

При использовании _Пользовательского способа_ создании таблицы может быть ситуация,
когда есть основная информация, но нет переведённой информации. Это не совсем корректное хранение.
Поэтому предлагаю использовать две роли: администратор и пользователь.
Пользователю будет разрешено вставлять данные через представление, но не напрямую
в основную таблицу.

Для реализации этого подхода функции триггеров запускаются от имени создателя функции.
Это несет угрозу безопасности данных,
чтобы никто другой не мог воспользоваться этими функциями заблокируем к ним доступ.

```postgresql
-- запрещает всем выполнение текущих функций SCHEMA "dictionaries"
REVOKE ALL ON ALL ROUTINES IN SCHEMA "dictionaries" FROM PUBLIC;
-- запрещает всем выполнение будущих определенных функций SCHEMA "dictionaries"
ALTER DEFAULT PRIVILEGES IN SCHEMA "dictionaries" REVOKE ALL ON ROUTINES FROM PUBLIC;
```

```postgresql
-- заполним таблицу с языковыми тегами
INSERT INTO "langs"("language", "script", "region", "is_active", "title")
VALUES ('ru', NULL, NULL, TRUE, 'Русский'),
       ('udm', NULL, NULL, TRUE, 'Удмурт'),
       ('en', NULL, 'US', TRUE, 'English');
-- таблица пользователей с основной информацией
CREATE TABLE "user"
(
    "id"       SERIAL PRIMARY KEY,
    "nickname" VARCHAR(100) NOT NULL UNIQUE
) INHERITS ("lang_base");
-- таблица пользователей с переводимой информацией
CREATE TABLE "user_trans"
(
    "id"    BIGINT NOT NULL REFERENCES "user" ("id") ON UPDATE CASCADE,
    "title" VARCHAR(255),
    PRIMARY KEY ("id", "lang")
) INHERITS ("lang_base_tran");
-- представление с объединением двух вышеописанных таблиц
CALL create_user_view(NULL::TEXT, '"user"'::REGCLASS, '"user_trans"'::REGCLASS);
```

```postgresql
-- создаем пользователя
CREATE ROLE "test_i18n" LOGIN;
-- разрешаем подключаться к базе данных
GRANT CONNECT ON DATABASE "postgres" TO "test_i18n";
-- даем право на использование SCHEMA "dictionaries" - иначе ничего из схемы использовать нельзя
GRANT USAGE ON SCHEMA "dictionaries" TO "test_i18n";
-- определяем нужные безопасные функции, они нужны для запуска триггеров INSTEAD OF
-- потому что они преобразовывают входные типы (для OLD и NEW) в нужный тип
GRANT ALL ON FUNCTION dictionaries.language(TEXT) TO "test_i18n";
GRANT ALL ON FUNCTION dictionaries.script(TEXT) TO "test_i18n";
GRANT ALL ON FUNCTION dictionaries.region(TEXT) TO "test_i18n";
GRANT ALL ON FUNCTION dictionaries.lang(TEXT) TO "test_i18n";
-- переопределяем search_path
ALTER ROLE "test_i18n" SET search_path TO "public", "dictionaries";
-- даем нужные доступы для пользователя
-- ключевой момент, что в "user" вставлять нельзя
-- вставка в представлении возможна только 
-- благодаря SECURITY DEFINER в определении функций триггеров
GRANT SELECT ON TABLE "langs" TO "test_i18n";
GRANT INSERT, UPDATE, SELECT ON TABLE "v_user" TO "test_i18n";
GRANT UPDATE, SELECT ON TABLE "user" TO "test_i18n";
GRANT INSERT, UPDATE, SELECT ON TABLE "user_trans" TO "test_i18n";
```

Меняем текущего пользователя на нового пользователя или
подключаемся к базе с помощью нового пользователя.

```postgresql
SET ROLE "text_i18n";
```

Проверка, что функции недоступны

```postgresql
SELECT dictionaries.get_primary_key('dictionaries.langs'::REGCLASS);
```

Попробуем вставить в таблицу `"user"` - ошибка.

```postgresql
INSERT INTO "user"
    (id, default_lang, nickname)
VALUES (DEFAULT, 'ru', 'max');    
```

Попробуем вставить в представление `"v_user"` - успешно.

```postgresql
INSERT INTO "v_user"
    (id, default_lang, nickname, lang, title)
VALUES (DEFAULT, 'ru', 'max', 'ru', 'Макс');
```

## Файлы

- `helpers/*.sql` вспомогательные функции
    - [array_except](./helpers/array_except.sql)
    - [format_table_name](./helpers/format_table_name.sql)
    - [get_columns](./helpers/get_columns.sql)
    - [get_constraintdef](./helpers/get_constraintdef.sql)
    - [get_primary_key](./helpers/get_primary_key.sql)
    - [get_primary_key_name](./helpers/get_primary_key_name.sql)
    - [jsonb_object_fields](./helpers/jsonb_object_fields.sql)
- `rules/*.sql` правила для доменов
    - [lang](./rules/lang.sql)
    - [language](./rules/language.sql)
    - [region](./rules/region.sql)
    - [script](./rules/script.sql)
- `domains/*.sql` используемые домены
    - [lang](./domains/lang.sql)
    - [language](./domains/language.sql)
    - [region](./domains/region.sql)
    - [script](./domains/script.sql)
- `tables/*.sql` определение таблицы `"langs"`, родительских таблиц `"lang_base"` `"lang_base_tran"`
- [event_triggers/add_constraints_from_lang_parent_tables.sql](./event_triggers/add_constraints_from_lang_parent_tables.sql)
  событийный триггер
- [init.sql](./init.sql) назначение событийного триггера
- `views/*.sql` процедуры создания представлений
    - [dictinary](./views/dictinary.sql)
    - [user](./views/user.sql)
- `triggers/*.sql` триггеры `INSTEAD OF` для представлений
    - [update_dictionary_view](./triggers/update_dictionary_view.sql)
    - [insert_user_view](./triggers/insert_user_view.sql)
    - [update_user_view](./triggers/update_user_view.sql)
- [test/*.sql](./test) тестовые файлы

## Полезное

- [Pseudotypes](https://www.postgresql.org/docs/current/datatype-pseudo.html)
- [Functions with Variable Numbers of Arguments](https://www.postgresql.org/docs/current/xfunc-sql.html#XFUNC-SQL-VARIADIC-FUNCTIONS)
- [Object Identifier Types](https://www.postgresql.org/docs/current/datatype-oid.html#DATATYPE-OID-TABLE)
