CREATE OR REPLACE FUNCTION _add ( text, integer, text )
RETURNS integer AS $$
BEGIN
    EXECUTE 'INSERT INTO __tcache__ (label, value, note) values (' ||
    quote_literal($1) || ', ' || $2 || ', ' || quote_literal(COALESCE($3, '')) || ')';
    RETURN $2;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION _add ( text, integer )
RETURNS integer AS $$
    SELECT _add($1, $2, '')
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION _set ( text, integer, text )
RETURNS integer AS $$
DECLARE
    rcount integer;
BEGIN
    EXECUTE 'UPDATE __tcache__ SET value = ' || $2
        || CASE WHEN $3 IS NULL THEN '' ELSE ', note = ' || quote_literal($3) END
        || ' WHERE label = ' || quote_literal($1);
    GET DIAGNOSTICS rcount = ROW_COUNT;
    IF rcount = 0 THEN
       RETURN _add( $1, $2, $3 );
    END IF;
    RETURN $2;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION _set ( text, integer )
RETURNS integer AS $$
    SELECT _set($1, $2, '')
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION _set ( integer, integer )
RETURNS integer AS $$
BEGIN
    EXECUTE 'UPDATE __tcache__ SET value = ' || $2
        || ' WHERE id = ' || $1;
    RETURN $2;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION plan( integer )
RETURNS TEXT AS $$
DECLARE
    rcount INTEGER;
