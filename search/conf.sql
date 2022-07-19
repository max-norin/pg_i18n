CREATE TEXT SEARCH CONFIGURATION public."ru" (
    COPY = pg_catalog.russian
);

CREATE TEXT SEARCH CONFIGURATION public. "en-US" (
    COPY = pg_catalog.english
);

SELECT to_tsvector('"ru"', 'кот') @@ to_tsquery('"ru"', 'кота');

SELECT to_tsvector('"en-US"', 'cats') @@ to_tsquery('"en-US"', 'cat');

