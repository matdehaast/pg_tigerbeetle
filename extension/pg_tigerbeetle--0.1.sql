\echo Use "CREATE EXTENSION pg_tigerbeetle" to load this file. \quit
CREATE FUNCTION hello() RETURNS TEXT
AS '$libdir/pg_tigerbeetle'
LANGUAGE C IMMUTABLE
