-- лучший вариант
-- Так как нельзя использовать `NEW` в предложении `ON CONFLICT ON CONSTRAINT "sexes_pkey" DO UPDATE`, то
-- приходится делать сначала обновление данных `UPDATE dictionaries.sexes`,
-- потом делать `INSERT INTO ... ON CONFLICT`.
-- Такая последовательность (UPDATE, INSERT) сделана специально.
-- Так как в обратной последовательности после создания запись будет сразу же обновлена,
-- а в выбранной последовательности будет выполнена одна из операций обновление или вставка.
-- `RETURNING` должен быть один, поэтому он присутствует в последнем запросе.
-- Изначально хотел сделать возврат данных из представления `SELECT * FROM dictionaries.i18n_sexes`,
-- но значения `INSERT` последнего запроса не отображаются в этих данных. Пример такого запроса ниже.
-- `(SELECT (u.*)::dictionaries.i18n_sexes FROM dictionaries.i18n_sexes u WHERE u.sex = t.sex AND u.lang = t.lang).*`
-- Поэтому я использую слияние двух записей `to_jsonb(u.*) || to_jsonb(t.*)`.
-- Так же думал, что можно сделать вставку в псевдо таблицу
-- и в `RETURNING` сделать `SELECT` запрос к представлению `dictionaries.sexes`,
-- Однако нельзя вставлять в под запросы `NEW`.
-- Возможно в будущем будут работать варианты написанные ниже в разделе "не работающие".
CREATE OR REPLACE RULE "insert" AS ON INSERT
    TO dictionaries.i18n_sexes
    DO INSTEAD
    (
    UPDATE dictionaries.sexes
    SET (default_lang) = ROW (NEW.default_lang)
    WHERE (sex) = (NEW.sex);
--
    INSERT INTO dictionaries.sexes AS u (sex, default_lang)
    VALUES (NEW.sex, NEW.default_lang)
    ON CONFLICT ON CONSTRAINT "sexes_pkey" DO NOTHING;
--
    INSERT INTO dictionaries.sex_trans AS t (sex, lang, created_at, updated_at, title)
    VALUES (NEW.sex, NEW.lang, DEFAULT, DEFAULT, NEW.title)
    RETURNING (SELECT (jsonb_populate_record(null::dictionaries.i18n_sexes, to_jsonb(u.*) || to_jsonb(t.*)))
               FROM dictionaries.sexes u
               WHERE u.sex = t.sex).*
    );


-- далее неработающие варианты

-- по документации должен быть один RETURNING + нельзя использовать new в под запросах
INSERT
INTO dictionaries.sexes AS u (sex, default_lang)
VALUES (NEW.sex, NEW.default_lang)
ON CONFLICT
    ON CONSTRAINT "sexes_pkey"
    DO NOTHING
RETURNING *;
INSERT INTO dictionaries.sex_trans AS t (sex, lang, created_at, updated_at, title)
VALUES (NEW.sex, NEW.lang, DEFAULT, DEFAULT, NEW.title)
RETURNING u.*, t.*;

-- нельзя использовать NEW в запросе WITH
WITH u AS (INSERT INTO dictionaries.sexes (sex, default_lang)
    VALUES (NEW.sex, NEW.default_lang)
    RETURNING *),
     t AS (INSERT INTO dictionaries.sex_trans (sex, lang, created_at, updated_at, title)
         VALUES (NEW.sex, NEW.lang, NEW.created_at, NEW.updated_at, NEW.title)
         RETURNING *)
SELECT TRUE                              AS is_tran,
       (u.default_lang = t.lang) IS TRUE AS is_default_lang,
       t.lang,
       u.sex,
       u.default_lang,
       t.created_at,
       t.updated_at,
       t.title
FROM u,
     t;

