[//]: # (TODO написать про использование SECURITY DEFINER)

# pg_i18n

100% работает на PostgreSQL 16 версии, на остальных не проверял.
Если у вас есть информация, что работает на более ранних версиях
сообщите мне.

> Расширение позволяет легко и просто создавать мультиязычные базы данных.

# Установка

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
    VERSION '2.0';
```

[Подробнее про расширение и файл control](https://postgrespro.ru/docs/postgresql/14/extend-extensions)

# Использование

Расширение создает таблицу `"langs"`, где хранятся используемые языковые теги. Нужно
наполнить таблицу данными. Например:

```postgresql
INSERT INTO "dictionaries"."langs"("language", "script", "region", "is_active", "title")
VALUES ('ru', NULL, NULL, TRUE, 'Русский'),
       ('udm', NULL, NULL, TRUE, 'Удмурт'),
       ('en', NULL, 'US', TRUE, 'English');
```

## Создание представления

Процедура `create_i18n_view` создаст представление, где на каждый языковой тег будет
предоставлен перевод, если он есть в таблице переводов, в противном случае значение по умолчанию.
Данные в представлении можно обновлять.

Важное условие: в таблице переводов колонка, указывающая на внешний ключ к основной таблице,
имела такое же имя, как колока указанная, как `PRIMARY KEY` в основной таблице.

```postgresql
-- основная таблица
CREATE TABLE public."words"
(
    "id"       SERIAL PRIMARY KEY,
    "title"    VARCHAR(255) NOT NULL, -- значение по умолчанию
    "original" VARCHAR(255)
) INHERITS (public."untrans");
-- таблица переводов
CREATE TABLE public."word_trans"
(
    "id"    INTEGER NOT NULL REFERENCES public."words" ("id") ON UPDATE CASCADE,
    PRIMARY KEY ("id", "lang"),
    "title" VARCHAR(255), -- перевод "title" на язык "lang"
    "slang" VARCHAR(255)
) INHERITS (public."trans");
-- создание представления
CALL create_i18n_view('public.words'::REGCLASS, 'public.word_trans'::REGCLASS);
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
