CREATE OR REPLACE RULE "insert" AS ON INSERT
    TO dictionaries.i18n_sexes
    DO INSTEAD
    (
    -- untrans
    -- без обновления и INSERT ... ON CONFLICT
    INSERT INTO dictionaries.sexes AS u (sex, default_lang)
    VALUES (NEW.sex, NEW.default_lang);
    -- trans
    INSERT INTO dictionaries.sex_trans AS t (sex, lang, title)
    VALUES (NEW.sex, NEW.lang, NEW.title)
    RETURNING *;
    );

CREATE OR REPLACE RULE "update" AS ON UPDATE
    TO dictionaries.i18n_sexes
    DO INSTEAD
    (
    -- untrans
    UPDATE dictionaries.sexes
    SET (sex, default_lang) = ROW (NEW.sex, NEW.default_lang)
    WHERE (sex) = (OLD.sex);
    -- trans
    -- обновить если OLD.is_tran = TRUE, иначе вставить
    UPDATE dictionaries.sex_trans
    SET (sex, lang, title) = ROW (NEW.sex, NEW.lang, NEW.title)
    WHERE (sex, lang) = (OLD.sex, OLD.lang)
    RETURNING *;
    INSERT INTO dictionaries.sex_trans AS t (sex, lang, title)
    VALUES (NEW.sex, NEW.lang, NEW.title)
    RETURNING *;
    );
