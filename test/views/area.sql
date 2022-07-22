CREATE FUNCTION dictionaries.area_code ("value" TEXT)
    RETURNS BOOLEAN
AS $$
BEGIN
    RETURN ("value" ~* '^[a-z]{2,3}$');
END
$$
    LANGUAGE plpgsql
    IMMUTABLE
    RETURNS NULL ON NULL INPUT;

CREATE DOMAIN dictionaries.AREA_CODE AS VARCHAR(3)
    CHECK (dictionaries.area_code (VALUE));

CREATE FUNCTION dictionaries.area ("value" TEXT)
    RETURNS BOOLEAN
AS $$
DECLARE
    "arr"    CONSTANT TEXT[] = string_to_array("value", '-');
    "length" CONSTANT INT    = array_length("arr", 1);
    "code"            TEXT ;
BEGIN
    IF ("length" IS NULL OR "length" > 3) THEN
        RETURN FALSE;
    END IF;
    FOREACH "code" IN ARRAY "arr"
        LOOP
            IF NOT(dictionaries.area_code("code")) THEN
                RETURN FALSE;
            END IF;
        END LOOP;
    RETURN TRUE;
END
$$
    LANGUAGE plpgsql
    IMMUTABLE
    RETURNS NULL ON NULL INPUT;

CREATE DOMAIN dictionaries.AREA AS VARCHAR(19) -- 5*3+4=19
    CHECK (dictionaries.area (VALUE));



CREATE TABLE "areas"
(
    "area"              AREA GENERATED ALWAYS AS ( CASE WHEN ("parent_area" IS NOT NULL) THEN ("parent_area" || '-') ELSE '' END || "code" ) STORED PRIMARY KEY,
    "parent_area"       AREA,
    "parent_is_active"  BOOLEAN,
    "current_is_active" BOOLEAN      NOT NULL DEFAULT FALSE,
    "is_active"         BOOLEAN GENERATED ALWAYS AS ( COALESCE("parent_is_active", TRUE) AND "current_is_active" ) STORED,
    "code"              AREA_CODE    NOT NULL,
    "title"             VARCHAR(255) NOT NULL,
    UNIQUE ("area", "is_active"),
    FOREIGN KEY ("parent_area", "parent_is_active") REFERENCES areas ("area", "is_active") MATCH FULL ON UPDATE CASCADE,
    UNIQUE ("area", "title")
);

CREATE OR REPLACE FUNCTION dictionaries.trigger_areas__autocomplete() RETURNS TRIGGER AS
$$
BEGIN
    NEW."parent_is_active" = (SELECT "is_active" FROM "areas" WHERE NEW."parent_area" = "area");

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "autocomplete"
    BEFORE INSERT OR UPDATE
    ON areas
    FOR EACH ROW
EXECUTE FUNCTION dictionaries.trigger_areas__autocomplete();
COMMENT ON COLUMN areas.parent_is_active IS 'autocomplete';

CREATE TABLE area_trans
(
    "area"  AREA         NOT NULL REFERENCES areas ("area") ON UPDATE CASCADE,
    "title" VARCHAR(255) NOT NULL,
    PRIMARY KEY ("area", "lang")
) INHERITS (dictionaries.lang_base_tran);

CALL create_dictionary_view('v_areas'::TEXT, 'areas'::REGCLASS, 'area_trans'::REGCLASS);




INSERT INTO "areas" ("parent_area", "current_is_active", "code", "title")
VALUES (null, TRUE, 'rus', 'Russia'),
       ('rus', TRUE, 'udm', 'Udmurtia'),
       ('rus-udm', TRUE, 'izh', 'Izhevsk');

INSERT INTO "area_trans" ("area", "lang", "title")
VALUES ('rus', 'ru', 'Россия'),
       ('rus-udm', 'ru', 'Удмуртия'),
       ('rus-udm-izh', 'ru', 'Ижевск');
INSERT INTO "area_trans" ("area", "lang", "title")
VALUES ('rus', 'udm', 'Россия'),
       ('rus-udm', 'udm', 'Удмуртия'),
       ('rus-udm-izh', 'udm', 'Ижкар');

