# pg_i18n

> The extension allows you to easily create multilingual databases.

[README in Russian](./README.ru.md)

## Getting Started

### Install

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
    VERSION '1.0';
```

### Usage

The extension creates `"langs"` table that stores the language tags used. You need to populate the
table with data. For example:

```postgresql
INSERT INTO "dictionaries"."langs"("language", "script", "region", "is_active", "title")
VALUES ('ru', NULL, NULL, TRUE, 'Русский'),
       ('udm', NULL, NULL, TRUE, 'Удмурт'),
       ('en', NULL, 'US', TRUE, 'English');

```

There are two ways to implement multilingual tables.

#### 1. Dictionary way

> _Dictionary way_ translation will be provided for each language tag. If the translation is not in
> the translation table, then the default value from the main table will be presented.

The `create_dictionary_view` procedure will create a view in which, in each language tag will be
provided with a translation if it is in the translation table, else a default value.
Data in views can update.

```postgresql
-- main table
CREATE TABLE "dictionary"
(
    "id"        SERIAL PRIMARY KEY,
    "title"     VARCHAR(255) NOT NULL, -- default value
    "is_active" BOOLEAN DEFAULT TRUE
);
-- translation table. note: it inherits from "lang_base_tran"
CREATE TABLE "dictionary_trans"
(
    "id"    INTEGER NOT NULL REFERENCES "dictionary" ("id") ON UPDATE CASCADE,
    "title" VARCHAR(255), -- translation of "title" into language "lang"
    PRIMARY KEY ("lang", "id")
) INHERITS ("lang_base_tran");
-- create view
CALL create_dictionary_view('v_dictionary'::TEXT, 'dictionary'::REGCLASS, 'dictionary_trans'::REGCLASS);
```

#### 2. User way

> _User way_ only translated data is returned.

The `create_user_view` procedure will create a view in which results are returned only if there is a
translation.
Data in views can insert and update.

```postgresql
-- main table. note: it inherits from "lang_base"
CREATE TABLE "user"
(
    "id"       SERIAL PRIMARY KEY,
    "nickname" VARCHAR(100) NOT NULL UNIQUE
    -- missing "title"
) INHERITS ("lang_base");
-- translation table. note: it inherits from "lang_base_tran"
CREATE TABLE "user_trans"
(
    "id"    BIGINT NOT NULL REFERENCES "user" ("id") ON UPDATE CASCADE,
    "title" VARCHAR(255),
    PRIMARY KEY ("id", "lang")
) INHERITS ("lang_base_tran");
-- create view
CALL create_user_view('v_user'::TEXT, '"user"'::REGCLASS, 'user_trans'::REGCLASS);
```

#### User columns

For the create_dictionary_view() function, you can specify user set of columns, different from the standard set.
This is done using the third parameter, you need to specify an array of column values.

```postgresql
CALL create_user_view(
        'v_users'::TEXT,
        'users'::REGCLASS,
        'user_trans'::REGCLASS,
        ARRAY ['id', 'b.nickname', 'bt.title']::TEXT[]
  );
-- OR using get_columns() function
CALL create_user_view(
        'v_users'::TEXT,
        'users'::REGCLASS,
        'user_trans'::REGCLASS,
        get_columns('users'::REGCLASS, TRUE, 'b') ||
        (get_columns('user_trans'::REGCLASS) - ARRAY ['id', 'created_at', 'updated_at']::TEXT[])
    );
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

## Recommended use

When using a _User way_ to create a table, a situation may arise when there is basic
information, but there is no translated information. This is not proper storage.
Therefore, I suggest using two roles: administrator and user.
The user will be allowed to insert data through the view, but not directly into the main table.

To implement this approach, trigger functions run on behalf of the function creator.
This poses a data security risk,
to prevent anyone else from using these features, we will block access to them.

```postgresql
-- prevents everyone from executing the current functions in SCHEMA "dictionaries" 
REVOKE ALL ON ALL ROUTINES IN SCHEMA "dictionaries" FROM PUBLIC;
-- prevents everyone from executing future defined functions in SCHEMA "dictionaries" 
ALTER DEFAULT PRIVILEGES IN SCHEMA "dictionaries" REVOKE ALL ON ROUTINES FROM PUBLIC;
```

