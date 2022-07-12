CREATE TABLE "dictionary"
(
    "id"        SERIAL PRIMARY KEY,
    "title"     VARCHAR(255) NOT NULL,
    "is_active" BOOLEAN DEFAULT TRUE
);
CREATE TABLE "dictionary_trans"
(
    "id"    INTEGER REFERENCES "dictionary" ("id") ON UPDATE CASCADE, -- TODO может запрутить редактировать?
    "title" VARCHAR(255),
    PRIMARY KEY ("lang", "id")
) INHERITS ("lang_base_tran");
CALL create_dictionary_view(NULL::TEXT, 'dictionary'::REGCLASS, NULL::REGCLASS);


SELECT *
FROM "v_dictionary";
