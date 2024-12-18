# pg_i18n

100% works on PostgreSQL version 16, I didn't check the rest.
If you have any information that works on earlier versions, please let me know.

> The extension allows you to easily create multilingual databases.

[README in Russian](./README.ru.md)

# Install

Download the files from [dist](./dist) to your `extension` folder PostgreSQL and run the following
commands.

Create a new schema for convenience.

```postgresql
CREATE SCHEMA "dictionaries";
ALTER ROLE "postgres" SET search_path TO "public", "dictionaries";
```

Install the extension.

```postgresql
CREATE EXTENSION "pg_i18n"
    SCHEMA "dictionaries"
    VERSION '2.0';
```

[More about the extension and the control file](https://www.postgresql.org/docs/current/extend-extensions.html)

# Usage

The extension creates `"langs"` table that stores the language tags used. You need to populate the
table with data. For example:

```postgresql
INSERT INTO "dictionaries"."langs"("language", "script", "region", "is_active", "title")
VALUES ('ru', NULL, NULL, TRUE, 'Русский'),
       ('udm', NULL, NULL, TRUE, 'Удмурт'),
       ('it', NULL, NULL, TRUE, 'Удмурт'),
       ('en', NULL, 'US', TRUE, 'English');

```

There are two ways to implement multilingual tables.

## Create view

The `create_i18n_view` procedure will create a view in which, in each language tag will be
provided with a translation if it is in the translation table, else a default value.
Data in views can update.

Important condition: in the translation table, the column pointing to the foreign key to the main table
had the same name as the column specified as `PRIMARY KEY` in the main table.

```postgresql
-- main table
CREATE TABLE public."words"
(
    "id"       SERIAL PRIMARY KEY,
    "title"    VARCHAR(255) NOT NULL, -- default value
    "original" VARCHAR(255)
) INHERITS (public."untrans");
-- translation table
CREATE TABLE public."word_trans"
(
    "id"    INTEGER NOT NULL REFERENCES public."words" ("id") ON UPDATE CASCADE,
    PRIMARY KEY ("id", "lang"),
    "title" VARCHAR(255), -- translation of "title" into language "lang"
    "slang" VARCHAR(255)
) INHERITS (public."trans");
-- создание представления
CALL create_i18n_view('public.words'::REGCLASS, 'public.word_trans'::REGCLASS);
```

## Domains

The extension has domains used to define the `"langs"` table.

- [lang](./domains/lang.sql) (language tag) / `RFC 5646`
- [language](./domains/language.sql) / `ISO 639`
- [region](./domains/region.sql) / `ISO 3166-1`
- [script](./domains/script.sql) / `ISO 15924`

## Database architecture

The architecture is built according to high normalization. There is a language table referenced by
the translation tables. The table with translations contains only translatable information,
non-translatable information (for example, e-mail) is stored in a separate table that is referenced.
Simple example:

```postgresql
-- language table
CREATE TABLE "languages"
(
    "id"    SERIAL PRIMARY KEY,
    "code"  VARCHAR(11) NOT NULL UNIQUE,
    "title" VARCHAR(50) NOT NULL UNIQUE
);
-- main table
CREATE TABLE "user"
(
    "id"       SERIAL PRIMARY KEY,
    "email"    VARCHAR(255) NOT NULL UNIQUE,
    "nickname" VARCHAR(100) NOT NULL UNIQUE
);
-- translation table
CREATE TABLE "user_trans"
(
    "id"    INT         NOT NULL REFERENCES "user" ("id") ON UPDATE CASCADE,
    "lang"  VARCHAR(11) NOT NULL REFERENCES "languages" ("code") ON UPDATE CASCADE,
    "title" VARCHAR(255),
    PRIMARY KEY ("id", "lang")
);
```

As a language table, the extension has a `"langs"` (language tag) table based on `RFC 5646`.

The translation table has a specific
definition `"lang" LANG NOT NULL REFERENCES "langs" ("lang") ON UPDATE CASCADE`.
In order not to copy this definition for each new table, we will use inheritance.
This will help avoid errors and give you flexibility (if you need to add a new column or a new
constraint to all inherited tables).
The only problem with inheritance is that foreign keys are not copied to the child table.
Therefore, the `add_constraints_from_lang_parent_tables` event trigger was created in the extension,
which adds foreign keys and other constraints from
the inherited tables `"lang_base"` `"lang_base_tran"`.

`"lang_base"` table has `"default_lang"` column.

`"lang_base_tran"` table has `"lang"` column.

If desired, the trigger can be disabled or removed from the extension.

```postgresql
ALTER EVENT TRIGGER add_constraints_from_lang_parent_tables DISABLE;
-- https://postgresql.org/docs/current/sql-altereventtrigger.html 
ALTER EXTENSION pg_i18n DROP EVENT TRIGGER add_constraints_from_lang_parent_tables;
-- https://postgresql.org/docs/current/sql-alterextension.html
```

You can create views to make it easier to select data. To do this, the extension has two procedures,
they were mentioned in the Usage section: `create_dictionary_view` and `create_user_view`.

Procedure parameters:

- The first parameter is the name of the future view, you can not specify it.
- The second parameter is a table with main data.
- The third parameter is a table with translated data.

In procedures, a view is created and triggers are assigned.
In `create_dictionary_view` trigger on update
in `create_user_view` trigger on insert and update.

## Using the language index

The translation table not has a language column as in `postgresql`.
Therefore, you cannot create a language index as shown below, as this would be incorrect.

```postgresql
CREATE INDEX user_trans_title_idx ON "user_trans" USING GIN (to_tsvector("lang", "title"));
```

There is a workaround make copies of the preconfigured configurations for the language tag you are
using.
After that, there will be a correct use of the index specified above.

```postgresql
CREATE TEXT SEARCH CONFIGURATION public."ru" ( COPY = pg_catalog.russian );
CREATE TEXT SEARCH CONFIGURATION public."en-US" ( COPY = pg_catalog.english );
```
