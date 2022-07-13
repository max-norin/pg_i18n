CREATE TABLE "user"
(
    "id"       SERIAL PRIMARY KEY,
    "nickname" VARCHAR(100) NOT NULL UNIQUE
) INHERITS ("lang_base");
CREATE TABLE "user_trans"
(
    "id"    BIGINT NOT NULL REFERENCES "user" ("id") ON UPDATE CASCADE,
    "title" VARCHAR(255),
    PRIMARY KEY ("id", "lang")
) INHERITS ("lang_base_tran");
CALL create_user_view(NULL::TEXT, '"user"'::REGCLASS, 'user_trans'::REGCLASS);

SELECT *
FROM "v_user";
