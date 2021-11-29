[![postgresql-14-build](https://github.com/bolajiwahab/pg_drop_events/actions/workflows/postgresql-14-build.yml/badge.svg)](https://github.com/bolajiwahab/pg_drop_events/actions/workflows/postgresql-14-build.yml)

# What is pg_drop_events?
The **pg_drop_events** is a PostgreSQL **extension** that logs transaction ids of drop table, drop column statements to aid point in time recovery: To perform point in time recovery in case of a disaster whereby a table or a table column was mistakenly dropped, you simply specify the `xact_id` you get from the table `pg_drop_events` as the `recovery_target_xid`. See below user guide.

### How pg_drop_events works?

`pg_drop_events` uses event trigger to track what statement, what transaction and which user drops a table or a table column.

## Documentation
1. [Supported PostgreSQL Versions](#supported-postgresql-versions)
2. [Installation](#installation)
3. [Setup](#setup)
4. [User Guide](#User-Guide)

## Supported PostgreSQL Versions
The ``pg_drop_events`` should work on the latest version of PostgreSQL but is only tested with these PostgreSQL versions:

| Distribution            |  Version       | Supported          |
| ------------------------|----------------|--------------------|
| PostgreSQL              | Version 9.5     | :heavy_check_mark: |
| PostgreSQL              | Version 9.6     | :heavy_check_mark: |
| PostgreSQL              | Version 10     | :heavy_check_mark: |
| PostgreSQL              | Version 11     | :heavy_check_mark: |
| PostgreSQL              | Version 12     | :heavy_check_mark: |
| PostgreSQL              | Version 13     | :heavy_check_mark: |
| PostgreSQL              | Version 14     | :heavy_check_mark: |

## Installation

### Installing from source code

You can download the source code of  ``pg_drop_events`` from [this GitHub page](github.com:bolajiwahab/pg_drop_events.git) or using git:
```sh
git clone git@github.com:bolajiwahab/pg_drop_events.git
```
Compile and install the extension. Depending on your distribution, you might need to add sudo.
```sh
cd pg_drop_events
make clean && make install
```
## Setup

Create the extension using the ``CREATE EXTENSION`` command.
```sql
CREATE EXTENSION pg_drop_events;
CREATE EXTENSION
```
## User-Guide

This document describes the configuration, key features and usage of ``pg_drop_events`` extension.

For how to install and set up ``pg_drop_events``, see [README](https://github.com/bolajiwahab/pg_drop_events/blob/master/README.md).

After you've installed, create the ``pg_drop_events`` extension using the ``CREATE EXTENSION`` command.

```sql
CREATE EXTENSION pg_drop_events;
CREATE EXTENSION
```

## Usage

### Example :
```sql
postgres=# CREATE SCHEMA t;
CREATE SCHEMA

postgres=# CREATE TABLE t.t1(a int);
CREATE TABLE

postgres=# CREATE TABLE t.t2();
CREATE TABLE

postgres=# CREATE TABLE t.t3();
CREATE TABLE

postgres=# DROP TABLE t.t3;
NOTICE:  table t.t3 dropped by transaction 1085.
DROP TABLE

postgres=# ALTER TABLE t.t1 DROP COLUMN a;
NOTICE:  table column t.t1.a dropped by transaction 1088.
ALTER TABLE

postgres=# DROP SCHEMA t CASCADE;
NOTICE:  drop cascades to 2 other objects
DETAIL:  drop cascades to table t.t2
drop cascades to table t.t1
NOTICE:  table t.t2 dropped by transaction 1089.
NOTICE:  table t.t1 dropped by transaction 1089.
DROP SCHEMA

postgres=# SELECT pid,username,query,xact_id,wal_position,object_name,object_type,xact_start FROM pg_drop_events;
  pid  | username |              query              | xact_id | wal_position | object_name | object_type  |          xact_start
-------+----------+---------------------------------+---------+--------------+-------------+--------------+-------------------------------
   729 | postgres | drop TABLE tab ;                |     884 | 2/7255F498   | public.tab  | table        | 2021-05-17 19:57:22.435495+08
 12540 | postgres | DROP TABLE t.t3;                |    1085 | 2/729E7920   | t.t3        | table        | 2021-05-17 20:49:21.727209+08
 12540 | postgres | ALTER TABLE t.t1 DROP COLUMN a; |    1088 | 2/729F7778   | t.t1.a      | table column | 2021-05-17 20:50:29.168078+08
 12540 | postgres | DROP SCHEMA t CASCADE;          |    1089 | 2/729F7988   | t.t2        | table        | 2021-05-17 20:51:10.929153+08
 12540 | postgres | DROP SCHEMA t CASCADE;          |    1089 | 2/729F7988   | t.t1        | table        | 2021-05-17 20:51:10.929153+08

````

## Point in time recovery (PITR)
To perform point in time recovery, you need access to `pg_drop_events` data.
We have this mapping of options and the respective PostgreSQL recovery options:
```
pg_drop_events.xact_id      => recovery_target_xid
pg_drop_events.time         => recovery_target_time
pg_drop_events.wal_position => recovery_target_lsn

```

For reference, see https://www.postgresql.org/docs/13/runtime-config-wal.html

Author
------
[Bolaji K. Wahab @bolajiwahab]

Copyright and License
---------------------
Copyright (c) 2021 Bolaji Wahab.

This module is free software; you can redistribute it and/or modify it under the [PostgreSQL License](http://www.opensource.org/licenses/postgresql).

Permission to use, copy, modify, and distribute this software and its documentation for any purpose, without fee, and without a written agreement is hereby granted, provided that the above copyright notice and this paragraph and the following two paragraphs appear in all copies.

In no event shall Bolaji K. Wahab be liable to any party for direct, indirect, special, incidental, or consequential damages, including lost profits, arising out of the use of this software and its documentation, even if Bolaji K. Wahab has been advised of the possibility of such damage.

Bolaji K. Wahab specifically disclaims any warranties, including, but not limited to, the implied warranties of merchantability and fitness for a particular purpose. The software provided hereunder is on an "as is" basis, and Bolaji K. Wahab has no obligations to provide maintenance, support, updates, enhancements, or modifications.
