CREATE TABLE public."products"
(
    "code"  VARCHAR(11),
    "year"  DATE,
    PRIMARY KEY ("code", "year"),
    "title" VARCHAR(255) NOT NULL, -- default value
    "price" DECIMAL(10, 2)
) INHERITS (public."untrans");
CREATE TABLE public."product_trans"
(
    "code"        VARCHAR(11) NOT NULL,
    "year"        DATE        NOT NULL,
    FOREIGN KEY ("code", "year") REFERENCES public."products" ("code", "year") ON UPDATE CASCADE,
    PRIMARY KEY ("code", "year", "lang"),
    "title"       VARCHAR(255), -- translation of "title" into language "lang"
    "description" TEXT
) INHERITS (public."trans");