```postgresql
-- fill in the table with language tags
INSERT INTO "langs"("language", "script", "region", "is_active", "title")
VALUES ('ru', NULL, NULL, TRUE, 'Русский'),
       ('udm', NULL, NULL, TRUE, 'Удмурт'),
       ('en', NULL, 'US', TRUE, 'English');
-- user table with basic information
CREATE TABLE "user"
(
    "id"       SERIAL PRIMARY KEY,
    "nickname" VARCHAR(100) NOT NULL UNIQUE
) INHERITS ("lang_base");
-- table of users with translated information
CREATE TABLE "user_trans"
(
    "id"    BIGINT NOT NULL REFERENCES "user" ("id") ON UPDATE CASCADE,
    "title" VARCHAR(255),
    PRIMARY KEY ("id", "lang")
) INHERITS ("lang_base_tran");
-- a view with a join of the above two tables
CALL create_user_view(NULL::TEXT, '"user"'::REGCLASS, '"user_trans"'::REGCLASS);
```

```postgresql
CREATE ROLE "test_i18n" LOGIN;
GRANT CONNECT ON DATABASE "postgres" TO "test_i18n";
GRANT USAGE ON SCHEMA "dictionaries" TO "test_i18n";
-- define the necessary safe functions, they are needed to fire the INSTEAD OF triggers, 
-- because they convert the input types (for OLD and NEW) to the desired type
GRANT ALL ON FUNCTION dictionaries.language(TEXT) TO "test_i18n";
GRANT ALL ON FUNCTION dictionaries.script(TEXT) TO "test_i18n";
GRANT ALL ON FUNCTION dictionaries.region(TEXT) TO "test_i18n";
GRANT ALL ON FUNCTION dictionaries.lang(TEXT) TO "test_i18n";
--
ALTER ROLE "test_i18n" SET search_path TO "public", "dictionaries";
-- give access rights to the user
-- the key point is the impossibility of inserting into the "user"
-- insertion into the view is possible only thanks 
-- to the SECURITY DEFINER in the definition of trigger functions
GRANT SELECT ON TABLE "langs" TO "test_i18n";
GRANT INSERT, UPDATE, SELECT ON TABLE "v_user" TO "test_i18n";
GRANT UPDATE, SELECT ON TABLE "user" TO "test_i18n";
GRANT INSERT, UPDATE, SELECT ON TABLE "user_trans" TO "test_i18n";
```

Change current user to new user or connect to database using new user.

```postgresql
SET ROLE "text_i18n";
```

Function availability check.

```postgresql
SELECT dictionaries.get_primary_key('dictionaries.langs'::REGCLASS);
```

Let's try to insert `"user"` into the table get error.

```postgresql
INSERT INTO "user"
    (id, default_lang, nickname)
VALUES (DEFAULT, 'ru', 'max');    
```

Let's try to insert `"v_user"` into the view get success.

```postgresql
INSERT INTO "v_user"
    (id, default_lang, nickname, lang, title)
VALUES (DEFAULT, 'ru', 'max', 'ru', 'Макс');
```

## Files

- `helpers/*.sql` helper functions
    - [array_except](./helpers/array_except.sql)
    - [format_table_name](./helpers/format_table_name.sql)
    - [get_columns](./helpers/get_columns.sql)
    - [get_constraintdef](./helpers/get_constraintdef.sql)
    - [get_primary_key](./helpers/get_primary_key.sql)
    - [get_primary_key_name](./helpers/get_primary_key_name.sql)
    - [jsonb_object_fields](./helpers/jsonb_object_fields.sql)
- `rules/*.sql` rules for domains
    - [lang](./rules/lang.sql)
    - [language](./rules/language.sql)
    - [region](./rules/region.sql)
    - [script](./rules/script.sql)
- `domains/*.sql` used domains
    - [lang](./domains/lang.sql)
    - [language](./domains/language.sql)
    - [region](./domains/region.sql)
    - [script](./domains/script.sql)
- `tables/*.sql` definition `"langs"` table and parent tables (`"lang_base"` `"lang_base_tran"`)
- [event_triggers/add_constraints_from_lang_parent_tables.sql](./event_triggers/add_constraints_from_lang_parent_tables.sql)
  event trigger
- [init.sql](./init.sql) назначение событийного триггера
- `views/*.sql` procedures for create views
    - [dictinary](./views/dictinary.sql)
    - [user](./views/user.sql)
- `triggers/*.sql` triggers `INSTEAD OF` for view
    - [update_dictionary_view](./triggers/update_dictionary_view.sql)
    - [insert_user_view](./triggers/insert_user_view.sql)
    - [update_user_view](./triggers/update_user_view.sql)
- [test/*.sql](./test) test files
