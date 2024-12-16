create function v_words__insert() returns trigger
    security definer
    language plpgsql
as
$$
    /*pg_i18n:insert-trigger*/
DECLARE
    "base_new" RECORD;
    "tran_new" RECORD;
BEGIN
    IF NEW.id IS NULL THEN
        INSERT INTO words (id, title, default_lang, original)
        VALUES (DEFAULT, NEW.title, NEW.default_lang, NEW.original)
        RETURNING * INTO "base_new";
    ELSE
        INSERT INTO words (id, title, default_lang, original)
        VALUES (NEW.id, NEW.title, NEW.default_lang, NEW.original)
        RETURNING * INTO "base_new";
    END IF;
    IF NEW.lang IS NULL THEN
        INSERT INTO word_trans (lang, id, title, slang)
        VALUES (DEFAULT, NEW.id, NEW.title, NEW.slang)
        RETURNING * INTO "tran_new";
    ELSE
        INSERT INTO word_trans (id, lang, title, slang)
        VALUES (NEW.id, NEW.lang, NEW.title, NEW.slang)
        RETURNING * INTO "tran_new";
    END IF;

    NEW = jsonb_populate_record(NEW, to_jsonb("base_new"));
    NEW = jsonb_populate_record(NEW, to_jsonb("tran_new"));

    RETURN NEW;
END
$$;



create function v_words__update() returns trigger
    security definer
    language plpgsql
as
$$
    /*pg_i18n:update-trigger*/
DECLARE
    "base_new" RECORD;
    "tran_new" RECORD;
BEGIN
    UPDATE words
    SET (id, default_lang, original) = ROW (NEW.id,NEW.default_lang,NEW.original)
    WHERE (id) = (OLD.id)
    RETURNING * INTO "base_new";

    IF OLD.is_tran THEN
        UPDATE word_trans
        SET (id, lang, title, slang) = ROW (NEW.id,NEW.lang,NEW.title,NEW.slang)
        WHERE (id, lang) = (OLD.id, OLD.lang)
        RETURNING * INTO "tran_new";
    ELSE
        INSERT INTO word_trans (id, lang, title, slang)
        VALUES (NEW.id, NEW.lang, NEW.title, NEW.slang)
        RETURNING * INTO "tran_new";
    END IF;

    NEW = jsonb_populate_record(NEW, to_jsonb("base_new"));
    NEW = jsonb_populate_record(NEW, to_jsonb("tran_new"));

    RETURN NEW;
END
$$;

