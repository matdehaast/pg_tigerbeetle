\echo Use "CREATE EXTENSION pg_tigerbeetle" to load this file. \quit
CREATE FUNCTION lookup_account() RETURNS TEXT
AS '$libdir/pg_tigerbeetle'
LANGUAGE C IMMUTABLE;

CREATE FUNCTION query_by_id(int4) RETURNS TEXT
AS '$libdir/pg_tigerbeetle' LANGUAGE C VOLATILE;