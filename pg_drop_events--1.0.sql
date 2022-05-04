/* pg_drop_events/pg_drop_events--1.0.sql */

-- complain if script is sourced in psql, rather than via create extension
\echo Use "CREATE EXTENSION pg_drop_events VERSION '1.0'" to load this file. \quit
DO $$
DECLARE pg_version int;
BEGIN
    pg_version := pg_catalog.current_setting('server_version_num')::int;

    IF pg_version < 130000 THEN
        CREATE TABLE public.pg_drop_events (
            pid             int,
            username        text,
            query           text,
            xact_id         bigint,
            wal_position    pg_lsn,
            objid           oid,
            object_name     text,
            object_type     text,
            time            timestamp with time zone
        );
    ELSE
        CREATE TABLE public.pg_drop_events (
            pid             int,
            username        text,
            query           text,
            xact_id         xid8,
            wal_position    pg_lsn,
            objid           oid,
            object_name     text,
            object_type     text,
            time            timestamp with time zone
    );
    END IF;

    IF pg_version < 100000 THEN
        CREATE OR REPLACE FUNCTION public.pg_drop_events()
          RETURNS event_trigger AS $LD$
        DECLARE
            tbd record;
        BEGIN
            FOR tbd IN
                SELECT
                    o.objid,
                    o.object_type,
                    o.object_identity
                FROM pg_catalog.pg_event_trigger_dropped_objects() o
                JOIN pg_catalog.pg_class c ON c.oid = o.classid
                JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE NOT o.is_temporary
                AND c.relname = 'pg_class'
                AND n.nspname = 'pg_catalog'
                AND o.classid = c.oid
                AND o.object_type = ANY ('{table, table column, materialized view}')
            LOOP
                RAISE NOTICE '% % dropped by transaction %.', tbd.object_type, tbd.object_identity, pg_catalog.txid_current();

                INSERT INTO public.pg_drop_events (
                    pid,
                    username,
                    query,
                    xact_id,
                    wal_position,
                    objid,
                    object_name,
                    object_type,
                    time
                )
                SELECT
                    pg_catalog.pg_backend_pid(),
                    pg_catalog.session_user(),
                    trim(trailing ';' from pg_catalog.current_query()),
                    pg_catalog.txid_current(),
                    pg_catalog.pg_current_xlog_location(),
                    tbd.objid,
                    tbd.object_identity,
                    tbd.object_type,
                    pg_catalog.now();
            END LOOP;
        END;
        $LD$ LANGUAGE plpgsql;
    ELSIF pg_version >= 130000 THEN
        CREATE OR REPLACE FUNCTION public.pg_drop_events()
          RETURNS event_trigger AS $LD$
        DECLARE
            tbd record;
        BEGIN
            FOR tbd IN
                SELECT
                    o.objid,
                    o.object_type,
                    o.object_identity
                FROM pg_catalog.pg_event_trigger_dropped_objects() o
                JOIN pg_catalog.pg_class c ON c.oid = o.classid
                JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE NOT o.is_temporary
                AND c.relname = 'pg_class'
                AND n.nspname = 'pg_catalog'
                AND o.classid = c.oid
                AND o.object_type = ANY ('{table, table column, materialized view}')
            LOOP
                RAISE NOTICE '% % dropped by transaction %.', tbd.object_type, tbd.object_identity, pg_catalog.pg_current_xact_id();

                INSERT INTO public.pg_drop_events (
                    pid,
                    username,
                    query,
                    xact_id,
                    wal_position,
                    objid,
                    object_name,
                    object_type,
                    time
                )
                SELECT
                    pg_catalog.pg_backend_pid(),
                    pg_catalog.session_user(),
                    trim(trailing ';' from pg_catalog.current_query()),
                    pg_catalog.pg_current_xact_id(),
                    pg_catalog.pg_current_wal_lsn(),
                    tbd.objid,
                    tbd.object_identity,
                    tbd.object_type,
                    pg_catalog.now();
            END LOOP;
        END;
        $LD$ LANGUAGE plpgsql;
    ELSE
        CREATE OR REPLACE FUNCTION public.pg_drop_events()
          RETURNS event_trigger AS $LD$
        DECLARE
            tbd record;
        BEGIN
            FOR tbd IN
                SELECT
                    o.objid,
                    o.object_type,
                    o.object_identity
                FROM pg_event_trigger_dropped_objects() o
                JOIN pg_catalog.pg_class c ON c.oid = o.classid
                JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE NOT o.is_temporary
                AND c.relname = 'pg_class'
                AND n.nspname = 'pg_catalog'
                AND o.classid = c.oid
                AND o.object_type = ANY ('{table, table column, materialized view}')
            LOOP
                RAISE NOTICE '% % dropped by transaction %.', tbd.object_type, tbd.object_identity, pg_catalog.txid_current();

                INSERT INTO public.pg_drop_events (
                    pid,
                    username,
                    query,
                    xact_id,
                    wal_position,
                    objid,
                    object_name,
                    object_type,
                    time
                )
                SELECT
                    pg_catalog.pg_backend_pid(),
                    pg_catalog.session_user(),
                    trim(trailing ';' from pg_catalog.current_query()),
                    pg_catalog.txid_current(),
                    pg_catalog.pg_current_wal_lsn(),
                    tbd.objid,
                    tbd.object_identity,
                    tbd.object_type,
                    pg_catalog.now();
            END LOOP;
        END;
        $LD$ LANGUAGE plpgsql;
    END IF;

    COMMENT ON FUNCTION public.pg_drop_events() IS 'logs transaction ids of drop table, drop column, drop materialized view statements to aid point in time recovery.';

    CREATE OR REPLACE FUNCTION public.pg_drop_events_reset()
      RETURNS void AS $ST$
        TRUNCATE public.pg_drop_events;
    $ST$ LANGUAGE sql;

    COMMENT ON FUNCTION public.pg_drop_events_reset() IS 'reset all logged transaction ids of drop table, drop column, drop materialized view statements.';

    CREATE OR REPLACE FUNCTION public.pg_drop_events_reset_single(poid oid)
      RETURNS void AS $ST$
        DELETE FROM public.pg_drop_events
        WHERE objid = poid;
    $ST$ LANGUAGE sql;

    COMMENT ON FUNCTION public.pg_drop_events_reset_single(oid) IS 'reset logged transaction id of a particular object.';

    --- Privileges management
    REVOKE ALL ON TABLE public.pg_drop_events FROM PUBLIC;
    REVOKE ALL ON FUNCTION public.pg_drop_events_reset() FROM PUBLIC;
    REVOKE ALL ON FUNCTION public.pg_drop_events_reset_single(oid) FROM PUBLIC;
    GRANT SELECT, INSERT ON TABLE public.pg_drop_events TO PUBLIC;
    GRANT EXECUTE ON FUNCTION public.pg_drop_events_reset() TO postgres;
    GRANT EXECUTE ON FUNCTION public.pg_drop_events_reset_single(oid) TO postgres;

  END;
$$;

DROP EVENT TRIGGER IF EXISTS ZZZ_pg_drop_events;

CREATE EVENT TRIGGER ZZZ_pg_drop_events ON sql_drop
    EXECUTE PROCEDURE public.pg_drop_events();
