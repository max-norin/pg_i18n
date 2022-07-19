SELECT '{
    "a": "A",
    "b": "B",
    "c": "C"
}'::JSONB -> ARRAY ['c','c','a'];

SELECT '{
    "a": "A",
    "b": "B",
    "c": "C"
}'::JSONB -> NULL::TEXT[];

SELECT NULL::JSONB -> ARRAY['c', 'c', 'a'];