BEGIN
    BEGIN
        EXECUTE '
            CREATE TEMP SEQUENCE __tcache___id_seq;
            CREATE TEMP TABLE __tcache__ (
                id    INTEGER NOT NULL DEFAULT nextval(''__tcache___id_seq''),
                label TEXT    NOT NULL,
                value INTEGER NOT NULL,
                note  TEXT    NOT NULL DEFAULT ''''
            );
            CREATE UNIQUE INDEX __tcache___key ON __tcache__(id);
            GRANT ALL ON TABLE __tcache__ TO PUBLIC;
            GRANT ALL ON TABLE __tcache___id_seq TO PUBLIC;

            CREATE TEMP SEQUENCE __tresults___numb_seq;
            GRANT ALL ON TABLE __tresults___numb_seq TO PUBLIC;
        ';

    EXCEPTION WHEN duplicate_table THEN
        -- Raise an exception if there's already a plan.
        EXECUTE 'SELECT TRUE FROM __tcache__ WHERE label = ''plan''';
      GET DIAGNOSTICS rcount = ROW_COUNT;
        IF rcount > 0 THEN
           RAISE EXCEPTION 'You tried to plan twice!';
        END IF;
    END;

    -- Save the plan and return.
    PERFORM _set('plan', $1 );
    PERFORM _set('failed', 0 );
    RETURN '1..' || $1;
END;
$$ LANGUAGE plpgsql strict;

CREATE OR REPLACE FUNCTION add_result ( bool, bool, text, text, text )
RETURNS integer AS $$
BEGIN
    IF NOT $1 THEN PERFORM _set('failed', _get('failed') + 1); END IF;
    RETURN nextval('__tresults___numb_seq');
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION _get ( text )
RETURNS integer AS $$
DECLARE
    ret integer;
BEGIN
    EXECUTE 'SELECT value FROM __tcache__ WHERE label = ' || quote_literal($1) || ' LIMIT 1' INTO ret;
    RETURN ret;
END;
$$ LANGUAGE plpgsql strict;

CREATE OR REPLACE FUNCTION diag ( msg text )
RETURNS TEXT AS $$
    SELECT '# ' || replace(
       replace(
            replace( $1, E'\r\n', E'\n# ' ),
            E'\n',
            E'\n# '
        ),
        E'\r',
        E'\n# '
    );
$$ LANGUAGE sql strict;

CREATE OR REPLACE FUNCTION diag ( msg anyelement )
RETURNS TEXT AS $$
    SELECT diag($1::text);
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION diag( VARIADIC text[] )
RETURNS TEXT AS $$
    SELECT diag(array_to_string($1, ''));
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION diag( VARIADIC anyarray )
RETURNS TEXT AS $$
    SELECT diag(array_to_string($1, ''));
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION _get_latest ( text )
RETURNS integer[] AS $$
DECLARE
    ret integer[];
BEGIN
    EXECUTE 'SELECT ARRAY[id, value] FROM __tcache__ WHERE label = ' ||
    quote_literal($1) || ' AND id = (SELECT MAX(id) FROM __tcache__ WHERE label = ' ||
    quote_literal($1) || ') LIMIT 1' INTO ret;
    RETURN ret;
EXCEPTION WHEN undefined_table THEN
   RAISE EXCEPTION 'You tried to run a test without a plan! Gotta have a plan';
END;
$$ LANGUAGE plpgsql strict;

CREATE OR REPLACE FUNCTION _get_latest ( text, integer )
RETURNS integer AS $$
DECLARE
    ret integer;
BEGIN
    EXECUTE 'SELECT MAX(id) FROM __tcache__ WHERE label = ' ||
    quote_literal($1) || ' AND value = ' || $2 INTO ret;
    RETURN ret;
END;
$$ LANGUAGE plpgsql strict;

CREATE OR REPLACE FUNCTION _todo()
RETURNS TEXT AS $$
DECLARE
    todos INT[];
    note text;
BEGIN
    -- Get the latest id and value, because todo() might have been called
    -- again before the todos ran out for the first call to todo(). This
    -- allows them to nest.
    todos := _get_latest('todo');
    IF todos IS NULL THEN
        -- No todos.
        RETURN NULL;
    END IF;
    IF todos[2] = 0 THEN
        -- Todos depleted. Clean up.
        EXECUTE 'DELETE FROM __tcache__ WHERE id = ' || todos[1];
        RETURN NULL;
    END IF;
    -- Decrement the count of counted todos and return the reason.
    IF todos[2] <> -1 THEN
        PERFORM _set(todos[1], todos[2] - 1);
    END IF;
    note := _get_note(todos[1]);

    IF todos[2] = 1 THEN
        -- This was the last todo, so delete the record.
        EXECUTE 'DELETE FROM __tcache__ WHERE id = ' || todos[1];
    END IF;

    RETURN note;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ok ( boolean, text )
RETURNS TEXT AS $$
DECLARE
   aok      ALIAS FOR $1;
   descr    text := $2;
   test_num INTEGER;
   todo_why TEXT;
   ok       BOOL;
BEGIN
   todo_why := _todo();
   ok       := CASE
       WHEN aok = TRUE THEN aok
       WHEN todo_why IS NULL THEN COALESCE(aok, false)
       ELSE TRUE
    END;
    IF _get('plan') IS NULL THEN
        RAISE EXCEPTION 'You tried to run a test without a plan! Gotta have a plan';
    END IF;

    test_num := add_result(
        ok,
        COALESCE(aok, false),
        descr,
        CASE WHEN todo_why IS NULL THEN '' ELSE 'todo' END,
        COALESCE(todo_why, '')
    );

    RETURN (CASE aok WHEN TRUE THEN '' ELSE 'not ' END)
           || 'ok ' || _set( 'curr_test', test_num )
           || CASE descr WHEN '' THEN '' ELSE COALESCE( ' - ' || substr(diag( descr ), 3), '' ) END
           || COALESCE( ' ' || diag( 'TODO ' || todo_why ), '')
           || CASE aok WHEN TRUE THEN '' ELSE E'\n' ||
                diag('Failed ' ||
                CASE WHEN todo_why IS NULL THEN '' ELSE '(TODO) ' END ||
                'test ' || test_num ||
                CASE descr WHEN '' THEN '' ELSE COALESCE(': "' || descr || '"', '') END ) ||
                CASE WHEN aok IS NULL THEN E'\n' || diag('    (test result was NULL)') ELSE '' END
           END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ok ( boolean )
RETURNS TEXT AS $$
    SELECT ok( $1, NULL );
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION is (anyelement, anyelement, text)
RETURNS TEXT AS $$
DECLARE
    result BOOLEAN;
    output TEXT;
BEGIN
    -- Would prefer $1 IS NOT DISTINCT FROM, but that's not supported by 8.1.
    result := NOT $1 IS DISTINCT FROM $2;
    output := ok( result, $3 );
    RETURN output || CASE result WHEN TRUE THEN '' ELSE E'\n' || diag(
           '        have: ' || CASE WHEN $1 IS NULL THEN 'NULL' ELSE $1::text END ||
        E'\n        want: ' || CASE WHEN $2 IS NULL THEN 'NULL' ELSE $2::text END
    ) END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION num_failed ()
RETURNS INTEGER AS $$
    SELECT _get('failed');
$$ LANGUAGE SQL strict;

CREATE OR REPLACE FUNCTION _finish (INTEGER, INTEGER, INTEGER, BOOLEAN DEFAULT NULL)
RETURNS SETOF TEXT AS $$
DECLARE
    curr_test ALIAS FOR $1;
    exp_tests INTEGER := $2;
    num_faild ALIAS FOR $3;
    plural    CHAR;
    raise_ex  ALIAS FOR $4;
BEGIN
    plural    := CASE exp_tests WHEN 1 THEN '' ELSE 's' END;

    IF curr_test IS NULL THEN
        RAISE EXCEPTION '# No tests run!';
    END IF;

    IF exp_tests = 0 OR exp_tests IS NULL THEN
         -- No plan. Output one now.
        exp_tests = curr_test;
        RETURN NEXT '1..' || exp_tests;
    END IF;

    IF curr_test <> exp_tests THEN
        RETURN NEXT diag(
            'Looks like you planned ' || exp_tests || ' test' ||
            plural || ' but ran ' || curr_test
        );
    ELSIF num_faild > 0 THEN
        IF raise_ex THEN
            RAISE EXCEPTION  '% test% failed of %', num_faild, CASE num_faild WHEN 1 THEN '' ELSE 's' END, exp_tests;
        END IF;
        RETURN NEXT diag(
            'Looks like you failed ' || num_faild || ' test' ||
            CASE num_faild WHEN 1 THEN '' ELSE 's' END
            || ' of ' || exp_tests
        );
    ELSE

    END IF;
    RETURN;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION finish (exception_on_failure BOOLEAN DEFAULT NULL)
RETURNS SETOF TEXT AS $$
    SELECT * FROM _finish(
        _get('curr_test'),
        _get('plan'),
        num_failed(),
        $1
    );
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION is (anyelement, anyelement)
RETURNS TEXT AS $$
    SELECT is( $1, $2, NULL);
$$ LANGUAGE SQL;
