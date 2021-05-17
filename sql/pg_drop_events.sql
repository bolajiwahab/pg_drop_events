CREATE EXTENSION pg_drop_events;

--- suppress notice messages

SET client_min_messages TO warning;

CREATE SCHEMA t;

CREATE TABLE t.t1(a int);

CREATE TABLE t.t2();

CREATE TABLE t.t3();

DROP TABLE t.t3;

ALTER TABLE t.t1 DROP COLUMN a;

DROP SCHEMA t CASCADE;

SELECT COUNT(*) = 4 FROM public.pg_drop_events;

DROP EXTENSION pg_drop_events;
