# What is min_to_max?
The **min_to_max** is an **aggregate** that returns a text formatted like: `min_to_max` for any type, where `min` and `max` are minimum and maximum values of the list or column respectively.
It works on any type and it is successfully tested with text, date, timestamp, integer, numeric and float types. The output can be formatted by the user by calling **min_to_max_config** with default or a specified format. See below user guide.

### How min_to_max works?

`min_to_max` takes result set as an input, build an array of the set and then returns both minimum and maximum of the input set together as a single output.

## Documentation
1. [Supported PostgreSQL Versions](#supported-postgresql-versions)
2. [Installation](#installation)
3. [Setup](#setup) 
4. [User Guide](#User-Guide)

## Supported PostgreSQL Versions
The ``min_to_max`` should work on the latest version of PostgreSQL but is only tested with these PostgreSQL versions:

| Distribution            |  Version       | Supported          |
| ------------------------|----------------|--------------------|
| PostgreSQL              | Version < 11   | :x:                |
| PostgreSQL              | Version 11     | :heavy_check_mark: |
| PostgreSQL              | Version 12     | :heavy_check_mark: |
| PostgreSQL              | Version 13     | :heavy_check_mark: |
|

## Installation

### Installing from source code

You can download the source code of  ``min_to_max`` from [this GitHub page](https://github.com/bolajiwahab/min_to_max.git) or using git:
```sh
git clone git@github.com:bolajiwahab/min_to_max.git
```
Compile and install the extension
```sh
cd /min_to_max
sudo make 
sudo make install
```
## Setup

Create the extension using the ``CREATE EXTENSION`` command.
```sql
CREATE EXTENSION min_to_max;
CREATE EXTENSION
```
## User-Guide

This document describes the configuration, key features and usage of ``min_to_max`` extension.

For how to install and set up ``min_to_max``, see [README](https://github.com/bolajiwahab/min_to_max/blob/master/README.md).

After you've installed, create the ``min_to_max`` extension using the ``CREATE EXTENSION`` command.

```sql
CREATE EXTENSION min_to_max;
CREATE EXTENSION
```

## Usage

### Example 1: Find min and max from a values list comprising of integer values

```sql
postgres=# SELECT min_to_max(val) FROM (VALUES(5),(3),(6),(7),(9),(10),(7)) t(val);
 min_to_max 
------------
 3 -> 10
(1 row)

```

### Example 2: Find min and max from a values list comprising of string values
```sql
postgres=# SELECT min_to_max(val) FROM (VALUES('a'),('b'),('c'),('d'),('e'),('f'),('g')) t(val);
 min_to_max 
------------
 a -> g
(1 row)

```
### Example 3: Find min and max from a values list comprising of float values
```sql
postgres=# SELECT min_to_max(val) FROM (VALUES(5.1),(3.95),(6.666),(7.222),(9),(10.5),(7.4)) t(val);
  min_to_max  
--------------
 3.95 -> 10.5
```
### Example 4: Find min and max from a values list comprising of date values
```sql
postgres=# SELECT min_to_max(val) FROM (VALUES('2021-01-01'),('2021-01-02'),('2021-01-03'),('2021-01-04')) t(val);
        min_to_max        
--------------------------
 2021-01-01 -> 2021-01-04
(1 row)
```
### Example 5: Find min and max from a table comprising of integer, float, string, timestamp and date values
```sql
postgres=# CREATE TEMPORARY TABLE min_to_max AS SELECT generate_series(1,1000) AS a, generate_series(1.7,1000)::float AS b,generate_series(timestamp '2019-01-01', '2021-12-31', '1 day') AS c, generate_series(timestamp '2019-01-01', '2021-12-31', '1 day')::date as d,chr(generate_series(65,90)) AS e;
SELECT 1096

\d min_to_max
                       Table "public.min_to_max"
 Column |            Type             | Collation | Nullable | Default 
--------+-----------------------------+-----------+----------+---------
 a      | integer                     |           |          | 
 b      | double precision            |           |          | 
 c      | timestamp without time zone |           |          | 
 d      | date                        |           |          | 
 e      | text                        |           |          | 

postgres=# SELECT min_to_max(a),min_to_max(b),min_to_max(c),min_to_max(d),min_to_max(e) FROM min_to_max ;
 min_to_max |  min_to_max  |                 min_to_max                 |        min_to_max        | min_to_max 
------------+--------------+--------------------------------------------+--------------------------+------------
 1 -> 1000  | 1.7 -> 999.7 | 2019-01-01 00:00:00 -> 2021-12-31 00:00:00 | 2019-01-01 -> 2021-12-31 | A -> Z
(1 row)

```
### Example 6: Find min and max from a values list comprising nulls
```sql
postgres=# SELECT min_to_max(val) FROM (VALUES(NULL),(NULL)) t(val);
 min_to_max 
------------
 
(1 row)

```
### Example 7: Find min and max from a values list comprising of non-null and null values
```sql
postgres=# SELECT min_to_max(val) FROM (VALUES(1),(2),(NULL)) t(val);
 min_to_max 
------------
 1 -> 2
(1 row)

```
### Example 8: Find min and max from a values list comprising of non-empty and empty values
```sql
postgres=# SELECT min_to_max(val) FROM (VALUES('a'),('b'),(' ')) t(val);
 min_to_max 
------------
   -> b
(1 row)

```
### Configuring the output format
#### Set or reset output to default
```sql
postgres=# SELECT min_to_max_config();
 min_to_max_config 
-------------------
 
(1 row)
```
#### Set output to non-default
```sql
postgres=# SELECT min_to_max_config('>>');
postgres=# SELECT min_to_max(a),min_to_max(b),min_to_max(c),min_to_max(d),min_to_max(e) FROM min_to_max ;
min_to_max  |   min_to_max   |                  min_to_max                  |         min_to_max         | min_to_max 
-------------+----------------+----------------------------------------------+----------------------------+------------
 1 >> 1000 | 1.7 >> 999.7 | 2019-01-01 00:00:00 >> 2021-12-31 00:00:00 | 2019-01-01 >> 2021-12-31 | A >> Z
(1 row)
```
