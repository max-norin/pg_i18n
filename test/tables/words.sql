CREATE TABLE public."words"
(
    "id"       SERIAL PRIMARY KEY,
    "title"    VARCHAR(255) NOT NULL, -- default value
    "original" VARCHAR(255)
) INHERITS (public."untrans");
CREATE TABLE public."word_trans"
(
    "id"    INTEGER NOT NULL REFERENCES public."words" ("id") ON UPDATE CASCADE,
    PRIMARY KEY ("id", "lang"),
    "title" VARCHAR(255), -- translation of "title" into language "lang"
    "slang" VARCHAR(255)
) INHERITS (public."trans");
