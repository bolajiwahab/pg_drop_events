/* setup */
\unset ECHO
\set QUIET 1
/* Turn off echo and keep things quiet. */

/* Format the output. */
\pset format unaligned
\pset tuples_only true
\pset pager off

/* Revert all changes on failure. */
\set ON_ERROR_ROLLBACK true
\set ON_ERROR_STOP true

--\set ECHO all

BEGIN;

--- suppress notice messages
SET client_min_messages TO warning;

CREATE EXTENSION pg_drop_events;

--- pgtap function
\i test/pgtap.sql

CREATE SCHEMA tf;

CREATE TABLE tf.t();

CREATE MATERIALIZED VIEW tf.t_view AS SELECT * FROM tf.t;

CREATE TABLE tf.ta(a int);

CREATE TABLE tf.tb(b int);

CREATE TABLE tf.tc(c int);

--- table inheritance also cover declarative partitioning
CREATE TABLE tf.inheritance (
    city_id         int not null,
    logdate         date not null,
    peaktemp        int,
    unitsales       int
);
CREATE TABLE inheritance_y2006m02() INHERITS (tf.inheritance);
CREATE TABLE inheritance_y2006m03() INHERITS (tf.inheritance);

DROP MATERIALIZED VIEW tf.t_view;

DROP TABLE tf.t;

ALTER TABLE tf.ta DROP COLUMN a;

DROP TABLE tf.inheritance CASCADE;

DROP SCHEMA tf CASCADE;

SELECT plan(1);

SELECT is(count(*), 9::bigint, 'Record of transaction ids of dropped tables, materialized view, column is correct'::text)
FROM public.pg_drop_events;

SELECT * FROM finish();

ROLLBACK;
