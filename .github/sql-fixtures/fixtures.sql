PGDMP  	        )    	        	    z           taiga    13.8 (Debian 13.8-1.pgdg110+1)    14.5 |              0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false                       0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false                       0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false                       1262    201586    taiga    DATABASE     Y   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';
    DROP DATABASE taiga;
                taiga    false                        3079    201710    unaccent 	   EXTENSION     <   CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    DROP EXTENSION unaccent;
                   false            	           0    0    EXTENSION unaccent    COMMENT     P   COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';
                        false    2            F           1247    202062    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          taiga    false            C           1247    202053    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          taiga    false            /           1255    202127 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	job_id bigint;
BEGIN
    INSERT INTO procrastinate_jobs (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    VALUES (queue_name, task_name, lock, queueing_lock, args, scheduled_at)
    RETURNING id INTO job_id;

    RETURN job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone);
       public          taiga    false            F           1255    202144 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, queue_name, defer_timestamp)
        VALUES (_task_name, _queue_name, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                ('{"timestamp": ' || _defer_timestamp || '}')::jsonb,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.queue_name = _queue_name
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint);
       public          taiga    false            0           1255    202128 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
	_job_id bigint;
	_defer_id bigint;
BEGIN

    INSERT
        INTO procrastinate_periodic_defers (task_name, periodic_id, defer_timestamp)
        VALUES (_task_name, _periodic_id, _defer_timestamp)
        ON CONFLICT DO NOTHING
        RETURNING id into _defer_id;

    IF _defer_id IS NULL THEN
        RETURN NULL;
    END IF;

    UPDATE procrastinate_periodic_defers
        SET job_id = procrastinate_defer_job(
                _queue_name,
                _task_name,
                _lock,
                _queueing_lock,
                _args,
                NULL
            )
        WHERE id = _defer_id
        RETURNING job_id INTO _job_id;

    DELETE
        FROM procrastinate_periodic_defers
        USING (
            SELECT id
            FROM procrastinate_periodic_defers
            WHERE procrastinate_periodic_defers.task_name = _task_name
            AND procrastinate_periodic_defers.periodic_id = _periodic_id
            AND procrastinate_periodic_defers.defer_timestamp < _defer_timestamp
            ORDER BY id
            FOR UPDATE
        ) to_delete
        WHERE procrastinate_periodic_defers.id = to_delete.id;

    RETURN _job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb);
       public          taiga    false            �            1259    202079    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
    id bigint NOT NULL,
    queue_name character varying(128) NOT NULL,
    task_name character varying(128) NOT NULL,
    lock text,
    queueing_lock text,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    status public.procrastinate_job_status DEFAULT 'todo'::public.procrastinate_job_status NOT NULL,
    scheduled_at timestamp with time zone,
    attempts integer DEFAULT 0 NOT NULL
);
 &   DROP TABLE public.procrastinate_jobs;
       public         heap    taiga    false    835    835            1           1255    202129 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
    LANGUAGE plpgsql
    AS $$
DECLARE
	found_jobs procrastinate_jobs;
BEGIN
    WITH candidate AS (
        SELECT jobs.*
            FROM procrastinate_jobs AS jobs
            WHERE
                -- reject the job if its lock has earlier jobs
                NOT EXISTS (
                    SELECT 1
                        FROM procrastinate_jobs AS earlier_jobs
                        WHERE
                            jobs.lock IS NOT NULL
                            AND earlier_jobs.lock = jobs.lock
                            AND earlier_jobs.status IN ('todo', 'doing')
                            AND earlier_jobs.id < jobs.id)
                AND jobs.status = 'todo'
                AND (target_queue_names IS NULL OR jobs.queue_name = ANY( target_queue_names ))
                AND (jobs.scheduled_at IS NULL OR jobs.scheduled_at <= now())
            ORDER BY jobs.id ASC LIMIT 1
            FOR UPDATE OF jobs SKIP LOCKED
    )
    UPDATE procrastinate_jobs
        SET status = 'doing'
        FROM candidate
        WHERE procrastinate_jobs.id = candidate.id
        RETURNING procrastinate_jobs.* INTO found_jobs;

	RETURN found_jobs;
END;
$$;
 V   DROP FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]);
       public          taiga    false    236            E           1255    202143 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1
    WHERE id = job_id;
END;
$$;
 k   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status);
       public          taiga    false    835            D           1255    202142 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_jobs
    SET status = end_status,
        attempts = attempts + 1,
        scheduled_at = COALESCE(next_scheduled_at, scheduled_at)
    WHERE id = job_id;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone);
       public          taiga    false    835            2           1255    202130 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    IF end_status NOT IN ('succeeded', 'failed') THEN
        RAISE 'End status should be either "succeeded" or "failed" (job id: %)', job_id;
    END IF;
    IF delete_job THEN
        DELETE FROM procrastinate_jobs
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    ELSE
        UPDATE procrastinate_jobs
        SET status = end_status,
            attempts =
                CASE
                    WHEN status = 'doing' THEN attempts + 1
                    ELSE attempts
                END
        WHERE id = job_id AND status IN ('todo', 'doing')
        RETURNING id INTO _job_id;
    END IF;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" or "todo" status (job id: %)', job_id;
    END IF;
END;
$$;
 �   DROP FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean);
       public          taiga    false    835            ?           1255    202132    procrastinate_notify_queue()    FUNCTION     
  CREATE FUNCTION public.procrastinate_notify_queue() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	PERFORM pg_notify('procrastinate_queue#' || NEW.queue_name, NEW.task_name);
	PERFORM pg_notify('procrastinate_any_queue', NEW.task_name);
	RETURN NEW;
END;
$$;
 3   DROP FUNCTION public.procrastinate_notify_queue();
       public          taiga    false            >           1255    202131 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _job_id bigint;
BEGIN
    UPDATE procrastinate_jobs
    SET status = 'todo',
        attempts = attempts + 1,
        scheduled_at = retry_at
    WHERE id = job_id AND status = 'doing'
    RETURNING id INTO _job_id;
    IF _job_id IS NULL THEN
        RAISE 'Job was not found or not in "doing" status (job id: %)', job_id;
    END IF;
END;
$$;
 a   DROP FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone);
       public          taiga    false            B           1255    202135 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          taiga    false            @           1255    202133 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          taiga    false            A           1255    202134 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH t AS (
        SELECT CASE
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND NEW.status = 'doing'::procrastinate_job_status
                THEN 'started'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'todo'::procrastinate_job_status
                THEN 'deferred_for_retry'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'failed'::procrastinate_job_status
                THEN 'failed'::procrastinate_job_event_type
            WHEN OLD.status = 'doing'::procrastinate_job_status
                AND NEW.status = 'succeeded'::procrastinate_job_status
                THEN 'succeeded'::procrastinate_job_event_type
            WHEN OLD.status = 'todo'::procrastinate_job_status
                AND (
                    NEW.status = 'failed'::procrastinate_job_status
                    OR NEW.status = 'succeeded'::procrastinate_job_status
                )
                THEN 'cancelled'::procrastinate_job_event_type
            ELSE NULL
        END as event_type
    )
    INSERT INTO procrastinate_events(job_id, type)
        SELECT NEW.id, t.event_type
        FROM t
        WHERE t.event_type IS NOT NULL;
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_update();
       public          taiga    false            C           1255    202136 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE procrastinate_periodic_defers
    SET job_id = NULL
    WHERE job_id = OLD.id;
    RETURN OLD;
END;
$$;
 =   DROP FUNCTION public.procrastinate_unlink_periodic_defers();
       public          taiga    false            �           3602    201717    simple_unaccent    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.simple_unaccent (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciiword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR word WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_part WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword_asciipart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR asciihword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR hword WITH public.unaccent, simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_unaccent
    ADD MAPPING FOR uint WITH simple;
 7   DROP TEXT SEARCH CONFIGURATION public.simple_unaccent;
       public          taiga    false    2    2    2    2            �            1259    201670 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    201668    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    212            �            1259    201679    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    201677    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    214            �            1259    201663    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    201661    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    210            �            1259    201640    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id uuid NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);
 $   DROP TABLE public.django_admin_log;
       public         heap    taiga    false            �            1259    201638    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    208            �            1259    201631    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    201629    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    206            �            1259    201589    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    201587    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    202            �            1259    201895    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false            �            1259    201720    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false            �            1259    201718    easy_thumbnails_source_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    216            �            1259    201727    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false            �            1259    201725     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    218            �            1259    201752 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false            �            1259    201750 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE       ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnaildimensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    220            �            1259    202109    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    taiga    false    838            �            1259    202107    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          taiga    false    240            
           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          taiga    false    239            �            1259    202077    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          taiga    false    236                       0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          taiga    false    235            �            1259    202093    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    taiga    false            �            1259    202091 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          taiga    false    238                       0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          taiga    false    237            �            1259    202146 3   project_references_3c106b28461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c106b28461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c106b28461311ed90644074e0237495;
       public          taiga    false            �            1259    202148 3   project_references_3c1b2540461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c1b2540461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c1b2540461311ed90644074e0237495;
       public          taiga    false            �            1259    202150 3   project_references_3c23a4ae461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c23a4ae461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c23a4ae461311ed90644074e0237495;
       public          taiga    false            �            1259    202152 3   project_references_3c2be740461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c2be740461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c2be740461311ed90644074e0237495;
       public          taiga    false            �            1259    202154 3   project_references_3c3262c8461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c3262c8461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c3262c8461311ed90644074e0237495;
       public          taiga    false            �            1259    202156 3   project_references_3c39eeee461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c39eeee461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c39eeee461311ed90644074e0237495;
       public          taiga    false            �            1259    202158 3   project_references_3c40e7d0461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c40e7d0461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c40e7d0461311ed90644074e0237495;
       public          taiga    false            �            1259    202160 3   project_references_3c486898461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c486898461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c486898461311ed90644074e0237495;
       public          taiga    false            �            1259    202162 3   project_references_3c4fb1e8461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c4fb1e8461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c4fb1e8461311ed90644074e0237495;
       public          taiga    false            �            1259    202164 3   project_references_3c56bd12461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c56bd12461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c56bd12461311ed90644074e0237495;
       public          taiga    false            �            1259    202166 3   project_references_3c5f39b0461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c5f39b0461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c5f39b0461311ed90644074e0237495;
       public          taiga    false            �            1259    202168 3   project_references_3c66444e461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c66444e461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c66444e461311ed90644074e0237495;
       public          taiga    false            �            1259    202170 3   project_references_3c6c84f8461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c6c84f8461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c6c84f8461311ed90644074e0237495;
       public          taiga    false            �            1259    202172 3   project_references_3c72fd42461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c72fd42461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c72fd42461311ed90644074e0237495;
       public          taiga    false            �            1259    202174 3   project_references_3c7af6a0461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c7af6a0461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c7af6a0461311ed90644074e0237495;
       public          taiga    false                        1259    202176 3   project_references_3c82306e461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c82306e461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c82306e461311ed90644074e0237495;
       public          taiga    false                       1259    202178 3   project_references_3c87ff58461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c87ff58461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c87ff58461311ed90644074e0237495;
       public          taiga    false                       1259    202180 3   project_references_3c901706461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c901706461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c901706461311ed90644074e0237495;
       public          taiga    false                       1259    202182 3   project_references_3c985704461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3c985704461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3c985704461311ed90644074e0237495;
       public          taiga    false                       1259    202184 3   project_references_3ca157aa461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3ca157aa461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3ca157aa461311ed90644074e0237495;
       public          taiga    false                       1259    202186 3   project_references_3e6d6326461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3e6d6326461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3e6d6326461311ed90644074e0237495;
       public          taiga    false                       1259    202188 3   project_references_3e729d82461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3e729d82461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3e729d82461311ed90644074e0237495;
       public          taiga    false                       1259    202190 3   project_references_3e78948a461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3e78948a461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3e78948a461311ed90644074e0237495;
       public          taiga    false                       1259    202192 3   project_references_3ed67942461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3ed67942461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3ed67942461311ed90644074e0237495;
       public          taiga    false            	           1259    202194 3   project_references_3edc0894461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3edc0894461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3edc0894461311ed90644074e0237495;
       public          taiga    false            
           1259    202196 3   project_references_3ee20780461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3ee20780461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3ee20780461311ed90644074e0237495;
       public          taiga    false                       1259    202198 3   project_references_3ee6c69e461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3ee6c69e461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3ee6c69e461311ed90644074e0237495;
       public          taiga    false                       1259    202200 3   project_references_3eec1da6461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3eec1da6461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3eec1da6461311ed90644074e0237495;
       public          taiga    false                       1259    202202 3   project_references_3ef0e7fa461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3ef0e7fa461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3ef0e7fa461311ed90644074e0237495;
       public          taiga    false                       1259    202204 3   project_references_3ef6532a461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3ef6532a461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3ef6532a461311ed90644074e0237495;
       public          taiga    false                       1259    202206 3   project_references_3efb8c78461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3efb8c78461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3efb8c78461311ed90644074e0237495;
       public          taiga    false                       1259    202208 3   project_references_3f00ec4a461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f00ec4a461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f00ec4a461311ed90644074e0237495;
       public          taiga    false                       1259    202210 3   project_references_3f0657f2461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f0657f2461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f0657f2461311ed90644074e0237495;
       public          taiga    false                       1259    202212 3   project_references_3f0f050a461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f0f050a461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f0f050a461311ed90644074e0237495;
       public          taiga    false                       1259    202214 3   project_references_3f13926e461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f13926e461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f13926e461311ed90644074e0237495;
       public          taiga    false                       1259    202216 3   project_references_3f1f6648461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f1f6648461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f1f6648461311ed90644074e0237495;
       public          taiga    false                       1259    202218 3   project_references_3f25dc8a461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f25dc8a461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f25dc8a461311ed90644074e0237495;
       public          taiga    false                       1259    202220 3   project_references_3f2beca6461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f2beca6461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f2beca6461311ed90644074e0237495;
       public          taiga    false                       1259    202222 3   project_references_3f31a196461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f31a196461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f31a196461311ed90644074e0237495;
       public          taiga    false                       1259    202224 3   project_references_3f39b818461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f39b818461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f39b818461311ed90644074e0237495;
       public          taiga    false                       1259    202226 3   project_references_3f4025f4461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f4025f4461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f4025f4461311ed90644074e0237495;
       public          taiga    false                       1259    202228 3   project_references_3f4640f6461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f4640f6461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f4640f6461311ed90644074e0237495;
       public          taiga    false                       1259    202230 3   project_references_3f4fe21e461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f4fe21e461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f4fe21e461311ed90644074e0237495;
       public          taiga    false                       1259    202232 3   project_references_3f5a5dfc461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f5a5dfc461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f5a5dfc461311ed90644074e0237495;
       public          taiga    false                       1259    202234 3   project_references_3f955542461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f955542461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f955542461311ed90644074e0237495;
       public          taiga    false                       1259    202236 3   project_references_3f9a0722461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f9a0722461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f9a0722461311ed90644074e0237495;
       public          taiga    false                       1259    202238 3   project_references_3f9f5ec0461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f9f5ec0461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f9f5ec0461311ed90644074e0237495;
       public          taiga    false                        1259    202240 3   project_references_3fa41bf4461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3fa41bf4461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3fa41bf4461311ed90644074e0237495;
       public          taiga    false            !           1259    202242 3   project_references_3fa9fad8461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3fa9fad8461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3fa9fad8461311ed90644074e0237495;
       public          taiga    false            "           1259    202244 3   project_references_3faf7364461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3faf7364461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3faf7364461311ed90644074e0237495;
       public          taiga    false            #           1259    202246 3   project_references_3fb4d692461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3fb4d692461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3fb4d692461311ed90644074e0237495;
       public          taiga    false            $           1259    202248 3   project_references_3fba5f18461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3fba5f18461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3fba5f18461311ed90644074e0237495;
       public          taiga    false            %           1259    202250 3   project_references_3fc1fac0461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3fc1fac0461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3fc1fac0461311ed90644074e0237495;
       public          taiga    false            &           1259    202252 3   project_references_3fc7b6cc461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_3fc7b6cc461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3fc7b6cc461311ed90644074e0237495;
       public          taiga    false            '           1259    202254 3   project_references_4053368e461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_4053368e461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_4053368e461311ed90644074e0237495;
       public          taiga    false            (           1259    202256 3   project_references_40a90744461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_40a90744461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_40a90744461311ed90644074e0237495;
       public          taiga    false            )           1259    202258 3   project_references_40ae69fa461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_40ae69fa461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_40ae69fa461311ed90644074e0237495;
       public          taiga    false            *           1259    202260 3   project_references_45518960461311ed90644074e0237495    SEQUENCE     �   CREATE SEQUENCE public.project_references_45518960461311ed90644074e0237495
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_45518960461311ed90644074e0237495;
       public          taiga    false            �            1259    201852 &   projects_invitations_projectinvitation    TABLE     �  CREATE TABLE public.projects_invitations_projectinvitation (
    id uuid NOT NULL,
    email character varying(255) NOT NULL,
    status character varying(50) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    num_emails_sent integer NOT NULL,
    resent_at timestamp with time zone,
    revoked_at timestamp with time zone,
    invited_by_id uuid,
    project_id uuid NOT NULL,
    resent_by_id uuid,
    revoked_by_id uuid,
    role_id uuid NOT NULL,
    user_id uuid
);
 :   DROP TABLE public.projects_invitations_projectinvitation;
       public         heap    taiga    false            �            1259    201814 &   projects_memberships_projectmembership    TABLE     �   CREATE TABLE public.projects_memberships_projectmembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    project_id uuid NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 :   DROP TABLE public.projects_memberships_projectmembership;
       public         heap    taiga    false            �            1259    201774    projects_project    TABLE     �  CREATE TABLE public.projects_project (
    id uuid NOT NULL,
    name character varying(80) NOT NULL,
    slug character varying(250) NOT NULL,
    description character varying(220),
    color integer NOT NULL,
    logo character varying(500),
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    public_permissions text[],
    workspace_member_permissions text[],
    owner_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 $   DROP TABLE public.projects_project;
       public         heap    taiga    false            �            1259    201784    projects_projecttemplate    TABLE     ]  CREATE TABLE public.projects_projecttemplate (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    default_owner_role character varying(50) NOT NULL,
    roles jsonb,
    workflows jsonb
);
 ,   DROP TABLE public.projects_projecttemplate;
       public         heap    taiga    false            �            1259    201796    projects_roles_projectrole    TABLE       CREATE TABLE public.projects_roles_projectrole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    project_id uuid NOT NULL
);
 .   DROP TABLE public.projects_roles_projectrole;
       public         heap    taiga    false            �            1259    201937    stories_story    TABLE     R  CREATE TABLE public.stories_story (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    ref bigint NOT NULL,
    title character varying(500) NOT NULL,
    "order" numeric(16,10) NOT NULL,
    created_by_id uuid NOT NULL,
    project_id uuid NOT NULL,
    status_id uuid NOT NULL,
    workflow_id uuid NOT NULL
);
 !   DROP TABLE public.stories_story;
       public         heap    taiga    false            �            1259    201983    tokens_denylistedtoken    TABLE     �   CREATE TABLE public.tokens_denylistedtoken (
    id uuid NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id uuid NOT NULL
);
 *   DROP TABLE public.tokens_denylistedtoken;
       public         heap    taiga    false            �            1259    201973    tokens_outstandingtoken    TABLE     2  CREATE TABLE public.tokens_outstandingtoken (
    id uuid NOT NULL,
    object_id uuid,
    jti character varying(255) NOT NULL,
    token_type text NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    content_type_id integer
);
 +   DROP TABLE public.tokens_outstandingtoken;
       public         heap    taiga    false            �            1259    201609    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id uuid NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb,
    user_id uuid NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            �            1259    201597 
   users_user    TABLE     �  CREATE TABLE public.users_user (
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    id uuid NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    is_superuser boolean NOT NULL,
    full_name character varying(256),
    accepted_terms boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    date_verification timestamp with time zone
);
    DROP TABLE public.users_user;
       public         heap    taiga    false            �            1259    201905    workflows_workflow    TABLE     �   CREATE TABLE public.workflows_workflow (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    "order" bigint NOT NULL,
    project_id uuid NOT NULL
);
 &   DROP TABLE public.workflows_workflow;
       public         heap    taiga    false            �            1259    201913    workflows_workflowstatus    TABLE     �   CREATE TABLE public.workflows_workflowstatus (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    "order" bigint NOT NULL,
    workflow_id uuid NOT NULL
);
 ,   DROP TABLE public.workflows_workflowstatus;
       public         heap    taiga    false            �            1259    202020 *   workspaces_memberships_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_memberships_workspacemembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 >   DROP TABLE public.workspaces_memberships_workspacemembership;
       public         heap    taiga    false            �            1259    202002    workspaces_roles_workspacerole    TABLE       CREATE TABLE public.workspaces_roles_workspacerole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id uuid NOT NULL
);
 2   DROP TABLE public.workspaces_roles_workspacerole;
       public         heap    taiga    false            �            1259    201766    workspaces_workspace    TABLE     T  CREATE TABLE public.workspaces_workspace (
    id uuid NOT NULL,
    name character varying(40) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    is_premium boolean NOT NULL,
    owner_id uuid NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    taiga    false            M           2604    202112    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    240    239    240            G           2604    202082    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    235    236    236            K           2604    202096     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    237    238    238            �          0    201670 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    212   �X      �          0    201679    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    214   �X      �          0    201663    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    210   �X      �          0    201640    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    208   q\      �          0    201631    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    206   �\      �          0    201589    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    202   �]      �          0    201895    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    227   K`      �          0    201720    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    216   h`      �          0    201727    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    218   �`      �          0    201752 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    220   �`      �          0    202109    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          taiga    false    240   �`      �          0    202079    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          taiga    false    236   �`      �          0    202093    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          taiga    false    238   �`      �          0    201852 &   projects_invitations_projectinvitation 
   TABLE DATA           �   COPY public.projects_invitations_projectinvitation (id, email, status, created_at, num_emails_sent, resent_at, revoked_at, invited_by_id, project_id, resent_by_id, revoked_by_id, role_id, user_id) FROM stdin;
    public          taiga    false    226   a      �          0    201814 &   projects_memberships_projectmembership 
   TABLE DATA           n   COPY public.projects_memberships_projectmembership (id, created_at, project_id, role_id, user_id) FROM stdin;
    public          taiga    false    225   gj      �          0    201774    projects_project 
   TABLE DATA           �   COPY public.projects_project (id, name, slug, description, color, logo, created_at, modified_at, public_permissions, workspace_member_permissions, owner_id, workspace_id) FROM stdin;
    public          taiga    false    222   �w      �          0    201784    projects_projecttemplate 
   TABLE DATA           �   COPY public.projects_projecttemplate (id, name, slug, created_at, modified_at, default_owner_role, roles, workflows) FROM stdin;
    public          taiga    false    223   ��      �          0    201796    projects_roles_projectrole 
   TABLE DATA           p   COPY public.projects_roles_projectrole (id, name, slug, permissions, "order", is_admin, project_id) FROM stdin;
    public          taiga    false    224   Ǐ      �          0    201937    stories_story 
   TABLE DATA              COPY public.stories_story (id, created_at, ref, title, "order", created_by_id, project_id, status_id, workflow_id) FROM stdin;
    public          taiga    false    230    �      �          0    201983    tokens_denylistedtoken 
   TABLE DATA           M   COPY public.tokens_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    232   g      �          0    201973    tokens_outstandingtoken 
   TABLE DATA           �   COPY public.tokens_outstandingtoken (id, object_id, jti, token_type, token, created_at, expires_at, content_type_id) FROM stdin;
    public          taiga    false    231   �      �          0    201609    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    204   �      �          0    201597 
   users_user 
   TABLE DATA           �   COPY public.users_user (password, last_login, id, username, email, is_active, is_superuser, full_name, accepted_terms, date_joined, date_verification) FROM stdin;
    public          taiga    false    203   �      �          0    201905    workflows_workflow 
   TABLE DATA           Q   COPY public.workflows_workflow (id, name, slug, "order", project_id) FROM stdin;
    public          taiga    false    228   A      �          0    201913    workflows_workflowstatus 
   TABLE DATA           _   COPY public.workflows_workflowstatus (id, name, slug, color, "order", workflow_id) FROM stdin;
    public          taiga    false    229   �      �          0    202020 *   workspaces_memberships_workspacemembership 
   TABLE DATA           t   COPY public.workspaces_memberships_workspacemembership (id, created_at, role_id, user_id, workspace_id) FROM stdin;
    public          taiga    false    234   %&      �          0    202002    workspaces_roles_workspacerole 
   TABLE DATA           v   COPY public.workspaces_roles_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    233   .      �          0    201766    workspaces_workspace 
   TABLE DATA           t   COPY public.workspaces_workspace (id, name, slug, color, created_at, modified_at, is_premium, owner_id) FROM stdin;
    public          taiga    false    221   S2                 0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    211                       0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    213                       0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 92, true);
          public          taiga    false    209                       0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    207                       0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 23, true);
          public          taiga    false    205                       0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 35, true);
          public          taiga    false    201                       0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 1, false);
          public          taiga    false    215                       0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 1, false);
          public          taiga    false    217                       0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    219                       0    0    procrastinate_events_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 1, false);
          public          taiga    false    239                       0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 1, false);
          public          taiga    false    235                       0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          taiga    false    237                       0    0 3   project_references_3c106b28461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c106b28461311ed90644074e0237495', 19, true);
          public          taiga    false    241                       0    0 3   project_references_3c1b2540461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c1b2540461311ed90644074e0237495', 1, false);
          public          taiga    false    242                       0    0 3   project_references_3c23a4ae461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c23a4ae461311ed90644074e0237495', 13, true);
          public          taiga    false    243                       0    0 3   project_references_3c2be740461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c2be740461311ed90644074e0237495', 27, true);
          public          taiga    false    244                       0    0 3   project_references_3c3262c8461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c3262c8461311ed90644074e0237495', 29, true);
          public          taiga    false    245                       0    0 3   project_references_3c39eeee461311ed90644074e0237495    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_3c39eeee461311ed90644074e0237495', 2, true);
          public          taiga    false    246                       0    0 3   project_references_3c40e7d0461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c40e7d0461311ed90644074e0237495', 20, true);
          public          taiga    false    247                        0    0 3   project_references_3c486898461311ed90644074e0237495    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_3c486898461311ed90644074e0237495', 8, true);
          public          taiga    false    248            !           0    0 3   project_references_3c4fb1e8461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c4fb1e8461311ed90644074e0237495', 11, true);
          public          taiga    false    249            "           0    0 3   project_references_3c56bd12461311ed90644074e0237495    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_3c56bd12461311ed90644074e0237495', 6, true);
          public          taiga    false    250            #           0    0 3   project_references_3c5f39b0461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c5f39b0461311ed90644074e0237495', 14, true);
          public          taiga    false    251            $           0    0 3   project_references_3c66444e461311ed90644074e0237495    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_3c66444e461311ed90644074e0237495', 9, true);
          public          taiga    false    252            %           0    0 3   project_references_3c6c84f8461311ed90644074e0237495    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_3c6c84f8461311ed90644074e0237495', 8, true);
          public          taiga    false    253            &           0    0 3   project_references_3c72fd42461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c72fd42461311ed90644074e0237495', 16, true);
          public          taiga    false    254            '           0    0 3   project_references_3c7af6a0461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c7af6a0461311ed90644074e0237495', 1, false);
          public          taiga    false    255            (           0    0 3   project_references_3c82306e461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c82306e461311ed90644074e0237495', 24, true);
          public          taiga    false    256            )           0    0 3   project_references_3c87ff58461311ed90644074e0237495    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_3c87ff58461311ed90644074e0237495', 4, true);
          public          taiga    false    257            *           0    0 3   project_references_3c901706461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c901706461311ed90644074e0237495', 1, false);
          public          taiga    false    258            +           0    0 3   project_references_3c985704461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3c985704461311ed90644074e0237495', 15, true);
          public          taiga    false    259            ,           0    0 3   project_references_3ca157aa461311ed90644074e0237495    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_3ca157aa461311ed90644074e0237495', 4, true);
          public          taiga    false    260            -           0    0 3   project_references_3e6d6326461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3e6d6326461311ed90644074e0237495', 1, false);
          public          taiga    false    261            .           0    0 3   project_references_3e729d82461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3e729d82461311ed90644074e0237495', 1, false);
          public          taiga    false    262            /           0    0 3   project_references_3e78948a461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3e78948a461311ed90644074e0237495', 1, false);
          public          taiga    false    263            0           0    0 3   project_references_3ed67942461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3ed67942461311ed90644074e0237495', 1, false);
          public          taiga    false    264            1           0    0 3   project_references_3edc0894461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3edc0894461311ed90644074e0237495', 1, false);
          public          taiga    false    265            2           0    0 3   project_references_3ee20780461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3ee20780461311ed90644074e0237495', 1, false);
          public          taiga    false    266            3           0    0 3   project_references_3ee6c69e461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3ee6c69e461311ed90644074e0237495', 1, false);
          public          taiga    false    267            4           0    0 3   project_references_3eec1da6461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3eec1da6461311ed90644074e0237495', 1, false);
          public          taiga    false    268            5           0    0 3   project_references_3ef0e7fa461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3ef0e7fa461311ed90644074e0237495', 1, false);
          public          taiga    false    269            6           0    0 3   project_references_3ef6532a461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3ef6532a461311ed90644074e0237495', 1, false);
          public          taiga    false    270            7           0    0 3   project_references_3efb8c78461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3efb8c78461311ed90644074e0237495', 1, false);
          public          taiga    false    271            8           0    0 3   project_references_3f00ec4a461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f00ec4a461311ed90644074e0237495', 1, false);
          public          taiga    false    272            9           0    0 3   project_references_3f0657f2461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f0657f2461311ed90644074e0237495', 1, false);
          public          taiga    false    273            :           0    0 3   project_references_3f0f050a461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f0f050a461311ed90644074e0237495', 1, false);
          public          taiga    false    274            ;           0    0 3   project_references_3f13926e461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f13926e461311ed90644074e0237495', 1, false);
          public          taiga    false    275            <           0    0 3   project_references_3f1f6648461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f1f6648461311ed90644074e0237495', 1, false);
          public          taiga    false    276            =           0    0 3   project_references_3f25dc8a461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f25dc8a461311ed90644074e0237495', 1, false);
          public          taiga    false    277            >           0    0 3   project_references_3f2beca6461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f2beca6461311ed90644074e0237495', 1, false);
          public          taiga    false    278            ?           0    0 3   project_references_3f31a196461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f31a196461311ed90644074e0237495', 1, false);
          public          taiga    false    279            @           0    0 3   project_references_3f39b818461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f39b818461311ed90644074e0237495', 1, false);
          public          taiga    false    280            A           0    0 3   project_references_3f4025f4461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f4025f4461311ed90644074e0237495', 1, false);
          public          taiga    false    281            B           0    0 3   project_references_3f4640f6461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f4640f6461311ed90644074e0237495', 1, false);
          public          taiga    false    282            C           0    0 3   project_references_3f4fe21e461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f4fe21e461311ed90644074e0237495', 1, false);
          public          taiga    false    283            D           0    0 3   project_references_3f5a5dfc461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f5a5dfc461311ed90644074e0237495', 1, false);
          public          taiga    false    284            E           0    0 3   project_references_3f955542461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f955542461311ed90644074e0237495', 1, false);
          public          taiga    false    285            F           0    0 3   project_references_3f9a0722461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f9a0722461311ed90644074e0237495', 1, false);
          public          taiga    false    286            G           0    0 3   project_references_3f9f5ec0461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f9f5ec0461311ed90644074e0237495', 1, false);
          public          taiga    false    287            H           0    0 3   project_references_3fa41bf4461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3fa41bf4461311ed90644074e0237495', 1, false);
          public          taiga    false    288            I           0    0 3   project_references_3fa9fad8461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3fa9fad8461311ed90644074e0237495', 1, false);
          public          taiga    false    289            J           0    0 3   project_references_3faf7364461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3faf7364461311ed90644074e0237495', 1, false);
          public          taiga    false    290            K           0    0 3   project_references_3fb4d692461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3fb4d692461311ed90644074e0237495', 1, false);
          public          taiga    false    291            L           0    0 3   project_references_3fba5f18461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3fba5f18461311ed90644074e0237495', 1, false);
          public          taiga    false    292            M           0    0 3   project_references_3fc1fac0461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3fc1fac0461311ed90644074e0237495', 1, false);
          public          taiga    false    293            N           0    0 3   project_references_3fc7b6cc461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3fc7b6cc461311ed90644074e0237495', 1, false);
          public          taiga    false    294            O           0    0 3   project_references_4053368e461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_4053368e461311ed90644074e0237495', 1, false);
          public          taiga    false    295            P           0    0 3   project_references_40a90744461311ed90644074e0237495    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_40a90744461311ed90644074e0237495', 1, false);
          public          taiga    false    296            Q           0    0 3   project_references_40ae69fa461311ed90644074e0237495    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_40ae69fa461311ed90644074e0237495', 1000, true);
          public          taiga    false    297            R           0    0 3   project_references_45518960461311ed90644074e0237495    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_45518960461311ed90644074e0237495', 2000, true);
          public          taiga    false    298            o           2606    201708    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    212            t           2606    201694 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    214    214            w           2606    201683 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    214            q           2606    201674    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    212            j           2606    201685 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    210    210            l           2606    201667 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    210            f           2606    201648 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    208            a           2606    201637 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    206    206            c           2606    201635 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    206            P           2606    201596 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    202            �           2606    201902 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    227            {           2606    201724 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    216                       2606    201735 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    216    216            �           2606    201733 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    218    218    218            �           2606    201731 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    218            �           2606    201758 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    220            �           2606    201760 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    220            �           2606    202115 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            taiga    false    240            �           2606    202090 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            taiga    false    236            �           2606    202099 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            taiga    false    238            �           2606    202101 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            taiga    false    238    238    238            �           2606    201858 ^   projects_invitations_projectinvitation projects_invitations_pro_email_project_id_b147d04b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_pro_email_project_id_b147d04b_uniq UNIQUE (email, project_id);
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_pro_email_project_id_b147d04b_uniq;
       public            taiga    false    226    226            �           2606    201856 R   projects_invitations_projectinvitation projects_invitations_projectinvitation_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_projectinvitation_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_projectinvitation_pkey;
       public            taiga    false    226            �           2606    201820 `   projects_memberships_projectmembership projects_memberships_pro_user_id_project_id_fac8390b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_pro_user_id_project_id_fac8390b_uniq UNIQUE (user_id, project_id);
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_pro_user_id_project_id_fac8390b_uniq;
       public            taiga    false    225    225            �           2606    201818 R   projects_memberships_projectmembership projects_memberships_projectmembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_projectmembership_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_projectmembership_pkey;
       public            taiga    false    225            �           2606    201781 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    222            �           2606    201783 *   projects_project projects_project_slug_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_slug_key UNIQUE (slug);
 T   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_slug_key;
       public            taiga    false    222            �           2606    201791 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    223            �           2606    201793 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    223            �           2606    201803 :   projects_roles_projectrole projects_roles_projectrole_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_pkey;
       public            taiga    false    224            �           2606    201805 S   projects_roles_projectrole projects_roles_projectrole_slug_project_id_ef23bf22_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_slug_project_id_ef23bf22_uniq UNIQUE (slug, project_id);
 }   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_slug_project_id_ef23bf22_uniq;
       public            taiga    false    224    224            �           2606    201944     stories_story stories_story_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_pkey;
       public            taiga    false    230            �           2606    201947 8   stories_story stories_story_ref_project_id_ccca2722_uniq 
   CONSTRAINT     ~   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_ref_project_id_ccca2722_uniq UNIQUE (ref, project_id);
 b   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_ref_project_id_ccca2722_uniq;
       public            taiga    false    230    230            �           2606    201987 2   tokens_denylistedtoken tokens_denylistedtoken_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_pkey;
       public            taiga    false    232            �           2606    201989 :   tokens_denylistedtoken tokens_denylistedtoken_token_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_token_id_key UNIQUE (token_id);
 d   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_token_id_key;
       public            taiga    false    232            �           2606    201982 7   tokens_outstandingtoken tokens_outstandingtoken_jti_key 
   CONSTRAINT     q   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_jti_key UNIQUE (jti);
 a   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_jti_key;
       public            taiga    false    231            �           2606    201980 4   tokens_outstandingtoken tokens_outstandingtoken_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_pkey;
       public            taiga    false    231            \           2606    201620 5   users_authdata users_authdata_key_value_7ee3acc9_uniq 
   CONSTRAINT     v   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_key_value_7ee3acc9_uniq UNIQUE (key, value);
 _   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_key_value_7ee3acc9_uniq;
       public            taiga    false    204    204            ^           2606    201616 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    204            S           2606    201608    users_user users_user_email_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_key UNIQUE (email);
 I   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_key;
       public            taiga    false    203            U           2606    201604    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    203            X           2606    201606 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    203            �           2606    201912 *   workflows_workflow workflows_workflow_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_pkey;
       public            taiga    false    228            �           2606    201922 C   workflows_workflow workflows_workflow_slug_project_id_80394f0d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq UNIQUE (slug, project_id);
 m   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_slug_project_id_80394f0d_uniq;
       public            taiga    false    228    228            �           2606    201920 6   workflows_workflowstatus workflows_workflowstatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_pkey;
       public            taiga    false    229            �           2606    201930 P   workflows_workflowstatus workflows_workflowstatus_slug_workflow_id_06486b8e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq UNIQUE (slug, workflow_id);
 z   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_slug_workflow_id_06486b8e_uniq;
       public            taiga    false    229    229            �           2606    202026 f   workspaces_memberships_workspacemembership workspaces_memberships_w_user_id_workspace_id_f1752d06_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_w_user_id_workspace_id_f1752d06_uniq UNIQUE (user_id, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_w_user_id_workspace_id_f1752d06_uniq;
       public            taiga    false    234    234            �           2606    202024 Z   workspaces_memberships_workspacemembership workspaces_memberships_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_workspacemembership_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_workspacemembership_pkey;
       public            taiga    false    234            �           2606    202009 B   workspaces_roles_workspacerole workspaces_roles_workspacerole_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_pkey;
       public            taiga    false    233            �           2606    202011 ]   workspaces_roles_workspacerole workspaces_roles_workspacerole_slug_workspace_id_16fb922a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_slug_workspace_id_16fb922a_uniq UNIQUE (slug, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_slug_workspace_id_16fb922a_uniq;
       public            taiga    false    233    233            �           2606    201770 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    221            �           2606    201772 2   workspaces_workspace workspaces_workspace_slug_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_slug_key UNIQUE (slug);
 \   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_slug_key;
       public            taiga    false    221            m           1259    201709    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    212            r           1259    201705 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    214            u           1259    201706 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    214            h           1259    201691 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    210            d           1259    201659 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    208            g           1259    201660 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    208            �           1259    201904 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    227            �           1259    201903 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    227            x           1259    201738 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    216            y           1259    201739 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    216            |           1259    201736 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    216            }           1259    201737 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    216            �           1259    201747 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    218            �           1259    201748 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    218            �           1259    201749 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    218            �           1259    201745 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    218            �           1259    201746 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    218            �           1259    202125     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            taiga    false    240            �           1259    202124    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            taiga    false    236    236    236    835            �           1259    202122    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            taiga    false    236    236    835            �           1259    202123 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            taiga    false    236            �           1259    202121 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            taiga    false    236    236    835            �           1259    202126 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            taiga    false    238            �           1259    201889 =   projects_invitations_projectinvitation_invited_by_id_e41218dc    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_invited_by_id_e41218dc ON public.projects_invitations_projectinvitation USING btree (invited_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_invited_by_id_e41218dc;
       public            taiga    false    226            �           1259    201890 :   projects_invitations_projectinvitation_project_id_8a729cae    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_project_id_8a729cae ON public.projects_invitations_projectinvitation USING btree (project_id);
 N   DROP INDEX public.projects_invitations_projectinvitation_project_id_8a729cae;
       public            taiga    false    226            �           1259    201891 <   projects_invitations_projectinvitation_resent_by_id_68c580e8    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_resent_by_id_68c580e8 ON public.projects_invitations_projectinvitation USING btree (resent_by_id);
 P   DROP INDEX public.projects_invitations_projectinvitation_resent_by_id_68c580e8;
       public            taiga    false    226            �           1259    201892 =   projects_invitations_projectinvitation_revoked_by_id_8a8e629a    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_revoked_by_id_8a8e629a ON public.projects_invitations_projectinvitation USING btree (revoked_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_revoked_by_id_8a8e629a;
       public            taiga    false    226            �           1259    201893 7   projects_invitations_projectinvitation_role_id_bb735b0e    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_role_id_bb735b0e ON public.projects_invitations_projectinvitation USING btree (role_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_role_id_bb735b0e;
       public            taiga    false    226            �           1259    201894 7   projects_invitations_projectinvitation_user_id_995e9b1c    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_user_id_995e9b1c ON public.projects_invitations_projectinvitation USING btree (user_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_user_id_995e9b1c;
       public            taiga    false    226            �           1259    201836 :   projects_memberships_projectmembership_project_id_7592284f    INDEX     �   CREATE INDEX projects_memberships_projectmembership_project_id_7592284f ON public.projects_memberships_projectmembership USING btree (project_id);
 N   DROP INDEX public.projects_memberships_projectmembership_project_id_7592284f;
       public            taiga    false    225            �           1259    201837 7   projects_memberships_projectmembership_role_id_43773f6c    INDEX     �   CREATE INDEX projects_memberships_projectmembership_role_id_43773f6c ON public.projects_memberships_projectmembership USING btree (role_id);
 K   DROP INDEX public.projects_memberships_projectmembership_role_id_43773f6c;
       public            taiga    false    225            �           1259    201838 7   projects_memberships_projectmembership_user_id_8a613b51    INDEX     �   CREATE INDEX projects_memberships_projectmembership_user_id_8a613b51 ON public.projects_memberships_projectmembership USING btree (user_id);
 K   DROP INDEX public.projects_memberships_projectmembership_user_id_8a613b51;
       public            taiga    false    225            �           1259    201850 %   projects_project_name_id_44f44a5f_idx    INDEX     f   CREATE INDEX projects_project_name_id_44f44a5f_idx ON public.projects_project USING btree (name, id);
 9   DROP INDEX public.projects_project_name_id_44f44a5f_idx;
       public            taiga    false    222    222            �           1259    201844 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    222            �           1259    201794 #   projects_project_slug_2d50067a_like    INDEX     t   CREATE INDEX projects_project_slug_2d50067a_like ON public.projects_project USING btree (slug varchar_pattern_ops);
 7   DROP INDEX public.projects_project_slug_2d50067a_like;
       public            taiga    false    222            �           1259    201851 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    222            �           1259    201795 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    223            �           1259    201813 .   projects_roles_projectrole_project_id_4efc0342    INDEX     {   CREATE INDEX projects_roles_projectrole_project_id_4efc0342 ON public.projects_roles_projectrole USING btree (project_id);
 B   DROP INDEX public.projects_roles_projectrole_project_id_4efc0342;
       public            taiga    false    224            �           1259    201811 (   projects_roles_projectrole_slug_9eb663ce    INDEX     o   CREATE INDEX projects_roles_projectrole_slug_9eb663ce ON public.projects_roles_projectrole USING btree (slug);
 <   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce;
       public            taiga    false    224            �           1259    201812 -   projects_roles_projectrole_slug_9eb663ce_like    INDEX     �   CREATE INDEX projects_roles_projectrole_slug_9eb663ce_like ON public.projects_roles_projectrole USING btree (slug varchar_pattern_ops);
 A   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce_like;
       public            taiga    false    224            �           1259    201945    stories_sto_project_840ba5_idx    INDEX     c   CREATE INDEX stories_sto_project_840ba5_idx ON public.stories_story USING btree (project_id, ref);
 2   DROP INDEX public.stories_sto_project_840ba5_idx;
       public            taiga    false    230    230            �           1259    201969 $   stories_story_created_by_id_052bf6c8    INDEX     g   CREATE INDEX stories_story_created_by_id_052bf6c8 ON public.stories_story USING btree (created_by_id);
 8   DROP INDEX public.stories_story_created_by_id_052bf6c8;
       public            taiga    false    230            �           1259    201970 !   stories_story_project_id_c78d9ba8    INDEX     a   CREATE INDEX stories_story_project_id_c78d9ba8 ON public.stories_story USING btree (project_id);
 5   DROP INDEX public.stories_story_project_id_c78d9ba8;
       public            taiga    false    230            �           1259    201968    stories_story_ref_07544f5a    INDEX     S   CREATE INDEX stories_story_ref_07544f5a ON public.stories_story USING btree (ref);
 .   DROP INDEX public.stories_story_ref_07544f5a;
       public            taiga    false    230            �           1259    201971     stories_story_status_id_15c8b6c9    INDEX     _   CREATE INDEX stories_story_status_id_15c8b6c9 ON public.stories_story USING btree (status_id);
 4   DROP INDEX public.stories_story_status_id_15c8b6c9;
       public            taiga    false    230            �           1259    201972 "   stories_story_workflow_id_448ab642    INDEX     c   CREATE INDEX stories_story_workflow_id_448ab642 ON public.stories_story USING btree (workflow_id);
 6   DROP INDEX public.stories_story_workflow_id_448ab642;
       public            taiga    false    230            �           1259    201996 0   tokens_outstandingtoken_content_type_id_06cfd70a    INDEX        CREATE INDEX tokens_outstandingtoken_content_type_id_06cfd70a ON public.tokens_outstandingtoken USING btree (content_type_id);
 D   DROP INDEX public.tokens_outstandingtoken_content_type_id_06cfd70a;
       public            taiga    false    231            �           1259    201995 )   tokens_outstandingtoken_jti_ac7232c7_like    INDEX     �   CREATE INDEX tokens_outstandingtoken_jti_ac7232c7_like ON public.tokens_outstandingtoken USING btree (jti varchar_pattern_ops);
 =   DROP INDEX public.tokens_outstandingtoken_jti_ac7232c7_like;
       public            taiga    false    231            Y           1259    201626    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    204            Z           1259    201627     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    204            _           1259    201628    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    204            Q           1259    201618    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    203            V           1259    201617 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    203            �           1259    201928 &   workflows_workflow_project_id_59dd45ec    INDEX     k   CREATE INDEX workflows_workflow_project_id_59dd45ec ON public.workflows_workflow USING btree (project_id);
 :   DROP INDEX public.workflows_workflow_project_id_59dd45ec;
       public            taiga    false    228            �           1259    201936 -   workflows_workflowstatus_workflow_id_8efaaa04    INDEX     y   CREATE INDEX workflows_workflowstatus_workflow_id_8efaaa04 ON public.workflows_workflowstatus USING btree (workflow_id);
 A   DROP INDEX public.workflows_workflowstatus_workflow_id_8efaaa04;
       public            taiga    false    229            �           1259    202044 0   workspaces_memberships_wor_workspace_id_fd6f07d4    INDEX     �   CREATE INDEX workspaces_memberships_wor_workspace_id_fd6f07d4 ON public.workspaces_memberships_workspacemembership USING btree (workspace_id);
 D   DROP INDEX public.workspaces_memberships_wor_workspace_id_fd6f07d4;
       public            taiga    false    234            �           1259    202042 ;   workspaces_memberships_workspacemembership_role_id_4ea4e76e    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_role_id_4ea4e76e ON public.workspaces_memberships_workspacemembership USING btree (role_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_role_id_4ea4e76e;
       public            taiga    false    234            �           1259    202043 ;   workspaces_memberships_workspacemembership_user_id_89b29e02    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_user_id_89b29e02 ON public.workspaces_memberships_workspacemembership USING btree (user_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_user_id_89b29e02;
       public            taiga    false    234            �           1259    202017 ,   workspaces_roles_workspacerole_slug_6d21c03e    INDEX     w   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e ON public.workspaces_roles_workspacerole USING btree (slug);
 @   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e;
       public            taiga    false    233            �           1259    202018 1   workspaces_roles_workspacerole_slug_6d21c03e_like    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e_like ON public.workspaces_roles_workspacerole USING btree (slug varchar_pattern_ops);
 E   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e_like;
       public            taiga    false    233            �           1259    202019 4   workspaces_roles_workspacerole_workspace_id_1aebcc14    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_workspace_id_1aebcc14 ON public.workspaces_roles_workspacerole USING btree (workspace_id);
 H   DROP INDEX public.workspaces_roles_workspacerole_workspace_id_1aebcc14;
       public            taiga    false    233            �           1259    202050 )   workspaces_workspace_name_id_69b27cd8_idx    INDEX     n   CREATE INDEX workspaces_workspace_name_id_69b27cd8_idx ON public.workspaces_workspace USING btree (name, id);
 =   DROP INDEX public.workspaces_workspace_name_id_69b27cd8_idx;
       public            taiga    false    221    221            �           1259    202051 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    221            �           1259    201773 '   workspaces_workspace_slug_c37054a2_like    INDEX     |   CREATE INDEX workspaces_workspace_slug_c37054a2_like ON public.workspaces_workspace USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.workspaces_workspace_slug_c37054a2_like;
       public            taiga    false    221                       2620    202137 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          taiga    false    236    236    835    319                       2620    202141 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          taiga    false    236    323                       2620    202140 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          taiga    false    835    322    236    236    236                       2620    202139 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          taiga    false    320    835    236    236                       2620    202138 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          taiga    false    236    236    321            �           2606    201700 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    3180    210    214            �           2606    201695 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    212    3185    214            �           2606    201686 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    3171    206    210            �           2606    201649 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    208    3171    206            �           2606    201654 C   django_admin_log django_admin_log_user_id_c564eba6_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id;
       public          taiga    false    208    3157    203            �           2606    201740 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    216    218    3195            �           2606    201761 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    218    220    3205                       2606    202116 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          taiga    false    240    3308    236                       2606    202102 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          taiga    false    3308    238    236                       2606    201859 _   projects_invitations_projectinvitation projects_invitations_invited_by_id_e41218dc_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use FOREIGN KEY (invited_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use;
       public          taiga    false    3157    226    203                       2606    201864 \   projects_invitations_projectinvitation projects_invitations_project_id_8a729cae_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_;
       public          taiga    false    222    226    3223                       2606    201869 ^   projects_invitations_projectinvitation projects_invitations_resent_by_id_68c580e8_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use FOREIGN KEY (resent_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use;
       public          taiga    false    203    226    3157            	           2606    201874 _   projects_invitations_projectinvitation projects_invitations_revoked_by_id_8a8e629a_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use FOREIGN KEY (revoked_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use;
       public          taiga    false    203    3157    226            
           2606    201879 Y   projects_invitations_projectinvitation projects_invitations_role_id_bb735b0e_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_;
       public          taiga    false    224    226    3234                       2606    201884 Y   projects_invitations_projectinvitation projects_invitations_user_id_995e9b1c_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use;
       public          taiga    false    226    3157    203                       2606    201821 \   projects_memberships_projectmembership projects_memberships_project_id_7592284f_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_;
       public          taiga    false    3223    225    222                       2606    201826 Y   projects_memberships_projectmembership projects_memberships_role_id_43773f6c_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_;
       public          taiga    false    224    3234    225                       2606    201831 Y   projects_memberships_projectmembership projects_memberships_user_id_8a613b51_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use;
       public          taiga    false    203    225    3157                        2606    201839 D   projects_project projects_project_owner_id_b940de39_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id;
       public          taiga    false    203    222    3157                       2606    201845 D   projects_project projects_project_workspace_id_7ea54f67_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace;
       public          taiga    false    3216    221    222                       2606    201806 P   projects_roles_projectrole projects_roles_proje_project_id_4efc0342_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_;
       public          taiga    false    224    222    3223                       2606    201948 C   stories_story stories_story_created_by_id_052bf6c8_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id FOREIGN KEY (created_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id;
       public          taiga    false    3157    230    203                       2606    201953 F   stories_story stories_story_project_id_c78d9ba8_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 p   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id;
       public          taiga    false    3223    230    222                       2606    201958 M   stories_story stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id FOREIGN KEY (status_id) REFERENCES public.workflows_workflowstatus(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id;
       public          taiga    false    3267    229    230                       2606    201963 I   stories_story stories_story_workflow_id_448ab642_fk_workflows_workflow_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id;
       public          taiga    false    230    3262    228                       2606    201997 J   tokens_denylistedtoken tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou FOREIGN KEY (token_id) REFERENCES public.tokens_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou;
       public          taiga    false    232    231    3286                       2606    201990 R   tokens_outstandingtoken tokens_outstandingto_content_type_id_06cfd70a_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co;
       public          taiga    false    231    206    3171            �           2606    201621 ?   users_authdata users_authdata_user_id_9625853a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id;
       public          taiga    false    204    3157    203                       2606    201923 P   workflows_workflow workflows_workflow_project_id_59dd45ec_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id;
       public          taiga    false    222    3223    228                       2606    201931 O   workflows_workflowstatus workflows_workflowst_workflow_id_8efaaa04_fk_workflows    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows;
       public          taiga    false    3262    229    228                       2606    202027 ]   workspaces_memberships_workspacemembership workspaces_membershi_role_id_4ea4e76e_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace FOREIGN KEY (role_id) REFERENCES public.workspaces_roles_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace;
       public          taiga    false    234    233    3292                       2606    202032 ]   workspaces_memberships_workspacemembership workspaces_membershi_user_id_89b29e02_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use;
       public          taiga    false    203    234    3157                       2606    202037 b   workspaces_memberships_workspacemembership workspaces_membershi_workspace_id_fd6f07d4_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace;
       public          taiga    false    234    221    3216                       2606    202012 V   workspaces_roles_workspacerole workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace;
       public          taiga    false    233    3216    221            �           2606    202045 L   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id;
       public          taiga    false    221    3157    203            �      xڋ���� � �      �      xڋ���� � �      �   �  x�u�[��0E��U���ś�l#U)�(\�gjv�Zt���7H��%� F�짬��:O���l�zZeԾ����;���O7�~���{�[��U����gk�N�]㺎�r����Y�6ԕ�`J�E�4	ם��e~=U����\�\�/@u
� ��J �l��}�e��[�T�,�kw�MIE(2HVԇ���d�Z�sjH5��j�=��\i�R5d@��:�X,��BN�D�i�9/��g���>�첾�OU;�swt�F�0x�y6+�䡐�'��M�5���z��V5�ﱦ�Zn
����4r;�Ľ|��A�w�|��P-/���(�s��.�輣��.rAu��.p����^�l�>ƭߎG����u]����4K�lb�l8��,�a1�O�4�$-�c�{�&y�V�ɓ�'wRO�EI���Ey�6�A�4u��1��{8�\jh��
�Q�.>P�-N�=\����TZ�� |@�U���yp\Q�m�wP�L�]r?7�x��moQP�����t_i��b�H��y��}�1�C;����Oe��l:�uU�GS�����*>�IN&O��`
�y0y�I�u��תL�$���ZI�d"��$o��!V_�$ĺ�N�k��2��}��k6�a�=�f/ �	2la�y�]�����gC����w�p\���Q6c)Dɘ1��!���n��if���]��	��.ϰ�9����2*'ῷ�>N�����i�[���줌���6&bD�(�1
�i��t��N�`����nv�P�߄�6[R
�%A6]R����̗sՒN�:���s'�o=�[6e���(6iH��(2m��	�����x���r�F;t�F���EX6s�9�c�S$\�Zf�����U��-�]D�(��?`�>�����B�(����Z���J��      �      xڋ���� � �      �     x�u��n�0D��SŐ�TBނ|�w݈��!��Ҿ����V��;F�<�� �P�{0ZCd����tѧ G��5N��'�'A8�hpOT��X�w�ԛ@�.&\����զ��B�p!�ol��~+��X ���Y�����"YƙCV[�
����hà8��3�����)��?\ʨ�@�E��2?A^�iھV�@^��&�M��M�`�m�8_�q��@uX#�n1�%����ޝ2C�ͧ�WZUo�&������K���� ~9�݆      �   �  xڕ��r� E���{'X���0�&6�$T���";��/��H��{���E�����]�3U���"���#��*ǟ��8�&�&�kkW��'��%��0��5$Lp`�oЕ?�c�U[��զ�^��q���H>0���n�����o�seN�p���YdqDR,�yx�fz��'�1�]FIF���H�׽�A�AQ�
Ц�6�ֆ�u���p��͛�lsJo-���W3�M�!���U���(�Jf�c��\�o㲡Tq�y8��~ϨL�a��Z_-[D�le
����waH��\��(���"�R.�rG}�r^l>��v�9}()
�8�q�;+>����P>��'���EF�xGQ2�N���6LjMɌ��K���d��m�o׻H.�� Kg6��}W�.lm�!��kU���C�H�5��㹯�����!���"�%5��]m��MHe��@���KךÖ]���BV$��C� ����o�e:�j˙<���M\��)}7ή݂P)�#B|(��	�0�,?���2�Ÿ格욋�&晬,��8����Ny^�!Q*�H��s�_7�JJ�E�hѥu��T���dE�/vK�JJ:�-|O ��{�ā�@Ufw�'��2$"��_��n��>_:      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   A	  x�͝ێ���{�"�A7D��Ƚ�'�'��� {@�y��v����2]˂5`��j��ORv����������^��wr��C�H�ۿ���	��?��G����k�����:�wp�.�ͥ����$��;�o_Z���%���S�E��S|��o���U@�=~�R�T}�_s��/�s|5~)���%r�S�E|<��W�e|Γ;�/�E���>�	�D���_]��?\��0��S#n���;ŏj��Ɵ�!0�3�F��)~��?��S�$����y��+����,�F:�����%� �}�XN�?"������o�xw?n�~��~y���ھ������ݏ���WKY(V�䈙��u�q�\�NȢ���ad|yε��U�]ۨ��0�W|�	�U��\풯U�G����9y1}]�c0mQo�1���~�!�U�\f�i}�����h�u�f-% �ٶ��q\1�L���0�$h��[�䫡\�����	�3����,���?��Uj��ƊN���{�	�U5�e8�uV���W�ҕ��c��hN�)��:AS2���i	��ۍ�մ�ʢA铺�>=ץ'e�Ɩ\6�k�*��
>�	�UI��^*&��>�����`�|e����0�j�������
}x9=b��6�'��k�\?~ �C�����qK7�%�&�q|��n����a�d�OS5�SAtfk�?���W�$L�n�4��9�X_�x��;ѳ�	�5��Aa6���,����g�_�R�0�)�Oy�y��ԐL�/M����9��km_j��\��)���T��#{ŏ�j���;�lY&U����̹rWL������s<>�$�g6���a|]dg��n���{�j|�ΠUmԡ����8����ȩ"�b��c:8�,:ABy$�nыE����J;~���Uk��_Y�.W��8^5Ǘ>�,z��㒳a^_�)M����S��Gym����*�א�aZ�!��[ZOe�v��1qt>~>�����]G@���P5cJei�r�4���[�U����aU[�U�|UUK�b��W|���Ui�Bu�����6����l���wl�X��yz�biз�aQ�����5�$1��*��A��?bi�:8����t����<���5}�	�u5]0��ͪچ��[��WU5�D��~�?����&��{4�m�/�>-��#!^��raǏ3ľJ�H��l���ᖕ{�U�FB^Z6ۭ��D�v+"����/jvz�Ы���ˢ�>��� <z����IheZ���9�N�����_^L�Q������Ry�������~��z���v�_�y�x �nn����J)��e;�)!<c��H�1��o0|��)�EVL��|ϯ�O���^�Y�]Kl�\{��Q��B��k�5���+�"ЫJz���3�k?��]�ku��,��(�v�}l��v�:��K�&���B���<��Qk~��nu�N/�6~kݙ�nm>3�a\�t��oa�]��\	�Z���.�t]h�vv'�R�t ��0��ҋ���Y�������	�Uj��:�0����azU^��P���
��������
k7�oY}�T�iVOλ��\:�����u-v����Nm�]\5�|��^5\[Z�k+=��7�LMhw��R�-�ӧ8�&��W���=�x���W)��������s��ջ�V��c����џ���јbY��_K,Ͳ	�x;�nYi���x��pO���a�؜������G�u�C��e	����+X�ߑCRL���tt�;�Ubd�wJ��{V�cں_���(��{���Y���k��%WC)��	�UJsl��S�A/0�fjܱ��U���J��z�te�%g���?:��Ǟ�A�qq"��?����$�x�>��A`��J��g��䢊M��lqw�om�vӥ?���!��k{N�v;���~�v݋󋝢��#��*E燠QH�p	?�	�_��|F/d�2��	����>��v�v�J�Z����b�{fƆ�'�W)Z�x�������f���y�[B_����E솫+>��'�S�M�Vf��tI�88?��sH�tp����t4��!g;��6�;�u��|�͆t~@� _�D�'�~��^��(���-]Z[�W��-�,�¥Z*���g}���HM%��Oa|����2����qLu�j�Hy���������%M��z�\`����������@O�e)g\�|��kхٰb|q��Jvt�U4l�W��'�W�ᣰ}>��W���tCH/����\�%�0���?�ۭ�%������3�}����� �.O'      �   $  xڭ�I�9F�U��}ÆDJ�,��x�#4�ΈD/�� �)D��?q��"�6¯D�8�/�~��i@N��� �+�_����r��8��;����@��'� ���σ�L�~��=���K"N�ĵ!nK�6\3�xk���"�.����k�� ��/U!��8'VHٝX44JK�9�q,�Ĝ1�U�p�ceEw�����˹�s)��8�$}I\�pA��כ�bY��T� �Q�������"���$>���~�=�Am��'�n�Ȝ�9q&�tB�)hr�1���Ao⭘%�ǼLQ�x+���v�o�X��;ڠ̰pH�!
B?�vd��u�~�[�J�GA�4�Gĝ<B4�h����L���T\��|AL(ɛx˵a�ϝ1Y�!�*�१�s���1���h�)S:"�P�c�a,e�	yo�<�s�tA,��M�5�����!�'B�$|��!v��2�x2\��"��7��̓\���9�3�^���:�b�W�{�)7��
*6NĄѝxϻ��$Ē"zo��8@녎Q�m����"��9���i�<;�4���.�"YVQ.�����M��R�|Q��UIo��#�*�R����͢��0���t�-�d��"wc%&�&��1S�b�n�������^�t�
��#wK��Œ� 
=3���*�$�o]t���'H�?�#�SŰ_wC�A����t}^�n�L�rB\R����Lz�%�l�:��9!�y��"Ϧ�C<k+�S(⡊�Q��2�#bm>M��.�ݢQU���J��g�6���n�[3/�eT႘co⭴"�Am72)g�=X����B��e��9"�&�*Ls�q�`Q$}�Vl��]���:�U�J o�=���y���M6݈7c^/z��d�-r���V��GdĬ���{�i<����!1{o� ytf� ���V�#2/�%[�{�'j]�yFj.�BJs�D���܈��e�M���
?⭼��!˅*L��=�=���K>%οظ'���Vm7��aY��鸖t��2b$y�~�[��x^�|��[{�b�ydB��1���̣��$WĽ���+� ?�Joe�G<�����4�@$o�-����xK�#<1�a���Ҝ�r�Ӧ*��:$����{3OM�7�9�=�=�\�b�j�႘�ћx+?�b�����B���[�n���M��yj/�A:gy�1�Ie�q�M]J	ƅ���m��o�
���Y�w�o%����p�
{�t���$� "4�8O�!~:�_��\/�8���S2��2�7u^V�6Ha�u�O���X8���X<ZB�{k�!(h�ޓ�H��0��7�%E� Ϊ�M�7�f(�\��7�^/V�͠b���L~6�J�4�o;�x�w�XC�E�Y�!�pnV��zC��ɛx�ƹJ� ��7�V"d.[�.�3��6�ĭ����c%��L��c?�*O����*fo�D��i�x�n�e�t!	H��"�ʂ�b� ��M���zQ�a��6�U2��".a��f!�gL$�f?��1�*̱���������(zA̠�V7?�=_1sm�3z�9�Yg����ۈ�#�*@J��.�%�7�7.AW-�?�"p&����f�E��Bѝx/�/��~?���w7z��Wm�V�eqY�+T�1��)7?�=s� Ąo�G�I�].T�����U@əx��(<C=/��w䀽�w��` {�!�q��E<�.�D4a����
˂�tNL�+~�+k_�%�A	���ooF��]�,<MRV�%�U�h�xJ�b��5���|��~��!�!�xd�!~	x���!f�����!�4�
��+#��x˵I�P/D����E�S0qipClU鑍{��ћVE�p#
˩�7�N�1z�N��w���3��j�t�[��B���*��g&9!h�A�����G`��8[U�� ��F�EQ<l<b
킘@�m��#`K.6��Ǉ���<�?^��� ���|�&����&��Ԋ�r#]���]�g9�s�gm7<�1Z�{`�M�ګ���i	�sb������%S+o<!�U�۴q�q^�B%=E�.��*��y���f�2���|�6����!�`j>&���|♆�M5g��+��,)��AZ�0���g�c��g�=C�,���*�$�ң-v�� ��?�؂�y�j��">6.���'��ClQ~q��Mq�s�13�bIc�u~��qu���"�:6i�*�����Z� ���=������8c2��B,9&:'��=k6��t�#�S$�xnc
�n���.v�aT��g] ����.�]b��c�R�<�y�>���K��
���.��%�6�<5�.q��+��T�����$�O�i/=V�٠�uu>a�8��gG �w�X��F�0{q�nH�p�� >��7�1��c����c�^b�A��b~��G���Kz.��%�����:�,�S�@�B"�gEz� ye���p�hΔ�tAl�-2&���<۴l�5��(���y�%f�*+���DG�}ykޞ�sJ��U��4��s@\�n9r��y9�~��϶�g��.q+�\l<�LĒ�k|���TG�>6�#�y�����Y/�$nH�bcUMG�J�~*��0��l�ZU�ʟA-Q!�l�&�1q
��Uh	K�*a�	�,�h�=ĖA��Xm2�>�0Kq�R�I,"p�
�%?٦�r]Ƽ�kgU�ytD�!fs�rBl4q�
�<j[ ,��9d~>(e/=K_�n�2DU��Gw�>��{�w���e��e㊌G����K6�ie�ZXN�-�D������@N�c,�E����]M1s~m\S��=��R��E�Ug��O
�G�5��U�ll�r>��ݪ0k�sY���qu�잍���<Jbxvln7쫾ۦ��ώ�=Ĕ��%{�Y�n�ai�%�h��_s�o&�G�Bn.���0�9����WZ�45#���ν�s_���A6�uu�ǖ������)q�M��>�����gwc��LYy�.9.j{��������&iU��9G�y׈K�3����҇���N�R��D��G&>�#h� x����[Y\m��q���+�pL��`}^�t����W����n#�N�Ή!p`g❽�F�PK� F�� m��du8��r�ۡ�c�m���c��b����9㲞�SE�鉧��C#|��q$�RE�|$3�b�_\�&�)ړJ�yA��!�I���۞dS/\������+>��녉���;���n{R����Ҟ�{�?�$�ҡs� �8 �!n��X�kӍ'�^ �VI�s��]��y���������      �      x��\Ys�F�~���%�}����ggw����c^6b�N�P{b��f��Hv�d�f-�d�������E�	��j�%a�����#���2ō(~�mӮ*_�]c�6���"%� A	Ra��xk;�rm(}[�]Y5 n�P���o
RS�FX�X}��w��pN8���񤔍��o���Ĺb��*��G��)}�<qTp|��~�ھGkXYj�U�)vm9�u�l�c��o���Z(k�'-t�B~xx�D�a��X�r3�U���Xw�]�í����o���!��{��l���H��\J�XpV'�h�<j�u�h��R�4�B����#-|��)��ƫ����U�](���v����6l�P=Tî�'%t��ΕЧ�e�%��v�t���7�)_�C�P�.��rm�?�fQz���V)f[<��J�I��X�A�p�:�Bg�JsNJ]T3N�K[ۮ�����M@��bS��u�`̦̀�����.�ХK��V��v�Ǯ|�L�#�1S���Q�zp�πè��zF��B-J�gi�]�$�M_��Hg�\4�b���?�Ѻ�vC��X��!�e;,�����B�l�u5�T'&��T+9	HͅQ�ٌ�� ��s@��]}��n�B~i�&��K���vA�4!�I^q��X]*���QT�����ޕ����"�_ٺ�)?lB���� $��؛B����o��[����&�#x��@G�$��Q������4Ic�8�N��0N'�;K9�eb
v.5rU��N.9�8 4�����+�x���Ǿ/�3-��k�-����ˡ�W}�b_B�C��[�e�c��|�)�,d 0خ�}N��kW�]	�������˙� �3X"���r��6����2r�H��� g��>�.]ױ�x��δГ�+����s���<BE��rѵ�r��;�xH�#u�b�n:@�P�æ�cJ>[�j�zب	l��H��o=��U��P8m��\�I(^�9�A't�A1���u��c�\d�>�PA��OAo��[~+�I�&2)͵���u�ń�&Rn��Ci�6���2&8:�Z5]�@��9G���,�h�g�z�����׭�uY��u\A1+���Rt)Ew���P����e�4g�Zd�Wq��=}���?�}~ ��ricY�23�_9��
`�qJy�48N���e$�cyւ!�*�$��B)dt8�iKX��L� �D��R���(3�z�}��9���L�P�;�^Bo����d�Pأ:��^UG�����U�ٵM�{����ݡS�Un��(�P7{2��uc@X�� �D��+)O�߇O��m5��c��"I)�f��$5�B}aI��r�:j2�᠕�f���C�B��DiS��k�>���{��'9:�##w�zY�s�(4��>bSA���5�n���5��)�߄��:��#T�
��?3ɳ4X�`�$�h��RA^���̥�5O��/K���r�*��b=�E���.
����e�#и���Ų�[_�a7Alaq�I=�t��� �`��.�;�斮h
�z&�S|h����z3��6�C@Ǻ��Zظ�ů�K3���өM	²|����lT	ס�?��|@�l�,��E�ϣ��C"�؁���c9�힔M�^�}�5����Nl�+�vDh8O�9j�'t��z���{��B5�e��+!/���_�D���c�J����2+!�������Gg<�Fh�'��D\��E�5�r� +B�n����$�(i�9��
6xf-��Tj7x�S)��L�%��P�Pw�,�)��%m[���J��n��P�C�v�#�$G��S����ݕ]ۮ�[C��zU��|s��j�?�V&�5��P�1�� ����}��%PNW�p !zC�����5��8%��� Cd%:�JI\Ϟi�����֩�[�XTO�
�$F��@��}=n�ﻀ{������f��������B)T:�P�^x������MRs^h0QX�p�U	ڜ�.��� ����I	}���G��3�}[�	H�_�m��m�h�nXޔ��~��:��qsf�3� �ɤ�e����� )]߃�j�5[͇Hn�@�m�3)�o�}��|�謇��P���e(��v����N�i��M���&��a�w7�"���A���:�����pk(]�;���c���ZnĿ��)M��[-��4	���8�#�q������ScL1e�,����������f�d�P�wl�_�v��Ϲ`ߚ��~�<��&f���Cs����Տз�����xf��F�M(tU~3�@�
�XBa3�;�P� �i��֣�8���	i��1<1H��Q8i�W�6X+>	5H/#�eP���LDD$��c�����q�6櫧-��Z�~�"'�Ά�-��-��d�7�'��^z��^��#J����ď�fHfJ�ϔ\j�/�[U�Cp��I��'R�ۻv[�}	bȿANؕK������q׶��~m3y����α�_&(=���d�X�����GX�8X�[���m��ַ��q��x� N]���b|����Ń��^;^^:��������߾����ןh�-�|�ֱ/����j�۰�Ň͸�Z�$��;^>o�C����`�2n�δ8S��	]�Y B�շ�OpW�3y�5��07�YN��!8�������Q:Le�lN�t����6��23����$Py�@���C��4�4�q	wmXUͷ��ɷ�\g̕we��+��v+Pa0\L��:?c*�"�� �fz��A�䈞d���o'��(��<�DM#z����C�C~���=��Gq��2��Y�9k�rMR�a5IR�ȡ�ϫe��B_C��x�,�k��{!F�	���4�����Yz��+"
��xQ6"�P����uD�v8��m���G���v��Fk��������P� 8�Hp|n��S�lf�Q[�q�r�jJ|��
�ڳI`A��W	$%���G\9Zs���~'�GLO�� �}� �/u�B<+a�~#�#���#���2�7�S]2�2%Br~S�1�T_R�u���u*w__O�����_��2y·iϱ<��g�� �����9�!��A-��j�`pZH%=����ʀ��[���W ���4�_LD#X��k �pT�:X�'������e�%���l�za�b��K�R
=�p�j�6��`��W��+h��}�҅���+��\x���*��i��K�Oר�7���WgPP��TD������[ܜn��ۥx|1/{~i�b�&�(��.���Kx�p��N1�,:�X���':� _�[ʈ��e� �o�Y�uI�+�5Q^,d�E�\�����"�W22�d�
�FH&,��+Ct��G����+�'��Kq	]�$3�a��5@$��3��a��Y�CGf���=_�~f�,�!�`�q&��'�x=]y!<�5p=����.X�/���(�Ц��8COOt�y1�H�9�-�S�g�JQB�����S.�?`f�t�	E%���Y��t�$%g��"x=d|�-譛EG��I�w�፻�����R��2AR�2�����| *���d%K���䩻+�YA�ddf)5�{!z.�y����3?�m���u�@~��{f�S� �"�Xz���\��,�$|����{>K��ShM��$e�Z���@D�VF,1��h�+"��5	Ol�d�(��9<��wZs1�١�ߍ�s�덫+�Y���ƢQ�B��Kc���H�5��1+���;��<|���ѩ�6,�-�_T;�0c6Yũ�|[a�NS��L��P"*��K���6;�i�V\6�(��_�fY�t�y�8�"�l�qy0��o�1�D'%4*}a����Ӣ:b�]9g˳m�I�3&��%�c27���!.9N39��	�s��̢���;< ~����X�w��k����c��h�NZ�ija���^G��窯m�)���\i�<�%�~i�K �  <��n�ؿ��b_�AJD:�S
i,P�7^$�e�2ø�@%14˯���LCa�6����?`Y�T3�IX��9k�WXּز�,�C�����v@ކ۠��+퓦�s�5�*$���)���U
�����j��a.�௴�F@�>mY3�L+�c�sͷB�<K�i3�� &mzv 2uv�mw_��gF#�TQ����8�~�qg�^V��l��r��)�8�m�$_7��y��K�[?�I >�F-��P�Z8�OVÌ1�{�$�(UB������0�a��3F:I�{�$���YF[E�e�љ���	�|�����%l]����ʂA��:�@O�-���m]�e��3���85	�䁪���]�w7���Oi�*�h������aY�[ ��4B>����یÏ��`ݴUL$%�JA�ȴRRD�5�6��C�s��e�Z ��X��*

ޤ�8��<�ۼ�|�x��̗`�ŧWO��UX�s�'WO��'�{j�P��y�z�fC���-���|8��e��V݊)<�3W�����9���&���Ԑ\��w�X�����	8@K��������DK$�̑ˉ�!޿tm!942�w����i������
:���.�ݮ�y��u�@�߇Ƙ��m6�b)v�3ߗ��Ci��`�=�9�D$J	I�XK��RC�M*H�i�&�AE!ʏ4��+&�K2i��U���/3���$�����Ǚϋc����I��\���"�{�?�mە+�;�Ϗ��y�	�������Y&0T.-w������O+��<�l)���h�c&�Ƅ�%�y˅���,Z*MDA�"�a<e�i4t�l�4 5�L���{�0tѮ����d4T��/�ER8KF'�}Z��S���:��u�em{�ZϮ]�����m�q���W���,�жu�/�~y������MqS����d�|4fv��f����g9���%Ҷ��A��y:�)�	�m���)����a�6$G�W
xOP@%�vL!nw�$��/���[�f���I��P��{�!+@�[o��A�39:ɑ�-6��{������%���	�K�tS�{;��M
���Բ� ���+jL��y�8a6��8�LG�܇���֔��N_c����=k:
5~���I�3��}����_L�xlɷ�O>�o���bt&F'1��6},~����'H�2���N���g,�"DO�����WNΜ�~��P������>���εГ�g�ܛM��?�>�㩯���&d����o���n�����~2�J�B�d,g){��X0���/%���no�ޮ�����7�T�I�������l��W��/��ri��]y�z��H)=o�� - ¯�������tl��z����󪇳�Mj�*��B��� =�ݾ��]�d0�| k�-`�)���|�ؓ͜��kw�0@�O�S
�4?��*O��܎1�֊�y,&�6�������+�5�>�w�	�l�M~rG&:������ TmD�3�[���!����"�e�ޟ3���2�[ߘ���O��2�~��}9nG4�Q4�(& )=0m�-����y#|	�BFJm
�$�g�#*x�G,3Z�k(j���$� ���_m��F^��	�oK�Ǎ`A=���ct���c��	x��e�ݳ7��x����:�c�ob8�K
c��1o����[M���w`��X��Sp�#�����T����n����\�=]      �   5  x�ՑQK�0���_��&i���	��胯s��rW�d�f�!��&m���?�ڞ�����Z��V1{�z��_%/�/�f�x�7��e�PR��_��y��`Hr�������p��cZ��[R��s���9�U�HM�\�O���ܺ�!j��s[�j7[t8je�ܝG�Ѯ*��>EE=��@Qv�Nl.s6�@�ڴw3Z�y9m����g�Mz����o,���}�w$����<�A�˭iM�]�i�"�s��ш�2��$���mc�(%H�H��Y&��so4� 1�\%��ŏ,{�Ͳ�9Q      �   I  x�՝�n[7���D��6$�
]�(��ԉ����(��=V�4+���x�	����΍�Q��,y�1�}2�p�B�1����y}����t��ḣ����O��盏��;��+�������+>\_ˇ�Coʕ��s}����s������'�y���s���s���s�|�}�]؝v����1����ȏR�$�HW���/�0�u���%�F9z����0��e�r���h#����Y�!U�[gB�:ZS�5�cS�Ț�H����?�G�ų]M]�?��K%�:Zs�^�c3H����)�Nu�vIõ�[׬N�(^u����<�9y� :eg�񪍰��<�Xp�UJ��5�1"Hf���J}h�c{sf�y���2����9g-��z��F8�����|�4�-�+^�a�S)޽pk\3kޣ���k�a#����z���4�Qgh�Nn"l8y��h1)����jWm�=
y����Vi*e��.g"���?vP�d&���FH �s��[��UJ���4R��<�G
�>��)S(�k�h!\��Cpb��RVf���FXsl�q�!5�٢JY�Yu��>��Sk�`��yj[ύT�"�4�4�0������ϻۿ����������ː��m}o�0a}
3'��|���G9��������7�^{ �	�RP������Ws�����|��݋�ϩ=�Vpj��ڵ��l���ӭS#ᤞ<����z�(�SC�/�h@RJn���Q"�*�J�t�H�J��uD�.*%�םK#���Υ�IZ^��ӣ�W-�+�"�+�@�"��34�:�+��9�XXRT)[Dv����6��q4�M���o�o!\+{�W�p&�rRs�������>��5ʖ��	-a ���z\P�TJ&�:��&��c�ԣv�e���g�Sl�ex6ka!�R�4�.a�MW���s�V�(y��F���g7��6�-�`�:ZS\�<��(t�2�5���6ae�:��BS)G���0�4@�N��)C,+�����sϵ|�P�P��*X3,T)��5~˄Z�*��~���Kb��)�7O�i�!%x��Be.�(9a��	5�k��r�K)�1�����ʅ�p4pv�u�	�k�o"� �{6p}aP)K������Y=�U�a�#�v�z��F8jtpP_4�J�+7�:Z���=?�rѪ	��u�@n����"��q�=��#w�;�6�1So�u���
��4�n�9�y�Ej4�yK;��Ua߄�lW�dV){�[}��6�m5�y��>p��\|n	�0�:R�>kV)�:��F�$��YG����0 U���`#,%���3@hA��}�9&�߾����B�O(      �      x�Խɒ�H�.�����v�0w'����)�t$u�ڬ6$:I��b������Pb��$�Jc�������3"|���*����?�/�7��^�W䥑�0���	<� ��//u��������8��8��=����]��߸���v�ju�~�۝��C�߻ղ�T�m����9ޝ7��	�0O���_������>(������i��o���U�4��.J��_AP�c���j�*z�6Ö��6�ݾ7�aٮ���f���bS�Ū�,��/K����?��]7�>����y�sK��N���8�u�4�g���bm���uo���}��k|�UѮ��`ۛo�����M1��u}�M��{o����/�����o��-w0��}O��+w�}3k|�n��OptW��Υ���ܝ�o��	�-�UK�;�J�w��/஋��<�~��Q>��.6m��e�.[�A^����[�S��UA?Xᚿ�����.}�>��M�~k�=�G��άV.Ec�m����-��E_Tr<�����?�Y�U�}_�HFA�W9�Y�d3�i��^�#:WE�SH!)�G�/�s)��wX�1�;
��:��'δ=�����T-�K����rV��/�_��o�|/�n���߇6��,Kn��Y�g3B��q��F�K�;:�CKq�+?�q���s���cY�������z4��{���\�����_{�����h��K���	��a�Q~�fa�]%�E��1��H���b�
b��]/���]�U��v���}�荼�����rO�J��Z�9�O�+QZ��U�T~5�%~#H��ܥ۴�5ݵ��o��g~���*��o����;'�y��jg�*M3#�&y��I�w�����*du���[���	�\HBo=k.e���]Qv����,'yA��<(.R��)s^u�m�9�u��Ⱥ��
��i�q��FOP]�
�([ʸ�)L�QJ�E*�iO��.�1u`.���|�e�����0p5���5TW�P�i�*���n�<�I��.��J
坓}���������1a0�1��ȗ��Û��2�T�]��r��J��n�J:V�wN�}H�*(��*��MryH�8ϸ��}��~(QѯZ*6-eSs��E���7ċޣ�����2�ۨo���&���$���򛸹�EJ����ί�pnIq��׆r�@�5���k���K�Vh��羢DG%|�����G@�Ը�;�gP�W����_>z�c�kN����A*������x�)�O���Pza2#i'��yC*ݙ55�?�-e�Ū�3�p*{��o��^�BC=����;�k޻_�pW��Ԥ�%��^q:pC��ۭV݁���[x�'+���<�A�kc�k���8��}ǃ	z������'K�i�O���v����.�%��#	G�|2�-Z�����Ѓn�׍�H�2�^|�n/�\��`�����i�{�C���/�;D���� 7�ID3"�{��X��R��m�;^ ��ʶFg�����K
���g�}Eń�e޴�ۭ�����mW�V��ތ�%Z�����ҷ�ӣ����
\��]��z�M��6�N�G=�۾��8�<d�����_�ш�_K�L^��VM_���x��0̤�ȝ_u�Pq~(�u�s���-T��ơ`�(������F��袪üc��kh(��Lf��6�uŗ�i�f^(����d�p�ڠյT��p}�k�r�|s����w<���F
;��j)�kyP�6�j&���
���Q<� ��z(fMg���4��4�M�WTh�����J��%��T��+��-���o�3�b�E�?ct����_]#<Ƌ���.�X������z�?(?�N���5î(W��	À٬���]�A�4Q2n7�h-�;^�`�������E�v{���tzOO��.�kL�yTD�������4���{j,�#�:�����R����
lG苽����q�(w�t���S��[н�7<����/y���&]˸c)�����d�cg�T�������U�-���џy|��vh8�[<h���p0���ݸk��f�2g�y�I�:����Ary9��^�2��l6�]��/Ή���6��������PM��]��~+XXщ�_�4�5�d6=غ$�i�L����Ϡ��bF<�0JeLO]瑂ў�.�w�^�.?�����}�I��_{�j��ٸ�����N_X���-��M�y�Ǿ��P��mk�qR����ҚG�P��F��T^'�U��,�|ܚ�������zCw]�n���������`�k]s�v6��b��^�?�gܺ�����*����%ݴ5��EOg�����X��f�ݹ�c�;l�z�e��!�}|6�T���!K���q��4�3��~�P�k�����B�R'�;,ё��}w���Q�*Dc�w��kVe�*ZM'3jY�B��E_���G폔3��מ='jסC����R?�pPq�� �汻Z~����E�?�2] �h\4:4|�d�1�gw�>�T��?������+1�@��'��U1;9[�d�Q�I:��&y(�8#���**�[��?,;�\1R╡�*x�
�a�H���4�e1�iJS�Kt�/����䬎�/�8��:��u���FJ^M��������Zǩ��"���G^������֢�)P5z,1��6L���s��Rw��#�xlk������}!���s��eHˢ�>�l�񸇮���`�L�f����kRe&��<���n���Q���N�a6Z��:z�P�2pCc9������&���*�J��G+N�<�1�*F6���$Of7�0P�Ф�mO��C�Tpװ�E�4��vY���<h����:.}�;z�\�2�)�=ntf��:�P����.uC=�0P1L�vE�o��V{޳���\�nA�F����zhB�I�=t+Cz4����,����K�D
�ϻ}�`�_�`�����ژ�"�4�x1連W���c��}韛�:f��}/;�5��to��2NA��d��@@������Q1�K`���ow|��s�̍����j�	M¸��X�͝k�����Wc��aY`N󲫏#`�M�Gb�Y5���֮��X���-���=@��q�g�*�B�� ����#�ES0P�P�l���-��R����xƩ���W�|���!���@��US�ь�?O}?Ӊ�k:
��U�ã��s1%�"�lV�������i�5S�W��*�*�,��,����}���°��N�`AaC2kl��H��Ep�%^�܈��mm���^�����C���=W�2�-�����5�T�u�L���哣<#��e��XN�pj+���``�(�ps�ӎ��=f�-��H�{<d�����%�F�է)el��gbl'���q1������:�6z,,v��a3�M��t��#K�u҆�k��:�A���z�XI\Zm�-����G?0������=�%����]Q�0fM�ـ`�{��Uxw��v�e��tAj�ڬ*p��@�{���}�[h������,��>��[�֊V�Ʈ8��L������N4�?Vd����&//�W�aI����>�C��'b�#�L#!�~t#�33���3�eO[�{���ˋ{ϏS�Z��?�nLI��[�����^�+�^^���tz�����J�|4v��jN�� �#��,t����~0��c6��(0XS�TvG���R��㴃 ����	�\R(K�Df�k;G��	����\� FH�XL�Z�~�7�/��(n��u:����0U�a�ψ���^W�N�EՌ�+L�8T��[���pY��wJZ��R���wz��fau�w���0�x�O��B�Z���dt��+�-����p?O�aUvj{WB������`�Yӿ�Lqy�bߋ�K��́z��bAO���Nk$:3ڨ�j����`���^��Iu�bA�A�����S��ƂQ`>:<P�=P��a��Mv��HBM��=3}� 0��Lq���)�8^�'K'�s���� ���    �\#,���!#�7���S��{st����|i����?���o�W���zj�0�Yԉ�B�,?�+���vwy���5�C+�
E&*q|��Z�3�M���-}�Yt�\�Y���}�����24�}Qc5��� ?͘?�}^���[��[����OY�,���|��o���΀�l�_��~��F�C�����G �M�(�J?�<D�=� bH:�}o�5Zb�{4�r�>lx��o�W_��'��xϰ,�#�P+鸲�A� @�	�����0E��Jl�8���U��uc4T�m޲��`�I5SK�p�]G�_�6���[�%���_e��޹��ƀS���� �T9��i�-�w�����[K}7�Ep��PW.Dw�5~c� n� Ɋ}��Lz�������:}W��G~	*��^��
5������%'�������"�Q�9Gt�`�^{e�53�Q�������1����`���M�g���4��o�/�S�ry$��!�&kq�t��QA�ʟA�X�q<�Q��$�1�W�=g�o݊T�E��{�9��-���ﶼ-�s��:I���6����χ���<9�������}[Ϡo��8�qr�4HyvP+l��(��p�
������K�j�h�s��
�G�r��=bx��4L���Ϡ:7qQ_^�Sm'�т��ڞ�R�J*����U���؜��+�	*(N�3(؛:�1t��0u� r^v�����Fn�获q��I��n�:T`���p���Ww������>�3%��_���*��W��>v\e��QZ��'d����[�l���M��~^p�u}�i
oFp2ߓ����ċ>�΋RP_{^���q�Xv5���ϟ�0h�w�2������MO�����H�w��p$OJ�R���X�B�F(`�V$���bE�V�<���&?-�Wkh�:����e�E�JU8oT�b����I�BX�'�=�,͠��3��5!5^�$W���~�����a�@��Z,�T��UW��?�E�'û�J ]v��ҭh�(���+��\#\�6�p~���t��4#D��h���G�q�/v�?zn�Y��~�VX�X�8�[=�gh�+���Ϗ�(��̏#�o�՘�a��Q���f�L]��k���� ����B5���!����W�2
E���w�E<z�s�����T��X�~^�������pƣ�/�W���)9,`q0�����Dݣ""����4իM�]({��G��N��R� ��/�n�`F��Gy�+U:�=�=?�f�B�Z�Q�N����(������i�z&n�1Ĭ�NHl�8�"�b"��r�7"�R�e��6��cq[`9wvpI��=���F�#�S�m���Gݖ�X~��f>M�п|��~�Ċ�o�<�b5t.�����D^�`����0��#��`<�k�{��q7��S:ߙƽ�����BI���h�H����=�����k޽����D�
��mu�%� e�Ȃ*}�F�����FU
��`��
�6]3���L\>��(P�9L�QZ�O�2Ȟ����)LĢoy/:��`udٯ s*�q��t�ɺz�I_0��l�y�Xi6K}9ZX�iI��#}�ez;a4�	m7��&=y�E�_�j �TԧoF�(D�P�#�{�m4��}4#�n�z\�jbd�Q�/`���@_G�@��������D~���T�Ba}��^����� z��øZ���C�CtD���}��M��<�e�?hY��qs�+x�LX�Yzys�G)�$v0��Sa��1U����T���jR0��ߍeX����ﴠ�'M�^����o�:7Z�6���!�v5����
B�&��1�/þ���-7�(�+���{�"�//V� ��HQ:/�+�-��0ϱ+o�)���x��h����k��W$͌d�*���ъ*����q����1[�*�10N��K@��!F�8�~�1��@�5s̮'�	ў��
�;���mQ�Hs?��-�Z����/_�Q��(�/��X"����r�9T�3(O��u��TkB���o��)K���y�v3�0���c?�-��rl���Cw���x5�Q�琁�l��8�fLW�8�_!���2�?��?Q�����s)y���`���\�k`Lז@l}�C��A)h�vM%Ɓ���O;m�i�FՌ�$��qA��*�
ݚ'dx�z�*��]��b@+}�j� �b��B�馜ݤ�GLL�7��OMk׳ٝ��=+�(*��4n^Z��o�9�j8`y��NZ���(Ɲ�<��F�Q�n��e��=�-b�Q�%�����6Bᱟ1�u�Wf�0����?����4` ���\�+��,� �:Y�x|�V�a���S�SA�tD-4*ܳ�(?�"&Ӡ�� Lf��[4���L�,�q��(�Cق��E�7�>L!Ы�.��i�nY
��e�ʾ��8Pd�s��-��aV�3�pa��"E��k�����(��e�0���f��2�	����΁7��.23#fY�1K��j���0"^5� �Ƙ�%5��xJ���|�,
�5V��\Z.��Fn�9��ÛQ�.R\eC�����=�k(ډ��=dQFםiØ�b���1!�D��r�G�4yyy��AO�fi	�pceO�(���B�B=�^�]�TS���)���~�Mgr���
��}�umy��L�0�V�M�{"#;kS�T��5g�S �?7��qk����+���o,z� ��?J�b�F�bm]��;�Q<Ǩ�:Ъ���i���d�i�_���%��o�������X|/c+�weiLzkmd���=����ګ�˓s�{a((����~/�S���IE����\|�������`���g�VGq�����$�r�d����Ii��gX���1�q�������CTeM��&���]�I�ܿџ�8/p>�*�e�G��A[�v"+�Lo ={�n)dXX��8���8�j�r��0^�ip(���P�O�G��w��Z�.�6��+5y�̄�S�<dk��B������^g+m}Q��_��b�bp�+�r$x ����73���V�/�}��[pG��j|��^�PTԢWE%�-6*����Y��ӱ۳��n��U|è p [7q�a�珺q��Ly�s{��~��]&�n���FL	��*��
X�DkF���'�1��S&�<���#���{(�QX���1󳬸������1��Jn��]k
���;nϑ�e��z������Yst�Sl���Nܣ`�������U�s�dq�G�����-*bA=�I��נ�X�V&5j�]��@�щ���Nt¢��D'�@���� �-.�c�آ
��3��G��<�u�L^���IE��3ߴ[<��|�-�E�o][[׉]�����ԇ$	�9�v�"��0_hr+��?;Λ�>���4�l=v�����65N`�ov��+��VO���¢�'GkvA����Uj+3��_@5X����bSJm�vb�L_�	 {�@߁���Sũ�nC�P�؂��:2���>���0�Q�YբYY���(Ƥ����&JW�]�r6E=�ܨ�\��t�o������9����0�-���4�u.,��tF~��<�����kJR�����``GkM��7�73���;��Z5�1���qU3@sn�˖9/��H����T�� ��y��P��2Tx�cC��S�8��-���`��3Lb���ụ��MPˆ�����gj��g�a9���Մ>u�,�9���C�m����F 6�D��B��2�m�3�|�:Y���N�>�)��������׬U�вJfP��Wq*���_,���7"<>^�S�HV��{A�L5�(�������1�Z���ƴ3�.
;N����� ����8���f�)H��
���Ѻ'd#�'X���R�5ml����6����{͗�j��I���\��q������hꠐ��Z�c�v�*����(���Vz).H�}c='޺Sfݯ�rd�o����(    ��AM�ܤ�Om�(���1C����ĳZ��H�s?��jތ=�.��0Cq��uj��	��<ݹ'�a$~�3"{Q*������4�n�Rt,;��C4�3�PV�m�9��&��Y4'hI���yK?~L���k�ڴ���z����k�e�)��1f��k
S�q��B����EV��ڙS�6jjS��P�S� p��Ƕ�� �;�|��C5��~���H����6�TuŰ�q�*��=��k�[v��Qw�<����s��-�*\�9ḁ<��>dy����c:��1+	�Z�6t�e@R�^dQ� �Eg�*��^�/�L����
9G��b�zM:C�;��@O���1�HQRe�n�A�����Q�NZT,�ϴ�;`DͿ�m/��=O��~\ɯK��Q� �T�g�+G�mv�k;�詋����\P�;���Kftl�&��Q�Ҳeo�ދp��ņ����Z��3�h�i%����ߊv��u�J���͊O-�j,#y���Ó�d���Բ���/l�'`�͈��m]h&!��ް|*��G��B���`��9GY������z�"�>��#���a��_��h�;t��щ*{��WN�Ҩk3�'�je�(�����U����ݙC�|\8��N���3�Vie�Z���|�-bL?<���rc0"Ǫ�'���ǝ�U�[P��U�Eu|yZJ�
56r^H�3yh��'����T)[['��'��lF����q���H�t��c�am�|��h�@<�+#�P,1A���a�+( e?O���d��v�%��&���� !��\��z���G����¶�l�l��(!����Ug��<Cu�~1�z��4������{��rs�m��Rc�X%?-V�{���/?a����ɜ2
 fLʓ���ڰQy]�;�"�j���Q���n(?�6�b���:�ò��S4y�#�EQ3�q#K� ��
�e�e-���P�LX2�E����������('���y(Rq��C��}�d�C���8���fYL�D
�߅�g� �U���ݏ%��]����S���ɛK�O���A����!�ћ'���c� �<��G���h{p�����%���8���k,6��U��^��Q��3�3k��zI\%�iQ����fi�ş'�Ga(��x�I�v[����/�6k��ۙ�ޣ�������fL�飼$�RO�J�=�v�6�T�j�8h�϶30#�3k�vDUt9ǣW<�<CZ=�5{�@�u2C6�C�W����cu;с�'ۄ0��*��Z�ƺ`��ۑI��;��mu��c����_�7*�Q9�������DQ0#�yh�������ڡYl<���wV]��S�+���N��	�0Һ𳰐D�u B���214T1sJht&[�y~�O}jj����	c?R��2)K���J;9*���+�����c)�QE���e��4�ob��ų�����/�l�P�::���a���v_,�TQP9.*%�2�*��O��'��}�;�+$0?o��(����y�x�r�0"q��`d����f��`�ft�:~��j����<�����1��U@�(�L���ʱ:������}e�݉yb����n���r,y$J��έ�t���<Eߨ��7��?1��6��������$l����2���wu͂�j���F(cO�<}�y/�`u��-k���J��)��d���9j�e�3�@dfM����C@^�>�v//S?�t�L9!�|K��D����4��<s��
����f�Q�H�����y����%r�{e<����hFt�X��Yx��(�q��{zO{�b�U	��x�k6����\�]O�;�7zd��&(� F�^@kSyW	�	��S54Jbߗ��R#'Yɘ��|!�zY�0g���i���D�j���M��(��.)��L���z�6Qvq�Lq��D�#�%ް#c��-a�i?J�]�*e1R1�P�mb�"���JQ=�a�~�y����=�Ǎ~K�0Rg0���u�9�'���V�O��](����+!$
|GDC�E�B�z���;��f��� �]�����}+��I��'�T0r���]�t` �e�b����0�	`�9�v���n���(Spb��ߪЁ�mVwY����e�0��v6�xTz���3/���-�8�f� ��e2��+�x�.���J-S��\�w$r�K55��]���AbwPi�-�?����h�h߄��KY�e�}W@g��L��`b�	��:��4#)��ϖ�b0[2K�8���cE�A�`Z�(G���� `�`���P;ʔ@��by�F��	>#Ý�1"��U�HC�b~��{�ZqQ�{y(�1�It��w�V"?�0�ߌwE�y◴�(53cf��w>3�'��/���>̱o橦ohſ����W���S������0��g�uлa906g�V� �_1�az��9�����1>�]U!���c�6f�՘�K�M�?H�J�"}����EfE��B͈d�fZc��БZM����WH�
b�2���x��8����;i��Oc��ħ�͌��GI�)�K@���/;)p���(Cg;��ӱ{ü��#c�iq������c��SF�h��E�-NP\��J�gţ���:M^U3^��K,�ź����S�U'+EVw��6��v�d��"���H�YmY8��Ŝ�y�,̇^�#v��++�I���m4�����q����o*��&y� &�PʓA%5*ȶV�#��\{@8e�=��O*V �,�,��,��v�i��#�m`��B��r;g�G��i�I�
<���T�ڢ�w"?gt��NL�m�^���#�<��z�J�*�d�I΢\�v ��؋T�$ ��8��>l�g��&�YYr�a�7ٌ���&��v��i�D��Z'0ǆ��W�k�wR��8��q�t��)��fF��BO���J�]};�[��H0Ĝ��k+��0$ED��� E~u�:8�'ǟ�.Im��$�~|�q_����2Z�˴�TIj�v㑱��:���$�Q��I���[�Te\t�U(h��v���8����7�Zu=}Setyt���&�}���T����!��B�+�	��<0a�GꃔƗs�)T����Eώ��A:F�����{�5��^y�@\^k�����~PB���&^�yy2#��EJ*�jX����H����_lEţ^Q���\ܤ���Q~�cw��>���wĩg�̂�g�d'#r5N���M�d�{�����j���֨�e��6&���2O6"0;�)1kH1���Wpr|��'}#3L4�VGqW����
.��·�s00`���⨌Ki��V�v��J\( 4?�>v��aQ=:��*G��Ms��"PJ$�v"�;��A�G�ܾ���6�&�s� ��n	�y6��&�H��v  =�ݑ����k?��2Va�G�7�AAj׳��e��NV8:%���t�J�v�c���f�w����S�{E��"��vU�W͈Q��A�+�7�s�V�2��uv3e�z�'Ecэ Uh�9��G�,7��J�bs��g
[�$ҙ5l���Uq������Ds$�Fg��H?��I���<	�>�2:� t����#S�*@�^�UC=��<A��b��9��B+�e��9��نA?"��DV�����,�wg��t��k%��k#5����,�:��㹻.�DWja���w'�D#���]�/�R�eN�>�z�5ٱ��63FsRV�	p�앗��[%�4��\�`iK��(�`c��� ���6	K�M}i���h��Л���ſ�Y�j:~x�L��L}ꫝ�Upy�RԸ���eq�(=��t��Y����q�c� �����zs����%P�r�g�<�fl� ˳X��Y�֌��`�tMO0�C��a#>�)��'\���P��qA*�ԟ�>B�ަv_چU�v�@!̝���������\d�3�E#m�N�,Z�H�)
4,�x��dg^�L�;�L��a    �0ZJ��b����߫E�j���a���P�b:�U��j� �w3��.�C�������B��-�4s�Qvh\n��;�lL�V%���## ��}m�D�������JQ$��S�Eۯ (�b ��@�7Ǜ���kiZ�Y6Bp����5��/sX�K6���a`d�,�͟G<�D�K��q��`� �������U�Nk�2�`�	�gu-��u�)o�� l!���)h'�l�y�g���*�<WD��TR釃��>���[F��Z��,��{9����']�}6�R���_(�N��i�'U5A�S��7�&�ꡰ�^x3{*��B�>�0��hC���A|���G�3p!}�~P]�S���*[�볆�z1K����*1��ڻ���8O����S��K�Q�f�M���g����^�\%yX��wsQ�R�E��ҍ"_5W�I�Z����NDh�]���P+���,V�SǫHL:��D�zi��gtx'�QE���j��+�䕢
�nkԿ��Ȑ�Y�O�.��7c�E�$��	V�$Q[�F�D���p�'�Y��G���c�SY<#8q�iO��J���M�de(a�I�v���ͪ� ��$]��쁌zN�����\bP	O��xË�yk�'�_�1Er��"�X���/T�M�v���T >5�)-Wު���CN��աOk��'���^M���ԣ�Ҡ���"�&q��%��&{Ȋ�y6�G�-���g(���R��B�Ǥ1u�z��(�~�I6��b��<��Gƨ���*1*렺�Ȍ�XĨ`�0���خ��НJ�Z�<��LP^�<�	=jR'�b'�v��cˁ��t�I`9�׭z��ey��Q�~\��&���n�&��<�F��4>,��錡���e нP��a���4^U�x�ӄ:;��27�h��jPJ�W�/+��ژ�U@�J�O|X/ʲ�K�8�4*��Q�m��������@S��]�%�8����7�`޹��O�r_�'A`E��.'��e�_�_㟛/����~q�~1�bڿpəH`�4�����ض���D J�S��Ĺ�EZ��������tG{�~�~�*&�O �g3���L֭�e��1 S�)��N����������.�T���}�1-�I�ꯋ�:PU�P���M���0Z+|�m��[����Gʹ��n7~�ԗϴ�܏���m\k�����ؠ�"}�h���sf�۟gA��`����Y�'��Cq�������juU��50�q��ɞ��	s3�0�xI��*oj�t�/�%���A��`��dEՓD<�4<�îMX�к�(�?�E��"ίR�6Q]�]%~����E����4�#��$���J!	K\eT��?V���,~�v-;�������3t��~&�����9��$��8U�闾ݢ`[���<�WA���x�+�y�ѧ����`F|�4�^D�����?�Ǭۢ~�B�(���9_xm62^݊�}�L� �Q�}��Y8�%7���y�ɍYY�/؈1��0&�#�c#.����۝	o�-,k�;��Q���B�j��5G�|(DD�K1�[~�r��c�i���b��N�J��XO� ������#':z\(�V��=�5.?��>��^1�^���/�=��#��[!P,�^l>%��o����G��l�����I d��(����)��M��6�#Ioq(��~=C�'��.	��	���J�:&cv ]�=�hRS�.N[eeC�����\�����Wa�3��gj��( �U{�R�oay�Բ	ё�� ���7����G/��A�F�4T�a�'���:���������I�y\^�I�4]_�C݁�o{ۮj]⾥ޙe.�o��?����ς�{:�%��<�,�� y(<U�͸�id�J1�w[����7.(�z�2D�O��謅��b���<.6&(f����KUG�b���|�.J�,�i��t~�h�a�X ����k�b�Ds�i�F�4�]��P�Xzc�t/p��X)�S�X�۵ð?߀_3Hu�k��豺�Q�2�F�mwf}Rn���}&�H0V�����D���{6���w��㪾���<?)ƄBF%ֽ�J�K�cf�RIb8߳� [z�ώ�;�v��zB�*�͢E��� ��u�Z���Q�SL�*PV��=���b+��м:��+�2O �	0}d?ְbC������4��o�XCr��b���6˲��*
RK)��E���Rf�
�+^'�BEс1���צ��x�@��7�j�����Cu��|����5H�U�۳�M�� �f��������Y(�S�Wu]��%Y+a��F�$c)AYB���y�-����<���+�҅��]������A�SLfT�ge�Ɠ�N����<8˦���]T���.���0eV�ZW�V6�W>��-#0"��E�av��7���;�`�?y��/N��q\�3�qzq����7��R	s�%֓�]�N��i���{ZV�=��yKL9缅T�Z)�b�b?����R��2���d��?q���eQ�V8��'��<]aP]���0��(N�@'�� Q�<��.��e.uT���� 1�kj��ťP�IϦ�7���._�eq��S�QW�P��xg��x�&�"(joF(�TT���"F(��`q �J����(�6~��������`���Ǜ�ue�P��K�����k7{c���zy*ьY�n�ֆ�˂�0\�����^�{�s�Q//����w��j X�����h�+�^
�s�@V�X��\��!s�Xl���e�cX�/U���ħ���5b��Bm�fɒ�l�q��KY������1���J Es��vo�M�c���-��� w}���臉Ռ�O��q��y
�m~���*�C��� 2��8o���l�2֪7���m]��1@0�ۛ��ub�O �����X�u��rˠQ�B�kz�DJ�2�il	=�vD:��<�J�dU9'`iəʜvC��V����W��2�W��L�x�逢�a��k���J ����&�g�`�<�I���'�\]��l��pVy&��E����������:�SĲۏX��Iq�*?��4�x��:��hD�.�"��~���ٌH�y ���;�پ[�S�e��Bc�P��So�_���`����s����O�L�����a����-�%����	�AX"�*��\U�^R��gp�"?��5��ڎ��Gk�!e{	��Q�[ x~�~؜�W�Y:L\8(�����q2C�*%�����K�3P��'�;[UL�a*���ۯFC?
.��������2���A/[���E��(�M�:N�(q�eB� ���/h�t��Ά�d�.�l��(%�,m���P~��V�Ӎ~kE^T3��adU��e�-t@�xk�V`���GU,����Cm
��8[�?���qq*㸉�'��%3�]��i��ŬȽU����X���g%l�Ш�~���1&�gJ1VX�I��&A��9[�_3�~PW�dT���Hb)��L�Т���d��2f�݉�Q�F�k@��X��T ���ĳ9�2���4��S���"뉣J�S�\U�Ɓ�x��C�d���k�(��o���Q<�<�S�똗i�>�A���Pח]���Z�"��,��x����2+����q ԁ%��Gn�2�{d��{l�S_�w���'�&t^c��>��
�?���;�D�3���`�d��Ǹ{������+�(J��b��1G1�}O}��(z�NT��a�9���Nt#v���b�>uX  \\� �#�+{�B���XX`
�O2t�������`�7�ށ�֘3%�k��ʏSs�0�Q\^pa�X���:����A��P�H�&`�9v�Z��W���7�<��W����<\�o��?�ؔ5XF�;k�aJ���Qݏ&�_��XI�i������*�qq��}��d��Uq�Gh|����EΈk��-���Փ#�������e�gL^�����,�(�g �G���:�IVV3h�7  �Lx������+�z��ܣ����	��:�    -U���yU`Xo?��\n2���W�H!��j'�������Ӝ�WځC�7�b�9��~�1�J!<�P�ͨ[wX-�vr�2�p�O�#C[�iv��f&/f���G=�����x��ne�V4yC9��**�~��d��9�Q#��N9�g�*��������h�˼��mf�����*�/�c^��0s�.�F0(��܌]����7�2
�/fG
	�/���2��I��-u'��Vn���q�U�A��;��	�y�lS�����s*�3ۼ�T�p� ��SP�RS��e��(9�vW����~�y���SKM]��ew��-W��5�f-������~���X�'��IV��y����#���͵�F�旛5QԒ4�u��ٌ*���5�Q�|.Y��	{������.�G���#2F�y���H��=�AI�E,+3����a���9Bf����-A:���ӣ��+��*!)�4���� ��M�/�y0�|��N����/�+;bb~��g��x�&�Ѫ��V�F�~-�UR
~^+���ı��`Ns�^a�5�	0�c�!��8�S���:�}'��o�.��LP�l[Ē�`��F4�1�[i��n�hNʷف�K�����˝�I�X�2� �'ps��`0��%�5G���2�P���t�bٸ�í��P�x�/��X�7�������=:��=	q�Sl�k'6�1�^צfn�X'[͂� ������'~������_��n*X�`�n���s�oW
z@�v�VИS��Y�O�PF^7�EN����.��-��ya9�TSR��0�������?�ǌ��3I��#(�~♇>��l��4ɲ��pD�*4��5�rfZ�1'��/в�3�~���<:$T{$W	I�y�t5$1%o����?`qs���(�2��V�>�f���g�#����Y�͸Hq����JR�Rɺ�g���}�PQ�h��1#m�N�w8�˝�4�
��*A+��"�_Z���.+~��b��T���߸�a����ģOQ�%�UR�A�]�4��\���R��QC��X5�����NT���c���Ӈ��B�۔E�e�N�̟�v_�X�ri��H[1�z�~k��0�~Ӷut����w���|��13̸�>�&N����枟[��d%�s%����Q^^|�U�j`&)���Z�\��(7����&sDğ>�6��f�y���J6r� C1�v�@�a.�R�N�\k�fI>�ש���e����aeK����,-c8�G�:��ꐩ�sV�o-3�'�0;���}/r����Z-?Oz٣�+�ިɟe
�Lpɰ�ט�i�cW��3Yc�������B������w<��(@��C�*s��N	G����޵�L<�~m;����ɤSyqq _Nf腑oe1�]����M�a٢�T���-;�
;0�SG)|?L�)D�����MV���;��0�v�#�F�,��o65���UA�xf��%*C8��1�,^�8��Pn��y^^�A��U)��PR=E w	�8�J;K��q��~�_E���Z6�9o�5�bPlx�>i�F�c����#�#���RPO5
iB�v[g���<`I��3���c�DTn�N8�^�J�nZYဉ):w"��&����D�K���M>L)�����a�E"z�'ί��2C��"N�S-�Tq��)�#B(��x8+��"�Wi
� 7�e�()��(��y��4Ɍ��~l)�z�~�92�aTz�W��ݯ��W����l+p#�wU���W,��ҝ�2o?�z��w,�]�cՠD�堾:5�XI@9܃�H���&�*���| B��R���R�j��8���	T�����z?,U�H��:�U@�:[qs s�3��5����o��kK�:J�r�����p2��g�9n��z���)�Έ���:��9�I�$Q"�G��k�Uc�Ny���a�u����dȦa>bbCD���}�k-�&����8����0�g��y���=pT�Mu۩�%]SUi_�����y#1S]��~�H��#�OV�s�s�MV/Mh��e��A�)��n1'���u�+P���`բ�Li�� �֧�jCS(`{X�s"�-���|�L#�2��"Gt��X�C���x��=۞}�>@���@�2ۊ��������ja��0��B��4T�x���'RL��\%�E��#����;��bG-�jR�5�]_���WL�\��Ww8�����9�y���2J�A|�L$
"�f����	�O��>��,�U�R��#%�}�X!�-
kyI'	|�a��j��ΰIfl��0P�I���A��R ]j�!���\��/C�p�x"�(�+$� P��T3[����2�t�,�+,:i`$4���D�L��"��o+�b����Օ�v�J�����(I@ϸXݏ�`Q��\U��<L�l[�\�n;i��2}���>�8�M�_��t1l
d�^�o��0<IU�tX͂���dS��WhFBhhw*�%֣�PW<M��Ƴ�R���M��(��&��($���T݀q��J,�m���.~+�5��(�IX���;�I<A���;�Q製�`
W��b�"�W��׫��`VV��'�ou�n���f�7����dm�B���;��F�\��D��"��#�nض�V� ��Jx�N�:~�1�a�1Z�7�&�>�����_� ��:�mp(�GR!���t�pR�Vb+N���}��j _t������rX^�~ȁ'��2�n��B7�a��W����:�n�P��7��a��؁$-Ҏ�aCA�1`N��g�M�4�	�(W�m�P&齸����(Z�?��ʭq���!p޶"Sc!���ͺ@G�$���[ L-z����p�i���6+���yg�Z〺h�dF!0(����*�����A�B�[)����}�o���L�R?(X�38pU63.^�$�H��rCٯ�i	+J�qx����_&�ʙ���$U)�Ϡ��h�&��<����/��P��mvde����[3�aI���[�)z�d��=�7ޤA~�Q�=/�y�8� �=ysbB29���p� KH�
��(�E*~�A��e5#RI�^N)�1s��@Nv��e:/�kHq%�}�-'�̝˶,\�1��b��\�z������3��<Y�w�*�c�m#Ňx*��^���N=�~Vl;?�,V�լK���3@?������ ��,w>*����w�l��,@t	�����R��k��"�ZQ��yoerвZ�p��~Qb�"/���b��E��"�ܦ�_ʡ�⅏l����㝄��Z�B��l���0�S)���o�MX�3�Oq�x�}#k
���5d:�^`4�cQ��l��<��XZ��S�y�?�0Q痯&�(̤���7����+V��`k:�5�D�(D�P�KP��ۯ�L3�:��0m��y��T=n����3�Ri�D3ʍ8��g=��a��{���-A�< E�2@v���$�,�g,��$�u�����8%l�Iz
m�e�(�+;':�Z`���;z;(C%Ü����H�G��(V��=�_�Et?b��~ϫz�FGz��/en�CA�G+w-� vb�ʟ�rj0Ƶ�FD`�[27�i�h/fc����b�~��U"T	�������g�@��%sN�G�A�`Ek�W��?0�i�`���!�����K^)� �I[1m�i��Qr�?,	�E݂C]����@�����	�M�����!xIŔ��^U��ժh�v��R�t7��I.���Q�f�ȫ�:�����v�z`ё�o�Y@S;B�j�z�Z�����F��ؚ�����LYՌ�,K�g�2-~�؃#���+,�P���j��ZYy%�p�HuSU&�q���%�P�eijE۟���H�z���K�ˉ�d�=��n�+���P��1��:��t��8��%zy<�G��.V�S�V��:���;�V4k�ي�,d��o�#8�K��WV4v�iS#D�‿�ں
*�QY�޵��� B��F���    �V�.�-RHڥba�^�� �pR���T���R�ĪRu�l6�=��&�XY��N�W+^���R�X�egy������͖�p�Kr�_-w� �i� ./��K�.$���3#�@�;�I���)!��Rw�&2�g���K��٠�<5���A��xqS�1��K�8p,���`�$սS�% �~�K;�{��C���b3ʻ����������ٸ��z�t9	ݵơ�i����{*����~����4����^��f^�o�� u"~BMP��	:	�<�G�d���X��-ƺ	���<HI#-!+��=O~9㾆y���F��LFxj�'�Cn��~�$�s�8�6�Oa�s(��t����@)�~�A�Ԕ�]�Q�~M��,�~5"�Dy��M�/l:D�]Bً},GiQ�@�j|k�W�C�1�	h���s��]��oL��Q4L,����_O��Kt�L5��U�u�K�)�F�t�)ř z�\�'��j'��{X#���8��Q�G�]�s��?)ˀ��Yk(�[�0��2`y�p���]��\T�:<�38<tflǒ8���N�Wl����
<�z���)����`��������Pe�k:&OYv�C�JIhu�3��5i�E�/$���7^kǙ�yԟW����6���̩�J��M��])��9u�����5�o�3�������2n2R�i+�͸�%?;%�t�	��̔	O�ޗbN;a�{K<Xs��.Nv�x'1,����7�5Ԫ�tj�ޚ�p",����<)�8�1s�=����:i����ϫ���5�V�OΊA_�lQ��~�s=T;��6`�cbS5!��*Pé&U���0��`�^��D錫��'�n.���5+NU��A���z�.��Y&w�؆�(��Q���IS4u:����4�˚���n;nP�j����w#�D�9�7pe���a�8M?�n!���;���ǓSZ,:��}[���/ɀ��2N''�d3!���k����R�o@��dm�i�]YxN4�q���8#�DS��FԬ\h�A�ɦ錻�uا�����G�w�8Dl��e�e/+�?g�ًn��Md�\	���{���ͻ��o9>\�Vt�Gm�a�*�rHC0��������r�1��X�x༟X�*�/�k�l�T� =D�nZQś'�-��E
ؗFԪ�Ȣ�o� �/yb5MM���Y<��\<&��yo礪���£��=N�/�>���s΄XQNJ�mu}S%F�u����>��}c���f�6����D��=�v7_� ��+)��mY:9�Jn~��	ח_�<�S���3:w����Դ�;Qa�0�7���s��$�&�g �R?��$v^� �7�VR���������|Қk3�R��)�rs�����%�a�C���Z0��y(�u%#;k���7ac�iM�J5 �'@��Y>@P�#�tE=��d��n*��Mk�eL�����FB���)8@�:�s��{�bY×�Ӝ��TC/ܖ�_��8����}&l�@��)E:�Q�T-D���������5�{/��9�K1Ps�K�Kq��z���b�<���<��)]����AL�Y�������T��˨4�#�'��z��7��}d��m�B�@z�J�V�.G��o��E��J��(�"�$7��������7�t �dӶ~2uc�(�1�v_ +�u�(�R��Qb	�������^���(	��%9V&l[���4���U�nc����2��C͑�ׂ*A:s:K���.�^����-S���AS���m��:l-�`��v�&�z�b�?��$AX͈IB��B.�d|l���9,(y�`-a,ڎU;~1�yz���,�1���7��w�{9�K�|�f�d�J�3�HÈ�fT�f�?a�)p��a7GeY.2-��Y\f3ޯ4N��3�{�N�%�ry,C�Ya%��\����}�L��	��1�����f*@Ϳwj���>����̛���fA*s�4r^�����&%�=�bz'�/�qy�(4�3(,�܏fY����ǎx�ʒ���_>��R��(���0�8�5�%(�g�H�v�v =� �e������Wһ9��S�>��y�l*f�ٱ�E�C��(�Ѐ����3Kuɀw%�ǘL}FVx��5��n�2nJ�gp8�j�*�bO<���y�X�l�X���kc�Q��U��g�-�g���ЭQ��UD��Ñ����\ԧc��`e>������X#���r����3&��������gtY%�LOs�7#�e�XmG|=t �Ժ8��!���zu˒�=�-��%�O��g�wY�~�9�j��oԿG�'G��Z��N6U.�aD�3{�B�?��~9�ݜ����t$󝏔ݺ;@�k��Ӻ��ڛ��l��U��,��ӄ��޹/�\*M7�F�w������"��H[�,��f��ȁ�5b�t�����`P���(�1��j��?�1e'AR��eΓM77zv�m#�ߒ�^���Z)L��<<0�Ç?7� ���Η?&ݶf/��W��t��+��a�Z�s��;]D�^��nH�2+�Ɣ��?7bc��e% �ò��/7�x拡3�/�x`m�qV$�˞1%��ų(��Yŗ8˿�և����u不a;���B� ���r���2�!:�ŉ�d���G,�Rl�zf�f��D��ј��#KbO�~���:�Bdsc��cҸs_��-0
��S���x���@
_x��nҿ�q�R�3	_�X\F�1<H�e�`��kt�؃�d�����)~�Z8��v��޼��PF� ud��,b~f�3�o���e9�Y����Wؘ�rU�M�̸o�e�Ro���yU�s�H}����[~�N�(������8�qi��f�ً������R�d����������������_&�l��O$x�,s�u��TQ*�6l�-�2l�������fD%Idǘ���nU��I
�n��	�%H����4��v(_����	�pbn��V%_6ojĄ�y�0F�>3�T�d��7K��^�$��E�t���f-���#��KH�z���^la�^M8=�O���Y�D�|��2=����¦|)���S/5���X8��ءU.ѩ�5`ʱr<)�QÔ�S#ű���Nb��g�o�ǧ����u��"�\�P��dZ�{(����+̜L.\���n�&�fhd恗�2��O8��N �j�� G��P	S4,sO�޷����,�%9�3�ɫ�^�Z����]����<�.�����_J���ݘ75����O���O����M�o?��W����GFIĹ#a��dyn|�}�+��V(��-�L�*"#�%����"<�K3ý+��Г�9�?_-�=���t�c�D�>r@P��9��Qe	��=�Q�@Dԕ~	� 4Y��^���S]�ڎ��g���H`@��V@Ł޾Ֆ�t�N�~�"�Q��I(S�<q��b��1h�Y��b [a4��:,�I1��yI5���<	}a��e⿗��iK����J86b���iѨ#��^a��@�Q��oN��dF��,ǐ<w����`�r"�*��e�*����ʢ��z�yv�{� ��zF}�%A���O�Pc���A�C��&����	�*Ơ.J���(�G���^��y�����٩<cA�ӝ՜�b8�="�qM���F1&���8臛�w�m|@�e|��D���X촽��^Z�!�� ��5�"]p�=�řD�Nk����W�{k� fy�����k(/2�`��j��e��Q!���G1�x���|"��o��=�W����ī�*	�0��x��E0��p,*�w��ҁj3��?�W��8�G����D�٢Wꢰ<y�F�	��nIgcL��[J�AdB�u��:x#Ʉ�t����1Y^�cÉM��8�}g�_��Tu�唅�,R[b+����1�t޾��qt1=�N���v��"�W-��	�Ƶ�͈0Z�O�z�z�â���N��Yx�S��D��xX�K�b��׬�#���$��T��b%�    ����B0<�ہ��*F��׵C�g�H����C�@ |/q^���*�c.N�}�2��X��b�����_��ڂ�T�H_;n�y���6�ɖ�#�� ���b�H8R�:��5�h�(]M�5a���Vt����`�C�4uryP�$KŲ�˜W�~q�Y���[���'uK&{�|
j��~��q��]�|�: �g0�7�o�sK�u�1��9�ęf�r֣��Q����s����$���>��C�lNt��=G�����^��X�$�Q@g�W��(�L�|c*�8dQm�ni�
��=����*�������L֬SG��i��ۮL��%F�g���7���n�^	���g�4Me������ʊ�%��fb�%�(%�l��w2]�W��A��z��$.ĕ��w�C
H2�gQ*�
t?���.�?���$���|o)�ӹT�v�CY~	2F-OD��w�Nh����r��V�/ct���<�����o!����PCHt+v���A���2l�lj��<�����>�s�Bư�� �;a�1SE8��`�l���X��x%QO]�壕)�k�I ���7�aQ�3�5������J�ذȤZ��^�m���V)w$Bg�I�=�V����H�!���L�w�I�0�[� ރHܾ��ց�\���������V�tV7U� Ga�&�0��ZY��X�m�ǁ�R���v�<��\lTsE�o�(n�ͲP+���9
e>��A`��vs7�wT�B�ݘ^rս��?tns(�F����~��J���y����I���� ՛�/3��s>#Ѿ�D̗UKD������S�+cdL4SW �	V��q5��i���_6҇��c�Z��c� �7P�<'�\&U�7�$3���d�)��\A�p���%�M\=}������g��K�˧:~&B����E�rmF�w��!�:�#���1�7s���(�������l�� t~u�I�v8�<)[��"rG��(Zu����]���������@�j��]��lƥNru���Y,����nx��CvƉ"D���A���5t��e�r���z��Ko�H�O�Tk� ��p�9�<������aEF�ۯe�8E��<$Y�[�8�v��N�*�(x �ʪb��fW�j)�f�AKoB����uK?�Hf^��8\y�����W�b���,ڞ���&�� �Ƃ�	ks� ��~EӨ��Xz�L��cS�����������4x��hT3�WO��>��ݗV��*ӳZ����-�i��`Ip����X���R'Y��qUNe6B��Ϣ��!�B�����*a6�(����U�����;�Z"T���:x�QY���-��@�l�{�q,�	4�7N��`j��w��٩��)"7��3ؒDUY�ˋ� #���C�a��8ouUժ��;����$��wT��#Xv��W�V�u9��Q�H4`��X#!��2�a�zz��g ]�/̌`䑂�P�A3pA�q�+`�V�^J��[�{T�_��ɞ]C�@�7 `�g�g{I]>6�4W�i9/X��F_��	�*tO�A����e@5���P��~�/��
T�43F�A��xc�3�)����x�&N�aۘ�,c���ɜ�x�T��j�.۵[����;:@4��N����6��d�ӗ����ġtZ��l�����Ȃ�)~ANܹ�.�xŷ?V�C�3rk꥾,u>��8�a4w:��rg=�ٗj]����"��@i�eH������؋�]��]̜�Ғ� ��(c��oK#��X���_��7	qFьeqdK�\��Dзg�.B-�Gl�J:Ik���Q�HG,�T]_Q���aS��Y�V�Fn���Өif�^9�2dhy�{Q"T&��6\j9�y,� ��I��� H�@�,���ʿRH-�.."���2�ǊR����Z�1CM��N� �_��*N��� N��@W8�h��}����jÅ�cЂ$n�S)�?7#�f�s	�k�'�#B�L-����4�a����~ײ|��Ơ����Б������L��X���w�ZE�xl�`Aj����|dԁ����b�g�x�j=^��[1�D*QE:a,�b��������r@!���ę<��e	��?��ZT^r��3�cu���б��a]�ތۈ
�mk*38��Dπ ��D.�iÀJI�Q���Bu+�q���?jY-Q�ncU�͌�d	L�`
��ݡ�q�I��M��c]�
��a��U]y�s��\z[��L�8��#����~�2��}B�Y��\bVx�%ծ��a���u���Q��i��3��Ǎ��3�hf2v�R�ez��[%���JUi��#��,J�����#Fpb?P\g�9j`eDbqA�������!��¤Rb$��J�+����Si!�g�#�π��P`�9a�}[�P��]�Դ���v��Q�f�mcY��5ނO��<\��t������*��"K$�"H3�O����>P�C\ݑ.ۢ%r�{X�U!��'g~���hDi�g�J��}ws�M�'a�AXа���d��?�����%ǲ�3ɳ�Ҏ����ÐA��`o��
�39�X���'|�I��h�/����,�+��}O��O��"ꆚ;r�8~l۽�
7�>�%�7"����өbdK�f�}�=��H�ܪ=h�,�(�H��Ѱj����Ұ,f`��49*�A��'$�?N|�5�n�Ck�SQQ<�6���T���S��������<LvXK��[gc�E��l����Ǟ��� 6�2,oJ#��J�C��Ú�\�-�)Ö樴��+�M2�����W%7*�h^�U����g_N�Ԧ��B�\t� Q�ۤ����[����"K�?H�Q(Gh����%��śG'���p��\�pڬ�L��,���l�HF��c{� ��Ϧ��~�ӄZ�G�,�܄K?[�&2Iߚe�����3�4��&�I�������c+wf��*5)�u+}�ī�a3�*�c��W�Q��E̑���R
�ś�hhW�����jN�T	����{}�k�7����!	��
Q��&֛'�͚�*L GW�h�����YD�x�z��O������-Mk�rŧ��-8��H�'D�zb�{͊����vly��b��+�C��=���|�L錴	�+P��W�b,�`K`���$����T�X
9yQ�IX�7��jJ�o�Զ�5�d�?U�E���k'�h�`i�ž?�N/���cd8I!'v�өܩ7������H��.�����ve��+� 2��H��j���X�ǥ{#��X��Y��z����
͎�*�8RkL���~ߓ0�� ��y��ߎ�
�@I�=�r�����Y\�9Ǚ�nU+Ra� F+�L�e�wq��
-M2��-��Gu(���r�ݠ�e�"/ZV;m��?-�L�W����,̢L�ح���JZ�:����@&3*@���5��Cn��=1qf똪�
��Һ�fd�q'� H����6�Ԫ5����&˃��l��6����\k�H ![�}nj~��X�q(g0��ǑT�ի�E��lN�Sp
�ӝ蝨�O��!��z�ݩ���+`F�'{s?�P�l�d��HuÆ�;[JW�-��.a����\\�U9�O����!Y2�D	a�Y�`�})UE큇�׺����6NI-I�i_6�2] �Ms77;�N�m�4f��)����u��vG')	L�Z 2����+#_1�����9��p��؇؛�5],]�vq��8b��ʚƠ�=Nt�������E���y�|��@^Z�8�
�P2?�g���$�'�o��Z�����ˍ�!�iY���`���&�=u��z��	�%x�֤��o*-\���TQ��R�Z�o�%ÝI%Z�&Ηr���ps9�/T��+RJ�˰��W'��v�t�Q|�Z�^�+o�C��V��d�3���0��S�M��G�Xr;qv%��t�16��#������l��x�т��Ա�v>�    lAW�ꅲm�U��b$�4��S3�rVSS_���mU�q+�&M0���^�ͦ=�����8�q��?�Ϣ��g�7Yn�O"�x�XY�gg�#j��@쉍-=[��g�Y\W�}��E��d��5"(�l[�Gsf*�o���T��jo�A��	�R�b�ϰ,�hƲ*�ٗ�e&v�qv&��0 �@N�)�Q�n��w��OW���e&��=?�b-2r�a�co<��29T�O�	��;���s�7.Ss�QI���пrNN�"����箶-��NRmg_�M��i�),˝���Ua�מ��C5����5�Ne�Q�-��fi�fFmjT�٣�Fc\�>��J�,��I:�U���C4��1�
I�аU����հ� ?P�I幄[/pJ=
�@�/�7��2��1�M�M�Y}�9��N,�l>���X�Y��aYxO$�L0	���ݚGub����jo�z����
fE�7� �c����3潪��2-2�6�w�6���	�H҉���f;j\�Ƣ(}x����;Sf`�X��o��6���D�<a�S�9�Oc�G�y�V_����}{h(�ڡ@���7�q���⾣����Т���4�씬۝lI$����RPH�C�"��� 2�T6'`r��Zja����(�*�?!N��_1S�x�l�L�B��O$�@��ev*;i ��u*��m���TT�W«�;���U%X���fUt���:��BP
E�f�Q�m�`!�I`��p ���&J���Z�n�+�g�N�lƚ��B�GY���w�kQ<MA[�
�Y����ݷ$�B�b�r\�yt�� �t]���*��qG8������wt����Z�������?
{�*��TU�3LyA�P�J��9b���)9J�ԃu�}Mҡ�&���Y�I\�=RI�-�B?���*��*����i��[э��x�Ѹd�q����H��y#"��e�7��rV�T�.D���8��R�k�P�xl�A��O����U+����+��hݔ�N��EID�m�?����y����1/�i5�.��y2��O��BL�[μ"[�?�j�%Ir�G�R�O��$��X�U�o������Z �_4��|�V��2h�7�`�����E�i5��H�<��B��,�-��O��٠s��Xx��&�J�#�)�<,�f�DWB�{��q�;�?x���̪���r��z���I���/��T+�Ko�,[�<(�ڪ��!h6r�N>Y�e%�6�����vS�D�V�TN�h�Qon�����g�"���ϣ8� �U�hbH�o;�:rXv.�xy����SL)y�7��%�H�8~d9�K�9�e���a�˅-�E�tKiu	�5J��m&�N)�$��0B�O��.�)�$�N���R��G)\٦�m���ښ�
qR�w��*�N�V����.Hf,�"�}y���:����ueh��J��o=�ؽ�Nh�fw?cJ���k�4Lg�:R��Z���R:��\��t�b[��s��YҀ�n��=�Q�̐F��^7LƥCC1�<��7��,��tFP�4�NC����"�Q��v)O�N+��Ї	h����Qq�'0����r ���f��ނ�2팫:�\� y�	-��~l�F.aB�a�{�;)�����|�(x"�6n<��Ȃ� i����c�i�&U+�8N�YP+M�����W�呗y�3��[!�<u���z���<R˝vËK>�
�YXp+	g�Ӯc���ň �+�#̫�����F�Rj����ƖT��N.����/].�eh缮��ei+l%ϼ���p��Q�O��!c˩ �LS�<]�m͇�?yK�0�$�ss\�T�;p��4����J���CWA�Rʺ�r`9���C�a�0[A���9�\Rڈ�.{��Y�+��1��/RCt��#���4���O��Ukj�6���4 � �ˤ�DJ␥G��ㆶLD@iU�?"��c��"�q{f��/��d{�ۻR|�7O�f���	���l��>l�-g�G�s9` Y��oBa�͘~�Y��� G�KbH!e��SA�z���߈�j,�8+����N�T��E�/��v}��3����p,}V���
dp�8�f(
�E�K9TĞm,Mnj	�J$l�K;���\�qzQ��F,�%�(V w[$U�%f~��)�2|c�P�C�"Rh�� ��Di"�*Z>���E��M8#N�ʔT�HM�Tcn ��49�W���ۼn��X$+8��YYidq�aɼ_D��0�@O=�nR��n���?��f��q�(�`|L�
4X��Yp�f��1Q�s��0uLU�Pe@#LP�r�ɯ�K��A�( Քs�(c���H�_�)�O��ȴ�]�/*�0�!�r�SUYJ�=-��|1_A����fl�Ȥ�\Y����� �d���(IO" %E�}���,���%�A��	��-g$Y����~���4�i�k�AR����QM�ر ����	�
�6lfh;fII��|�� ��c��sI;Zt�>��V�F� �'X����r�A^�&a�Kx"�G��,#s��"P2f�}�2p2�p��)�,�!qor�0��ن��N��G�3�ߕG�TGWU� ��jQzY}��#�(C?Z�f+s"�_�d��H��q�Ҧ_A$�N�{�Db�h�j3���7)^��]�U7C�%˳Ć�$�/�
���!zl �"��Z"c��$�ש)�����l�&��ށ ����F�=���ڟ��ج �T&~<o��a��5�{���Y�Ԭ�S��,�n�gmp�h� .i<�2��
��O�F�l��$P��8�vəB;�j;Iu��[i.�r��	�T�a�{_�V8�����pA�_]R4�6�Z#�+�Q�w3���0�E<e|A:���z��7`�Z2��r�6�՞B1U@�W��ҟ��Ga$�0���Y-�A����@�M�&�@��� �E���ƦʭF�pڢI������Q�@e<d]��k�c��,O����� ~�7%�Kq�~����;*v���)(���o~�o#�Ǫ1M}z@��)s:[0.����g��|6�?b����?�ath���H	!mՋN��G/Lվ�5~jUVX�/����_�N�X�+p(�"��K1�#ݽp��n9�Ă��@+��kIZ�,�C\KKt�Z�Y��H�UU�p���T�4a{欄Ň0Ԋ�ڋ��!.�~�,_Nl�*4�&7�
�͑�����$*�(�� *[,��?��4@=�rz�|�1�-�eY�|�Y{/�+#�����z5����Ә�+�#���3�~��2�>(���Sћ���<FÙK��ۢ�q`�A������yugF���t�.Lg��i���?2�#�Aqޢ5�V�e0Y��	@&P&ϡO�3�Z)]��W���_��Y��K�}a�ɼ��X���R�է�g��"PoA���xDTA�Ϲ,�8�:+(��%�(��(}H\���s��<ߖ����/Va�̘����0�t�(ð��!62�G�k�oL���.���
d���kf����������LŮvkrqB��ƨ��Y�S������n)uh⼂�w匫Ѽ*K��
CO9��j�S�����&T���.�d�Ҩ�aTI$z�ay�ď2qs$`�F�߆� ��e@��*|��ɨ��)K�Zr���M�1��Q	��Y4*9�;�9v�3���VF�'e=�0
M�$I}���������"���;���A:0�>��ĮX�(�Iix�w�`:�5�aWT}B8W��WE���UQ�dR����Yty��i�܀�=��f׃]�Q����>��z�%RX\-i���/��
|���
������Hf�����d\��SQ���w�KեW���>հE�o�c4+�Z�uY5s� 1M��쳚�'�=��l�$\�zs�k@x4��#�LP�U)���B��l�ܟq�&y(�aXx�����j���|�uX~���
 �U�(���	TM[̐�/�$ІP�{����W�m��h��iq�U�    ���#tN����H�p�����
�
m����6~�,c�0<
q4�Nl�(�j��?��0o���0�~���ئ��ؚ,��@ԯG.Gsj�VG򩅇��pM��Ҟ��[�#tWv��@$W�@n#s���G2�b�
���z=_i�qЧm�:pB0�ӕ���_�m��(� K%���؟��T����RP>���̹l��
����^��oFy4#�Z��t�9,���i4<@��oZg����.'�ʆd-׺�K&���6ȑ��r���#x��s_	"��+��jp����7n|�*�(�B7�,�Ƕ�vR� �RF��Q��5$E�K�I�o����t��j|�A6�f��A%��٨ʊ�f���6om�II��6�B��D�
�����6�����U���2<�hFX��g}�A��p?-�,Ի2��ʲ��N"����v�"ťI��0h{O�Q�׶�at���.t���?��dRpƢee��B�"�dҞ	���b�J���$O��^����p�v�4e 
^dY���>(��>�����3� {���u4���)h�Fx2�Cމ{���EK��ƒ��@t\�e~x��B�j��o̻��	G��Wd��
$-�0��l�"�:6��`�۲�|k�ѡ�z�R�Q�%���k�:�ӻ[�h E��1�Q�A	J "�#�nw�G���D|���
���q�*$\8����ja_Z�k����Y�_�NP��t��j˺~ً#E���s��wSY!�#nK�P�vU;�y	Z�q|��� �=3�O� O���d�~��7�V���9�JN 6�.{1�R#;00?�H�2���%��r��ma砦���h���������ДCP!��U���8������B�n�}u) ��=����4��Q<t
�;lk�$�IylS��A�kb���L�i�v���d�����5�W��4�ZF�����N=��a_����<��#n�����"�7�Y��`��F'I��q���)A�:�/��R0#�V��OI6!�#���[*u��EI��+�� �Īɖ����w0�^��L��6��d�]״��0H맥E��/LTI��X��������f�{�:�d���TB2eq/�����M~�.gH;�*�x<�o$�e��-������8��SH*]g��J�*F�BꆒN��<"l:��z�sX�䶮�ПqG$i���8��ʿ�Eک����i϶ݿ��R��_�ꁬ@�ۚ�@o��񋰾?xi��צH6I��֑�n(׮*����+5z��VQ��$x˧b׭)�f�	��ı��z�P�����P�(�6�)����:���fC]��A�hr�����S�Ě����`�\�5�<J(p��	>[�0�b�51�܃�.����j1�%���}6��C�ҩ`�a�c4�V����I�E��_��R�E�x#F_J|��#�������CA|`k�%V������q�� ��k:�Vʻ�$_��|��8Z�E�%M5c�澯h�8�>�T7iģt���a����-����P;�2����
��?O�9q��\&Jq
�]��>G&�od��@���h�[�b��0��`.��h��*bw�fއ�p�u؄�v��G�h�r�~BxV��h�*�qK~�j��ޟ=g"b���v|HG589�����!^~�՘��3"�M�T�}�8�B�ľ�/!�P���x�id͟�7��x^�Mb�az�,�e�%�g=BD����+��"��@Ǫ�yN��Y�����jft��*�O��[��g��ڢI����&�!d�$���I���vB�*�ib$���|5����ݖ�V�� UL�Dy�U\Ga�-o�@��"��jW�t[��M�$���!1͋̆2�h'�� �=!�z��@�=��!HT,w�������U�5����
S:�N�DH$E�\��ù}�n�8V���]��S>&���
�����pM&q��"΅���l@L����Τ[gIM��"��2�Sz�����N��{��WAs�͓�~��S��-�dH�&��`�]����ڰs�J��R���y+H^ϛz�vd�
�"��0�8���$��.-�1ج��_iG�1�~EhV`�ޔ�?'�K�,֋#�8��A���aN1�T��|�`��)o��Q-	�Z���(�q�&Ei�����n�k��}�r���e�aq�1}F���}��"~���-M�W3��A�R�%��;aV`��B�M���F "�
����g�M:�� Y�{�"Z6.���\��Z�@Csc�o��_V�!*d�֢�O��Ķ�g��<(����9K�ŔO��oI�ο��-��* ����C��I8�{^�+�z�~�3���(�F��f�]7�Xk7v]�j�M7kUJ��'<�ofq#x˟?�q�Xta�'��i�}�E}���l�{Jw�<iV�l7��͑tЧ���4��"��x_PX��/&c��#`]t�n��fV��Př� Z��k� �����?�i�$�1�
��PA�4�޷4�ۼno�ޣ	�<���c
l�w��	�mKDl=�6�b��Z1��X/�4�~-�o�'#UA^��BG'���*���pU�gg!� �+���-�_C��8�M�{�r�;:1�Nch�=�٦���rm�'3 "&���+i�)��ve��C�m6�6�p��+	m4����P�S{5�{�psa�����vF�aΡH,������L'WN��&�i�� �ch!.�%a���VŚ+	�������{�1`�~]�V�bY���,Cu�m�|�����Ynj
푽ͥ���OfQj����tss@�1���;s���M��!��C��f����
���q�e+�o�$Ng,��4N�TQ]h��!O�� A���p��R�gE4#E��T%��?�l� �T�4I���i���i_�!qj��T?���9��_^7�E5 hb'�JC��������'�8���JU������9'J����qh[g��.- ��7�$(��꟞�F��A�Rƹ�k��z7���*���QQF�dvg'�,��m�S�N9��IrFͷ��Rk8��U&���K_��� ��@��LW���ՂPmγ�x�Up���V��yT��F~�g����Ey�u�-�z����p2Mvܷ�v+V�@և$J����BJ�&e�S�\7C{�#B2L��
���Y'B5Y�ֲPDN'�&�i���{lˑ�I�,��U\��Dz/��Z��r�H�����Ӡ���'��ݾ�t���r�MWE$�����)�.��(��n�:j�E�0JU�M���:]AW�3wǌ�7�4����f���� Y,�p�͵�(m��-$E��&�A�O�E�$x4��9��l6Y]T�u<#�Y�h��y�����'���d������
���Cvq����rQG���9B�X�&0�st�nleAg��řmRB`�J�4=V��7��h#o�[[n��/7~���k.$���[M={}T��Q���Ï��
ϧ�Ր����m�+Y|�FD�6��`[�{!50��������Q΢ǯ2g'�W���ť�ބä3�r���� 0̧�ec�=�����`�F������=�<S�,[~��%MR�X�f#�Z��;mHY��|�@�		�)O!$+���&��!�-q,��������:G�%�"ђ�P�ˬ�: �"a'��^}�
�]����(�|1Ys�CK�+���� љX�M}�NW��~ב���yGS���lN=�y��>AMf%&���NE,ς�V�@F�2�̈́#��$q�.�ɣ��baru����T���NE��{m~ZsPc����/;H�'�#-aHɥ�*�G��m�t$�Fy�˰vO��b�/SN�ɖ7���vjE�]U�,jw���8�n�*����b��L�%z������k�@٤��X�>UW�q{?�>J�}.R�y(CR�J�K��@�O�I���dq(��@Q�+͟g��I�*k*������
�9L�!g"��J��/�pBp��UT�3�4S���    ��� 1��!=�Z�Ϥ3*H;��x�F@E7"���;%g�4I�i0�ߙӭ>���"rB�Z� ǂh
�V�ΝDa���=�-��J�a�W��Z!�� h�RxA�9Yp�(}OSx;�^U�e�>CO	��*��P���L�?�*be�?�����3�@m�LPR�	n�a3LvW�����Z7?�^��4홙'd��c3]�+@�uuT�3��,J6�'��Ћ��@��8HgS�X���JY�	���<^A����gd:y`�9&�5RBa�q8'"��Դ��a�"w q��Mm%�wɱ]�6�,$еi\�X}y���^�y��bv5@{kKW��09(���R��dNzf"q�S��Ȳ����H��ZBY�(�h�5��j�p�@�Wr�6�L4�ހ�kJѻ�#�u�[ޞ���Q����8���5��u8弩�hl��,�{�(�n�Mΐv�k)϶îS%:�v����jeq��|��X>SM%�P�`[��߰'�4��O,��w]����جLY���H���ֺn{�Ƅy/Vܦޑ�ꛠ�E��F(�	��a�
-��~���1�C?�0�S+�[V����4���lgj���o5�~�錸���VZ��S��I���ؚnT+�*��1q�
h:�C+X#�8��ݗXT��	��܋�İ��|yc ��L*վؒ�ԪQܵ3��9e��ǖ�}g�b%Hk��ú��.b�$j1�>=K7 ���ДQƊOA�OPִ�����;�d����r���s��Q���'x"V���cŦ��#���̗�N�ox�c���}B�z�pƚ-%�m���{C�W��~�B�!Zڊ������f���Z��j�Ca�-b������V��9�~�����8L3��G�K�X�'?:�9�!�GqȠ��<ٕ@���q���\4�C_^�T�Fn��b5?m�BC����=g�nR�è`B�[���#YV�3[4;Ҝ�eg���(6������/�o��Y��n���s��Od�~$��xؼ�@�y�f��/8s�~�M9�z�K[<s���x�S��/�*���$Y��]E�=��&�.B���:ḁ\<��׿�_�e1c��I��7E�}� � ��5ؓ㺑t����#Mz6�ȩ���E���Do� �Я�2����(��Ƚ'���(�	]�w{S�R�+<�i���B{�:F�L�ҳ����0�`�Q9�,̺Mg�B��T���� ��VmLȂwS�7]���Z��ʹ����B�B���\:�%�3_|?!��6�f�y&< #�6�D�J����at�wL����X�f�������'�������B�$����$�MJW�p3~�:����Wf�����+�M:J�B�76M�ۀ�K����L9āq	�{��\�3���`�"?�54)�8�v�0OSR(����f!���Xv�&� -i���ٯJ�L����j]O_�G7�"(L�t�)����D��W�Pj����Y
�Ju:���ї�냦��|
��u�>�إ�F-�ݹF�zX�m�\:���^��B[F�L<-πd���3f�"+���{5�CT��d���1���MV-����Q�� 6�{k5̚(��V�X���S���h5������YW�aktC���s��q�a�e<c��Y�7u��
��4��.���F�8���HGM�7[Bn���T�Z1��`�UW���K�8s�g�=�~��bx�@�a��.%u�+�4��|�p$]7C�/�C��"?���\X�د�x�*"���6"�*�W�wݼNgE�3"���Zd�?C�/I�,�T/��
���NԌ���	��<�V��#ꋗ�
�<�xF��0ѵUx�:!�?�d�p��(�;�J�Rs"�C�V0J���ѫK�$�$�|���m5� 9����g�i�Es���QG~Ѳ;
��B�G���_����3Z�J,�6��ќd�4� �ԡ�	zb <����V7SaV�.#|��"�{�;}��Z~�$��(�g�E'
B+'O����l��� b D<�f�^���c��o&dQV����zy�i �<u������凋�ja� "�
R�6(��{"I�侞m���;�B�x&�'@uN�� ���Bt�,��ݬH
�=�O���I�-{`o5���o՟&�g������?�2�(������,H�oQFefQx��H*uE�
�Z\R	��
_��y��I�ʪ��<,$`��D؉��L�@P��� Wwe��:�-kv*]A��V��M�8�4R��D�?0]�)�7_��+�E����.!�˯x̵�3V�9K�@�Rx��h��7���D�z�!4QP@tV0	�"��AO�,�(�=
U y|}#�u�^�7��Q��Y�`$L�2�qT�i�}�0�Hv��h��۳⡫�l�ĈJ�Oz&wa��ڻ�ي(h�u���Z���xn�@�ۗ<���a��3�����������Ӡv���ÍiލG ���XA���Ռ�j��&���@ ��ک�2ZT���ذ
��Va�z7�\gae����9Z�a����ʦ���6���{��Pc,p�b5P�8�25�2���S y��Q����u�^43h��!̫�Ga���[�Y6#�YR�zo$�#�V���_�l҈�4v8�3�#�����b�-i~��}��!8�����jaU�ь�%��j:
S�<���h�"7?�T�s�e�U|�(����X�/�d~�
�a]�38�iƉ���l��r['�'�u�$�� ?�_�@PcB*�P�_I�yKBmd�[*�j�|�k��[���s����`8!���ω����rl0�'mht�m�sX����i>'0yjdL�a���(��!Ɉ"����F��zD�ڄ�P�;P������`�/'��a���'��֟� �5�|�3���=��������؏fj�)��`-�*4�S��?���8RD[x��x�)o
{�֛"nB>�˱'��a��/Rl�LwA<����M�k�俩�Q�=�k�un��R�P!At���)D��5�Y�pnh�;m�Ô����^}��`��(��,*M£ȳr2����qHDj-�棵Y)�,6Hm:�֚��Pd��Q`�$͌.{�~��c�}b��:{��=��G�LKy���x��"�8M͙��@E����4���S�,�s����ě��	��B���r�����ճ�g�Z��V�U��~�i]�e~5c��A�x�(5����^2_
�'r��3��"�i� r�sx�!�ǰ|�\�M�Z%�o�2��WN�\Բ:����;P��	3=�_i�]����P��g�QQ�s�%�N���3�N���ٌw��2�yؼSц�|u�����n\�m�U2�<;ˣ����ȯ���dk�� a�_�N��r��_�V'Ҋ{�KE�
�����|F�\�ܢ��>8�������dʳ��eS`B��/����Z�_FkUI�by\�t匍[�/I�z�:�ƀ}�/<�h$(s��  �V)���To��V��.�q��l-�(�o��^KJ_AI�Q�� }�I��zY�dg��|M�����Pa���82��_l�AҰW+���gg(�	�Y�hoy��_�Dm�n���SX�Z�͢��Gσ�b��ج�W&i�W�q��F0��Q��kM�<m@��	-�V5�h4cfA�T��&�#�|gEbM�*��,7�z���T��<���
`Jq��3	�9t2�V�	�H��4���G���RE��)�����YC�E7���0�he�����7%BZnZI�Yf�ٝ/�����d�z��J-���q[�U�9��j��`���1 K���rZ��������'Z�#u�%٠b;3_Z�*�
��ߟĀ������ Q��rgFA����]'O�l?�R�ɖ����#k��S{�a�嬬Bs��G���֋_8�c�D�L��W}J��|$.��^;t�6�f1����ŕ��L�    �'��_Ćqh�/�0i��W��h��a1._�=����1�ʓ��(.�/=�QuK%����!�1K�}Q%�<��P���my�0��Z�X},�l��7����Lc_�؉�};@�S���Fz�6��&D��ȿ&�+OQ��2\N�U�/̍��*y��Pwϳ ��.	`�1�gj�����{$'����[\���D��T��$���sNcԡ�ʡ2?=K�(	���˼��6�#4"�GEz�9�qm�u����Q��\���ED�?9����f�ElYI�,t�zH��;���q��Gˇ���*cr/�+�Z �+XUu���1
?Hs�Wb k�5xyZUL!m�T���Gu9 n� �+8���-�)�3�z�j��� ��yx	�,�m֘II~i�"����	(�o�� �m�	�-I�?���0��*�̷��T����(B���Q ��A��T���V�g��K�F��I+Fo-F *V<��C+�h��.ָ$��x+}���G�bQ���?����/ּnhE���Ȇv4��`>MW�w���;�{��:
����\�7Z2��d�H�����5�!@m��A���!֑��`i��LU*�� �J\��fM#���kوQ� ��Ѥs��$n�
�9�@���Z�����ď�����C=7s���G���B����q���߭��Y)�#�dr�I��3X�(�T�")�G����*�8�V�s�XYwV����2�	���'��u$=]�J�M�
�`IXF�����G��������m�E.�mL�h��0&��������#b��'�Y�Ww�'A���MO���w�����g��>PӉQ��w�b���|�h��6���n�M��W�ra�W�c#��B�Jw�lն�i�H�GhV�&Q���=�kd�Q��D^���J6��D���Q���@I6�ζ��q�q��P��q}뭈JExi"��$rl�.��~`�66�!�&��R>ҽҊ�V�ߪ�F����]�#yC�g~U��*{f��_�"�.k�!�G��;E���Y�"h�#��T9�*M8ɛ���҆XD�E�HV��,�^����&�N���?q�q�Q�ǅ��h"�/��H�p�.�$~7CG�H�"�:�oV�ά@�s�5f��Fu�!�b��ͷ/���,b;��n��}�n �NZ"]�/I㢞��Q�eNy����M���.ٵ�՝�|����W[6HoH��+H������[dA������Y�)
'w�#"���'y��@�Y+�$M����u�*]E���y� ��j��FĔ�K
�����K�nKf\�yj�*�>R��f�OYq,u'�ٛ�^Q:Q���WR6��M����0ZIs���(��P%<���ק��c�����o�&��ߍZ�Bb��Is�I����,ކ����MvB��p�Q�?�t~ݢ�g�"�-[~��4AS�3�V$:�J�h1���T��~�LH��-�%�<0���N�-@�
�pI��E{��,�{���I?��Y>���&6�0}�|���o���i >�ˀz����G� �h�%]ڵ���ͧH~�<u��K��Q���w�b9�G�#���R�Gf`��|\�gՌ�ݏ�T.���l�1o}�5��������_"0�2z��&�I}3���i����*��B`�����oں$��ܨi}�.+�7�͝P/�B�y)y�	��Vz��V:��Q{�@5��y�������-��e�^�E��QH>�9�E��Ug���k���B�����o��5Dt�]�%��S�4���
��b���|2^z.[�/�K��(;MO�c[�vt�sN����bx�lo���~k��sk���ntA�cs �����[�ҟ��V0�Nú�f�f���� uΡՌD���2bZ�
�/i5ڃ���X�:�"�@"M2ZA �6����IXz�&���B�IR�k�@���6���cj���Y~B��M��3�U䡞����6���[Ku�����ڹC,���̗q?Q^�Z����?ci�y��%Y!���x��� �k���U-���W���Ґ�
��i��������N������rv�%��
㸽u����p�F��_t�yeN�����Q��,� ����_:��jDW�`�z��, �����9���_H�:Mz����|۵��dƕZ�"�r߳�%�e
d��7��x�~���&+�F�{�o�0)+V�c+?hf4N�"U�x(Ru�5��!�6��dP̹����R����sH��~z(�"�^��'�](�uج\A��N���O�&ʓ���:�����d?�����p)�ImR�N��@��oR�mܶ3VTh���y����$A����c��V��ߎ�E�=8HUU~���}��Θ�\��Q��eψd��r���t +w�x)f�� �ji�yro�z�����I�hT�����h��ʓ�!ډj"�X&%<��l����@�����/G��aZu� }e~ڍϛ} �`c��dB~�m2Yض�p����b3��8���xsb���t�Q��aw�X68�Y D��iTK�v4of���d�ʭ��Up%7K{��������FpA�P��U��v{�f)��j�l�!��s��G�_��5�0'Yy���<�xFeĉ����:�I/�^�G4Da1h����Y��&�����=��+�QK�L�Zy�=��˶V�m������Ԟ�lh�˚;;�a�^�R�����f$��+ME���$B�F���l�]�<_����ьC�f�NG���g=t�PJyr��v{"�=��7���݇ެ��yk$#&��6[\�[:H�-�HZ�h�銎;��W�7�^�F-~��#�wI����Y���79@�.u��OL��^\"�͵�o+��V1�.q�<j��'*੫���9h�i�*���YX�	!�N�����y���M9�]꒶�0��@Ƈ@��P�FX�+���q�_u��-Wfox����N+w�3˺zF^����c� q��E�פ�I<�w�QX��-U޹� P��qgYn��Y^d���|��}����VES��Gb�7���(��LD{��Ҭ.���&c$��rU�WX�#k�,#�q���i�,(�8%�G(dM]G��a���� �8��Su�{�ѽ�ϼ����	�8C�W]��
VY���0FQ�&E����z�~<W�nV���Z�����ԗ�\���
ds�ȋ��#f���Z���sǦ4 &�O0d 	�J`0@�l/�b9訨�6"�/s桟F3"f�G�c��Sd�%��3eU�o�>d��Qw[^/f+pV�q�}wؠ�cV���A� 1�D�6D6���v�@+��V^w���WѼ17
 ��D VDz �'O�d̴�6�A�	E[	U�2��E��-o!e�e("�A%���Ƃn3@2���#%k���f:���k�� �0�}yz��(����~�0���,�uF��nT������ۡ�"��d*u�%�O�<�����DUC5��#�����v�MJM��Rp�;�d&�	��S��	9�L�E��ؖR�8h0�/E�m��+$��(��^K���%�0��E&D"a�ZǠ�v�w�������/����&S�G��&���M��8�h�BzN�����W�b����B����,���f��^1ڎ�7���2���F�E��S�$Q������'�����V\՞�-x�湬`��I>�i�(�h&�w4sDB}���ZybXHWD�P��(���5�~*M��O��
ڴަ"-��82�ٔ;��R\�NԢ��1b�]Ƽl�rN�
�Е�y__df>5���X�ڞ$�̢����Ƥ:P�N�I����ܰF�f�"��
r�:����(��\�#f��b�B>E;I��M�ĘA:�D�ҟ�d�(�޶�7�A֩jx����K�I����6
���v���wY�����vyc�nL�i���+H��*O�OѢ�|:پ���"��vl@&,F��H�P�uZL����/���    ��(�{�D&𾽑ySv0J���׋+��a������q2%a$L�8�oHK��$�v�����@i$��7"���L��-�I ��1%D�����|k��E��+����|��������i�ZX����#��fX*�GP훷3:�o�߷G��߂����z 7&��?��]��ns�ג���y�2�wXTb#�|��v�H?O�B9��\�,#"��`aɭ�'T�m�؎i���qy�Z6cJ�Ԉ?⋓��Z-�p�]�"�2F|2��g��Wl�	�Q҅Q��S���9�(���4҄N�l������Dˇ=I޵���"�&�g̬Ŕ� Zw�"������i�&��i�<��g�zO#����Y�'����L�����0X:
��|�7ηbX���:��e����
8(E�Es*�"N�Xy_`6AQN��+�M���Ѭ�/���?ň� �B�#w�%���/�M{.w<�W �*J���(�X���"z��p� }d WP"�~a��6#րB��
���*���Zf�������r ��%�W�I�H.�Y�y�����$��<�G�C=��ڇ�����
JS�3VBƙ�o!��*@�*�$�
\		V�!v~P�_�����7a��%tl�ګ��T7u���/WR�P�l_��,ʽ�{n�{��6��At|��CȺ���%��(�R0��<����Ƅ)�ږ�*W��l�SB������N�#c:2;ɱo&��ck�Qpo�@��@*��)˙/1oMd������ E��l������	�ޥ<d�9ϊ7H�����m���b�9>ծ[F󘆭:�ɯ*1`�SГ��W��)�K���wq�]�9ἧ���K�~�&ب�a�s2�)uGބ��`��iZ��亄�˗�&�V�V΍�a��-�"��܌�L��0�VΨR;l�=��Js��<���Gy>c��P�VWP�aY���i�f*S��*��h^� 'hm�Әê!��j~O���6M$pN���Q�3��>i��{�����6%Фx�������<�Ҁ4�Q��%� ��Œ��v�;�6]~ߢL�d1�#�f{�9	 R0EO�����UL$Ns}Q\n �'�����R:@b�b��ʖ�K�&���mMk!r�,<�ʸ�?�Y1�z���'Z#�w?MG ����+I����{
h%d]X휝{�e�Ѵډ*��T�*�#����3?�eu�	Of�o�}�+XYN�wL�l��K�ZW#ls���"r�&£dH�UM 3@���Y�R��I.8������
Vu�w3�?q�,>�\�T�$�h� 	}�|&6�$�Ug~��V^�f�_��X�S8L�Vx�IP*��
伬fȉ�9�q�{�9S��cG'����i�����Ѫ5O]^��W:�
2�2�fte� )�)������v�tX��?�9;��`W�/b���9�#g쭿<��`�Wf1�_�'aP��QE����+^�&�7;7�l=��*y�2���)�n2Rf�"A&U#u���Y>F���bF�'	�TӪ(���P�ԡ�NI�T��%'�tWk\$-寽h�#h�
��4��Re�;�Q��6�ɔ�,��~�� ����MA��pzQiJk�![ȏ.b���@��l�p�Dh'a��M�_�5��:��J�����u�e�����`�VM"��R�_0�yYh�cJ��SljHNA�)"[5{��C3b/�mP�N&�e���i �Sb�e~R�#[Y�Miڝw�Kk)wyIEմC}�U-]�5�:�Z I�)M�?�N��rƸΝI��}��ůB�E>O���(=;��4�[�c�m��vH��b�����%��3ׄ,B1Cж��O%���hm���hy`u��5WY��Hf� O�*μG���F=���5�p��a���ϠHkmC�*��b�E��f���{撚�g��Jk/a��L9{�V�����${΄�`�#Q��d���Zum7#�Y�( =*L(�VX��3�cߵ�C��+�z3ʄZm�-{�/h��2���H�A�/���8��	%y*,;�����y
�h�@۽�^�K��z�8��3��JfY#l+���Ҵnf��������I�����\�غ_H����V��5J6V���_>x�ʪ��?�I��M�8a1��<Z���T֏uh�{�K"Z�f��o�fR�g׀KSR�w��f�"�#��a(d�8����u������� S���e�M�ӝE�Z]3�>��B�"�Q[��sA=��j�����2D���ӁJC�c����V��T�b�F~��s�Qe�Q�lEt4z{��8~&A�h� M6�xG�dȶ!l���o��j1&48Gk�:a'�ڢWK/P��۾�ړI=��Q:4�Gv���"���5�,W�
U�YY�߃MC?'�8��',���M�p��L䁨L����+��q�����WΎ�M;f��ő:p(����D��*+��͓L�{�la��Mg��jE�`�f�55��䠘���
y���/o[�U�ܟؤQ�ݓz�q�����^�|�V���$��V�$�~ۗGM��Bm�(��U#͉���(�����Ӝ�ܥ�F�{B��e(�TqIW�<Nٔ[RL�;�V#B��`�vIP�YƊ��s����!*h�d��;:J�9���h���O���iR��T+��`ˊ��\��t̨+z�>�z= �e\� U�gt�4�ʔ��;(֖�5lq��&�.A9��a�p�� �KJ�=U�"�Z�Y�'��TF�z�*�1^�
zmr�h�v��,��fL[�v:z�Y�r虔o[�+3R�_�����Њ�j�%H�՜�$#�$%����Q:W��9�PQ ��Q�&��>ЗZ% d��G�uܚ�tF��B5)�ȳ�T��NG��V<�/Z�"_�Z�Kfv=�4�)�H�UH�<���4����i�&��]Sh\{q�rj.=>�@�B���<��@�pOcZ������R�)�^���+��$Z����z!"�ì��&�/ m��1��Ӽ�9�2�mT�:bj��R\�`��p�? �s?/��*�IROd��]���S���%��)6O\w�@d�M�+z�x+�������fA���$��=� �L�q�;��&�s��<PdZ@�8n������ݜ�n��uw�:SJ<W0\��8�a䒅Q���8�=tô%*|d5�Ҋ����o[W�`�@����,��o�,����~#}��G/��Ɉz��d}�w)���+`�yQ�8>���/���2���j��o�a�;Ї�v@M���7������NΆb��� �[!�\p�
�K}��_ǧ�H*�b:�H���#�X"�.�M�%���^6�����?�_v �
��+0��~
�q�)F�&����}%Va��K]�A4gq*{7�M2m��D��^�y�G�������ajL�,B� ؠ���O8��
��릭�!�s_l�̿����E8�4Q2tK�����|F8�4�5��'�ޚ q�X�*���c_�ڳ�i�m��+�8V5~U�w��4�\�FV�y����(9�7�A�u��,��ö-��SO�����9䊦+Pi����Ȳ �ْ�fb�,��7�(=�?&�]�<�s��3K��ף�>��|溌��!h�2+g��̩㥉�E�wL���5̱���+"� BQ]�]1�F��i�֙� ;tH`�n��P�i8u(�1� �Iƈ�ly�ģX~��M3cb�Q��`<!g�#t	�U������f���"+qYU+�_(�b��R])Z��y�moh� 4����`ԤA>ct��A���i��G`��o#�N2�I�]q��Ь ��d�?C�*��0��{Zx���Sp���.*� n<l�H�3��yo^^!y�<H)HZ@�W�|�"2_����>pMa)&�'���wVU��F�io�-x^����h+�lFN��Q��M�����lz�������dYб@�|v�2!��z�a_~%ڔEZ͈z�B�B���0c�gΦ�G��tl�ݙMLl�[��h�Wջ�5�     �\�ښW�x��H.vJD��*��f F�(�u����Uݬ�j�#5[��MΧ�R�E�dp����V�2���)�+|�]���#�k�Aꪚ�ÐǶ��j�ee<���m����Z�n�Тc�X2I��;�SaoaĮ*b���i�4�?�Γ(�WL�+Ď~�����v�ʢ .�
��.L���cyخJ�z�V	�$$��L���I�I	mh��m��,�x�q�I������w�@��B��V 4k�$��u�.��GÂ�T�Vh�72���9ކ��#Q҇��'�܉/��>�V���e�?F˳\un���ױiO��i�X�bug� Kֆ]��H���T8JVx��{�WG��H���"�:�i�E`V���Q9�9/�8�=����D0�E�3:VK���N`26����o�3�J�=V���P�nG9-�W�m8w5F�d�kw���\@�9$8�U�N��hb1��u'����i��UW�aC=fڇP���n�)q�6����ܩڌ�Cs��.4��6צ8�����	�-*��Ĳ6��Zކ)�Q[A!��~�ωZ�j!��	u�<$2�g�A �I���|���W3�N�0K|a���'8�p��i�_ʎ"5{�`��DˇʵeV� jQi��'�̧��w�9霙��P� ��Vy��2q�؃���I{���@Phq;q^��²���*w(ed��x~h#�+U9 ���t����|�7߾�ň֦%�li�i�΁jGK�E6�fB�ErE��z��e ��\CByf�Ki6�G[4���p��g�#$��iC�L�6%9@��uTD�RT�0QZp\�|W،�,jڎFEB%^�s?ε�"����m�73J�$��X�g��湚o���v`.�����T�0!�z2*��G^N�5'D�I3�)R���ηGX=�(�6�e-CO�J �w���@�+n����C��NrD�����_�������"��֪���}G]"��Rkt�JszKV�A՜�J�1�U�8�,rx�ˠB"�� 7h��=��B�-��Ԟ"�7�dײ�Nx��3���*]��s����?�hD������t~㌭��	�Gmh�/���!���3�� X�vi��	Z(D=�t��,�|���e��~*��椩�&��SM]���oi�N�|�������"��D���W�Q�W� �%�<"6+���:���*�(�eo�&�k)�ߚ�l!3��

���iJK{��������.l�9׭��c+��v��iK�髇�7��S��j9PH�=f��?��J�s�Ɣ`�e�`�E�)g�3�Sݗ�GG��[)k����a�V yM�λCFV&�8O�"��d�_�vI��dH?�*�����I�2���XF#����]�v~y��׻�@M��٩�����6c�bAY�RA�i���0�U.�H���E��T�9�V�	�@
$���JeI�U+�(S��5_A����[]n��|�#d�Uo9����$��٬1�tm�
H���愈|���@h�<Vp��a��3eZ���!�G�P�����M)�7�#�7��/'Apj��C�V0r��i&tq����
�i7�	et���tđ1�)���m� � Qqbj;%�7<�,�:�V�6QL�L�a�4��7�v��^Y�F�CB.+��"icmM{
�"^+��뚼h�����̜?0�;�A�ì�2A��5ˉ�3���;�%bU�سH2�_>4�k봚���<�u��ޟv�F��rۿ���nPe�ͧC����8�N�ZW�����zS�+�krY��� -`��%O���8u�B��a��L|Q��J��٪�&'����<���8��+�|��?P�|���B�nm~�W��sIsA�y�v:�����D��I�d0v�C;���ƶyڱ���D���~C� ��ƺ_~���:?�Q!di( �ď�o���^��t���8*�gYk���ձ���j=b����#?Hһ��&p��`	\�}��C%��9M�\��m� �6�	9�#��4ſ�����a�r�A%D�g���%�ä���Y��<�@&�G\����Up��׿/���Ho�m���C��CF�lCn�v_�e2c�H&~�jx5�T��+�`J�E�j@�$<_a�>-h�m��[��eZ��~e��dޟb,��c��_�Gܬ�
cA8�@��n؆=��Lˤkm�U��Y�2��Al�&1�=��������h m9��w�a�ژ���ǓX|�)��.��oa�Fz��PL��$�����ף런kNk#W�����-�d�Z�.Y�ג{7_���Cߟ�w�"�F^`2�i�#�n�.��"8j��bM���o�i�PV�m�8.�C�(�b�[���]��v�b��/κ��Ш�<�,�8 {���
��2�g��P`r)��	i� ��Z#�p�]C�y��7�#������S�D�j����ro�N Ə�V6DZ�@��	dG�&V5�p0;��F��N�8��G0�_wa=#xi�
b�f��9�k����E�R�U���n�U�������"�i�(��,�x$&13wbU>[Y���|Q+��ĩ���=@l�V� $��!�+�;ߏ���ٝz#�`�Ed�B�H�?�m�?�8U]T�ED�F��� ��p�y*;�j�xk�d?����Q�Hqd�/�N�
�Y��9����جQ���-)]�~5k8If����\DX��������<����]޵��V�QZ>.+2�g[�8Պ<��yP�0��6�ؑg� A�I�t9q�e;�f ��/�������&���}�;ឪ<-�b���I/��1:RcJ;��X��J�(�?a�8��$�o���|qљ�z�� ���è�M[@�v����A���YX�ZK���H�'y��ܙL�'sCu�Mv��Ӯ0t��擐;Ą�f]j2��+�_gՌ��E ��0��KC�[籢��\۩`�-�Ĝ�w�A1�����+�.~�yl���a��X�j��֎�@�;⁏-����l�O�82P>~��䱏h�\~1Ezؼ3��-�fJf��7T�:7}�#D������`������l�f��f6M��[��.j�H!��ۜ.P�m��H;SnH�AT�Ov��گ����$?3������P���|*���ms�p,��Ea�Ƭ���t�����#�Gh�b�	q���ɚ�����A���Ў����rIM#��Rֺ����z�(�,JT�'��%~2�	��N�i;�uٓ!f:����F<g��n���9��Ѱ�N�	H�cM�u��D���@�1IоӒ�I��?������㤍-��[�mAB��+j�8�8�ٗ@��9]��	�wG�G�^��i��"�-{�I2�z�_P�[�ޖ�Z#X��p~�D��T�m����,c=
Fn`2��4rњq�l��6�������{B�/?d��g3��a��5ϐE��(C;�2����(KQR;�E��/�������"��7�;����f���T{QZD���)���H�3@A�O7s����ؓ���R�Es���|�G���d�Z����8�є��n��BҨ��9F��~�T'm<�1ɜ���\��&��zF�2�,�,0�F�(Mm�����������4 Hвh-�T��L�|پ���x��??�6�gD���X#{����X���=�~��0�������PqQ��0N��4�;�(,(�I{cҐA��f5R�F�8����M���H9d*h2�x�f
5�!�؞�N�X�ɏ'�ݙ���WpU� fo8���/�@��E�Ԃ�EsxP��g��7�bW������*fL�`��	��� cm�{�3�;��0��_�G�;��Aq���8��Xt�x�-�0������a���K�G�>��ɲ���hv\x�yn}R�(��NM�m�����@h��zF�Lb�ә(�t�`*XJL�d�b����p��o߉��HJ������AXd��dg�v�\���Ub,0%v)���k����3    ��S��#j�
��ȋ�;-Q��n��{4���qP\cj� ��|g�.zڊ�a�����ు�1b퐔.��~��\�	���+�몪mg��id���G�U��=5w�/�@�k�)%[���G˓��^�ZCMV�ŜD%-I������i�ȡ��V��]�ڏ��2�,��¦ng�â,Ku��r`6�^]�g��h�#ɲ,�`�~�ь��0S�8��eF�p.�V�]��}�\�<��V���m�b$qP/Sa���Y����$�B0�~*�T,�8�޷��IV]����Up߼�OG���N�3�1��E_ɤ�J�C�V����������"�t)&��n���ye��ճc��ؒCg�x�Z{�����P�$�~O���� ��$N��i��[��4��(A�p�-����<�x��(j�~l�t.Ӄ8{C�D�-�9v�<�9��CX��������O����5K�ԋ3]~$��`�*C5rK��� �N���d��`��amc�p';��)3�Vlx��7�Q��\IWT�gq��:��ST�&y���dZ_�s�`Ｙ����Pp�����b���"����M|�zZ�hh�u�.è<�JV3����cij���P��O5[T�T<lޙ���%E�\&k��[���	`k5Y�!�ݫp�I:�2H3��f:�Ȼ���&G�_�)�b��i;;���$��=z���h��3b}פ���S$O��2U��D�h+\�C���)Zc�U����|@�9^ӎ�PH���RQ��8�p���KQ�+�j���8����*5���ץx�:���Q��4{��E�����-:=��P�2��.��T��<�ـ5�g�v��zQ������8�,�?A�Fi&�גny�ga��N��.h�
P8E�9�w�K�w�� %������g������1'6:����?�1���
9#�'�dB���^
��(z��*�7ɿ��aW=�.�(�te����b3oB�+�݁I	�<p����������tc���y��0�Z2R���`�B�l��|i�.0 ����a����g8��,Ĳl�9P��\�I�}�{�!��-�B(�'$�q�ih�9��!7�����#T�9?و��Y�+8/����Q4���Ӓ�x��cR�no؝���a6�u&ϵu�<��܍����%K�\#�x�"iљg	3h���ɰ����
fbQ��N�y�+�)I=g�qřl̙Qi���� ��8:�n��Xś	�D���iL�ev�A�:������.	��"��'��NQs.�@9WF��������j��dC���G*��$�q��L����1C��^��Pذl��,����V3J܀�ر$P���NV H����A�H�$M�-�O����L=���:XKS^��i���Q�fKnW��u�����ʺ$)R�oS�'�b8�75v�P�1����Z{gVQ�>��NDՅmYl�����5L��In�cP� ����\��g�|�J�}��s�E��I�6��D� ��﨎D�x܅�Cy�X0��n{F���>u�
����Z⫄Oq��&M�z��+}Jz�<
&���4�گ����*��͇��~sJ(��I-g�fQ�V3"VJ �cn�]�{���ģͳ�J�� ��v/ �6�Q:UvY-ݑ�i��8^I�0�<��t[�����z9��vi���лm����I&�X�W��KQ��8e&2����2x/�ٻwu@B�q���@���J�L��V��v@�u;��}�Δ	�,�om����f��4UC�,O�Wb���A�E�^^�+���N�����w~�:�鄟6� �\QB���=�6�(���I��@*���[q�lU�N9F
R��X$	����g����P{�. ^���B����w�B��� F�;r�`A������r��,O��.A��%��ή����/�vi� ���8�=���Pnlǎ�����X4Pޢ$@t��ÇV���OVprMU'���389�40ςO��Oi�2GQ]0z8��C�W��e����lE�mS|�y9���.��o+���?_��Z~�?�)�+[�v)��.kf��$����E�tt�b����M���k!F�5^q��.��ނNZ�t��'�����`5�6Y=c˙Ei�g�����3�,�]�u��gR^�����^tg�$�+^��vB�(B�t�1>��ֶ
g��3�E�Y������pX�\���٪�R��E�Ǵ�>)��;)���.�Dt�R�I�5f'2+c�'��7XВ.����"d�-8�
�j'�U��@��׋�G�r���������D��j�(�$[��(�����1m��y�Ɍ�$���CY��+�����2
����ۑU59E�
HX���w��U��~�,j��<^��Q�z�����'"�0\�zF2j��B$���	��,f(����v�H��� /'�lWA�"'Ǯ�k��ml� $5[���O�k�z��7M?�d�.����s�D����ﳲ�z1a���5F������2�R�|�@��Ɍ�@��T��">ۂ�j[{��^0�;�
�V��C;������2"��D@�[�4˻nNJL���KZ?�~X��r��Ϯ���;��
��6�t4 �'\�ޒ'��)F�
�?2c��U[�%�B�� ptT����g,)�:q�'0<�D�	��=GUǶ��w7C}���j�ۋn����Y`���\V&���<��MK�2 eC�T>x�T���7�wrC8�gW�Щ{�-AD+�d�*�錰��6c��}�@�C��H��v�Y�<"�9O�F��=���8�X�1�묟���WI�e[`�E���L����I�:�`�I�p���?���,ב���߁��<U���'��5t����{��|�| ��0_Z�w�B�6b�
T�.N��+��8�I��2����3�n
�� 	�YC��gs�N�0,�P����Y w[�hO,h�_$�]�I�?G��*�̌`'�g�¸�u*�3�U��pG ���Q��-s�����8A�8��o��	g�E��l`L.^$���ɷ*�#�;ʇ�Y��_E��'�@}�z����$�(U�q����q����L� _�{�﹆D+�E�urNP����WpYF|�c/�ȵ�����G�R}�Ҽ��Y!\^l@#!)@�H<abtv�l�T�B_�~�,���ӾJf��ľz_�൰Md=qđM.� ӕ��V�"��<R|$�/�m[S3Rf��� �0��a{�q��r���i;\�rƐ��s׵�E�	J��PITQ�
BYQ7�g�^�2
(5�;m���*d��Jζ�Oҩ���By�J��گ���	����(6��P �I���
8Q�)�~`Eml�����m)OGp�l9BK�r0����lƕ���4x������\M��_�Bp�Ɂ�����\gl�PN��~�ѷ��������+W��˫�Ig��Pl�?�(�"������n!]���O�e����3��ۦB�y�"ґAYBI���i�7�P�yy�O�W�	�A�L�ȥ��O��ڦ���g8��8�w�`�p�HQ��wb��3�h*x���F�gQ9P�>m~>����{?ɛxY�xr�>�����7������E��"u�~׳#��EI�6�������w:s����3���J����
��s4�v����u!�4�UD��&�zps^���	]�N'oM>�CV����y�;�������D(�-�Зa�[-XM��C�� �Q&���>)p���������'���Ҿy��,]�|SD*��v�x��}��@��(t�6X��9��^�������Us�Z1r*I:u�)l�׉\�+p�*b�9?C4"S����y��<�虪&=�'�K=�Zg)"È� fT$U;��$�\� E���Me0�b���x��1�J��I��ȑ��^~)\�M8C�ݤQ��8x�b�v��������H�6]c�IwI��G�[����>������9�+�o���B�    ]�� 5 n��lOR�k���Ju*RY��7D,^�b���m�xO`����D,�:�T��:;���ޕ�qIV�M2q>�N�e�j�塂�����z@�tnb�;�И��ĝ���7�7 �A����2ig��L�e*�˃� �5�U�/��vB�GPV@�/*�53&[��z����]���UT��U�J)R5d̅�<�q�g52�a�K������hwyA W�Q(ꪛs�L��W����ƙt��䌌Ijlٺ���w��#X�{��M��͔�ɴ -�SQ� |&`{���h��Կ#B+ M]X�hx�0*K��Q��3��'�Fm\M~H^5Mw������nw�H�q��VV_��xO��4w���+P:�6C��pU�	�~�+�5U9D���r�^v��l��J��t:��s����8Q���.T�6��ӱG!N[t�T�?�WЂ�����1��^w�quƟ���k�h��iXEt�ڥaQ:]¨���gr���������T�4���-?t����b>���K����]~0LX�3Ʊedl7,ш�wн�\ "<�b��6pL�,םU�RqFER�R�y�8�W��ӕ�����Ǉae�ǩ0	^9�Q�1�2�sw-<����>�t��Q�)��9H�e�[�k�o�]�G�ۙΥ�
�(&���2A��??�[�H��ҝ�<>��'86?���[����g��>��ħ��A�I�9@q[&'�f�:d/�H�P�łL�(�Q���$'5>A�V�q�ʭ�1_+3���}σ��a����:v��w�&��y�q���Q���T�2K�6�P�M^�3�2eV�F#g�2j�*[�zKTV:�t���/���)L=C¿��TNyd���?^��� W`�q�����6T�B��_����ұT��m�W@Sv��w�J}���3r"\8Äe�a���lo��Q��A����K�	/-��94�t��uY�&�k��/��T_�y(y{�BWA"�ףl�p��YY7�x�.�#��$��\����0u�3jS��YG��|��%������j����q�n?���&��Es�ŉ�*��Z���y滌�VG���ޒ���mn�o�>�`���h��agQ��q*�Sy�����%ڳէ{��m���Wl��$ ���ہZ�B�d��Kx�����.6]Q&3B�bCj{�@��O�Se�������Q�Q=�<�d����e���R�QxkQft�'�h�6�n^�8]�U�u;',q�f�y�_�vþ�A����獽t����2aSŷ�����u�^�DHFxa�g�ߧ�qh������IF��-��"8��DF�F �Њǩ�m�񸳒m$;N̔m�4���gF�|M⬝�4��R"j�Wx�=�,����3x�`�˽�RctoE{T�tej���iW)܍<.��;�Z:_�6�ف�zlL;=�BE?� ���/3ȏ?���|��I(Px����.4":�>�3ɀ�j=����t�P�Y�ie;�aCq�� �Um�ǃ�'�b��!���t��o6\N?�C]�J�sL$ȣ���G+���f��",Jn$P7F� Vo狳�^~��=�s[�H��� �-�q�E��5/Z~�Z�>�f���Z�$I�hwԩ�����M�=te���*��]�c#Үn�����6��
\T�*λ̀�E���$>����4BVЂ�:P�BٮsW��N�@)e��d.�7(�8�f�e\�h(ɂߺ�A�Or	m�y������L�6����	�Q)-�<@����7+e�����!
�"�"$ɹ<��=��^y�������`��ڐ���Z�j�k��1��V[q�n��fsK>e2�����7[�q@��4��Z�C�I�8J��=)D���@}!H�ԡ���
�4�U���@�*�����n�؉=�+h��6	Ǣ(7���&xO��@v�%��×j7���%�G\Mo�e?����˾g<�Q�*k1O�kE���Px�vc �|$�b?.:CS4�/���RJ��gFR߿�ù뜰>���*�+Ɍ�&��	�)d�GG�b;��ܖ��xO�_m�f��Ih����/:������(�B�Ⱦw�;t��p��c!�����τ}�}A_����8���#@7�"���TI�3XZ�	��8���cT�j�p+7,X�Z��+ʧ����u�ij��gQ��w}n����,�G�ҶI/D�,/��J����mS#/�E׈Gh��۞F���u'P�Àp�+��y�I�y�p���\a@:�v^�"8e�ߐE�g7��_GȒ�O'�"�o����$dY��ҙ����'~n�5ڻiy��e81�~e(v�=�C���/�q�^�E)�|#�(M�?p�웖ͨ��2�<��nR)
��
�MUN�6�ިF���=�m��eؓ1���� ��m�+�,�q�MEz������,&h*A�	
p������i��������~p��c"LE���j�\�͙�%�3�����t˖����F��2x+ ȣ��^��ru�l�)ĂJc1K���ݨ�P@Q�v��Ȭ�5yU>�8�E��lY����c!�-~��B�'�S����]e��������P��n���8J�(R�Y�V�ۉԝo��4B�ԅ�r��L�,�3��@��:��<�8����)~��Dco�1�v��A�;p��%X/��Rv�M��k���m,��ǵqf�^�$�e�����̚ښ�G��}�miK��=$�d�p/YG��dcD�6�����<��Bǒ���&~5���9=�������٩�XA\�8���:{�z��[,�yf��	o�%;՞v՝�:��4��H��
�j{ɠ��!Uf+�\ԉi��3��X��w��s��,��ѶD6>]����>�jQ�g+�b�Ӳ�1-��R��r�ϟ�9�M�&�F�8�
�a!�>��wު��	JW����uV'Ō��23��g�g[�.$�j��&Hv�����������y��3��"+����?���;��,��	�F'$�k��6��1��O��V��F���6i��H�ƩQ�a��P�a�)2}*j�6x�REp�|�V	���C$�T�y��+uEvJ�g�\�#BL����B�o�L����Z�KgL�02�����g��;a�V�(DV|ڼ�̨��������m�u�� L�^5�k�ls)���ኣ�V$�k�W���楢8��xV}p{|Ci���mN�D��v���vO�/h4ē�S��P p�u,�a�^�m��ةa0:?���G��[�o��xD;g1���{�*���!"����w}��<��9ʭ�7����b/�dp/wJ����m�n�9|�$,3%�I��kje���7'�E�~�Ԇ\*�/X-݀�B<��gxM�.k��ˠ,���`�R�E9��L"c�	j
oP��U+]yv����tuZ��EI�U�Yz<&����R�� �M��Ҧ>Pr���1��Ma��q2
Z�v~P�H�˟��}�Ψx�Ķ��:���ܝ^1�o���t�уD���A�^�@����o�&J�tF�`7�eI|Ƽ�����~�4\!s���RX�E�<_>Π��~N�ű�s����*ێ��t��+Ip���<��;�cy���k�tE>#<yX�ge�3J0BǤ���_rU_����Y
�ɒd-'�M�Z.E�]�R�O�)�ύ50ƶ>T�-�ز9"-ӖZ��bz�.��%)ّ
�����<�g�쒢Hu�_D^����!J0)[Eu��=���=햺��
8'MQW��%Qb�4ң_D�z��mHQ�EU�X���JY�����s-cN���(�Ǔn��<��^@\�wSб����^������};l��X'�E�C�ps@�ug(�Plv ��r}���KG�T�3��4f�	�N$E��XA�`�*~|����qwn��c�K�N�H�48kg( q���:�' "�0����st_����:�3l搊��Å���E�@&��QC�_������ss�����!    ˼�vu?Wg!�
	�և�'�n?����f��0�="/�a�p��C'�O���u��W��-Ѷa�M�fi��eE����ubwKA?{r���h>ڨ� �˓g��:Y��O����a7^���7s�M���񴚆Q�ZE����ñ΅��M-���˗}�\��w7�fFF�VШ7u�fF��Xw�m�P<�t�a�'J�ؔ�hZH��]*V@k�*,g&*b��А �S��_P�l/<YNtu#s�^�FK*�Pw�,A�֐D�:���H�45rE�s�n�A�A�� Y&�"qm�W�3E��@��tV]ۖ�zi�Q�`2�v>1�zM������A������(�C��m���OQ,���m4C]	�����2`��� K`��w�Y�8�s�**͑;�wgEPibP1魢�(L
�,���i-��n���`�i��0�a�bo�k�9e��-����	���Ŵ���d/�@�oF�m� �4�� ;7���sp����g&mj���J��uNE��=Cd�Qk�4�`�D��7>������7'�zE4�8xOk>W�����k����'p��˧�Q,�c���)��a�
$�ڴh��Ln��blO'KV����([�Ͻ:N�N���W:���-b/��fe�̈U���[n��(�;��������0!�Q7eb�q#�����>D���vS#���l[B��:g	}_'�*sP���*,_��ލH����)�My�_�)ZϤO�-���=���Z�L߷��p~���^�~�6ov^�V�F1^d��Uܪ�s�����8�~ʩǐ������d�+o�jFj�R��LfӂXa�8І�(]�ЙlŌ�9���P��3�NS��I�?m��3�����<�<Xow-&f-64��W^�:.�hO��8s�tgD�o�?TQ��c��T��GpW ?mM�ts�kBu43�(/��C�}�6��[z�]�_Hs��S�tf�m���mYf��Č	(��OC{���N[�"���U/�����#��|��:#��
�p%30G6�Q���~�n_����l>Q"f�p�E|�e��Dr�g$S�͇��ԝ��n�]�\��Y~��6i��,�2�0xu��R47��`��)԰N���tXԶ�����,.R��KlRQ�6� ��v�V�ۖI���@���]Z !$�ї{���zUo�xjەI>#�If��D1���0��>��V,��P�ŕ����6l��a��
�"����(�u7L�`�ҷi��d*K�8ѐ&�4��~�Gw0�/n�FW(d �x��!u�� ���V��+��8��Y˲8�e9Q��(%�.�ph۸�.��O���ۻ���gz�����Һ8o��+�,�~��b&~hN����EƘ��Pp�z�t"X+@TvI�XyeyaTޯ̃W"�cO�e�	"-.X�j��w֦(���P
l�}�j��8¸�5O�VI?�+�"�
�,�7b��#ko���Wb�����*�Nr����8y�w�֤����R�9R�������N���	
i��J�v���up8=�԰�kv]m��	݀���/��s�2�=\;�|5/�b��Dw�?�V�a���b��������2\~̘?sJ[)�j2~�܉���S���e�\�Z�	�^o��+�H�]bdw�RZ�lڶ6�؇rP3�*a_��`����+⥒8m�%Y~��em<�$��8S��������}�����l_�K��
J�9�g�T;�|PCJǎ�T��otyf͌��I�a+�7J,t�x2?��;�v6��ݶV��#�����'{I0k�E�r�>�� ��]%������L�3BZ:Hha���ȭ�R�V�E���JH��|��!�'�z/��
vm]�34l�0�-��6��S�}G�֋hl�QcѶ;7�m�F�&kB�����)���Rӷ��z U�W�{w�/����:�^�����*͏&](�t���b\��#3��'�Ѽ"��pj��F��1B�U�"d4�ö�[OǢB�pA4`V�yT=��|��eG��zp��:#%�p�#D��B�m#�6��}�����Ӊ��/_�-4�q�������^
���a�CƮ*��B��b|c'ӿo�3�����m�l|��g�'/u�_��ݰ�'O�>|�.=!5�= ��.�htu]���qX��&�U�)GP��b�b0��B��K)t� �����ϩg)��T�_������'iTbz�6=ԯ ;*�*�y������G땉�ڙF��
V}d⤙�2r��_�X�G�P�ڈ��×Y�;��<����6��!^+@o�q�����9:q�Wik��.���kP�m^ٍ$umaМ��sx�����'N7#�3�q���h�mMo3ˌ�Y^؋M�G��'�.85U��A�K�������-�&��Q����
�/�6�d�8XDQ���:)���U\=���8���Y��O��,�Z���!,D��P�<fe��/t��G�PN�D�ەݤ-`���D�1���k�Dń�^�$x%˓)�#!g�؉�Ǝ�S��CE��-S��"�����8�Mkq�\���������uu���(x��=������T/�������YQ��}%�|�{ח�:����Ao�����9��$l���?�Y��Ͷ��6q"�y����P��?��iB5�	�S8�g	/<T�]���?����c���D���5�}w�0�Ez���=�@���y���%zcL�����X�B�(�p�G�%X9-)��^��ԋ�t� �Rg��T8�Wb5uY���%��٢LSH|�*����T�m�q[;L��)�,2�=���Fhs�A�l��6o�߷;�-H^4�(|/�t�T�����qHN�]!wFy���/��"����)Z,rD� �XK�h��}ݵ3������Lâ"x����B���؛�q��<+f	�	T�G�> �=��V �꛾�!�_$i\j԰���_"Fېgm�7]qҋ�y% ���X>���ⴚ�4�K�{e�GIb�Lh0.��͟mx��Pz����Y�4��m5<��lʔ���Kؓ�/G�MR�a�W�{l����04s�U��HD����ཎ5=˖���=v��҉�U͸f8_l�Fv�#�4�꾜�<�,Y�q@�mՓ7�v���sg�W����m�p�&��x�]Uj+�6�q��$����:�a"k|��Xf��������@�[�8^|���iR�h���4�qꪤ�vT�8��K�};`^�98l���������+C���U�Rcf�'c�T/[���H��.l^� ��t�l�É�JW�*�E?�Z�yj�����,9��B�y�)l�m��K~�'5�@��ŏ���+�=�	�2�H�;Y�푼�j��O�v҅�#g��E@�D�@t͆|�U�3��L�H	�#j�Bq{VI�Q�_�s���>�jt������W%u4�hš?Z%��*m"��KG�O�$z�Vn�u= \��l�Qv{H|>l��˹|���q�ψ�Qf[H��<��j���)6k:��,�~�S&
 'Yx��M��g��WR����oJ�͸�I��8F�ī�&�G���tuo�!�o�!��V��c�`N�1<��I�s����ǭ�S��K���-��_�:aE��=&É���
�Y��o�FQ�+/\�/���/fh�)_^�ը�H-��q=������2�S���;��EApQ�zڼSī
�n��̵1`�'P��b|��r)�T	��8��Y&�nD�P�S�3AA��+ڭ$\�X#ۺ���4I�$CR T[vZ��C����-���(B���A�XA%�������T�@I���T�������}�5�Ƴh�Q�vw�8��R1q�n��3>��g�(L�xy����@����y ���n�5�����ߜ2���-�N��d�7�&�:�5S��?�ﵤ�Z�DpPl�� yJ�#�P���m����>���q3~z$����~�xњ����*S����ڢZ�o")wO����iB��^��    \BOWT���އ� ��O�����|a��z�霋ҽ�׻ʁ��b	D�S]+�p����y��׃g�:@r�s��(/�_��h�m`��G�������t�+�4J�x�e�Ȇ?Ƀ�pn4����9u���<�E�x�Y�i?C���5�����ڿȑ�RV�t��2�iq�!���`ML�^��竚�>a`!��.���F��g�2�E*�HL@���Xt�E6�z�i�R�b��PA_!����K���{SĘ��x���@��2t��fWm��*F>1�M��"j�q���;���U�	`�7�m��~�{={=��}#���F>�;�UTS��
������������آf�rN��&��9t^X�[ Q��ͥ:����v+�D�q����7a�%�x�X0Z�ؿ��&F���"�,/_ "����i�adR�'e .���vB8�!����	V��e��MԺd�x�と-��FE7G����H�ui��;n����v!E��N)��prJ�pV�΁~	���՞<�B���m7	��Y�8��_d��V��<��>u���rW�A����V��{���.�d��ѹQ�(7"kt߬�/b�\�,p{�ȩ:w�^ 3/x�Ȱ��4���AxI���<A搰4�h �����e.~�~��Z�P��,������� �+�w�tNo]ơ��i�j.���,�+��@nE��g(ur^�ڗ�����{�uX��7��rF�S�&WFP��66�&FH��e1��0������P�,�7}D:b
t2'`�9Վq��r�������IZ���B�{��ñ�t�Z&��W5����%Ϟ=�ՉD�V ���h��H�v(e�m*��j�!:|��5���U�1��GU�i� �(����y�[A�Sѧ
�G���YF�'[�7/@���DP5�p�W���.��PQ&���i���H[=�i�A¬ݱT]cʷ��2��{W�Tٳ��^����e������̿d�bNS��*��RC"SIR#��d{�3��w���"=�\g�莨TDe��-�V̐U���o�m�LE���bCc��u	���hю�"��t�T N�a\�ۿj�z����0����j�����e�p^���T5�ҡ,[Q۱/�Xa��b�Ai��t�x;�D���]�%�ej=��wH���䟼,#�?Y�}C;A|�l��u����ty��L����u��Wѻ|��/���q2�'�,L�ܡ4�o�8J��T���b����@�{�e`���~�Y�"Lem��k�û�SKR�ܲo��֎�Nb�qK!b��/Z�5Ɍ�XfJ�LM��d_G6^$mjtf]C�����q���]�����#�aCZ���I�=�6c��b>a�$x' m��x�H�۪�$�~QfW�Qi3l�S#Vf�}їY�x�"[��������PJ��mK|ņ�(�nG���&;u|ױ���=~m��$��>fQ b�nq�L <��cu�n���>��rg?S7�����reK�a�eo\�&�q-�ЈXX���[r�&t�[QS�q��b%�&h�T\�C?'@�wɞ3K�?�Or&�5M��w�>���=dw���x���U����i[J�:5D4^��8n�<�qe�,�)Rl��j�qَ���ys�).[C�ߚ҄�G(�c#��,^��S]RU���z�����	xu���pU����j���uuW�8Xy+�3˃7�9s���Iقu31����6W �����P��}pܷ�����.͊��M�R����F������g���<�Hʦ����6� ;�s�@�a1��"��Bf����Ԋ1�6�������c�?X� ݊@���O�kf�L�z1���H��y\;(}J_,��W��,_8��0��Mb�P�(��&_F���*�/���fIE��xV�I��7J�a�u�@س�W$�Z[�V��-WS�?͌�4�hˣ�ӣ�}L��H~,k��������П�6��B���h��\�G��5_�x�dUV=�(�2��,�8x�!J� �<�����d���*����z��8{���;"z��s�o��c���Q�۳ͯs%pě��v���'���/��N���:���QP4w��_&�(N�������{�v|�R���`aq�M�kQ=�a�JG�� �Wn��q����0ʋe��2Z�E���N�i���΅�-����;}���
.�gODބ��P%�K�('�?9A�`4�7n�nј¯J�S=�T�;Xw> ��!\+X�%E_�	W*F:O�wj�i��u���Kx�&��� aO���S�YP|lKP.�	�}�ܨ�>жW��p�e���U��Kl˔�A'4��U�o��Y�c�*W0
�G�����v�؃9�b���D�y�GeF���KL�Gd2��h��!饸d�4v��� ^MI)�~��T׃j3BtQ)�<Y>#)ì�s��R>����;����]{�(����7½�ر�$�8�+�b�c�m�Ԩa��GG�����xEt�q��fU�)A#�D1���wO$��F�4�t8v��n?����:��'4��P��"��U��T�0v�!���r�	h��E����al��4��1�3�<3��$	>�GPj���V�;���$i������X�2(���a�d���P����{�(�"���o�ݳ�Զ���Iq�:��Xŷ�DIu�BlUksgBl@�� �������6'�A�o�V^�m��E4�y��)���أ��ή;���������ENd_�ך�x��JA��9��ρ��\������a�~f(n��!������V'*S-�8���iB����o(�α���y�|�M�ګ��8���ds��?x��`H�ܔ����p~�!6k��t]ϸ�y�q�0�P i(.��d��F������F��X2�
�U�s2a=������>x�짱�.��vƙ+�RU�(�DA!�X��W���5ísk�'|��QZ͘�G&2��8x+�[G�s�р�:ևw�Jp"���6�t�����jF|l�!�n���c�HA!wR'��*��qY����0}|0���`i@�)�΋�8�TRQ��0`�s&=� l�Q!�!`+Xͦi^Տ$��"śY�Z������U��CP�1�ؓU��U�A像��yMqi:i��ÖjZ�T���N_{|X+�pV���Ga�75>b���J:��9�%O}ߜ��ͣDA��-_O�öi�Q����Ջ"��m��eb��Νxk���8�9YgӦ����
~����8.�Q*L�Q�8�}�f�N�6�n�0
���v7UǙ���l�eGEE��Y�7/�F�(��}r퓐�E�A!��Sw�,G���.b�|��4�ں�q/SH2V&�������f(�3O��8rP�(�ww�F줲��AOj��m�(��qF8,*���&�����8K[�s�~=Rc�P���F��Fڨ���B�d.�"�T�?vL�<�f�uyfrOM,��N?��]�6JtAҕ�h��+Dy7�+Z�Έ�q�Y��� ��ӟ;���0���Z�V�;�������[�E c���F0^A���Y6#�)�K�eĦ�X�0�>
>Q)��W֣Fv�x�C	,�u;>���B7�4�F"���{��V�3P��I�|MfS�/!�x_
�v;��Q4��Y}��t(+���y����L��fq��3^@pۥ*6y��!ʸ7�K;�r̳"�ʅ���X~E�%y2c}��a����~��.�r*䚀',q'.Ż�L�� ��!h�򷥶:�M5#hƹ �Y	��NEG{��4�X��D�em�=>�M�<s�F|&�Wv��9@߈�WoP�k啖��>��jV�dy_�3�Y��:�-����
�ʻR��"l)�vg� �����N�_��f��b����(J*�c�u�%�I���$�$�۬�Q��@"���?��|�RTwݹ2"I��%e��Z�L�x��K��T�8�|I��v���ҹ    ��U~8H�(��h�UUV��c��RǶe��f���݋S����Wu�V�����nn(q�����
�T��#�+PM�ꮮ_q&Y�*"�Lm �v0S�ڛz�c�%� �<XZ&�o��6��'@I�F�4d��}n���
��f�]�.�g����C�`�)�c�
�~q0�%��<\]R�3.j�
K+sZ�:�����i�m�A����������L�pyN5����)��[�,�M1'1����3lģ��_�I��C�����a��g�|�����",i�>ڪ���*��׊3���+{��B�An�S5�����<lG<��ޟ�^��}� �W^n�ʥ^�	�QuH�j�A�7��^�N�P?ս�9�J�u�]��o�W��}� �
�g�@�P�0�p#HG��]�ѣ�{�O\��X0P�9��jiH��k�X�
��yXv��}|br�ir1�߫�≼J���z��"2��(F�vq�ݼ�TZuWL������_��rF*�$��> ���f�_)5g�Qu�7�4�����8���+���ls��K���<���z8�p�+y$��I�~`�Y��;6�*�].ߘ=͓.��]M�2���	�������Hi�����D��zG��}|��.5�ƞ�y6�+8NY��(���$�F���e~�l���x/b�IT�u��?��b�  ㎋���[��gt����<X�����˨���~4�D8	ސrx���\<�Twt�켢/����j����e�B���]Z�D�����M;C�(M�$�%� �A�O��a��Lj��y&B��_m�	ЪpEː�k[��G�t���0�w�Ѓ�A;V������v��P7�w"��M6(3
���S;@n������0���eaZ�˃/Tg�l �kC�Z�����{	h�{�+�=N�� ԫ ���_d���͞g�{T[r�)�>�n�)ƥB*�	6Z��5(/��� }y�>�q��~R$����y��'~ 
�w"��<ȥ�H�"`�&C#�=�li�����J]�<��%X"	R����Z@R���e���Te��T*¿G�BΦ�v���k(��C��Ϡ��A��]��d^�E��8�F�n��~����j�g��]��EpV��˛��P����5<&�`�����Lz'�4�Pڛu��\w��1T�}W�E/�z�p�����B��]�'e�6����A
�Hh��mu�Q��~-uDD�ƀV����׃:=@��<����O:�8r�wP���
I��3�e��n9��`�.�&P5�i�S��K`��on�m:9b�0�A�ZET�h��m�I�MR���~&����xS&�OF�B/��]|�$��e������xa_���F� X����ʡ�>v�d:B�E�������-5����V��W���|F�n�P�3&
��8{NB���+���A�O��Gh��/��06���ۘ"��C��	*;>g��G�sct
�}����%Ta�l��I��B���(ͺY��c�ś��u����ZINL���m8?z�����h{�/ ��<���;�Ѻ{Ƙ�~l�/͋8���6�LV]&J���d\�3F��I�i�p�:�Q_3�#c� (��Y�L�H�&���"��IJ���=(m������\j�ٿ�t4p�j����Tm�,�+z8_ ��&�[]Ո� �@���iG��=�S�|�1S>mޞ�ً��P�/�1z�ۋn��$�,�X�Ŏ���O�bQz��p���kke'CDg�9@����t2.psKj�7��+�zh�\H �����I4@��NԻ!��FQ��%~�6sړ,*�D�K��yw���)�����}%m�3�V���Q�[-�z�;�����ǸE��[�,.��a�<_���Q����<��9�f��;�AL��F�&���*�\*	Dll�l��EW�H&i����~W��f`��"�2r��q>�J5X�~t"�"�
t2{'����z��+c�*Õ�b{�n�M�`P���F��&j��������ph�!�D�kU�S!cT���b��/:w�V���u�:C�|�&N�T��)��<�h��	h�D�)�Hw��%[�z����&7���zn馛
x���� \���f<�i\���L���o/wE�{�05��D�	�3�{E:j�wTjF��<��	��b&����B c��P��n5�_m~w�/.�������(�H�	"��渨�r:ˊ\��q|��=�7��5��JrM��d<=q��q��J���8DnX�n���}�����+��P�s^$J�ʋ� ��n�3~�����>��Oe���o���Z':q���=��b���l2���m���cl���GBH�NV�[����E��uf�T��B���Tx"`��'DX����펕 B���qѧQ;��3E)�#�����(P���؎�ox�E���N��xօ㇈%���_R����,�*#΂w���YZ�N}���k����ws����:1~�B�RqҖSĈ�<���8]�I�	��A���4J4�y��M�G͂�"��E�� le��H'�R�bRI!���{�.b_D+ndU�:nkj����X�{FU~�̥'TVwӬ�)쁕L'�p��NeZ5��(���Fy/v����Z�Z���ۈ����佧ǻ�fVh�b.V��>S1�~�]�rv���7�O<�yh�<�Nx}���T����V����9��Q]�����h@,�b.1q������sWaj=G�&����d/Jc�(O�A)�R�4���pޏ��+�FG��~",+���,ng���1 ������펢V���n:��.�Z���o_��.^Akel�of�$�e"��`B�8��ȴ�f�6�b�q��'@�t�h�V��m\%�<���>�������M�Ws^�4*b��I�$T;��5�ha10�N���qQ�{Cs��`3iL�f�
rii���+Tk����V�p�2�^����`�Y1V+p�3u�����ܖ}�4��S��
��#�^�R� ��I#F��w�D�����un�,�c{váV:$i9�VԟX� ~*�6)Y}{Fֈ`Sc
��Xf|C�%���!2z�?�.<�´[�n�.@
�	"Q����$���<�
�t�.��Y�ѷF8���lMP��o��o���y��[��LF�
��j�@���/;���� �)d�܁��n���Y�|��ټT�g/]�{ߦu=�-+�R1gI��hI�I���~�F�v6���
��M��Ō:����LR����xq�P�k�� �;�>�#��Tx���-y����t�s�a��~�/������Rj�Ė��r�z��<Z�W����/�mB��_Vm���_@nJ3#���$�e��o�,���#R^���#��y��kGI�c����S>�ޢ�4˿�eT�I8#���*�-�������ݣN; L��+����b�A9n������!͈i���[�]�=~{��W�S�#��n�l�21��}R��U딸��|xX�����"N<,���n{�~m�ݓ�ՆH"P�Pr�b�?���������y[���eq>�Z�$J#I�iӤ�F����p��mc�����"ZU�Nq���~UkRIe�"���Q�e�u7#�&�^+M��6L�VT��
T��:)<�_�O쇱��LYdi2#݂�#=V�o�!Ln�d�"
�|x����@��qH�h7�v�@	��`��� �+8a�d3PE�$����<x]ٖRI�Tt�����o�b�����~�~���Q��yq^j�"�z0��G'@|f+(˪�f�<�=�E�J�@�4C*�:(��t�삏b�����E^�&
���N����
�����0����ų٢��G�8DiR�e]u3|d�"Ml���߉��@@2n��mD���3���;�1�${��۲��~F��M�"e2�t?�&���Oœ�] Dp�ދ��H�m�8Q�I6X�!�+0�.�,Ig��2*t��E�Ǔ-ZO��܏?`S    ��b��í�+�]��X�go���H{���"F):�%[l�Ԃ��6�;�׃�u�o �
�D��0�$�$�ɞȾ��Y�0�����`�J]��/6'_(Z1�W`�"�俫m��ΨL67v�A��[&�"N�J�|o����&����C�3�g���  @��mp��՝�]�E��Hmb}�X�'T8[�Wzٛ9��,3#dq��vO���l �*��>x���Y኱���ĜZ��K���DYy��V�V �Y�e=���k��$��y9g�6C�Sz5�8�5�pCh�I!#���������ѩ�(+
=��MP4��8&��FVЭUI�Ψ�L�B3T�]�*�U�� r��fs,Y"���_b������U�$�ㅌI�Pu*2یm�0�}S�Up�n���%�4f����`k�D�W�̶�Ռ�I�g�@��Jx\1wb�$찧����u��%�}ԉ���6���#�a�A������7�4M�>��(s�w.�i�{��.���D1�L�!��m�2�\�5U2Oۣ'�@̞�.����2�XW�v������Lܱ��r��6��es���Yʗ�u��,���`�4Jd������Y���f�T.�bP����=(���0�IDY�|�nU��X��6P&+��X�*���V�>gp�������.�\��Ҏp#��ӷ-*���Ǫ	J~�l�����Ye�εea�h���jo����{~A���}�HU챻q��܁<��+���ZB���m�j~�@�t������������ĵg/6��+l�C�����m����1���}�N�Y>�2]S=^��<�T�1�N@�o�H�wt��Ѣ��6ȔΤXΈ�֊Z�+�_��(G��
�N�*�gx����g(�H����%��3���ֿ��L��L`=H;��� f%���M�/��C����o�\)M�SO{򤈅�����0Q����pt�L]:(`�.�����!�G��Q�4B���M��-iia9�=f��w�D
� �Z�}�T�IA+ۭ�O(&Yz�FR�WS����a�\�W~�7�;)�Z��O�#+��"�S����9�����=#����B2_�a)WvIG�܋ŗ ;U�\CO�4m2#�6n���$�c��R�L������=XvB�Y�/���I]>��EOQ�����4�8��9���Q����b�W5������ݗfYd����fy�T����~]Y��S�vm:#!�I�x�<~�*�e�Aڀ��:w��k1!�q" �ӻ�j�|=�W�1 ��3*����E�B�oJ��x��qg�5�.�n#�,7������%����B6�Q	�>��=ܮ��Fف�$td�wP2�ذ�l"��'�"y:0g��*���>[���/Ȅ#5�_���Ťx�	�U|ԉ�Cr|Ķ�g$*�lrIL����C���f���0U}8�V�a���<��\4N��D9Z݉k��
a�у,��o��:�M _�$OFf�3z�,��\���|�~aQ&�j����k@�;��t[GY�<>B/�<r!*���v������JO�4lVIZ���nźD�l�W���flJ�k�&���(t;�Q�{�<2�J%�ܩ�"T,�U�4�>(��A�2�S� 'uX�1��c]���܁���3=�FX���r��b�r�6qΈ�I���a���:/2�C)��E �MΡy�%<��h���dw3��p��Ls��WoGh���74f�%�6 ���`����?/�����Pk[�3*�,եtۗ��%-fm3?��9g�u	���Y��Km���xQ�Q*�s�Hqq5�w7s<3;\lGj��i{�f;o�ľ�NK0�w�_�F~G��ɨ��;Dw��u�&3,YJ{O�]��� �h�s��3��<�S9�R>��/���>_3�Rdq�W2މ\a}w�3�6o��8M��=MT=$��0�$�n���7�]�������.�hF�4q���"^�p8�p2F		q�['��VH9�v���D�����
8�uc7#i�2tǮ~�&3P��8Q?��aPVHY�f^uh>�]c~�NF�|�b�u[�3d �2�"�
8��
��6:W���R�5�U��Q��IД��
��
��k�3&��gRZЖ�GlS%B+�L�/5ؚ7�O��V5O*�|�\ݷI7#TQ)P݄ �����G��g��K�rt�S*F [|�=aLP�!+�_�6Qh�nF����[f��5����^��}���ӫ��~Z�`"�9�9B�vG�斣���������D�i�i��P�����Q���|� �����ix�/�yb����Z�I
*���{
O�͎��_��w`�|�]��|	Pt���@�� ���H��9.�G�M��	���8na�s癎[M��Q�	6-0Vݟ ����-� -��x⪺M*-�I��s�g�C��A4	L�^���N&��$����s����=8�$�d��݂�Q;	��L��¿����x��Hk�o]�(�.��H%�۫�T�1^�{�UM1'2�BvM|^���J<�1�v��'U��)�9^��o��"Љ0Ϥ-@\�`�l���
Z�&o�j����\UEM�C�%J��Ճ���A����Ŝ����
��sa�`�!���=v��k��暢�����i�liS@��D_��ɣ�<d{Q�8��,,T;?vV�S�z"��
.}�ь"���Bo��M*OϾ����ޖ���At�c>n.��w��`Y{���cYA��.��V�0TwYS�8G�YbZ��	B`��Z۴{@;R��2!L+�j6u�3?c����0���㾃z(��u�X�X��J2�ʭ���
T��e��*�4�,QF����	�q����dJ�{���]*:�О��O��.���Ealt�]
��P|q>�d`J�M׶��Ou��� $����,���7���h��/�*���;UZ��3����G&Mgf͔*W�6h�r�΃ 6:�?��h����`ߩB{p�?�r�^��&����{ծ�\��z팪6��RF?�~���ǔ:�Td�|�}�Bz�Sw���,�?�#j�E0��%��V�G����\~;�Ƶ��$�<Z��vSp�v#4�J�ΐ�f^u�?m~ܭJ���^��ŌI1G�F�O�Wu|6�ݟ�,�����]�����Ѯ�A]�����e	$�v��?�;Z�oF(����Rx�O`1����v�Ǒ��l��-���QB�\ܡU�K��EN�Z���wgnJ+�*]0,����머!-�m�>p;�匜}���7���J��8��7a�ü���q�t�&�tG��|%8�i��
i�]�g2?��/�*�]���@�Q���@�ۤ�o����i�l��"�M�
uXq(�Y�CҜ��S��W�x���x=	�1�"�^S�����:�0�	�R�[i�đ%��1��S���6m�Fj���|��!D�	�.�[�i��r���X��)G/�/ixwz�Նx����̣�^{/N�I�6ԧ;�Ld b���R�X�,Z���#8L1FS�/z������B�i�s;0�jx�嗬m����&ʢX�:�q�Pse��se��Z'�^`��ag�_�}���P���'����_)�.͝T��]�n��S��3Bk�2P���!;�b��=}^G���ٕ!��T*�+`��Eޘ}S�e2(,��G�^j����z��.	dx�#�����%�����)�E4�*]FV҅�@7�5&�g4TE��E����
h�P��/����
"R����܄i���7jq�����V=7���RF��["�g�_�R�5�յ²E��0Z����LgО)`b{��7�uť��	�{'���d���˟��u_�3��޵D"�����Q�Ȩ�eKג�VM��B�IS�(�x�����1�m�{\:�Z�� �By�5��4�Ab鉂Y߈�@S�x���@(��+>���ڮ2��/[    %�#���D�alAF���M��:pQ ��|aY/~&[>g���.��ڨ�qkԊ��A��։�������Q�c��弁��dFSN����:y����P��eh�/�0j�߉;%�]�)����v�wO�@�V`7��E��	�-3b	T�2*�3)j���dU4N謾 �N0;Ȑ13˟RwI�d3bf?}7)�0x_��8G�����Xw��� ~�Ǟ%/����0��¤��,���EQ��M���;e?�.{8ۨ�N����~�I���`{At��~�Z:�zsT��V�Hi>�Z����,��<�d�[F�,N���\46Ι�;�F�/������c��^�y0���}�=���ZI��(��2�qi%�'#zZ������+)o{N�|��d�ՠ�#��,��`��v,Z�)��*>���J;����{\�;�)$����ב�_1>GrPށ1 ��K7	�N�ƹ3�������83���-M��i.ڕ&؍��֤����(�u-�S4FQoz�]&���BAl�)' .M:F��G�4m9�@�+8�Um��Â��3w�s{�фTσ��G�a6�]����)	A�  �xh�-z���ܘ"���H��V�k�t�)	Mi�g�W;Ebu	&$��RqE-�D���W�?胂��j;�z�ΘxFТ��4h�����-\
*�Kaâ��?C�N�Ʀ�����UP�ŲM�:E���
�c�UŌ�
���q�|�L�#�P�\��@P�Z�q��f+���|������=|����Rʟ�
�s����3�i������r��N�D'*q�Sݿ��~��Cs��>O�Ϸ�˅5��M���E+$2�Țh���+ď9r���Ϩz[X��\%��M2�h7-q9�Z���qb *(ք׃'�<)�f����O�� '���k�p������'{IfKdi��$�BkeQH�M�)>a�6�B�N�W靸��^.Q[�B�E]�8 ��"׳�#�B�X�K�l>�1��Ħr{��{VD���W�����/�.YA��g$��,E�ޖ��[�EBqS�D�p�<_�T�ז�	�^�(��EW3���$���<�<��fU�}���;6N�2q�9xm�ŵ���3Q�c#�� U|�V�@��hwF�L��\g��}4�����4]�+Qh�q^~��Wy\=>�Hʴt%�	 ����ArR��E�L�r�"���!���i'榶{�H)B��&���&~<)�ad4pe �t=͘�:L����{!����?'�
��������	����i�B�AKB{	�p�8�:�(�Tz���7�B�G@��"~�x�˧��]�����BI�	�� 0��w��^�9u1��3
H���U'��Z�-���Cu��5	W�C�(��X�qV�Q���O�+'�v�_wdn85Ǘ�nǘ����=��z�Pk+��dY��+��->��/��0L����$6.�I�֣/���"L&�D�B9t7����R��a �/���
YeI�x���a�s�$un*fͱ�־����#�N�hؙ"<���F�&�f<���ĳ�L��Q�J�y���A
�8�P&�c�!��_f6;F3��4��R�O���zݸ}�(,���´	gHY�y�Y�%E��^�z;q����X q���͇Ä�E�a� �#�_Ao�^:�$��=Y�����cib�	��Vs�ڦ�o#���Z0a.ܳ�P܍����|�~=C�����.���m�@��c�	[2K�E���k?�A�}��s3����S�5�:;z��.��?�)�F-[�cA!~~�\��U���L��_�zF	nn�>R��P�{P!h�1�]8�����)�ٞԻ�iqʊ�W`�<���OYalm+��t���_�K��U����`���䆐���?�E�����f'fW��7㪚<�%/�a ��7y�ۮ�]���;���s��W��[�����(M3�q�ބ,
>��б�7��8�<�:|�"��ѵc�vbY���|����v3�O�k�(�S�4vU��6�b���b��~�&� �!�"e$A�-�'�!�@Y��T�9T�/ j}/w�N�&$�� v��9:V���o"�H2�MOGW0I�����klB����N&!xxa�C�;~
V��G-&1 ���l���L9�� �ϭ�ϟ�����&{t�'\��[U���ƶM32PI��խ�A^���D�:R�J��X|߆�ۜc�����~�\��j�n�0�8ۦ
 M���&.�U���מT
���#��n�*w��{Yq!v�
����f�2����}N���k���#0�ÒG����2�s'��qs�4YA��>-O;Y��F�4^�cgTj�~��U�6�ˌ�u7Lr�}�']<.�8m��$�}�r[Ȱ���jԣཱིg�B��/jp��,�@�"T˗�Ȣ0+͜P�������E�_�@-��r�w�pQ���e!�_Dk�l��Y��v���T&x밺^���wpڣT'�"%�a5�!�����1Y�Y:#PY�~�e
H�lF��!�[�����_�������\{QU�ٳ�P$�J��I��b�O}����}��G��,^Q1K,j�_I�;��n6[�t�������U���x�B~�?��K�Q��4�l�CF��kCMz�ǝ%	���R~0`��rnN����J�)l���a�}�oiEb2�_����8���J����n?R|���r��Ңts0�A������(EQG]M�(&j���M?z�Ѽ� �A�:�<F�J9j^�T,���2��6'�T��=��ƀ{����x��^�B?����g�R���8� ،jg������"�^�t_�M��A�ۨ$���p��h�(�,*�x��Sf�P�5Y��&וc������~�"���^�o��Q�9X>R{�
��ɣ9�T����@�}��4W9��ڼ��[�*5~"j���.���V����Ʊzum�6��|T+�jY�3PYY&�Ȍ�����={=	L��g���Bv�B#T�
�nU5��w"w���rG|ūv=�|�sQ��24߰�辩�(�!g�^��ȿ�5"��n�n~�>����C��r�BU��"ò"��x� �.��
������^�%_A��E8��_Ӂ[FM4���O���?~���j�� �gҕ�	�>O�+kG;����9�Fs��b��w:���|Kr�Cn�Ξ���<U�1�������O����?җ�K�ľ�Q��:�3?�=�h#�,�I�G�}Nj��E�*�x�|�i.���GN?��\|��0$b<݈	�/��
��Qg�����G/�� ��-�k�dK&�����#�d��q^ ��Y�ƍ���'e�c!�t�2	��z�ҍ��)�L�`��%��������j"������|$β��E;��c�����e�'�f�<�ei�O�u��ߺ���oW��MM�V\�j`J����x9Q������T�S�.wc���J1����>�;9ů��ԎO�����Ěce�a��ע9���Yiԗ]��8�e��a���X#�B���J�}*�h�����m�C��"@UO�F([K�=������eq�v3�Ź-�S��Q���g�a�\�>ߏ]9��OA.(dTd{pY��-�Љ���!��gi���<�{��HHX;!l��m�H���<K��Q�I=���0x��[��+M���<��6$W�� J��bͱN��(��]�/>c�ե�����K}���8���w��c8V�їjc;�
���8�~m^l�؜����=�����Y.�`�2 ՜}� uԈ����%d��ȩjO�g%uC�m���\[z�_������6��%�Ӷ~��N��'�g!���|��#|�7 �I��_�_M��sG>  d{���);V�Y5�9��0T;�6�t�؞YW��T	0l֭�h� �G	Th��?�r���H��Q��8�e�S�<l���.�%(���(`�K�"P3�ˁ��
t��z)D-YAԲ���΋ܨxb�    oP�>��$�z��r1��\T?�A��L��� ^��b)I�����e�3��3i�L����
m��m$>�C��!��g6���/!�yNa6�Q�H ���;��"��g�_��ES34e�����+��� q#���n�(g��`" ȋ�
��I���/t�����������D���Ϛ�.,8U�tK*l�?��A�JD�9�,T�+B�g_�A��(��旜=P:b�9q�I�J6�)Q�^aH���j� ׻�z\!O�f�@�B!c���Nt[���)�6����8�\�;2�-�.��|Yz��Q'\%��×)�r/&H���Jd,61n�q�0n��'����w��$��Znė�����|-��)>��-��Q�A��4.U:�V��T���s����l9�#�}���/��<<��xJ��"�he��ȈH ��Lt��_}���#)k�������"!��}k kwEH���a4��| �)/�ݴ~�{Z��K��� ����.��D��*��*6i��=�(W�X����/�*rO�A�zx��h�3���{�Q�ۗӈd7>�Iɣ{����" �&r�-���i��0�EȤ�����,��A��Vq���� 
��8lp F(T����[|B��q�5m.<���#��!���LY,b����U@����>g3�ہ���=��8�"��-���_M&����ؿ�8Fī��k0��/T�.��A>��SD�4�b;�I���0�!����~
��g�4���[Lgז����t-�~�NP�p9�1�o�F��E�	�"p��؁��'�=8n� +B(��[(�ӯ��uF����Yz��`��4�$~�y����Qe�]�be���M2����`_��E�U%���]�d���>@+�������`�s>�K�+��Y����������w[ǁ��� ���Lz�gbJN.~��qCo�Dw�)He� R���m�DI�F(���������ϕ��,\<V��?"b�v^�m��t:jlVɫ�[(�M�O Ty�p�ʢϐ�R����%�~�r�b`^=�k��"X	�*t-2{@!�F�8��בL�3���o0O��&�&$�"N�}U��̸\,_\�y/_:(^��䇸����ʏ^����u�8Fe����]�����̐�9>��{ɒu��pz�:1ͬ� �ԵMgC�t����[9�d6��K ��Z�KI���R�hY���UY�rV,�O�2?�E�z��цVEc#��5��̴���K��G�����.��ăv��UލGI���)��.����K���� �o�)��k�P�>����4�����	ik攔�Dl���	>V���x@���'��χ��}
��}���t9J������rF5�k,bj����1�{E�?ț��5��j��W՛I�%M������؅�9��$�*�Y O�)I���ZU4�F�D��vl���!
=k���L`Z�Ȓ����bW��J���i��+ݬ(�nBL�1e���< �$�����C���ګps�e��hP�Gw�^V���fe�O����&7^`��_�\���)�+8�[�R����"F�_�D��Z�:��`,@:��N!�^IV���oՠ|blkH�a�7�����zz�s��K��smd_�玳�_4Tv�`|G�q#��N�8ƶ��`�@X�
g>�]b���M`�ΐ�Q�	
j�����)�h�����1���$e�]N�`�A�?��ߩ�������ig;�+��럞���U��04crW�݊�A�zr��nk+T9�ǜ�3=\��Em'D�XP���$�z�M�V���%���{�Wxk���YU������,ॊ,�͡���;��?��ڴ�o�I�G�N��:���P�-�h�tu��.��g��n*0�� 0벟��U��OuYK��)�!r0���]i��k6F�uZ�f�Σ�=�lԺ	�9U���H_(>�_��p5a +A�(�e�:�������-	�����Uh�
����
�	�k� &��4�@�r��+<Hs����ײNP�������2
F�������N{B��p�~��"��̈́�vR��)u%�A*�pp5�L; �����9O�t��.�̘~u�jPT7��I��}X��4�8��p9(SP*�`C���<-������+��M���ێC�$O(���#�Ud؇ح�QTo����� ��	����5q�#&�[����d��۳��h$ z@F�;�r"5�<g�4������;\bz���A����x������H@�	��$�E���`t��T�W1&�_�P7������H�	㕗���X�k�����6~�\A+k�q��6EȰ�B(�"�{��:R��'x���O���<��	/�8]�&���{ӟۓ��Co�ʷ��zg�������W�vc�q>_��!/�r3��k��PcҤ �N�x��z"�����9��aCn���`�%�d���y{����iE�g�%�X�X�jg�ڦac��rSQ�-�J x�T�����Q�!�����ܽ)O�A1i����⁎we�&�UIk�ݨq���F�SYew��_N�+��b#;&���Y���`[��G�`��uZ��ة/l���yUכ۟�dW��Y��l���Ж~!xz��D�D��j�@&��Ӊ0{���A![��&�5�=E-��B�7ࢾZ*~���ޫ�=DnI�W���ӋK��0�{����T��UW��OsoW�����z��,>2�f@{�AZY��`z?�A z}g� ���j;\(�-�]��Q�U��!k�H_�7 ��4�V���S�����O������ı1�,��L@����VZ���^�uy�pDG��7xq��z�g@���J{�#x�>�Wv���4ߞ�zjK�����98H����_z� �K�7���$�&\�4���/#9�n.���eE���F��j� ����c�.sQ�=TY��'hSE?���4� ۻ�q8���YȉDW�!*��Z����}���Hե�Y6u��n1�8X�D��`�Lr$ c��g>�V=����S�ĉ@����o��.�BmB��k�ࠤA�F'":����yǞ0�ݜ"��Fw�YmFm�*r�RX~몾�����מ�N�Fx#�/q��0Gҧ�E�QnJ$v��Tg�Fy ���Q��  {�]?�����1��X�j*�$p�����嚲�. )�X%�n�\��﷒����6y՘5c�D]W/N<��ϼ�[�����f=$Y���
�!�����1`u�k.�S}�9�Γ�����ì��9�.�y���wi'%�I�)�Hz����;=l� �n࣍�.'A�F�ӿL��[V��(�}>Ż��V�c��ɤ(�F?Ay�\U���(2�E�X]��<���^W�y��i�2�=e��ܩd��fH�z!� �NlBV�*P�q�"���pF.&�1�Ft?�A2>�R�*�6+�eU<��Ue.|A}��7U��[���H��4ro9f�I�_Z����~�(�E��,QJ�u2!Ju^�XD��l�Q�
T))��@�Ëi��q���s�~��O�����O+~L�X.�b�q\%�,�̊�VF �٤�2�f[?�@��׽A�hi�Ţ�ں�%y���	�h�!TѨ�f§W�+��K��kT�`/l)w��hB��X�V�y�{�6����*ո���G�|�� h��$|��T�s�����	����筲k��/Z�������`�`�N�?Q��#Er�}�C�4���<S�>PN�����Z���yU���	�K��lT�G�����rF =��j�X��r%ƨǔc��L�Ge���h�』rGi]?(v2�܀�ڛy��p��؆1�d��-g�i�/����*Q�����"�z��^+���B@�jFB\�k��ctP�4�������y�i5m��[���� �ԏ6C`3i#��{҆����Ft�
�����+8�3    ���]l0�Xŗ�����L�W�Vai����:��׊��/v����lI��b�%
Ja�/sMF�X�וI3��o�u<��gu&~B�F5��h�'TqO��kA$9��Fxi.@��a3��u=�����Ln�I�/������$�/��ݕ�8�����_���_2E0Ky�?�����0$��tK<�ٰ�ox����������z����?\\�z����o�s�n꒯6�z�~%����<&�p��}���G��RW���@��&ȟ�9i����j�i�?0*̴[,���Jl� �3"n ʤ���~�ꡀV	@���A0��7�C��;��bG�l�������n����"+%����Ϡ���I�xH�����v��K�t�)�/����%��UR]���h%E�����g����憇�/m���<���ypE�w1˗��x=��b=S�ج��D�C�W��f��n.U�^�]K�Q�>�7� /'��\���?��s��~�4-�zTEınȵ6�;��)�̅��j��z��fI�O��䖐E(Hmv�'�~o�CYwu2OP���	Amj]䪌~j]=r�ŅQ��a���+%sa(E��A��/L�9g�m��Tu��z±˪"��@R�'�o6��S�-����څ0ٱ�39��ƀt��H?���v���[���������n䄚��	!�p��6���~�(��ܪsH�ێ�RU2��_��~-U��G������3؊і���`�G�FT��l
�sܾ���Jg@b6����,uOcsve�Z����hhkk��z__;(/����K��R��t5[=ː�I�f��4��4�#�}$�Tm��4XގR	�-8Q �^!e������7[�k�4�	�kR��,g�|��au��4��$]���KUseS��,�I�U�ʹ= Mk�������!��{��w���u����=PV�V�k�n��i���p��,��ζ�h�&n8�ȴtL��#e	���Ք ��Z�u���+i�ƌV�L�VU
5(�s����f(i����b�շ��<Iq�4���q� ����t����i`G��G)x�v,���R���_�m�׸�C]�~��4֓�f��`�S��;�`S#�Kb�����l"�{�t��u�&�����p)Ӻ�T�G?�8����n���Ul���oio�	uZi����X�*��콈�+Dӿ�"��i��j��6.���+�������k��������� R����h������bC�")�Y�M[��	�.�Ӝ���>�Z6q��K�z�iF�{�
�~��x��f���W���ף��L����  ���p�(�T�<��p$�G����?R]� (��w�F��6k"�P��ē~����ʟ{#*pɒ��B�����h�����4�8��}���a�A/�@��K��.�~^�!1�N��:�d�~w
wF�kg�4�u��>��� �i���ڠ����bB� ��4-+V��L&$��n�,H���؆nhJ �%8�a��e�c�	�Z�d�-�6�Ț��LÏ��О�}��>'��2NU77�?)m���1�a����{'��2ܭ>c /�g����n��	*n��3p05@��w��bOM�3�ћ�����+�%��e���M�ۀQ�4t�}���gF��x=�ZJ����[�Z���ol��٦�� ��G.�~��.����{vd>���h_T�C�ǉH�-m��*�2�D���H�5����{���� ���a���A�Y�}N����1�#EW���s�q,�����?2���@�Zm�ǜ-��\j��2M�=��@�5i��}���zH�������H��a���q�����')�8Rk-hN���w��/
��z�IU&ښ&�YC�F�\ue��#;���6��g�w�?ѫ~�g��:���)C��c���k6�[�v�fBVt]d¶9�"qN��oa�}ٓ�
���XB��9q����W:��$�g�~�^{�}:���f�طY�O�	�+��dyD^��OL���E�7:R��� ��-�۝��曡���I��<d�MF�����ږ��V�����~tD�CM�eß-5�C ��Z��t�uwe>K��㤞�[n�"�'�41���u�݁������K^ehC��d�����D�ȟ�,��d��ȯ �Pk����z"�~d�c��>%�{���:�;��1누]���mX� i���a�����^i0�-_�[Q�_}g��4�Sq�tD{E�':�,l��P��_w�*[V?��9*Js�a�4(d��\�ɫ�#6F�8�W�P1��ȥA����X�_19P�A-w�v��9^��<��j�,�ph�F�<Y��U����t�4�,h��=��4���?�hm!���_�M���/<�Ȩ�B��]�����zO	gV%��:��ݤ�HfWs��W��쒪�hr"���&Z�V�By���N:kʴ�1���n��M����V�H��~ ��ZS�
�qX���3�8�A^���O�x�C�Z*G*��ϒ��>����� m�>��*����u�L��EZ5��8����&j����2�x�mڔ�ަP��J�=�o�����ZDX��kzd�pY��M�m
�vI]Mx틦����I��n�TȽZ�&������߹d��c�:n�yD_���K���J���)2�l���kuOW���;+�_�������{r*�CEH��';�/�Q���9��6ó�Kl��6)mCOqDf�7�e/�:Z�љ�uX ���l++F�Đ����aL��k�?O:P�$�����u�2�L,��9q���v����3X2n��ӭ~������1:t�$��+To[s�3��z����q��ta1`�deDHy�� ���b��M���T�C�vڢ��c�Ey�1�����D0�	8y����_**�m��ʦ`]���>����;Hp^�T� �Vۺ���($)�quG�:�����v!�U?���ʸ���V�lr��Y�
o�Ѹ7��w�N����� �Gw� �����F%���f�N�Գ;c��i�)v�6"0���r�J�a�ڎ�H�s�;u��:]0���Zl��c�bzj�jq����#nݺ���g�/��ʡx�����X�戤���S��ǟȯ�N��!g��~�Oh�<���"J��JxS�\p8����i�3wNZywW+l>�hP܏G�A�=ۀ�����"�|�q++@��`H��/|�^Ne�U���5-����}d.?fK����O�q_�����&�sn^�"��e.[��F����L��a���5��(��/y�$���_l�5�s��S@vE�$ʌy)�j�I<��Ý��������ڜ5E���,]"�_[qkE�ն�E�Xj.9_A�β���ާFBly}&�����)Q N���`Hj�<0�eo�����d^�~\�:/�jB��<UcWG�����]0D�BPm�8O���з�$�9Ϛp᪖���B,��6�n/����:^�����=y];o
qA�trT�4��\����lOA�'Ä�6��E��
^�=��{Ń�b���@5���~	�I�+�Ś�&�yNR5�4�ʬ,%�T$ћ�F�k���V��K&#VeqK`%�Go�N�M
�R��@ǧK�jƝKdE�؈j�D��	)�X��H�w^SBlW������ȓ>ʺ��@���}�����l��ǡ̹�l�ʽ�)���F�U�(/���H��}��0�R2�,����Τ�!GqY�����n�w^��<�"?�GuMap@���8[�C�[�_��'	Hc���I�z@�s�g2�ޣ�h�^|Es�ƺ�a�����w-V)*=/^չ;���f|<�b�@+��}�h��"�3:�	2e�#>qp�Lɟ�:���X����B�lw��:;�Ű����&�'���k˜9L!�C�Dw�\^X�V�}�I��G�b����-[�9_��\��M�[�4:~E�j�O�f����X�Ah�V īg�����g�qk�!��#�z��/TÛk�����RY��v�E    �k8i4H���4��8��>�(�0��Ip�}B�þޤ̈́iAY���*z>?���ב
#��їa��K��I�%�<s[lv:�����18��U���Md�V�I�jltP[�,����p��.��;��\��G�}@�_[�s�M<��nላ�m(����%�E�Jc4���=-�����#��.R�b���I�!�w)�n�TWq�P�q�!��DW|گ/:���q�Geg[�I#i=��W�w(v8'��+]��މ�k׳��]��'�S��h49(�B4�ó�����ʈن���"k ��Bb�sgm�$ꫡ���������i2���ViV��.��=�T
�{��XIk��9��>����]���ʾ�^YTʾ*K
IԖ0�9z2����=���=��3����ٸe�/��$�g��d~�mx�z���9��2ry��R.�^D0ZJ�q�\CKO*|�p9&N�,�����#�t�O��b�^��,�`:w��%�f{�S�QWǏ~�<�h�0���L�nn�_��Tr����s�5m��>�r�(!��,#E�Q|���$��r�MА7���H�D�N_��((D8Ef�����H��	��Lb���U��@�.�X�Z�r1��l��zSO`vVe��zjC�o�PA��뫂O$^�g�F�{G�e^G��a�ړ�g��^1M��Z���A��T� �I[=��`�����}�gg<��^���h?�]
��'쉰O�^l�Ƥ4S24��>M�TH !�`�r:�?��0?�s��bT6��?��k=���B���nn�8���wWRw���!���ɶ�u��BW��D��F�N�b��ٶ�]���7�*1��ƕ��{�;���v6<��3��*����5~�g�yv&���	X�@V4V��S�ܽȏK
7t�ZK拊]f\>oG׸��nOҭ�_�aO��?*Ks��o�h�z>�-
��3Y����	~����8�����iB�x=ގ����煞�=BV.�<�,���-���I˧�Pz�z�hw��z�b��2d�b�9��4�9����ޏ&��>���ԋw~����#�<O���pթ!��b�C����lڲ��R̜�J��CoKq��2:�/4�CI�ljk��e�q%p���{�>v�0h�&c[�ѕ����.��[]@��� �Ϣ��~9U�U\�ޭ2w�8�����`Q0We���)c��X�x���igS��x3��Q���P�d��N���{���{g�ѹ[�?�r@�<q_���}8�b��bh��t�{ܢ�A�u�~G���σ/�<��+$�$cB���_Z
�~u�9�vX���@�JHGx�U�U�r$˹֌}=�,��"m�!���{��'��:����e�������p9y�J�Ք�����K�m��.tWױi�S��+e�b1�W�oD��ãH�rAj^?ǯ_gm�OR]H��N��.��7���<OW��qdt�"��{0�R���)��*�b�it%�f�k��$��5	���,vnf���vJ1_א'ft2x�IF�Sw��H�j]7$f�T +@�O����k�x�V�k��H|>�+�	�κIK��y��<z���KL	���Z�n\�䂒�~C�!N�	���ݿ��.�_�\݋#C���9ȴ�{����>ʜ��HܚZi*��/�c�m�<$I6��T�]�K��@�R�O�y�PM"�Y�Б��N��}x9���6Y$� �۲���w	���Y�3��������&)�T�C%�>O��8ۈ�4I�ϩ��=��B,��^��{k!��_�b���OgٲS%�#$�DyZ=?��	��T���������⥢�?���h�\�XJ#�jFP�{㩉���j As��T7�k�C�*�Ih��c$v��ת U�,I��cj[���3?��
��pr./�4�܏򏠿꿣~N�wm7�|��}��k���F?���@90M�e�?dU=A��I������w�G�iy�;f"OLSK�4#��z���V�A �m��������~Hg�yO�m�&����g=D^�St�, � z. ��F��<-]�Oζ��6)o����,j����G�IzWB�>�%������G�8����'#�l1r�|�ҡ�	.�M^d��5	ր�L�=i{��l� `�^���3R�� x�u�d��3媿a�JhD·�u��Jݲ�k���HĶ/��!e9L�k�{���^���J��
$��=���QD�`������|�O�/�v��㾇J��1��TmH��!E-�3�q�0G��������G"�gU5��yH$1�pimH �FnO--���s��Gl�^N`���yD�x�.�b���V8C�����"O�ؤW��g.�&�;/9�̡.�7�R@5���f,"�6� Z���#���4�C��u��0�'=z�>*�$�J�	%I��}1��l�(C�f����l���&��/8�y{E��9g��g�a���>�)9�"�X�<�|jX���NSUy����<�' ����X�K(��k�7ݑ��)�̚�h%�,}<��Oћ���>�(���eL՚6D~*Ԑ(��uW���F�.���5g�(���&�ɚB�΀�����{�֪5����6W��3d\�Ũ%�:��Y�æ��fY�8v�ʑLSGo��g2��mkU�6.����#bo���C��I�d�D�$g�;�H�4��PI9����VY���.��5��[m�x�I'�I������@�] Y��l��晳�o�r}���"���#q�5x�>_��Æ�B���ro1��l��M�n���ɊB+�$N�w�����Y�H)�R�X-�@5CeDi1���x,�bȲ	�'�ҴQ��裇 �.�h�9����,�ۦT �|�\��*���o�d��.!IR٩ʣ�fj�Y�g��ԙ�}�%Q��5����x�P�p�R��`���wI�,-&d��v�\�,"�����?��#��y���nT�ӧ�"�&���՟�|1m�M���ֲA�6���e,�F����D�z$cԶ(��}����`��u�.OTu�<* č�ᩥP��B�����.��5cl���V��*R�b'q��É0j�=�M�k�[�EB���4" ���p>�k�T��j�l�M�$S�b�e�=u�M�v�s�~�� �����0�p�.���Z���G���I�	P��i����`�|�������Y�N8�M�����tH��Ci�]x���A���i
���FS�3¶���|{��P�Sz��.�H�8�g+D��A�8��
�!��!T��q�������P5����e{{�:Zf�JL�j0�/��E)B�X�=WR�q��&�'EZ�
I��7Z\��\�����[AT,����c��?�d�=f?d�Lk�8-�)�J�<6�,�=L� >�W�v���q�����S���~��tDm�i�\d�2����=�'e�4z,�*��c�wtͯO�f�2�5�[9��$6��[��.�̴��p��ŜVg[��q��&$����4���ފ��z$���=�;%�����3 4H|���POX���eܦ���Ue�jP�4�w�t;l87��rR������_�x`>dh,��\�����&�˴ioW����\G���æ��n��E�[QLU�i���;M][�NS��ָ���P�(F%�?���q����<��|aO�(x���� t�e{�!� Lk�kP�[ ĺk}x����J�FZ��Z�7Ryp= 
nGm� =��N��u=U3�\�-ߔI�qO���v����	�ؖ\9Ѝ&@�AfC尖��-;¿�v���/)�y�'��D�.���7�c��a�6���Akrv�����+�^���B��������k�T0M�
>��4�����֛�L�3>r$�+0�m��ŜXfR.�+׷���}���l�z��t]_�!��o�I��IW���.M��Z�4'��ٜ��T��G���7è�D�M���a�����.�U����� ���>     <�khw�Z���;؝���4,$��>%�A���>'r;b=��	` D��8���3K���Gy	�%�~Ry <�dȪ+�Ju���ID����Y$5ܶ�|e�M�E���anT��y_'��9^�f|7D�N��3��6R��n��=������{����J���i�~3��-\��K�>�/vJ��wm-E-�G����Y�YV ���/�?�;	2s1�?�-Z�t1&�l`W��	nBig�e�2�H���C�_���t۽�G�L��">�b��������u�O�OU٠ ����5a�����H���&��-D:oV�b�}P���V?Ҵ	j!l�U��k�n�\�>φ�)���6��Ҽ�
��:"� �k(5�[�p⤍��jq\����Bܪ���gRJ.�2��	y���Jϴ�~#��h�QF�A��I�a�	y��RsJ5�>V���o҈���t{�NǕw�5�/�(.�'���.�:�d�T�5�˒�e$�9վA�V��
˳9��XӐ���z����p/v��rb.����ۡ$iUV�E� �� �n�"M5y�J����Q:6ԟY�m��н"��^�Y�X�5�H��뺜p�BvQ�ɡr�U�����Џ^K�]�F:߻֥y9��5�ib'Y��9��|��=t=A�j��L#�T�-���K-�Lz���~�\��-k�G�ug	s@]��ݭFZ ؈��x��5!Z�bd����PeI:!Z�]F����x�'FMX�:UO����9�h-�ߞ�NR&���'D+)ݙT���G�Tsg.�X#x��v|�����K��~ۓ���H	��J��4��4^����d��il���>P�j��E��z8?c�-������5EB�Y���n��^=��D���x���>�Ŏ�lE�;�m2!�Y��z}�#�^�t���&�b6w��t:\������ͧ�7y���|s�4����:5LGGo�;��7���1���Xd��i�%@(k���u���n�Ldy��:Tyrm'q%�N�0,Gpy?B�.�j��>��֨��:~��}���7��Q��z�
�;|0�!ڬ-fA:��[� Zˊ��+
.d��G�,��@��Y˓|�M(N��s��i��gi�$��we��� O�X&�^��L˦���\ڬrȳ��7���T��F������w�_f��i<�j|Yl� �ˡ{gbȔi�tՄ'�����я��s��EȰ������á�����l�*f.2U��뾺}��UenА���]�Ꭴz~�S��^W���m������p߭~:�G����95s�h��]˴�����ʬv��^�2���?����L�;N�ħ<��JPP x����>��� B��Uی9p���٤Mb���(���FDx<�;S!V���I�I��J��i�}�-�ϩ�0�"�롽���Dt����Z�]Ѵ����8��׼�m�ŋ��GN0"3h�4��|��c�R���	g/��؟�&z�w/��Ġ��(�����Tٽ@�ߨ����d?�z��7JI��/���������r��rq��2��� �E���M%ӈ+A0c��!���^��^1�I�DVi��=�Ȟ����V�֫�HP��]Q�?�d��_k<9��N�s�V�g:�BA�������a�����h���O��ma�쾿{����8�� �#�pi���������g�<Ƶ[c>H�8	܇���4t����<)M9)\��O$8��b�k��3�{ڣ��ϙ�<
�z��W����|^+�|9h�\�!e�eu�۟�E�*�	V����z�<��@G�%���}:	@i��@�Q��K��K�؟y�IE*�~�p��E�@�Z����;����tQF.-g���A�����+=�,?�崆gC� UńWϺ��"�KC.��ё��gp43Y���e2�^V�-��r��d��,��p��U���w�OjX�/��Y{%Nehxj�{ҥƾ���+xX^j���|��z��2��z�4�}w��/B�&f�͏��Ά�U@���sq���������@m ��GE�;� ���~������<�-��\�2�n}����c��e~�Xx���NQ*HζBȪ��n�l����,��;�]o�_��W��U��J��U��8~��zE��uʬ.�bB�Sթ�݋f����jݕ���O��]+5�!���op�l�0�|���2�ۙ��#����~A�],�A�Wi��Ox�kW��(.U�}�F�A���<�CT,�B�/}������Ҧ�e}D[�' �e�	��!$����SI�l�����gz�
��܇���w��2xC0��Y���G��˂����6C����D�D�:���sx��Y4�;|���!����A�),��v�B����H����x��4��{�8�'y�@�zcA��ؿ5osx�ept���>p������|6�ͦc�=�k_\�����#~�ߞ�A�f���<N�bm�|����_q����,ⴶ椄 � H`LH{&0�������x1���\7ʬϊ	��"��F3�2�>sM�eM��-�#�7T%�!�褋4�9t�3�I��:��yl\�0O����l��a��|'e�G���^���8,�S͘�7u��^�i�q�!�>�����pds�����p��*Ų��3KJ��-vZf�M���uȷG)��ҒLG��9� ��-A?�0�]=��!YQ����3=��q�>|3� ��8�K��&����r[�ي�<٤��F�g�u�e}l)�b.o�
�#�;��}�	v�Y�4w�4��.�nu�1B�1����������<V��q��? J@�_tD�&���e���r��)cS�*�+�������,�R_7.�#L���w(�=�I�GoT�A�����ǖ��` 9o�*����>��poG�� k���o��5�jPW�����\9����-2�<�as��5wx�D;�n�r���n5:�sdB�2�O�>EÈoW]�5�b�3a1�	B�ï�v���8\�y��5K����!~w9��펺m{e��Yf�I�e�t��\���e�}���2��4z[�׊Omz�f��΁<fV�6XG���x��р�*/&`9\����
m*tZ���S����0�O�8b#�Nn��)������G�E�ېX�������V��'3	�0���m{(�X�ڂ= �G@���]*���}���7 $i#�����&�Y��17��g��-S��E�
u�ͥ�ȫ�e$*`��Գ�d�(�^��޵�'"�D�5*�	�$��`y��&��q���s��yݴ{�i3�y�@�X9wy��ٸ�)<M^3�c�&�7a\5p��C����l���nBĚ,mT Ui� ��Q�t&<�C�^�
[a߭��R����ދ��.�g�'�`����	z�?�x%i$�8ǟ�E�dz�-�\^SFׯ-�pO��n9R��>1e���e\%&P�v+���Zf$�ld�E|���Y��|�>�T�fD�ߚ�,���eɈ"���ԋr*.���zu��0>���y���	���9}�M+�w���|���dX�tUSe��w����N�η;�fN�5����2�w��5"�.���mB�wY1Aק���$��<�������!��j��D(����Ixb��!8�Z0�V�D���&����S�/s�u��>�(��Sz�"��[�m�ryZ��J��}9�L""ˉ~�WH�f���.Ӣ2����~�U�]6��4�si�	����A|��K��X�pq��"��D|re�m'�V�����$�DL��`盤�7la�.|o���G��q�|X�f����9�D�\.��:���4a�ޅ���3�톭���������{�B��Q���GÔj˙���S����"��bBvwϔ?OU�i0;���;#.~���:Jfz�*��YJ�(4W��g�z�� ""Y�~E�"�7鄛��e��MUGa�ޟ�_d~�Ve�x����L�{^QLl�6�v�
�����L�E�/'G>[#\�m�Lx(¦7QH?��c����jbot����    a��{�]jt�L��h��O��^�e3��(�tJyRV����:q�K���6|<��}e�s6�Uw27��ֲ*JC/�i�y��T�
�c@:M��I��z9q����E�V���Բ���Έ+���i=>�r��&��m�����v���_^h-����݋\��qN���A��<ܓs9>�$�bd7����}8�u�!!ME0wyh���	�X�R���}����� �.w��Gz�_^1�J�X
y�/� �o+P�`If��є�k��+L�W�=��
 9�[��'-g�{���z����ߞ�V�D�����+Z��`C��ˉ"�曌��WS�e���ʐk�k���<��)gζ�+ꡙ��W6ijn5���Ǹ���G��GV}Ht���0��ޟӻK{;C�(�+ �8+X_�Tfߞ۠� HZ������[���S��u;x��-�<o�P��ٴ)��%��GA{I�:�$�̲�����>{�Ҡl,��������S�)��t�}�"I����1-���O�g,��t��[~��L��5&��D��A�~^x�hr�&[��#8�������Zc3�Yj���|�.�^ ����W$�n�Œ�a�?��0��sx ]����"n�bqs_�2+(�q���tUq��2r����E��=���r�ps1(�d����I�kDRW.���)�
?��x�D��3N6��힡�����e"�(e��(�#��Sjt9M��XAE_&TU�dFN���?iC k����\o��.ݍk6ĥZ�0_�;4�O�K��jI�D�zi!��xlG*�N �-.��zk�yX)�@�J�a��G�%�� ����̇ӣ}��K�*�b�>�8z�1�E^� �x���$;2�k�B��Y�*�>Rq2D(]�M��6i��ݯ�2�	#U����MI���x�4��X~�Z`��y		Co��6��(Y���4���r��)�g�B j���܆����%~6�4�.�0.Uu(p��V�K����K���tߞ�����?u%Y��W��*X�\�H�/�O�����syF�_�9��g�5�>4�"**�֙&���Ԇ����W��pM��o.�c�M�����w����ٶje�f6�T�-�6i��}Y@� GP��0J��U%��:��.<�M����2+���QUUƕ��5Y���nPw��ei�^��21,�fY�Zi�%�;(�� H�إ����F8��&���r��b�K��n��݇ĽuP��C � �}�E>�ż�fCA�E��@���c-�W�񊦣��6�w����C�Mn�/�R�D��̗�ʡ,'T�u֤��,�WC$&j��T�y�T$�	�(<��AC�o��cVEG���|��5#��@�����4@��ܖ���a/,DJ(d�����06�/���'�d�3:lHm��AOsX|���|gs�t�:��c��	�c�����y�]y쫏~���.����c<
���瘱Ү�@hfu��L	���փk���z(��ì��� Q��;���]P�i.�ŲN�	DܪIJk��*�ѕP���)���
�b�*�/��D�^}�����������`��	�DP�ׯ�V6iO�c���-�u��@!��.ؐ0��r�O�67���7m.ۢ��^�U�i��4�o��hX�O/-(����@�z1��lj庫&@F뤨��M�> ���^ɓ�mG���Z�q�-o�x��Wo_�]���^��i��Ɖ�U��@9\oy���uD`_?���j��u�����+	����ԯ�&1�5���{���wV?�-�"��G5��ap�@`����6�+7Y=A����ʹ��E�0�����.LU�y��M�и�l�m�)e7�P��@���̝�t���R��i��~l��r��"6��7se��ƥ۰��u��n1%�4gE�=��kh���+�UI�T��"�bga����B���A�b����6��(\J�`h�͡��l��,�9[�Q�m>�:�.�2�dXFo��3�%�V��{4D�S����-�g_�J������>%CDq1M��ܻ��O�xB�h�*�~��Y]�kOb]�Y��}#bR.-�͚�*�|=�*VU!��4�G�Un�G&�(v%�c�߷'��E�G�-��6cN�R����'�x������0Wc�	����dM�>��Z����˟6�����(H��^La��~�-�����TC��z�!2_����E��^0=U�PQT�n�/D_k܍���.lF����$�����4@�Dh����y���wu&K�2@�Ƒn�����^,!�.W���@�Y�.�y`\ۿ�P<�Ea�G�tB�b1W��.�`~��ƬMz�+�P@nw��b���0UU�S�c�e�.J�ضB��Vlep�Xp�C~�K֤�U�f<h�t������A�Yzf�,����[��|�gf��U��$�/�9�Fw����m�W�J�r���
Ɨ'��O~oI�z���E� ��-����C�j�vB!��u�����1�=^�j��Զ�f��2	>��#�v=K�\��uw{�äS��i�E�a����2�uW���	74�I �8�� �K�	�na�l�S�{|���Η����Gߤi�)ɣ_�C&<���
�Db���| ŪϺ<��FZ\iRDo	���z������ɴ@7��t�/5��|E2�|dU"�4)��E{��dյ�@���C��EA�@�4\�b�i�lܔ�f±�]J��^E�Iǚ�'�tvoU�V2����AT��d�o���	n��U9�~}�6Zv��b���
�:�	��M�U��}I�)�S��G@� �E�4K�J�'�H�B����/\.�L��m�Dl׹�����D� ��۹����L��o��?29Jp��@#����IX� �����L��'���!�Q{�ԱM0U��*܏6�?<�U�|Dm܊l�A��D>Z�����W���g����6�`�Tu���K���\Oۧ0�e2��#=w�K0�o�J[�z>��K�Ǐ��?�0�`'\�/�2Kk�A0,kG�.�����p��9ƹ����2��(�4x�r C
��k��_o	X�����@��!���#���u8��\�;�bPd��ln��!�%y)s��1sh�d��ьF/�	i��U?�~v���7�$w���WspOf9�E_�'\��,R;����9����b}�n!�F�6�"�`�6��v9n��i\��+BWHy!�`��Q-�a��v��M��߬�4]���5��U��b&���b�uZշ���{��k��-���U�J��kh���������b�zCs�k�n��I�T�;.^I\&�"�(g�Q\:P~�I�ʏ
���I%��t	��ظ�m���+C�jy��iIy�&���Ë�b���=�g�p^1Z����Е�sF��P��'o99��������lv��k��V�Opbػ�l3�Ip�^r�a�s��v0���,�X,���vt�r��,�l����Z�m������Tx��
�~�ǵ�P�Ed��)RUH��$1�hHu!��bؖٶ�u�w���5���MD��������2���ň�bI���4�n�I^4��^GJ9{�����o����(�r��l騉ݛ:�y*�X�%�G��m򍔼�e�t�K��(
�o��
�����Ax-Au1þQ�\�Xk��8¥Mɛ��v�&�\D�`1V�f�FYIJp@�UK7=T�ַS?�7r���!_Ϟ!����4W1@�X�5Q��D��w�}��+C�W�^<�J[�=b�4�9_�dJ�Fo�?Ɠ{#�/��'}��U��%����)_
�1��I�a�]�=�Z�,�q�_��`�ud�y���s��@-�_9۰�I׷�\����z#ˢ�ǿ��so.���߈�Pc�=E�L�_�.� j����7Y�&�WUg2M�<�Ⱙw0QS��<��Ѯ��X�KE�����6�MO*c�21�DV����[�ٕ��Q[^vN��!2�w��զ>���:�[[e���+�C/�i    3��G��C�f%����m�*�&�	�&�#�A)Ӎ���Ty��=(I�U���V4��ri6a3c�E�,F��&m�^d$��L�H�����veAƦv��֪��PVGop�� P��a3%�����t I����8��튚��͆v��'�f0�qMW]�r:{�<�^𭎃�4��&�DƄ��c���e��>�>�6�w�7���>w�E�	r�7�(��.W��!�P�4�qO���@i[? ���HV�oZ<W.w����5�}�m�@��n��q8��d�i{��^1 #|:���?���9Ң������l��������$I�w��1k\���#��c��VӞ1k�H ?�K�߰��&�SJ ���>�㪼���i��u\X]�����cT�;���^WVV������7�vF�����g�럣4kױ�^&Y\�'O �M�ٱa�`�`s��No��Y=�����~�M���	�6�j�}�y
35�(.����Q:ۿ`��5؁D���bR+��o�cż�Z�$~��z3���
:���,y}�2�)��Go�?o�h�u���E)����.�ΘM{����j���Ԓ\�/(��G	
�O.������W(O[5��#D�)'�FEo�&�'��2�J���"��IG�Ө)/�A�%�ڹW���h��Y=_̙p��M�<����:��(/����ܞ)/�|T/�L�����
�~x�B�˘E.��?��=�]����`^?��M���pC������"?{ă�4�����e��>��fK�m��ل�Vg���^��3�� L�G5z~>j.%O�j1�&�Y���p�}BA�$IfǤ���"z��;��h�Dm9�b����vƮ�b���$4�r^-�i��֯�ԖiU�B[5�B[�T#�=�L[�
������'JZuV�x6���c���J�W�Hܽܛ/'�ZT�����)�=蓟��N~wJ�=��B�i"d5$u�z[�O�s����iTFK��l��2�f�I�ky��w��֗qn@Y������Q��,����qF@��Ua6A%yz���@��@��,
!�k���Kݟ�UKW�#�Х�j8cio$U�x����ú���htn��D�Έ���Q	K�k&Q���u Ǒ��^�,�<ɯ�݅�o	��mV�>:M���uZ��G#��,R�K|b���w}2v�(e�T��h��:A6����c�����OLӬ�-d�o?�f�)&j`'6b�'�=����� �6�*5E��a ��H����7�<��}���:i�$�J�"�<̥����A�}O�Ec���j²ް��Wk�R;�택�o�̙�_2���ޛ&�<�qpB�S�=i�U��3�V���o�ߜ������R��ʓHڹ��� 5>(��n��p��|e�QM��_.^����~�v��I�e���<��C��@@)O�p 3OL��c��vp㓇�7 x��Fo�_�SÍHG��P/��MW���dJ��Ն�)���9zp���q���B�G�4����<�Q��e#�EN���	}�ܐv!��\����G��u��JXS]����������dt:�R�mH��Ѭ�LPV����AK��m�aGKmxX(����Š������;�Q���3ԑV ���VW�d��xm��gj��]�j�pm���A��������<�t�q�����l8��/6�)��%�2�(�z]��s�F)>_.A`|mki��L��p�B�eډ]���k}�(����,������|���e>�@*�U$$�|_x,�|cF&�Q.�+��d�#�Yg�	G������:�d �8p�L �ၥ�/��?0� �Su�kGdk���@0�ܻbV� b[����:���g���Lxޢ��2���
��i��e�j�^֔����wy����'zQ<�e�7�W�F��*���:��|�ƛ���yZ�����8�.��`�u������n�*'�� �t�EfАS�'U^��r&�sMU�Y�m&������i�D�!9`1��:}�9������v�K�����'��b��r�o�zB�l����L���n��P�:�?�\cK��,X���U6!2���Ff�7�"�:��J$�︥b~<��3F?;0��W��0�A��F��j�u��K�2��呹Av��@+�G�j�ġ!�H�%[��?߉�7qs{R�Ҵ�,.ED� /4���6����k��<F���
3l��ԫҙV2�g'�m"�$46��9�$a�p���7�d ��3GJ���ͫ�5E������f���g������GنſO����@�&#�(؞�[�CZ�V�A	���բ<��;��p7�x��Kƹ9��⪼�z?N8h�~`Sb��]g���k�C�yo��8܋�_�qR�S��0�Ǜeq]h�[�.�L�����G���33��,|�߰�~��0�.n/d���F��=�'��vW|\�5aq.4zYE߉wdV����L�Ѽ��T�[i8+�S�1�A�#��j��.׼�ƈ^w]�Nx<��dI}�¹����d7q��y��m��C�4J��忔�M�=�M���8�y� L��@�?s�����b�\�4���z�����pWj��2UGߚ2������GH_��rN|�ݥ.λj��)��(�Uْǃ&ۦ�}�.q�ڹ��2�6��|?�#���O���蒲�oeUY[���dSWk�� A]���ެ�0>\���n'P����L���S�f4�ۨj1s��4h���]��E�ΊF��*�~m��>�u�x����>�վ�4w�� �\-�.���f3a\�5��P����=�x��I����"�UYV&�+�
lW��	�� �sGB�{��j3����Y<%�uj���>���-��ݻ�c��|�l�`\�o:P�(s����ceB��~�����7����<.r;V%r�dSX`i�3/GO������q���,Z�rS$���y�ҙ�U��`���Y5oG'�8w=���C�-�	�$	�k�zmB(x����e8�@ss�	���� 3h�1̹=}	�����<�$:��XrL�5C{&��r�{�J^ s���ݞ���d��<e���~�pk���5���M���~pwl��Y�䭀	7���8W�>za�Q�=���Ӽ�3�\6��K[݄;�&��ƫ:����)���6�������yA�re$�g(��!�o�:wU-��Ά��b3A�&w��x��y���٤.�ߗ��r�t?�9vW���'�Ts�گ4ߐ�P����lN.][5����<+C ֱ�%`X6���n)�����.ڋI'����U��}p��ER�[�\ g�o�L�e t�iiɑ�3R*������]�Q�{� ��aAy1�l�Ǯk7��}4��e�b��2���z����҄���p<��]�N�J�a��Ѻޥ�	�HQWF먳�'�=�ЩGX��6����s��7��r��ldPpA�	9�,�Z��:�� ���w�4,<��(��P���˾b�a��v�=���^���y1%�Uy�Y<��_��[a�~�_�}�Y�u��oۑ��?�R�i+�6w�2�0��k�,H%,��l4��a�o	>~�Aӓ}�%��b1X�l�>]gFly�ͫ�� �&TM6�"�R���F�}�̈́[Ը��`���Q��JC��<�+u7� v'=���\����L�G�&���Np�ګ^���Z���0a�Q�yb�����1E����S�\%Z�"%����X��A�g�6h���T����E��j�Z�%�<B�}1��c�"I\%�X6X��EB��k>�3����@~��QȊ{��Ϻ?���ň|���Y:��}�	��"i��M��0x70����Gq�!Ђ��w��b1ʚd�����	<�"-��L�Fo�j �n�J�� n=�|��󞲺�"G�*8\��������&���k�
��d�;���]?=��/�����;{)�qDDE�V�����;.�=��;ٵ��!Qd ������    �� )�4 q����r��զ�����N�~=l{�;�O�R۴� ��W���l�q�ڝ�۽�=��8qW=���@G"�ɵ]�)ȞI�&��=�c�/�4���_}�)ĭɬ�T��v����cn����~�mY�_����&�~�,��Y"Γ/LA"j�Qs ��m�GÄ�!���������r��H��l�8�W	s�~y7�3S� Qxl�T"K�2���@6��k�r���W�)K���p�L�9�x~	$��u�"n��=<���g���ZRh�^����l�=6��� 9���6���5�AB��i��a����2Z &\z_���R�LR,�X�-%�73ģi��/�ۯ���'��0���7����d{���	�O��L�=�EZ��	�_�����0�Ec����~'���I�_إ�s���"R,g<8��w�32^�Yb����><�h��<�	�=HP���f]���9h��� �0-A���$盔}9���Z�Ҥ�B�C��	_[���(�G������W�z~pٕ�O���w/M���KC���	����M�D�SOAsr��Oj,< ����Ƒ��z�{�ܷC��`%T6W�@
�2�C-���3�$�T��z���KF8�cS_<��C�<�W�RR�
[c�Pa�D��]T��hX�%�!�����D�d���8��S�˥�7��g�x �@������F��2����vRK�X�v���� ����q-5e�o�0d�����)�Ъ1����������ßใ����U��±M��xZ��i�.��N'(���&L��s T�n�w�gFa��e�l�Su�,Mo���I�#�$����	�|�w���<Ҹbo��/lŕݻ^�� �}x��U�֥�'u�%��t��������h��ٖ���n%�����tA ��-����۬�'��ʪ�,΢w-[�yO+6Kgrz��i��d��≩����<���`:�mʆ��4��e"��G�ݡ�Tw�Y֒�ő~8���&�ė�`e���8On�W"��-��K����|U)|��j��k��@��HO����$�>�}��J�\�����i���\���N�	��2���ފ2�����)U�I���i��&"����l���I����*��gW�;C�H�{�����k3bD�Fh]=��c{��\hf+��2�L8=y��vz���f6Bk�i)��	����CP�6Җ�bc���"úJ'�i�EZ$�&�� s]m�Mz�����3"R/fC<�k��i1�t(cI�dI}�
J��v9}{�i�;Ow��wX�G%��W�8t�]q�4�eܠ]9��=���/�0ڻ]I�a��0}RWߡ!��;q�����X����$��SWJ�$��>y ���c0`7�oQ��_����յ@L�_O�M���W�Ƞ@K��u{|�L*�Ie�&Ю|�G��>��}�l����s>��л�pB�T��5��K����χ6>��S|ԣ���D#��t�����/gѶ���C_NX���w�bMl;+->R�)�j�w���;�h��Ru����,�,����.g'>u�J�~��"��ET�k~k�?�g:�½d|ؘN5U�5��KɑGx�`b���?�D��o`_�����<c�������������ξ��pTBJ4z�6���c�QODǀP�܏�m�%��]"/<��~\����<*;p�v�`��� i�n�hަ�j=������|l�����'�q�+h�f]�s����'i0ڵ���M���r�`�E�F�l9Z�\
p��L&�k˦*Ek˒���W����	Jv�f�����-*��ʑ�k<ޗ 1��ZT��"�� ��h��Eg<W�����Iq��Ul��&����(���2J��]49Y�4plx���\MS�� �u�fז-@ݨR�K��z:���7j-�����(5l4u���"�w]���rD�5����L�p8s��O,{�}}�P8ˈ<<:1|#?�9Zc��]|%SJ�T� V�u��6y�U��$U���Ū�ި�YOV��V��/���k>w~n|���͏��w*�a��F�
��%§��m�7E�M0��&�WO���Ү�h����a���
��gV�aRTcUa6P}�6cX�ȱ.�!����q�}�f{��F�T��UW��/���Y��۵��'�Aޞ퉼OUW�E���O��T}<�,�ʲ�ʖ4vMǟd(�`Cfk!n�(�-P�/-��1afgK|tD$�s@{4��w��Y,a��&���g-U��j��$���q�玞�P�1�/i�)a��<K�ڋ�
��z ���,����E7�����6�	�qޔ�R`�^���	ja��/�{k��PM8:���E�MyvՒ�|U��=R��h���w-�Q�� O�;o겇`p��%X�?��]�_?7eӭ�	��UYd�]�<�}K-����j�ךl7��>!��뇎�����	�fW�T��sW�p���a�W�>�2�X�gj�����E��/Al���(�/�R�r&l�Wڕ�j3!o7@K����d����S��N&>��O]����U,Q:��Π�@]��� h�!QSf\�MP�yT[���Da����0F�{*=��=��X{�NH$�ᅤ+�l�l0_e8����*KKE�;� ت���?��ʙ�4�D��1�v��Q:4H���������|���	�U�ձ��~�N�yZӌ�3Tw9PR�C�Q9��`�vx��X��:�LxvW}Y���X��Bb)�%ū'�D��W�;v�1�.�us��8Y�ٔ��if�IA�ǳ�I��l�^�gL��s��T����0�U�v�)���~,�6�*�������I�l���8����QO�	m��+9kW�t'��A�0��D�ظ���Z��}�g�z�%���)����� r]���Q��`t�P�U��sQF12��q����ȏ��#��\�����R�E����X�Ia��,�~0n
O�D�B�$mf\��B!l��HY'8��,v��Z�UqY�E;!fu)�E�F"�ac�))<G�kr��Apt�[��@NW����b��}b�l.nWe2�ĥΊܰ�Y�ىdA�̎NqLvt %�kK���������a�f�D-A3�OA`��j��v�L���pc/�^DRآ���&݃aw�d�6����V���t~$��g���_�f:y��a{��,�V���z�:�Z���^�-xTSX}�y�y&-w��vj*�t�Z������(�1�I�̬ʆ2����=C۽Z����I��n����γ�֫����&�eW��F��v��=��^�:d2xp�*��8�&.Ɯ�V��pVE�/��3�ZY7C:�WIc����>�n~kf��w\s�Ѽ�=���ݡ�����+����Tm�����.��:涊��BM���YV��5�� �lC�x|���<����f�e��.]o&<;e�d�BRE�)�r�M��QƔ|����1^���uU�}O��U�V���n�U�F""�+�=l�
��$2<���`��N+S_I���s�۞��p�:�{(���d��\И*�jJ�W�ER������'V��8>˺�?k��v��2����~�*��~��vݤ�˲<����
��4�
��-ͽW���,|U�\[6��i�$�&��b4M�[��H>7Z�}�� q����`��'ݾ���z s-4��F��5��2"��v��g��d.�x������i��z�4���v��ׇ]����.���"H%��!x���wj�PG���X�Kc��������A��.�z��u:K����PS7IQԚ��Y�	�Z�ހ���!��A?��4�yf���C�,�t;��0�?h�Ξ��J��!�z�*�]���i���*��<��������Gw�.���K����隑O�n1�W�E?��gIi���� ������������]��ˈO���ͷI�����o�N�L��'B`N�q~G���ƹ�b>R��b;��Z-��e�    ��ך���(N�$��a��	:KxBF�7��2�XS:%�J���&D�(�ɗׂ!\mj�����H�����+C�tM��[qr�kᖕI�X�7��J�a=Al�)�4���5>���c<��\�g�v�1���$d��@/mW@}P(�-@��+��W���z._�;`.i�*Yo�rB����@�ELi<�6�ep��4ԕ�x���ө&��"E��Q�f�qW��s�E���z�(�XyZG�F���܃��ן\k��*�:·+�" Gز$�vg��@15�5��;(�J\�˪��З�bw���M㸚Z���f�E�:���d"��{"]�B#�NF�9�a.�|�ml�bkCg��	�M�7P���R���]D]^O0l/M�)�#��)��Ν՘],���"��D�A��izm���B�Ԩ���W��	;��螰�Ζ34��ZD}�MP+K�$�I�A���F����ys�s�<0�Wo�B���������=�w��W����B#� ���˩��$�\Ķ��Y�ClB}f��7��q;+8E�D�� �{�t��RX�~4���g�R�q��,�o�����df��ZʮެؑP���ÁJ"���7ю��M*�$�o޵#@��^-�	z�a�����q�b�	]Ca�\)��UU���e��:�vJ�d�����q����G�O��oG���.�l�煎f��Kۻx¯����|9w���:�qn�8p��V�D��많g3���E�Uebnb�F:��L ���<$�qY����۠
�2<�5����
�dÖ�=(���~��A�,c���Y�yݬ�c��Fq$8���*���JGǿK�w�]8�����s��<�q*��L8u�ƫ�aګ+:X�����*T>�J�������C�F���Ӆ�P�E.��؎�����f�U�eRL�˙͘r�rp�\qM����ϫ�����6��i,5̲���,ѩ�0�p7�,������;�-�9��)\��2�od��G������ѰO\�р�F�:�������(� qx5��4�����_*��'l��#g3n�fl��y�CP;�H�,P�~�pC�+[VW���(��GoZ9�d�/�D�ႊ�Jjy���/��(o|�h�	o<�u��2�Po�N��Ԓj�!w{�#�h�p��P#���1�p6�vO��*m@��D��9o	qW-�dF�Ǻ�
��~ϲV�n���N	�������*�ɪ	��D&��l�NEJB���sV�+R�k���W�.�bX��HIE��y<%Je�Ky�g�7`6 ��5�tD�����W�-]��,Z�nCݑ��MD���,��=�W���Yŧ���\��E�gM4a@P���y0���2j-�T&DL,�{��0��/-�&���M�<o��i�����vG�B�ԟC���6%�R�=:r`�9d�}^���"�Q��2��+IT����נEQ����CUF��tEx'��A9�9l 4l�F
Q�'ڭ|U�N�T�Ck\�d�G`��@`��̈́����hy�ʗO贛��i/�%�_������<\��ͯ�6���$��8�PN�^d�}=@8�js�dr�8���$x�ߞ�'���)�����>w�b�%1�隧��A)Tc�b�r+��z �׫���Bv��]+�>qm�߼L�u��tH@{�n?1�͔��({c���TnXKm�<#��VQ����V�����Fb`�X����F�a�(M��#�%Z�D϶H�6	o�/Fq^�A�	��������_�}��O�_B@���M�!@��77Fـ$i�I�S y(��S9�U�Uc7���(볼�?rJ�ǎG��n�l��+����Q��XN�r.������}��q���!y�Zy(*Q͜��b���} mG��c��TtszǢ�������Hkjf�MؿV��d��V�E|d�Meut�	�o�=�W�$d�����Ub�u�J"j�ޣ��{I�|����US�:�(+�B���̕��ruÊ���"�g���e�Nx�ԡ,�,xs27�aD[�7	bK��0� ��Peb��z��"������Q�MK���:G1$v�����Mm�p�d.�/�1���;̩ވ��I�8��k�ʹ�z�D�-'�?�=�۬���e�d���XڭA΢�����>7ã�8	�B�Yy]P!]�-���(�@?Ds1'����y��I݄b�䥪o&�"x|u�$�����_wB�\
�/��+���G{$�W,�:0ߛ��E1�~�i�m`Q��d��l���n��K�#y��4�:���.U��ǲX�7��+�>�}k�6��U6a�F;_q &^AfZ�k0�1c1�NO� ��$xձr���x�>�TV���U)	�^M�`��z�����R�#��=��a�*�t݌`���W
q��Ԟ�T��V�v?΢�G�.�#���e�"e�c�;��żt�Y�k8�R�U�����@	^)��f��0�s�R�:�c�X���c	q0p�*��p��%ϥ�Wؿ-S3�LڢC���3,BwJ^��>9t�`������'�Z�vMÁ��]�w���L�n���&м�����b{��J��~R��[������{��Y�'��^��Z�nAw�����7 ���j��Y�n~�c�̈́�1��\�L|r0#5?�E�Z�R�U2yO���N}�����Qʠvu9 "R����PL�kGP��\Ϣ�%���7�I�E����d�t(n��-ŏ�C'U�۠���y8v��X�p&y�Ã4�~�C���j��,���#���=<c))�e�5��q@@)$-�M7�����όa��n6��4O�h­����"L|q{}'��J������w��&[�8y62TZdm2��ein���7��y�y���z�ǟ^	\
W*���KEf>a�ԔQ2!G�q&hc��)�+�bNE�bëH����j�g��ɺ�*�C�SK˺�R�a�B/��]�\��Yբ>$v;��ly��NG+(�Ez;�/q��#���J���D�(Ux�cV}��am�{
��=�ܦ�(|D}��dQ���&ʺ�g���L,P�2
�n�ͯ/-�C��8i��hu���j~�M�����a�e��/�C�_?0m�t�%.c���2&g�j[:Ԩg� 6����Yu�������qAD�\L~�1gڥuz�`.	�Xse;��ޝr��Ե�t2���b��l��&�>�����J�lѧY���n�
R�7�F��$��3�#J,�>���].���K��¢�n�m�Zdz����j��#P�t���g�Z8�;�:��^��$��{񳨞t����v��qe�$<����&�45�xE��������Φ:>t~Z�Q"��-�6�[*dq�f.iEJ�*��-V*��q�p\��Q�{b�D-r4����b
O�5H}v  "����Ҩ�&�`�%GQ����:�	��p�
!�}%[׳?G��b+��4m�QSL��iV��2p3�=��d4�v�jm�����,����E�GS�O��`}j�K�9��MH�z/�a�(t؅��^�ф{���j1�Rhi�$c����>�\l[0߀'+�rB���Q(�	iٸ�ZR9��%�4\�9�4��83,RT����uf*[�NQQz�l/��W��\[�29��tr٠���h�m�l�YYw��XbS�x#�a�s��#3�Ѻ�k8?�!�p�F���orS�2� 7OgX��3Xlu7�8?�ں�}h��8��]��ǵ����R|���Xj��P���˻߀���?t5rVw>_�n�x8��Ň�ԍ��ژ�}��X���8f�p�?>T���Uc��zU�с� -�� `ڻz�F�e7�C4�ӏ�M�6k�4��"�"	�&���C==��Kq���j����$
!�����`�YQ��36S�Ќ����dRj#d�e�6hr.46�P��>��q�{�́j>c� ��m$����*�m�&��E&�Lk�.�S2j*���%��c�ҭ�~�1C��Ò��P�1��ڪvN�W챇z1a����ޤ��D�&ׄ    b���ZuDx׭���%�D2@���*^���2onG�q�"��ȡ���`G�U��0�C�|�����0�w�� �2�]ӹ����|B�L!��4
�pm!���gv�{��'d��0/lѬ��6�0�C��W�S\�q_f���i��ߧQ��ԑd�0����U��I����<�!�p�l�b�P|�&�i�JTD���@[g�F� �� S*��U����^W�E�ͧ$��y9~��"��a"��^~;�*;�㚎[�À��Q��������NHOCb9*M}��q,�w-g�bcT]��D~H��,����{�m^�c޶�n�5�&��>���?��gT�j��'~'�D7Ȧ��8Ƌռ�mi�,��	G1s� �$F���� ��#(�Q��z��J�</���m�E�§��ẛ=��t���'y	��nO?ȫ���<$l��RX�p˅��d�-��#)���N��kw��3��j&��us9�4���!�54�2N�
���k)��X*G����Db�O��n(�e4�Z/g�H�2�phE}����dՒ���%��a?Ҥ�2E0�ځ}vv[0�X^+Y��q`G�=��r �ټ��T��gJ�J�,x��s�Qkz���L�[w}�1%z�:JF����K>97u;�B�_�1�m�ŕC��������w��H����r
���AV�W�S 4d�Ɋ@$�`�o��m��>*IM��"x��@=o$r���P��K�P�F�`�E��.::uΚp�I����%��ڦ�	��y��P� [@����x4�q��( 	j�>P��~�!#f�"���R3�y���2��>\�U>�z`)����銰�夊gkQ�������q!Nq���I�(���u-(o�`9ч�}y��D�P��i�Cj��h�9JL�*G�R��^q��*�����Lp�r6^�N����z��̻�>k&<GYT���3~��������2ᑏ����=~����g�",�	��,NM*��8q����r�<!�U�3�&*N��Yp��s�)�������>bʅ�V�o����۟1xS4*!�[ꢢ�����M����N.���k��ǣ=�N6��WPa� "?d��+5�l!N��Q�M�m��H��l����������+b���V_T�������[���M���"�,��2O�Z�N"����a��Q8�6����^�i�:F"���i�J��1����Ͷ�/�*� M�%�i�4N'*� �����	tH�jW��!�Q|��GQ^�Ք�:q�ē�8&�=��نq��o�.�Y ���u�ny�S�Q/��=a�n�pY���0�q6�hm��4�@��1���Q򗈵���k��ה�H���q��N?C�Ǩ� �r�2�w�r1:U�OG�l�L.����%��]`�8Qw�c\�թ��I��pC/�tT*��M����H}���a4l��W�S��#�U���QD��=�H6c��P�:���P(��s9����{E6m>�x�b�q|���@sQ���.]oq[�Ti�"%+Q�����\ro�M���מ���gS+l�2%pY��V?�W�4�cv�JCl�E�k�0�>��ri�C�Ṓ�v���ڱȫ��G��4Oe��@D��#C�&��>��R'N�`S��[�(�c<I\e��<��\���xs3��h�dE�����gYu\l_6���@��}��4��){,?(|l?�����j��uf��5Q���6!M�:�{��T���u��N���Ű�q�ų4�E��͔0�a!\o�܊̞�R��K���W�'�5��������	Uq����%�����ʂ��lg�����@���=���o��[�&y��eјj�9�0Xu�_�/��?���wA��40R�s�߈�b/�|�5�|f�e��I�7�v=4O������b->���b�?>!L��l,�:No�9�Q���,��= v����wx����mNJ�p��]q
7H}���M��r�F �����U���Ōeߵ�{�8˄�&y��q��C�#;$@(R?k�(�����l1��lj�6��ل˘�y��{�� �ey�����V�N��JG��~�5�i߳@��=z0NB��r����qU�^�� �jm������`�������`o��7����н��&��R>!J�G� ��xpv�����7�6�"S9�r��S��ܭ��*^ $G�����PQ��S��E����}@��\�֯b�u���ȡn)?��gՊ3�]��ʦB)R0�����q�d��KM`� �>�Hq���7L�h���w����n褲�rglo�w.���#�0t�H[v�Pև¨��0�p>�co� z���	F�x#A�/8���(�&m����0U�4�_�F ;������%���H=�+��r11�٘�&�hB�l��5H����!j*u��]�� �="�~�h9�ȇe��r���6Ab�`
h�vP���f゙@���&ѵ�a�AyS�������G�� ��Y9���A���/�R�0"�S}��w��>O��Њ�\���?vo�`��e���q�N�΋��#�H���UE�eT�?s�3-�<f�A�x&���Wu?���w��4�;�_�9�'����=����aO���N,V�&�d�����͋4Ld˛��Q������"eIڑ����#>��B��|�(d&� F��(���'@�r��|�&�;���0��Q�Od�|(0�L_оpѲ�����y�F'�Ҥu<dlE@����u9[��O]��/�+}5,7�x�5����A�)!�b����;�=�����LoE'�4p��ݏ?v_���Ŝ�j���MS<*���j�d�@(��X��k�M�PM���oV��1sZ���c)"�D�b@��i[Q� ��z�*e��#��U�����9��>z�b�[8���D5Mc�YF��,�nwji��4�#~zU/��`xXa0��Yf̨g\�@c�������&a���g�	$�OP��Ծ�7g�I�l���j�P��2/ �f��c' RW*?!θ��_��ˬ���@��̦%n��o�=E�d�2O��;:����a'�0oAT ����l�}>U;��2]q+����HEq/1|(�f�6l��!	E��/�-��h0I�s�І2p���;�ճ�Kd��0�?��İ��6���r���������t���CAƇX_��5���D�V�+	�l�@�	���XP	e.9{��;���-�ܺ����(���Ӵ�ӟZ T�$��hK�j����e,AOke��I̥Ƶp$aZ+�q���j�p+���I���[Lu>�=���������8
K���&x���������O��(���������Rcf�.�J�v�<2��o�	N=�!�j��YO��q��8f$'�G��?���$d9��\��2��T.�!�A�µݩ9�!*���@_N�@��N��[�G�.��)�,}�����9,����C�L�<�}^dq,�oi�p�lɎ�H�º�.�lD�2��	����2�����rtn��b�F�o!�~W�f7@�=.��0҆�&����Nv��z��.�̼
b���l��g�p�E���Y|{��P�qU��?J_w/$d�������f�y8���q��UߺG ��V-���"�/�@O�4P1w��*i٥�g`��k���w���ځ׆'/K�Ks������	)����,x�<����{���4��p����R�=�.����Ʒ���⽚Z?�&K�{̶�/˪����n\��΃7
t,e:{د	�G����y���j8 s�S���B��h��UM=A���@K�N�l���G�m��v�uG�6�����a�Z��n>�����	�{�"��f&���e�R�\�IR�2ƁJ��b���bS���He�u|��.U�,+�awT�F���[�����8y%�]����G�������30�@�Эo��x�� w�Ew��    ��I�u@N���e9�D���{R4������%��ٚ렾�
��G��M��r��xg�*����:m}��s'�1��K$����Qn�
SԖ#�vڏUNd��ƌP@'�B~s���~�Fz+hJ����������m��^��ga��@�T���f�	�r6�h7���=�4���ߚ.�t���Ž�!a ���@n'�Į\L9y�F���	c�d&�*1�4)���Gyܖ�T�}6W|	mQ�Ј��Uҕ��|�ͧ��p��VEI�L�,i��R��q��rz��}��S�9X�$���7j�����^�!��;,'>����,��f��K�n�[��R���y܋�1�h�����z��q�L�1y���FԨ��y�R0����뽫�$�`�l D�����#u��[��ve?��"8�b-�i�B�|��,�D)Dy|aK`L��[R��"J��ԓ�B8[��6��6��2&�Y��y��X��}�Vh8D��Z�soo���ҭ�3Ԏ��h�	V���u�T��),&�7ۢ�2QN(<PHK��2Fv�]���ώ�H!�~�:��1������BS� >��?L�*SOPJ.�,VՑb,�]�%���~|�%����(���^�JyjAOx�~m�V��۲���/�g�J�,��#��q�{�7�1�����2�Z�
\��џKy�˥�K�Tm\LЕ*�8SHJ�����{ �9˄|0=t��z.�P��d�lB�_&��1�!�AU2��/ ��{D�/�XOC;���B�ZL�r>9����vJ�L���ay��v6�@B���
�y�0PZp�o�f)_�o���i�0�&���#���H��{h� ���$;zT�@��jy�T����Oc1(�l(�:N�	��2�L�!˂{`�U�c7)����`/bWjC��ǔ��('�ɔy�e����v�Q"�cpgd*"#�`��R�2]�������Q�`m]:��H��Xl�0��p����qYġ.a�"YH��s����tC�Ί�ç�XA?�δ���Lx�L�*�� =��9��$	�^-<��:�:A����]N�\�u��]�b�(����$���a#����^A�^?h�*Z'�Й��6�<x҆�m�n��Yl�7�y3eT��@�e�M�ƚM͋'_��{[�z77's�:"C։dV��^�|竬���󅌗F:�2Q �.vWZ?Ac�aV���6��M��2A��.����'N)]M|0���yVZH0�*��f���6�W �T���)Y�VyX�����W�5Zl�4o�n��f�"��L�&65I����ȷN �^�n������A�hH�h!����-:ⷜ�lD��Mn�f��H�M|9�1��9�\�:zF��������Tu(:���H������l"���Oj��o6����~�5O�O'5�ɂ7h���+�Ic�@��a���������:��4�͋*nRsšID�]P.����xV�Lm�SAtC�3'R��,c�~����V�_U;e�A ��k��t?g9@���>���#�G�z� <��1�[���ߟ �'"k�moEO;������.�T&�o0{�K���/:�>��	7��ec�ୌf��P�tP�+|0+��?����f������G��[�j�>A+�!p���@x��%��k0��fBxMɢ��LX

������+��>	�mP���ZN�~6+�&2}?!��fT�	>B�t+�>���xI��t!� 2y{��P���]����n!\��KqܐJ�l��.�t�R-9?�����;}�H��*�*z��@x�&����3��ґ�yS���1�EY��R[�� ��Å.̅�ؽ���}�r�jr�~���D*��؀� �]�,U���6̕� 4���1,��(�Yh⺹�j�a�J�1e���ٝ�`$�Q.d`�y��kwr�v:e��ʐ��7	���U���-�飤ԝ���dUX�Ñ����{��>*�L>���tR�9t���9�p\э�f
e�G8,�ȡ��h^Z]Ӯ���~�vN��p�*� ��M�����ǫ7^;B�~�b���zG�t/��j?'�V�b��qN�o�oP��X6�dAἚŦɳ��MR���Z��ԇeH��6�&�+W'[��mt��#h���b+B�;��,��&��xB]S���RB��wĽ���XoTT�B]Gz�8G=�~;���-h�8w�ꀑ+�;�|�Nn6Ɋ�~iz{�L�Vl���
��SgI�h��V��;�@uU.g�>2�)���p��$S�2	>���K�Y��T�:x�90q��h<vM��/�w��|ϓ}�۟'�ae�F+>���Em;R��Rw5�b!K������7e��̽���\�^�jy�$UF������vJ�����1dbc�goP�K=E�A �:�nB�ʸԷ(ǬSTld�0��*Q�T/E3��f�ٛ����{&h
ER��E��S�]�!��$�!%���f�*�ލ�:��jD����%�����Ky=/����KEw>�Z��T:��%if�e/M ��gՅ=Q���wEq�lUJ�V_tE`�X��4�o��pic�v�K�Z�ؽS�Q��t|�d��,Ү�j'�>*q�P�\4��$Y�E;���3��m_A7��8���H�ݏe��� �[s�걿��n(�HH��-�w|B��6P��fGWM�v����V�,{�f[�7]�4�]Q�h���v^�Hl!��&�J'���V
R$�,uX��$��X���h������#��7��) �8)j"�9�g����7!�a�J%j#��EpǪzα*�g�Ӥb�첩e�h��ێ���ks��wn:���onX W�4d��l�K�0�٨:����4��=g\���mF�K�[s߂��R��.���Vٳ���0J��Ǚ�-ù|���Z�y{ٳ׋�	��_ꄨ�Q'�#�/4S�3��H�����L�� 	��\l�=�����2XXF�p!u��w>2�Y9�d�	�mު�.5W��>��;���m\�儷2��5ea��]��D�M��<q,5��R.���Ԏ�l9��ٺ�61U1�b,�D�!Y��S�Z��T�P�n��WJV���Ꞡ6�C���:�T+h�K�����Y�1��M�(���(�#	%��[�OIV���|�p�5�����������{EB�ʤ�يgò�H�3f�'Y]��[�/2��ͣh�%*�D촲0~��2�o�`�w������V4yX*�Of1ŗ�t�"����e��&o���^e������"���E|�ߩ��,�άϬ�$��W��E�Z������8L���C���XU=�v�=T�&Hԁ���rLs���ee��gP��s�X��+�PYԐ�E3t�-��+���A���D��U����&���8�� %�-*.���8T��@$��d��mm�(J�D��2)Ţ0�a�kl;����yh��/X`�>��//+Q��
�'I*՝�����u�RT��@ ��_��w����X��t/�ȼ�+e�2�Ę�pH��?]��n���y
����д����F��M�
>��8-B!��R�m�w��S����"4G&���NĨԷ�I�\O@� I�����tT	@�S��"��V��)���t�+�~����w�Տ2���_l4?�m�4�}�'y"��,�ܞG�#۫ʸv��B�'�:?6�c����i0�v5���TL���pi����5�o���&<i��2*���g���8�ݫ�����.74�x�p�Xw危%Ղ�����g�ԉ����S�o��ͥ�$�(	>2D��®
܄�
����[k��+�#g�����Mz�Y������[��*0)(*u_��\�k��U�T;H����=Q@�K�U���fϒB�{�@tZ�@K���H�-Q�95�v�����Q�hF��罺����,�[��=@��,h��d<wp-��}�[ğ�p���E�g� �B62� Z�C��H��Yn�7׸���u�q|��    ~9J���*����"�R?n�VxD����*j�M#N+�'Y��>N��ʾ�p��,5�d�g�"I�_	���("���o�!	������)RU�͢<p�u'EG��aU��G[`����U���;�'�d_�D�-�g����t�Ϩb剌��"x���j���C�=�
σ�&�5�[�:l6�.��n©2eTjN5����vd����g��㑯�#[Dw1��V=]���q�"��Ee�*7*�GT(�PL�n���,��Zғ���m9ݖ��q]Q������I�I�a��0폼W�Г��:Ag��ںJ��[�3�9D�|���1M~��J�(.�3�#�.�a�ݷoy��VE]��w���d;�PU>�v𝰎a�k���[r,m�y�]���tve]7Մ��Rgű�f�ݍ�٫�`{ ��.�� ��;��
��Z��>��]W�Q=!\q�Wq|�������4w�՘�/m��i�Az/'�5WK�5Q�Ox�4;�,N���-���M� ���9� � �ӆt/b�X�>��P�&�2q�FFHuYl�y��� <%,��7eT�醓�?��h�9s�.��D�.}��K�"�;c���@E�I��[�p�^B/m�q��6�mM0qx���Z���b�l�]o�~B3��j�-�_��D�,�D��E�9j�mΏ��`^�>��2(i:�uP��������aU��An;p�>�&�u?�e�5"�ٷ��~O��kx�����+���溹}��ل#W$i����L�X�����q�7��|)����s?���PD�m�B�O�uP��T��d<I�����.�y�i�3O��x*���+�P�;����g "�Ї�N��g�����ɻϏ�n��"�ΐ��D������I�ܫ扸BN,[�티�^��߉׆L������Ʉ�0���{.oa��bCFIvY8�����$��	���E.�^���`C΢µ��n�sz\T�B���5�gw��+��Qp���Y�9=8Q�Þ��r�lI�O�2�2�;�$.�v^�/g!����nOD�������_�!̣b@1)�B�=Y�Ts��E�	X�������!T���4��`�b�0�
Zю\���#YLO~>Jb_�Q��K� Ӏ&�g\N���w��Gf>�����@��ԛ�� BLm��"�^��5Nrh5�j*�����`�2�4!��8�		�xI3����03րee�����Ij\�q�;}�R��[�mZ�@9����z����s�
�C�`��P%)�|��[����4	��5K�"@"$�-.���`F�᭖a����3��:i�'/�u1�B�&�z�dIa[[���� ;���i���Q
	!}�3��g�'�4M�LƗ��/� Xpj/ڔ�%]���K~���SwUjz����N��Řc�M�����M�H����T��3%sE*�t��1��#�ء�3�䯮#3�]�@١YH�o��_�>�]�8�>qo��	�4+U�(KC�WUk���=k�ײ��#[Ԥ|�,�I<�H���D$�c�{>Bf|�v�W#�"���=��=D���ּC�_�^:V<Ex�l)-<�#�-���+���	����'��_��(R���{,YU�S�F'.�>�sJGP�e���L����$j��	�נ#�М�VVT���`G-%�jAi�ZuW:����X\�/[�3���2!!��@D8^�4�T�	Өj&<zeTF2DI� l�G�NxofTo2�����,��7�Ք	m{�~u�`K���H��Q�l�Б?�!��5�.���wbo��̂G�n��4]�o��>����+��d��"���y𽒒�� ���i<ئ��Q���r����y^��-��k6��e�" ?���Ρ`�ؕm�:%��}W�g_�O���
�y�؂f6��	�$	'�-�Ř,R����:~%�{)J.T(:�l�Ӓty`���F�"�j��(y�,��U�;�w9���SV�� �e[�4���v�v����kD��Qp�#j9�������#rE4�$jq����Y�x�F�:��d?�������w�S��EdX�0�=��>O"W�Kz��0�u�<&�՗qi]_Uǝ�j ���,#��G�e��A�ɏ�@ü%\�aBf}=�ȁ�_�lN{���d���g�����c�k46�J7�:�F�Ϡh�s��r�Tӟ=��tu�})�AD�u���d��?����&��J.}]4R/���
���*^�����^/�~����[�y��$TZ.��0�фm�M��f�eO���)�Nb:{苿�y>��5gd߃e�O9\Oݳ���Ւ����\h1��$ھXXz����Y�8���a�LI����7V�Ђ�<������K4��S9Dr��)�S����f,x���Hm�G��e���	��(���#�翉>�Ʉݏi�rF���⚲)�� ��4����3~�bD�W� 3�*~T����W��i����Y������"���(�91�ݭ��4�N[���cCY^�8�r� �j�g'��h��Q*��#��l��~ϵ�4a_�儞'��P*�,	~s�!2Qdm$��C���n��n����aQ�9:b��r#��u�yX���C��gob�*�9KmEK���m��݊D�� �3���������A_�5��H#��%�i����	�����R&^���S�x���{��!�1� ��*cN������+?T*��������ņ9���$.'�de�E�RBDST˩f8��*R�&�k�����K���z�h�y_N	�)U#+� dyak�?� B�luO��=i���T�����VY�ޱF��������"���O"QV�֝yX�
��Lp?F�ƃ��?Bb��(=�'N���y�'���dBV,�K;�`(*�pW�ހ��,�/ϻ�`��m<x�-�� 'I#�f�5�^���Q�?���r�Y����,�p $�E�V�oe'��+KxJ8��caIts^�B��#$���� �}��7���i�2�ܕN�};7莉k�:�����8<zew�K�8%�l�+�!�H{��-�]aX2��E�݆��c�E�?U����)�C�NE$J�-xl�Bi�q�A7I���E ���"�ڞ��d�FR�\�=y|�(�A\� -{�A��������鄘PP��Ӌ�cI������Be�NPA˓(W�~� �}��i�WD�nxl�Gb���/�M0��*�fBhl~�e��s���(�������9i�4����m&��b��@�FT��<	�쫭�!`n�a�b�bp�0�Ok=����������mT'���s��������^�}F8��u߉Z� ��T����|�m6�
ui4������d��&RJ���V)�zCb�̬֍W~%��vL��-ⵘ��l�y�6ɘ	�*�D�P�&g������v"�C=Ü��v0Y��`�{����n$y>r��gK�e�邚8��h¡+rG�ȋ@�V!xe�Ǿ%��n�I%�Z�\�y�z���ms�Lx�M���Yn�Og���L%Gey��.| �-
�n+�*���ӦOErFH��Xl5_c�Է���2rb�m�.g���<j�)���E��.��␂�U�ID�O�]S)27��#���qR6Մ��4�$�"�iC�%�v""��>�w�q�q5���H�'@Z�uR�D�"h�y�ͷ����L�Ga�F�(� ��]*�
-�S-�$��9��
={��z�Nm�2�Z�ؚ
����$Z��3Zl�g�R��y�L(�(1�_��?����;��e���	̆;z��5^!�@;	N�L�ŖB�Y�����	���̵�/$`۸�w[���R�|�LCiۭJoAVJ���"/��0�>6Y9aRĦTft�o�?���������"[3;Pe��/�D��$��~Gՠ"Y37&5.�(�p� �%�0D��[�3R*XG N����'��߭�`����՛!��F5ǋL:(�������@wAނ��H�GT(=�������:��v���|��    ZQ:�-j4G�'�L�{�ףy���9n�(eCf�R���%�k��&*��yL���ފ9`ҳ�$Rk��J<�Y,�CR�\N�d��\\eS���4V�L���%ig�ts�i7�nsDP=�i��/8�K�z3f�:��nB�JG,е�B���~^S��\Y���_�"L�ؖg�t�T��s���DjTx
2f�����]$ʝ��.�V+��C�p<@����.dU٣��/F�m�m�M(��,T�`A��{��m7����x��{��w����<�^��R$�f�����-բ͘a�v��Ja?LE�0x/o=�ul�]%��{�b�A��A�A��zW;Z����%�ؼ	PY/�~ b�C\�����������0���D���^��J-p5}�+�G��+7�����.��v�����Aل�%�8j�Y��$J�,��"7�|M��ޮh`ًz$��rޜ.��jd�<<u�)��̫y*����x��@�.,��C�l&��{�=�eGң�$�1NA���$���� bE*�'�����F�h���Lg�����phc�����n�M��?�&�Ke�4pC��������PWl�N�1U5�b��l��$m�	�C&������l���Ų�'���*Qy�E�2<;0���C����uք��L�S&������	 謧�{�q8�w�A�l�e�'5�S)k��鈀�L�Jł�,�?��I6ad�<5��'R�w��R��,5xêz6���:5�YY'
`Ns?�/��:���ILZL@�ۇ/Sc��=m%H�xb���X2�tuPL�L����vݭ~��+Lc�Q���5���|�SJ�K���臭��hҰ,5�%,�Զ���l"n��,umuk��3s�I�h;��N[��y�xݤ*�	K%{�KU�,��#��b��+��'5�guD����6�`��SRZ'ur�Eӌ5K]G�����E�Q��F��j쏠<��niv�U:ϲ/�ŧ5l� }�'�D�ޟ��v���7��ږ����^�u�I�����7��y�8��k6��SWX	�c�LN��� �K��(A!X�b��a~$m�N��y��&�$�N*6�nH����أx֨�zb�� �|z
I��%���Q�9a݋�i�2^��T����0!
�JdyL�g�h������GJ=�7����Uh(ȫ�:�z�H_78���2}�Ĵn�����i9�k�~�Pߑ����H����54��+.vzNH���_E�P����8EAp���G�b�{��A84�
�5��YL�~>nUfq5��2E����+�i��9�����q���H�T��E��LXՕhm��9P�&ihҨJ��7����e��͈�`����e�N�cW�	���'ED([l�1��I�2��PX�Q��e��.�C�t�1"�ی:�l�d�G죽�܊�+���ݢ�%�b ��HM�T���M"�ji�{����\@=�d��rT���@��݉/6�+{�6*/~��ӆy�-?�8r�����l��4m�jBp�<T�Ĳ~!
e���tr�n�E�`@�UF�Y���ܭ>��@n7��g�ѡ�*�D��̤Y�M��q"s�<���~�[h��sN��Q9�mE��h4 Y�:|�	�K���^?�9-�z��p�Ģ��Q��	����	?���L�kC�Ue9��D��\�F��wة\�$}B^>��\ǭ��=��K驟w-��G��+��)���<��FR6���xHl�����OʳGm=�pp�S�����9Tl�Ñ�%��A�'�GL���y�����
[�dt�a�#/_�9XL��/�Y�MH#5��{��g�,��`��قĢH�	���oV���IA�������4��ڵr��s�&<
a�A0��}{�_�l%-MWN�o�瑾�I�� 劋��(���U�����MN�P���Zl0_����n��Y	�/����?�$���=?���ĳb/+X�JY8y�6�� �1�f��u�M�D���c=YY�6��s<J�L�5*)4!ԯ^XܤMSM��+��>%�<�Uu�dT�i��&  �L�dI��x5!��<�O�dS�n����zi�T^?I�V�Y<!����4����m0���91^*�/�@n���=>��(X�ծm�	���r�r�C���I��?��l1?�<�u�����w?������� �BD�v:Pl���_`�e��pJHM��]8�0O�������ȣN��~&�������q�ۄR)�a\�"k�C�������Ql<�(�)�w�g�;K�9����%�XPAT�Al����e?�Ŕ�g�fq\���c�db��G�&����%����R`l�9���!�i_�ϡ�SQN��T[��ُ���,)���=tQ���<��n)FC�k�W@��I��99��%n�h�<f��	�sV�m9��▖Ic&ĭ��ja��iC�~,-�k����(^lh2z"˚���87.$i���
_Z�έ�Npב&v��D{��e�H�x��3�	Tv�9-x�?v2Z�����#7Qi\��)쉠��(������wl)"!���Da���u���T#�q(I���0c���^�MX���"��,o���~1:��5M�#��ɖh��h4��)�t獱5#�5�l��Z��,1���F ��Q�	������P�e���r6a4{����� 'I$�m�y	~!���^{���ӄ(sb߫��C�R�/&�1��GV4Q�N��S����<���4R��?E=���nD'[%:�~f�,�p�ҼL��O�hT�W'�$la~- =��V]N�|1��l�۬�jB��%e�J�d�F!�G:r�A����m�"Q)����ř��0�'\-�����2���ɳ��f�/rTO��B3�������|�`�@�s�m�Bm1,�7�I�jB����ZdP�0|7�;��l���DDPk�f�tm�NZQ�)Q�$��n�ɧ�X(�g�;�~�{�h֬�<��([�*4TPxꈛ���q}b9EAG��<]Z[�l��M��w��Zo��S�#�����jLN)w��zѻ$����~�A�.1t�0h}����g�/�9�G,F�T�yX� a)�#'"�WЯ��v�S�c��+F����z��F_
�8�	�O�F�n�eӪ|&� ^l*������YpZ����^nQ3�"����a5Y��b��MN�|n*]���t�@��-�x}��s���'d�2�� <�����Qс rb$�!vn7�Ik���k�-�I��uג�xl�z��:r8�'�������,���	�W��t��)�˭b7I>V�44���Ĩ	o���'�EC�ש��Y$����fp��%��jB��YQ��˂�\�������u���/���A������]��~I�˺+΃���##���#潎�0&{��<鳸��R�����ܷ+��2�`v'�~�>�!��U̢dQ�<�����,�M*BylԬ[|���Cw�a���m�O(�
3X�6���fS��&�)��T�2��2=#�s��^U��n�A�@�_t���6(^l�4�2/�<�p���$RD%a��V�5�����c�"X�* �����=P��&�d�%�&A6�V�͵�G^�����C}��ݹ��>N����Q~I��ы��mi/g�pu*�?(���y����]w~�p
z���'�=q�G�W���#v��Qn&@�|0�́��:R��]�/�o�@�Ԅۋ�8��m���`
U�~[_�������p�	|&j�T��G|��9�en��3gY�<O��`��?=c��ҹ�z/���j٘h�U�L�j4���$?�p[]ky�z��ݦ*�d	AůS�=(�"Z���f<;UOɕ�-a$W&�}؆���ŵ�Hu ������T�ᚴ@�S�|-ME�1�_�XS�DՄ%pT��؊�I|à�����O0���)�1:(Q���\*���	Op?�p9�����6���14Q��H�o���%?~}ܟ���7��@�zG�N�����I�.    6������?���y�]���`0����3�Q*F�Ö�
����*M����s�Bq��L��Q�ܭ>��A�j��I��>ar�wt���������S�����d��v@�7{!Ki_���^��i�+�5�z7�����Mk�	�K��#��?8M��"%�Ur���n[��,�=K.YA�o����
�1K�av�@�RtrAN�@����0�I���&v��u��>��ʼ4����+�A���x�m��yn�	����g�$�����ڋ�m�۟�8L�T/�	D͋dd��]�&�8�r|CDu���l*�EV��g'�b�b����������3�D��4#y�j���k�̡��v$�@l�!6�<���ص�s ���WEb��|BT!�ư�ap�k��JH]�)�!<Զ���?w�PPbə?�H��ʿ�]}ٴB��"Dv��l6���~]<��E���4
�l|E�vhB�C���C�B�8Foخ>�-/�0�+��������rc��F��-/�	�ӶqBP��8��������N!j���Q�`Y:Ёm�- �He�L���-G�=b?��n�l�pa���0N���L��WQ��w�P<�^���䪒n�;�%+�O�9Q��`���̲f<zVk"W&"j��i�5\�[)�e3�'N�~����l���K��;H���EeKő���$IdpǕ5��jB+t[�m�-��
�|2��~Z���������a=KUB�Q�s�o{�G�5ْ��6����M��ӆ�iz'HUdǀS�����;ե�p({���%�Tȶ7i��!��AQ[�(P7m����FK�Aq@k���M��Gq����,�?W}�j�3�(��R;/�/�[���]k
� �S�-T����tPf��e_�Bi�BJ�4�DaY�x�;�6n�m�E���-���CQ���X�d��m ���R:Bk����^��<;쏟���`��0d�����^�'�Q���ܻ؋Q����Ŋ˃���S�{�k[@�u�z9]4�~�,.[�	� �d�0x�"�8��)��6�*�Jn���Edbi���p��CM� Gc	?S �1t����p���ڄq �rut�R��竂�.G>�wW4i���[�J�NMp�rs,�0�>T'�/q^5�8x*�d�$�ކ]P��]��Hq,^�$~�f}4!�&�����g�/z�<t��P�)_tcDn癌����hq�\2��q�O���L):ӕ��,�D�w�,d{wu�P�$F/(N넨^�h��edZ.��Mf��"�}P��Q�w4���J�vk�Y����l�}�@�жi5�j��q�!ڋ�k�Y<�����k)�2��7�g��u�����=uI�i�G� �Ak��^�;��'���(K�m�$�G�Rs�K9�\=\_�����ɳ��ћ$��O�$U
M�R5�����P��[�u�IP��*r��an�b�q���&S��f�b�Y�%�,�Ҥq>���$��K4��Cu��wj�n�Rۊ�6���7��x�fR@j�uC�ҥ�5	��(�/��R gy��.��]��o���>P���[_?�]�c}��b�a�5M^D��fF�Ѳ"pH)�f����G���s�C(+�f�@��T儈dI�����HGh�9V�	A���%�?vߎX�9W&��`'D�ջ��;�f|�)+�s٘KȘ��n/K�<*"�f�MZ�~߂�-;�~�t%��!��̼���)ۺ��(W'{�<0���`�Df�>�(@��H��DG��7\4@:��<��WZ�)����h�&���}T�����v;S&�tݵ#��O�Ӕ3An���X�����j��?�`C���&J��-�R����e���~7Jw�k
�ڱ\����{9st%>�۫�5ye4y��'�P[��[c�3�(O��xϿʹ���^g$*M�@�u?��q�z,�[��:l����p*�y9�#��?<^��+�O�	���a�(ܝ����Sw�*K=��X�&+�	��n���� ����$K7ѧNG���_�-D!��]}��D:<�	q\�97�ɴu3���6�ұ扎νd3/=Nù\�`�y�0;Z��MUX���q,�g�mxi�&ioo��0�����@@�M:u�g�%P���T*6;�h9!��x��o�|J��4�EL�߸�����6��恨m{�@DQun���q_�=��`�	+	�"��b��j�2�����0�<�"σo��s�$�],��s��L��P&�A���XX �~	�"�Å�	���*fS��ΞG�F�!�wRF셔Ǣu@E��d죪���ɷ�U�G"b�����c7G9.W[س$���/J9B���G���s͊�Y�ӍJ�Eɶw+��'خ9:�H�/q)��e���g�*���o�ĥ��6���r}^0����z{���<��K�yAdE�%�����W&q9��M�2��An���Ab�2�u���ݝYy��#AL3E��ey���͋�+Ӱ�'D,�"�����M.>�ܩ���@o0Qr�xm�ͪ�A�(
��3�vͶ�.����ۣ�Ʊ�X�0�ʭ�� ��H�M�TD�].5��A>��b/3F,��dJ��X��"
�x�=X�{k�D�?����dOJV��z ��X�9"�,�nC�UU�.b=����E����%$��CQ&@͇�u�E��a��/P���noo��<cҼH�������Q���h�H�0�RC�X�����)��'�\�E�߾`N��(��HE	B��I�D3`\��)02]j+OJ31I޵i���1eKR��
�<9�C���+��(�IV�
���[���@BڠTa[gQ��E��������.n�i��d��uT�]I�*qЉ�Y��a+��#�mE��!e0F��F ����Jz*Z:(��!jl�j[7�u��k��0����/��sB\A�R�~�ɱ����c6��
�a9g��UM  ��I1Qd�g�VH~ ��6o�j7�t��o*����~B�LVh�Ƀ�heGj��r{('�Qkc ���x{ ��X�m�y5�;��Zt�;Y&i�i���R����b�hāRrg��N���C��.�'�"��:	�	��e�Оp�y\?<b�o_�� ������r޳і�>�&����t_��[��o��{�~��h�<�X��Y�U��G&�3"]��Rǧ"*�<`��/g4�]<�#V�q7Au'��Tw8&~�K2�Z��	���nѐeU��aCـ����D��Ҿ�p?�8�d8b��I��Z��Y��M_w���km:�o�Vp~$'t`��M�%��#	0 ���#y�:�U\�Tb��T���3�vG��T��?����=2�����m�����G�Y����_+�m�9��)dW5B7����gk����'�WYj�=!i�-��н�+Q����WV�X_�hD�e�\�_",�o9��fFU�E���eq�:e�S7��*�Q�x���i�X�w�/���۴jo���OW�*�vJ��Pu�M��!vK����fR���JV�!�^�-Oe�&�'��Й�)�oض9��k��
)��Ji'أ�[m� [�Q����At�=��r}f�K���<w�L�j��^�I�o�	�n@Su���,�֞�_��%%��4P�O4l9-��P�U�eD�3���)���o/��Ua�26�,��(7��Y�ޭ�n�LN ^l��g^�ZIUguNgQh�_��o�ӓ�����/l:!�!:價@��H���셑�nX�m41�CP��h6bL՘pJf-��_F�:?��ݷ �+��5���|��J����w�Z3��"�Pq�el�u��p=�[����x�#<�IRń���V�Ky:O�M�ƈe�:k6�����	[�<����2	T6DD��j�n; dD2���m�����6P��kuj���mb��y6<`�7ٔe&#�2~�\u��ʹTxv��J"��**l6bϔuQL�����^	7B��A4adf	a%��8��!��$�;��Pi�c�(    '7����ʕe9���H"u�LQ�Γ$�֪̃wة���ͪ��\4R����-�g6��t"]`k9��lj�5@/Մ`��{Ɋ�ok�t;:+�� ���(��~��oq�<��!j�����%>��e�Ӽ�&䂴�������;@̾ؐ5�04�y�8m�Zm�N�� ��m-;]�R�����[&�aքѭ1��"ƒ�<hj����K��B�)�����(gԋ�Rg&�'��LI�e)�˔�2���R�PN��#E�~�Q+3U\�t�J��|��;��yQ̑��f^�e�7��}���4��i�k(+r�6��f��̎��J�8�<@U�9:�AY.�E̶�.+'�<�(�XE�^ENmh�����IM�Է�Zb~�I����x�ө�ɺ:��&E_mq�u
� ��T}}��0:��߉���hbdH�G���M_�pu̳��ʈ:�w\q�M~�;!X`�!~@��T1ƣ���J�>n�V�����H�vv`4??��v?��G���h�v�R�R5����Ш��y�Ɋ�*��Ğ��x9��\�����	��(��ha����v#�3U�鱋��P���A����%��V�շ��0���=Y[ͳ�����o���&-��V�I b'R��������^�����`kǦ^��؂��(��X��fB�Uƥ;wi��"����W��7mC���dw+�{�l"<�)!��Fՙ)�M��G�;<����\N;c6�1eu{x�ek	o�_űJ+�=�M>q8��V�,���_F»�R����ٶ���2qLܓ��G�\R��$���������Ju��J�,��b$��tZ�>���EL٧]�U�V����B�-A�G��ӜT�C����P��u��0�b�Q�Yfb����Q�|tZN\��_b=�P.֏�V�6Q�N ��w"�4[���^����:$Y��_mو.�4;^�����pnR{�8�,�0���h[)��L+�8�n���x=q_����=w�7Wo��Cv]7q����;��		6I�����F�R�(
�K��9M������8�hg�O���;�۸:�"��~Bw�������ܤm���0�wO�LƁR��ְ"����]�>r��Y������3�*�r���dy�9�S�	1��=�=��E�짵���l�ͣ)H�"��P&Q��� �����-���b���h�MWv��]����R���m�A)򼴕Z��sbQ�&g V�bt��d��F�EQD�'[DY���űnf0\�V�8]�N��W0�v�`P�=Ԭ@F*��l��ٷ�Z�[n�}`S&��:��6@z�('W|�Q��E@��p�Ʀ��> [�c�|���H�q��<϶�n�"/&\����"���9��g���a?�j>�y%�
��������^u�xޭ���&G��7"����VR�W7N�p�Z�݊"�U���@�.��|�Nts�U�yo�`�.1ahv���#�Ѓ�����#S`�n�%w��� ��2�p{��N+�p�F|���Y�l��<�;D���%N[�X�>����<�P���[ׂ�����;_+s���񑹊5��D����c���z)9��?���G"���^,ϗW����mn�"�o��_������8�#�������@>h�rBo��R1ڱ�a�e�u���:��H�J:y)�g���@:e�"|��k��f��q�\B,M�������i���8�:��h�e�<y�M��l�A���b=Ve��Y��mX�ܷLbC#�8�{.���Ok� ��f'��\5��z�bw�.��W� ��~�m�&�pn����L�7'i����:����@V���Ӊҋ�?д�����I�Nп3��h�)���=F�5�/a��Y�T��V9~�Gr��z���H''�U����mZL�4���Xe�1P�{���$]�:بU�5�F������b����^AL�:����M�s9���6,mf�	DS����Wqܟ��J��k�B��*�`m6(�c��/]�9\?�c�l1���p�m^�Ʉ��^%��E��rp�[R�F���H8t,_X�R	 &G��ߪ����*�k���m��k s7U���GYUm�#p��S���%�ꐮgR��->`Ȅ�����#Bd�72Aĕ�9��i+v�Aq."-Xw�=G�h�O<���G���� yEu�Y���NV?s�K�2�вv��=l�Dˌ�s�$ۡ��)7�'�E�Z	��{1��l8��D&�p�M&���f���^G��r�8�[�I���Q����#�L����t�P��	ABD��P$s�M�2�'���/��".����i�Ih��Q����Uy`P'.�o�S�^'f{gæ�U���>M����s�b?Ϻ�Fh���<S�X�%�irp�#�a�ټx��L��'�x����	�2��R�])#��jB����m�R�l��4/�n|�°�f�Q'Q�5��8�4/u�e�8�"����(���e̽�9���rF�t��ac&�2N�DN���-7.���J������o$�����T�Ij(hs ���B �!z�Y��&j�PlT��8l�)dدg���~�L(�K����M� �z�F�ʝk���J�) yL��j5+�rF�sa.ۮ��۳�=n���I��Hu�[c��#�55��_|�J�q�'�;�x��l���o�����}�L��{�y ����+w���I�ŮnRiKc÷���h��&�[ݚ	&�}��;�t���id6Ŗ.�M:!i&eR��̃_����i�.�[�b�'�:�3�Vo�얐oy�#����wqO[�7�&6)�Y�Ƴ�\��Qg�m֝�Hc4�$���g�f�5�\Ņ钬�'�R���)1��t���+AW�b�.K�nx 4�	��0�Һ0���e��WTBS�z�O�PርJ>b=�q������_��:6ymu|��  -4}�o9���\a���'���"������'��S�F,�����t����/�"J�	'�(Cq�(�(x{�:�
m����:U[\�4\콙�ؙ(�'���;q�S4��N������|<!�IP$e��Rmw��n���eZ�2i�&��A�8��]����b�Ot}$I���� B��G�*@�nn~�0�)R"��`�:@�y?6��Py��N�0���v��:�̈́�زF�S�?W4t��(��e��F���>[{�i^,kl�_��K״��"6\Q�z�TIZV^Ɯ؇�=�'�X�G�͠
�5�VF��r?�5o]�$��3�0��PJ�>�F��P���t�zӶ�#?�*%�ўi�I���>�Z	���Nth�
����|#���mey{p��(v65}�V0�[��\w�6@��A�I;gO�I<��U���$����pj�"�*���؄nX�x
��:���ޯ��A>*���S"�|e���Y�*� ��Qc��+�����	��Yk޴��U�/�_Ь��U,��X�	%{�+{����52I��"��
�4q⹵ɤ^��?Rc���a�K�Ѩ��Ci���rX���i��L8�@�h�)�/�PO�
��#���`A��0��!��ʨ���O�"��y�`�N8Љ4?�kW=��LN�x��F>a�_N�����A~�m,�6����ǭ	'D2��T��,
�3�V0Ąi����BWpB�EO�;|
�_Y�Oä�P��iK��Խْ�F�%����/H��#GQ]��V�D+3�`�1"�SY_}��݁T�s�e��]�t�"�5dq�2D�x2�{T�,"r���5�D�u��M,��Ե�m� /1rV�{��CKM')�vC�������FHT�_�QEF�;�e�z���t\��G~������y���Ss��W
5��,�r��W�޹�
�_М��OGqS��"=�ܪ�9�7�g���uxʲ���k�Y^-Vj�W�L��,	>��[JF£���*�f���$wU��*�]u�5l9u�>/�rN�L�۟:�pOY�{@�AF�=�穞��s�/]D�Cn�v��?c*R��Ÿ������4v��Oy!    �<�z�N@9�����7�!,�ra�m~%j�E>BIE{�Gg��y��ڟ������@F�"ypƲ���/�f��p�8=�NBQJ�w[���{����Dy�T���#�r���C�2���Wj(A+uG�.�J��)[ml�v�/��E��A.u��e�?��]=@S������9�;Ryso#��PZ�t-��r:�}Yg��פY(�,�v���	��	?Ta*�}���r���7;D�N��� H">�j�Db�e�(zS����LFi�Ǯ��Ix�S��r_��L�*�8����3����՝�4��:�(�!(LZʩhB��a�Z��;w �&����f셞�J��o�.�CK���V!2�iFn��플 ���Y�Ml0�>�Q^�z&3
��P�HŢT%�_5G���X�@q)K�m�䔸!q)�0&�5dA�M��-WK6��A�-�^�6����C���_�B�{5�w��~�q�Q�[�7�* `�	3.����aQθՉ�;Rf�Q�	=ՎB�d�N�x�"�G�2�+�bG:_3?�e�M\:�� ���Vq)�	mP���:J�LL����(�6�c%C��E$���"ZA��ϫ�!7�[q;�%�xy�ڦz1�iIt�d&��4��'O�ߝ��k��At7�W���!���^"���m{���$�����X&��,�qa��7�:�4� iv9��0|RNOh>Б�>�9�N(��&��d&L�.��o1}��r�［<&7�?�Ͳ����6�=�g��V~�/� ��z��"W�a3#r����P��m�!p�8��r
�ΔM	[{)F�#j�H�xr�E���1�	ˬMf��>���z�xD�W����"(A=E�e=�[ч�2������W?�<��i�ח�9������nt�V��j�Y,
��T6��-�+�-��7�'W���d�͟ �<�_b�t�\z���]�(͍�tE����忊�n��7�l�<�t��<T��4�zH��<���1��������Ql(��F����q��@`�qq�B����Å��F��{���L�v�ו|�ϗ1ak����vڡ^�"��z�C�0�S1!�z����'�>Rnu�]�#��f�n)�	�.Kg��i��KOQ$�։�1��N@[�����j��I����ք-�E�0i�9�_[��"��c�՚�'s0�OG?�նb"~�=��F@��5B��̟s$6QT_o!k���X��E-�4�A�r�h�������:��/4#8����X1Q���s�v��r�]����}ê�k�A�����s��=#�)�l�=�bW.�����Gl�w����κ�<���� c;�t�Z��}���3�G+U	B��(�Rd e&�f�����w��=�}���u�ut���~v��Y�*�������(�)2&e5���Z����f��e�DU
�N��R<�J��B�#��~{�������  ��`�I���,�g���߫i�PF�:��.�j*�����L��� 'adt�Y�������`Y�RW	�GU-!I�����$�Ο�Ijy�1� N�H;5oZ,(<�/֜Z�G���A�����N(�XA�+)T��$.�h%�?�P�9�!!���ēW�T����}�l�N�M� ��܊f��Y���W_���D���w���)�ت�DZ�T"�4^��χ� ���p�̋'�B 5��o
�(=j�O���H,t����&�	�KV�78��i�-�^o����tF�
G�)c�7���e��VF����/)n�j����b��Eo3&�|��5n�΀�G2�u�Y&�~W� dX�G�'�T�v��t����P���ZhA���l�v�n�^l��F���!�+ۨig�4IRݴ�i�:��N���kQ�R;PAWQ?D�d�\�RW� e)x�����1I����,L�B���;��?)���*MHTڦ۝P.��`K���/�fƳ��X�we|�u���G�����vX:���.��������\2}��8׵�^~o�u�^�j$��1�j�E�NZ��w+f�l1����zT|?u*��=��DV�l�W,��|N,��q�aHYB|�{�g����`��� ��%�����[Dz��u)Զ��g�Z�m�E���P�I�BZ��K����-�A�6�ى`�pQ��S�	�t��4uO��wy�&N�p�.?��&o�|],$H�=_`�7�-�=�i��*)37�5����l���BO��;�Ñ�����G��f����9����50��x�����8ϒ�m�I�. MP�SQv�;{H@�������v��"E�\H�ټR8��"s�	kC,�6�2�L��˒�ւ���"�,Ѹ&����Pfs)�1Bbu&�w`>�뙘WUv=�^P��E�w1C$�XX��a��͈�IU�ݤ��sMi�˰Ĝ�f$~����j��Y���2Y��it}�M�"�4>Y��dY���fi��(ҙ����Y�L�[��T�=r�@K�0���q�+B�^/��ĵmg�2�5���&-Ha�����n6p��x�E����,�_�?��ų�M�d������$�b=pE�Gf�/��{�ЉsA(a4!c�u��Ot��JF'�������l�Ĺw������{,i�=��9 ;�5�T��8U�)��p)���b	&��&g����,�q�^��!4H�<N���s� ���/�0�#�_E�SW��nd0�궷�G?��0�,T��-c8-h�g�NO3�~�S�%�	C����kӰ�K��
����扅)���yA�pP���&�:G&ns�]?�J�0te�e����ii���N��FA3��Ȅ��S�xV����X1�c3��{t��1�#
Yߍ��.����v`K�A�����z�����qh;^���s�G޽?���`mC�l�z����ïW�(�k��m)�B��]2��M�LK	W|��6�.Yv�-W2t�?�X]j����+IP!����8�eV�.V�%I�3ޭ"7��)�$����T_r,܎F� q�W�mE�A�0�=�D3�>�Ǣ�d%�5^�Z/�s$i�Θ�e��z��� �6�N�쮂0i (@M=�o�`�dd��Q��łS�)X���ް�3��l9`F��E:��4��7�q�_֊l�m��<R�G-�̇^����@�J��+���a���H�R��o�y~��J��v�I�e3�f�)S��a���Q<��En6o/S���R-�n�E��h��!���I
��o{fFP|eX����f�8�B�g;�ի������-STQm'2����w�IY4���<�b[J��@QR�8ީ�mº�fl��N�M9�P���Mb�v�7�L�;g�Wj-�%�J��~�"q��VQ�j���y��$!��N�ح��Xl3i��z��[���(�֐�@�"�\�����V�<�=b��Q���ۃ�ק�,��L�W"[O?�����-qj%F|����F#��d����1I�R�e�ů�a�ɱ�{�T����H9_"� ��<P����;̞X6KC�H[ύ%�K�!V��qԆ˄��9�2-}�$������%�S��-��.r��h³���rkɤO�hFJ̊$�G+>r�.����|�|�Àv�5[`x�~m0|�R�F~?�L#��|�:r�z���Vji�W3��Y��^���S�R��������IW;~K)Hlt��)"a&�Q|Vwh��E@I������Jڤ����X� Vl�W��b�46��Q�&�#U^푃:e�?��S�H: ��hj�iv��������ĉ`�x��|=��Ri��팢�,B�E ���8����:�<��Ce�X���؈.͢��q-�`�5���� vh�����<.p���%G@��ո�K	\A�?���al�$�(��.�cw��x�)����c'
�1�Z�L�2���jo�'�"Kg����Q@@���wXJڒԱ#�I����:;�� Ϋi/6�    I�2���ϣ�>��8x�u�O2{�b��<zʺ:������/��

w�a���#�o�n�*v��y��w��y{�s*&�T{naJ�R��֣��ү/6������(���QL�����!��[r�y��^�����f�
��� �2�z^c�����݀ 2�oq���p�����)Q��H���(w2�V�3?���Y�����˩��l�W��0hm`�3N�G�.k1�qj�2�~n��y���M������6�ȋ����+{�. *�6[{�y�p)�Þ�I2��	`W�C^n��V������p"�]����s�w���]��������I_���P�f�LV{E�!���g��4Tdhg�?:�>�q������[�Um?*��n`����GŗX��-��Hۤ�1ɳ�V�����ij������~	�j۲��<Z�re%��~8�t�ձEQ����[\9֞(S�t�F��ժ�ŐiW�3�+�}߅�]�Ep{&6��mi�\�.֞�按�h�Jo�\�,�p�hZ���p���gI�I��"�2DLѢd�\���O
#�h�	����z��R��,����N5/bWI�����Nr�=���HcxL<��m>�B����,6��l�UϨE�0�%a�3$b߸��D9�J��.9=}Ǭ\�k��#9��)��D���=���8���Դ��d���H�@�*'@?��lI:�P?�n'�8�5��ϱ^��� )K�fN�a��%Ӏ��o,fU����ml��x�8̶��x�z<d�tv��(�NH�pYT]A���G[m���̪*�>�E��D��(�����Ui�o�*�w�î:�����0��i^N6�z!|�z<ϥ��Y�%���FE��L�����q�FоR�9������@��ܣ>�=��=�w�*��>�9Ύ?_�.߈UMEk<���������Q��H�Cr˱P��s�ֺR�����j�U���E�x�PLu��6�݁0*[���*��G��s%K���!���mB%�0�����O~�BN� �&ZKQ���l��p��<�4��R��+��Y4�q��@4�Q{R��ʇ�F=/�4n��j{1����t�"�e���,P�Ez�;��i�3I5#���e����h}92w4�!���-��c�1�P�@���5��q�S'I� �*f���獴1;�T*Mp� "ǟf��]7�z������J��CS�n�J���.k�˃2�{h[��|�aFV����&�JD����k�(
�kC՞� �t N�a���H0��B��[��rM�m7�*­�:��w�f��EX1T����f��iw�=%��;���YLf�j��UۂQZ�$���x4ܻ"�P[�z��~�a�A��S�
��S�F��A�b`Ve�s���Ѩ�g�O#�uO�<M/~��I�ku+N��R2�����}�j�V�m�w�pzd_D#Of�_l52�b����L5�\�@_I���CwSe��~�#�+��?���O�ۦ�9n���qڄU�\���b�!iO^��(�ߙ�'�b� U��x�e�g��QmA�:�U��*e����7��Q�� ��Z:n��� =�e;Gy�� /�uu�$R@6��+��r��k89$.vX+��j�	K�/ִr�mM�,v��G
� q9V�.��5]4��Zd�J���	�/I�����)�'�.�����~�_�6�8�;<��)q���?��tՐc'o N3[��]-w�ȴ���Rf�i���r:��?�[Y��N|�˟g}��y��$e��Z��ð�&���^)x� �v�3��ì�/E���e����	9������7�x��}R��qo:�i)j�S��l�e@L���<(��'�e��=�a�~�y���T��qP�:���ݤ����ظۨj�%~�_�K��OG�q�+P62��m~06���:����NW�X��$pT��}��)�gޘY���5%9s(�68���8���Ena�՜�s1D/�$xK,�za�f©�ЬAbh�G�y�QA�����ʸ��912�Xg�i*"���
+�۳M|0�}�N��>8 Ǩ��K�B�*W�:���X�c1�B�4�>oA}M�Y�j'�'��DO>�Fk�� ��t�+��9O�p%��"�+����Nܾެ�&���X���A*��2��u
���gD����91���R�N�^��\��}x�h��B#J�eZN��?�t���*���HW%\̓��L�.g��D��L� ��b\����8�e=)�%�+�3о�kZ���[���|>�⭌�2��̨��8Ҡ���T��j}����b$��/��6��/(,L͹tI�&�������JCP(���|��FgZ؀�]+�9��A��ZQZN?�r�3�dJɆY��u��ܟ~ػ��O�7����4g�a�! Z�#ګb˝�:�g�U�sʻ������E#^���A|j�z�Z�T�^mN��g%1�1��R��ˬ6�X��h�����r	h�Ƈ\P�[����ʠX=������m�=R֨k:jjG٫3ʊcTD�'6��9��|�?[K~����� �~ay$�'N=��t��0Җ��=*�����n6��`�#j����rW��M���\�p9�\���'
E?V�4}�҉ �x�n@*J���u�1-�Yգhe�^�#Y����v�eD��s�ƫ�۾Y�x�]��8�y\*D2K�_�4��B�ۛ��9���Ѧ�+P$���P�lL��D�#\��Wͻ.�!IV�&J4�d��Cŭ�j���r��Q=�fD_����X���X���e�jЬ�rK��s2q�g�����֭]ĿKt�^? �eB8��Dn�*�*�/��$�>)s��E𲵺��$����g��(,f�v�e�<Rh>%4�`�u �I��-teP�X�&���I�2q�u4a��(+����^$rJ��qm���0{uT�������m��Q�
{L��b"(^��l�$��J{{��3�W��ߟ�*�	$)�9l~p�%3�R��<,��Ծ����L�e
��m��5���y$KrQ��
������ʀg�Y;�γj�I��s�����q�Uk�Q��#�rW6�����0Ql��D4���������l� q�Ϳ/��[���o�=Б�ve�8��P�ø��y�c��"�&�fO|ܬ����0���Sj���,Α���<��4s�@�7H�����������(5����t��@W޺�%�]^/{��P������X��">aR�
ɯ�?�U}l�9����X\��콒FX@�24a/2���0�J�R��}Jv
�@P�wc��\��+[�\^�(%o[*��Rl� �Nx�;���ݚB�Fł���*<���g`��.���2�H��gy�x?��o�45��C�MwOz**W�0W<>ÈN�$*Č^����tQ0��R�e��z�_������S'�7��(O�lq�m7��-��G���,���/K��q*�h���oȹ��G��d%1�n$A����n?4X�6B���2o�q�������f�VM\��$ �Zp���������G�п8, �X\*(�o�T��)��j ��&9�	��r}w���4xe�`7Ε�֖ji-H�N�
`p]��[ў�cF�k=��b��E�v��+����NY𞋲G� ���FMݤ�����j ��d"��,fp@�r�d����r4�&p��Xz1�i�ꌌ�J��8��WSͳ���eM's�er��͋���ى}
�bw��#��,�D+�t��)�s���^��<�\ΊZ�&�]�}VS(L�YDȱh봜Q��y�P�b@�řE8
lb���X��W��F�8�"�� ��rz���ϸ�w1L|ѵ�֦HJ��&�P1Κ�T(MŤ���-��%�%��
�u�V�E��;{!�"��j��b$עoM1#�e���.�;��LH ��$�ȝ0f@��j�/���5:]�ȼ���݅K�WG����v}9,F�۞57z/�g�Q�E
�7��IE4l/���5��9~>�j��Rn�d�    )�G��_��ê��'jBų�� Jj�	Dǖ����ª��15wHg���������/��7�ϐ)���;�	�{�i4��ᦶ�0��S̡I4�7��e��e��(���ci�\�E܊x$�(��?��8��� ��$�>v�[��\��Fn���e\�݌�o;�H/~|�ӝ>|��(
�<�~o����u����9�K���fZJr)��)��bͮ2	8����c�h��Ζ9�i[]]��hDI�����I�J�8��2� �d���q��#ܺ��bmY�	]��_f}{����V%
�)��7ֻ�A"�R@��e��$�7�h��{���H���y�$Г��c����ms��b5>�r�5��5��'a���E�:l�8�j��=�ګ�EoPr�K��&hN&��jJw�#����ֳ�_
HZ�&,�q,2͔E�^�c'آGl{���o0Ia]l��4GÐ�=5����b ��T��<2(Ig\���lEX٫)���]	Z6��8y:b����ێ��z�׋�ʪ-����"қ	P)��t�%R�$1P�O6TAt�vqֿ:�"c ��:y5y
1{~���P� %R�j����G�B�����2|?�5q��X���Y���y }h���D:��澲�А�ëڨ��%A2��^�������;���,Rhc�(��Q{�Ŏ�bOܺ��t����A�7��^�
�-�X��x�߲�@ì�oAd��F�N�ql˗�,���f[[4Ĳ�/���N��{��He|$��⤁"����oiU�@���)vI��C���f�tF��L���H$��]��o��`�&��"�j�uZTh@Y1z6����QžL��^��J���I��n�V{A�]��������h`�@$dV%Պ��j���>-�(�\�o�$x�p�Nk�-L�an�;!%���5!����؛�h�upiJŏ�i�U�}`�w���|[�j(43���H6`�̺Lٜ,"�B�X�~�����ӍQO9.���~�e�pN]��\k�۶�,�${�u���~1T�D�B=�|��t��v��3�x0!QA���T�ɩ�2e���N�b8�U���,��p�R7�D���W��؎���x��]��5trjH��]  X0����N���d���� �k��igdSd���,x�ɥ���3�����ym���f�[�-�K��y0U� =R�Q��SR���3�_h"49田Q"��W��I�R�^�K>6{�Z�&���q]�Y$� 4��[Zl�Q�����'7}þrtSC��kf�Y�,�gd�(�T���>�$���{��T�����͆�!�gAܮQ"O|w����-@�43N\l�v�����lj�cM
w���a@,V랖�Y �3c<%Y��τ�?`�W�N"p:���Z4�b�t:��4�y�-5���e��x��Ğ/�M�'O �x�'��7TEee&�G�_M�>E�_�ڎ�S��i�D��a5��/�]�Uk#�ŉ��8����I���}!
��5��a7�����0Ǒ����
a[���%�Ӫ�~��"M��>�)��q��R=G��G�(`
 �TĴٔ���".(�]��e�L��I9#vE��=��`6�el3u�s>bd79y=�uf=;��]�-�hFX�Te(�/�:@�����-�����*?��~V��`ag��`KXHeQS�ϡF���7m\���]���O<�24Z��<�������`k^I���6�����6x�e���e[^p/0܅�Ԉ>�lA��GtW�]n�o��T3���(���U���Mu�Z���u�.;[/uD�g]~���N���A�X6�z6�K��Vao�<��Ht�k��'8�x4�50>���
��D�;m`������O`���q2�Z�ݥ����7��8���M��^�_~d�ƾ���O��{0ԏ��Gz8�gn� ������k�����!]o�S�E�LH������bی����{�9��4T�����<�^D-ӎ觋�O,ž�6Wy�یM����u��*T�i��TGFT�L��;LX�Q���WqA��7�T�PeTV�j�:+<�1�.�~�՞ͼ��E��U֥���47@۸8Ďc�4P�������w�Z&��*F�:�V;P|����bL�*o����B�d�Ⰷ/���H�t��3kϓd*>z&ܳn�Z��� mUti2#Ti\$����d��rn�K�C������EK�.�!1*F��\�V�ܐ�*۾.gD�db�k�Ld�d�C�� ��~�wN�P+�;���o^�Jn)���壣�*I��G��J}���y :��\Slz#���D��D�}wz�p�Y� j뱭h�긟���O��+�� *9nq?�C�����K[v�v��;�!�]_���款�Mm���ȡ����+�/��-9'�������=��e�쀝Ga֓�1!d���;��@�p�c8��&�m1����ra�gB��NQd~��xdkL�9{�ΔY�l�G��[B�6|����b ����9�,�X��(>(�S(ImG�Hf��̘�1P�E��1k����l���F8a��A�;n�S��xG�w5��妬U�E݌4b�D�aE�_Z���qq�[�o��5A*�l.9��H��S-F۩�0n�/X�0�E�Dq�Neni��I ��A����k������D�O{��Q�p�h5�bF�u�F݌�EQ\�K%�W�ҋ���P��F\�[�n6�:��UO%�{��v�2��:)ۤ�#�����@tD�4'<G���g��o�*uX *�pl�Tv%ph��t �e8����#-V��ie��P[�ɰ$ʂ�E;>~�pp��w��mj��@�s��U��=r0���,U��YF�O��$)J}���5x�t��PfR��r����K�t���:��*>�j ��nm����5\�Fjsf�"�t$���21Bg*L$�{���I���9b,��!z���/.V�a:e�BV���`	qw/�H��z�ʉ:}؟Zs�(f�A؊��$m�/2��M53NZ���>j&��p���� �6�� Q���Q�0����?"d�ZOۂ!��6���4N3q|���JFs���`�چ$��l~�N�Q�C�ټ�`]���aR)?��E��j�v�����>�~�Q&R�&��W��p<tߝE|F�qł�=R����|���>am��E����0���KN��F�j&�������u�Eg�M
�{H���e7��l��{���Zy��b��x�G�j�-vmF�f�d1��ʦ�A��ږ���Y ���Y�ײ�w#�'D�i݊�l��_0�G
��T໣�� Q����X���C�?pL˘����A����N���]V�)7�c?3H`��:�	z�����1]m��_=� �jG���ۿsuv���q�����7p����.Y���P��v���=�e��8	�����D��H�L)w�'e�L@��CX��v{"���o�%س���J�O���pm�IS�}X�3�N��>E�k>�{F����=[����H|��mǩA��|�&���Ij���wM���P���ڞU�,"�\�7���[�z��T�s*�׏`�ȯ��d���hf�����=_9�[��&exm��~z��f�������"T�uq˙U�ʪ�1�J#�R31,��
�P�W}����o6Lac8��z�5eE�����vf�m2��� ��֊,��E&�Me����4�?�^c �Xz���m�HP��F�g�	�ӊ,,|��0΋��,j����؅fZJ�o�"3��y�m(6�Ek L˓p�;��P��zx��5駢��m���Bb��"�1��rò�L\θ��Vn�$!��J�R��@���+U�ծ7�����ik���g�UDҼ|7��H�ؖ4-SM'�����xv���F��ԧ��]GQ���2��B��$�!�Z0S���@uV��90C�p�d�~s��D^�|EG�����'�A�~�$*�V۶�At��~��R��*j�P�	Ǚ�Y�M��y��F\oÇ��ƭÃ�    B��7`�¶�RS���ϺQv8���kf���.!�O��I�ڈp1j}/���g�r��q��ZZOxFA��L'��{��� Sr�8���������#�p��dc����Fr��e��$�Y�tO���۳��T8����fl���;�X�ֹU��څ:�����l80��j{��J�u���ݴ��\��4����3asj��e�����m3TI޹���Ca�$/��4Q3��a���$TV�I*�6f��H��"��)���<���j��M��6��sF��P�.I�+`7�"mEX��!�M�(���uT\���^f���+�|FybFm0�"x��Fa�8�` �M�hL�<b�5��H���_m��%��xF���X�	���P�,�l�����d!'�sTn�g�X���*[�i�����A�"������2���,�1&�+mv:6�Q���T`�;C�f�z��Dj���_v��'��+Eɇ��*�JG��Ȥ_��jnD�QlQ1I$$Z~7�dBNH5%]�\��i��%;���kt[�Gq��]d�9�Qjq�
 �\��U�R]^�2�:O�t�LH��(�<�Mu����C1vr�#��`�Ϫ�G�3�`&��F�U+.9�r���b��6�����$�CU�2ihk>��B%�"
����vk�X�M�GTQy��@](y��P��E�@&ʽ�\�{p�y���6)�"��2M�I���d��gvx������S�����m��:Ѹ�����Wߧ���j���^R�?��&�?�T�i+�G��?��i>@�t܁����y��PT�cXe.Zm겘>p�5���>pi��-�I������`���1��J�7���^���1(k�� =ȣ6mZ�VЖ+�ۼ���,s��)�k�y3B]��"����'�xU�	��	��n�������	4�E~��]NV;���{�2�9�5���4�Т�ԀO��i��j/����!��jfk�h��r��F�M��hИ���<�������ρ��żgA'#�Z�K�	�=H
��j��h�m��͌G�H
-^
�gR�kh�B�Nzf3��P�s~8g8F-�-&��j�V�|u��3Rj�F3C�~R1�3 �H�o^�@@���v"��Q�����lEg������5	3��jh��0mS'Ō��GP��	~��ğ����?O��v����:W�-֫����`�cj�y7pt���Y�|=��������F��,�acc�G�C��Qٰ��*�{v�X���06�G1�����2ЬV?'�Ηɹ]Wuף`r{4�Q@p��@��"|�l�gb���m�������6CP-��T<��	������F���4ч��Y;G#�6Qԙ|�읥)[�V���+-G���a�-�[��h��u9*H�~�V5M�p���n��v�	��rhsRe٧i(�����v�@5[�������~�i�q, �M���a$РQ��4����e���M�w�F�WK
��]R�30�y���D�,��I1r&!�Y IL��n4�=�N'iQ�@�賴i�K��\_�i���J���_�"9��W�n�Bd<D��r����K�����e��~kź�-�fF��R�6MV��0ɾ���$v�^��7���j��N��|����F�Ȋ��D����^��A�E�z�uan�GL�6*_(>G44Ĕ(�n�<<Qq\�ꂢ{���c��j�������X���Ȣ��Ѿ�,RW�߃A ���R�sU7/�����J� �l��v�
(�\�;��|��IT3���H�v����$k�,_M�a��]WDi?#+@�T߹2�_!��b���!ĻǱ<N�jBf�ɖve��3^�<K"�gM�뤦�:G��|O�Tq�PM3�����ȝ=����_-��M�;c�9�A����̇Eb�{�v�D�@%O\����!�_���|���ڞ�}�r� #��2�fV�3jg�_��Irf^�.�m
�Е����G4�:sD��^�C/n�9�=���d�|�xԾ�dg]�,�:"?�V>Qs��Z�<\�:���k�b�"_^b�����7̸���>����:w=��4������6w=��ɣ��ח��tmR��O�r��h*O�od�ݣZ�i�~ �����pZC�~;ڌ[)��=�E��Q�a�_�}i�卹��,�,�ܥ���E	%\�Sx� F1$.�#���2sӶIP��k�I�b����=VO'-�l�����/EYk:E���Q'o6� �I�;)TIY([A��/#�In�8v�F�_E��~D�]С;I�{�Y�W|
eV����ði�s��Sz���c'�f�A��� jB~P��ߓ�E����H�+*N�o�Q���w>�󂞉`;%����X�m���S�sÊ(v,�<xy�!��Nu�n٩*�*V��2�#uD��ml��	�V�ΚR���j}�r�>,�lNT�\e��<���"�]��~�@&�$�r��5m��`/���#��/��8�D/��E��Y��t���Ճ��챓7�Q��QA�VS8Y����͜�f�$��]�e�j��Z�V4���K�s�^�Ԡ�o�9��kO��󏱃��P�4�$E��3%��HF��(O�#�@lw�z�hv���ĳ�R@��Z��C5�<�"�����=$�a(
���w��7@��(zPQ�pK�f�TQ�}7Y:�|��A&M4l"����X=�]E���a�f���H���V"l~&��|G&��M
���sd�v�2HOB'�0�M�#�D�">����x\��@���������.Ej/�^}�n��&'y��D�Nx;0�6�AJ���C�z���:i���ql�����Q0�wc/�C\"��i�eϛ�>@��,������(k#���,6��A�-��-�������I"9�o�	��9�[��e�i���_I�����i��G}�ܼ�W[��^L�/�hNT�4U}�"n���[j���j��m���tci,��T����7�֮�j��{1�M_�Qr�:�(�{W$���S�e:��`B�Z��`���xFH�Ր�m���B�6���t��w��ھ���HD^D�g
����-6�@
����c$0A1]�$���^_�Y?#{�N���]�Ng�_�q��-��S3�o��(���	&a#�Z<h�҃��ċ�Hj���a�x����N�1z��v�ό�hG��I���{�~��6ڮr�3�@��4����t��o�c�>멸k��ً��8~:_Z��iҥ�X|�p4W{����MT�0h/L�y�|A�[yb�i���|�G<���R�%�~���G$Ȝ�b����\��ٌ��f������؊��t(��2c�d�F���V�����50�Rĸ��TU^o��\��eslc��ġF�n/$l9SU��r<Z>�9!SD��ak�F0� q���9�u,ފ�����"�g�ը�U�0�bt'|����PԆv���KQ�n����O��-����O��Ft)��*밽�q,����W��u])cwi�а6�?�ަbAB��d%\���j��T6�0j�B�e�ni�v�C��F����l�`آ1�������=R	˽|�� �Kū0��l��LL�I�V����è?�Zʃ�d� �}z�)�Id7�nǖH��ޟN�7��۝�u�P<A�)��V+��Q�¤+f8R����V&���5'@!Jk�.��dZ
�"u�$a�z�N�'9e�iu�Eq�]_߶�Y�*0������g7����[�H΋��(&�P�W�y��h��<,T�̂��I�$!��$�{��SFK3I�$�c�[�<�-� !L_�p{ږ7�Q��E�k�2���
��-�Au�z�荒Js�����h1��S�"u�EPe�Vhf<aE���"x%]��9{e׾WP��p�Z����-4��BSE͌ST&Q��S����^I�zsU��a��H�q5�&��+�r=RZ�Gf�Z���bFYkY���!Ax�w��|t�[motV�R�e�C�� V�^H�ꛗ6w��x�q
Ws�4    /~�[�u��U��s4��zo9�<���E�傠���W�M��X��_)�D��{@��y!���DX�X	3�H %jVs�Z��S�]���w�(I�-��b_ZR1�S�n�{ ���͹=4B�R������<���W�fUX.�ܨ�G���$�P�$���	����X2��ܮ�/�L���C�V��X�]E�i�pF�J��Ѥ�}�F���~+'���ȩ�&����O|��s�W�����W4�ڋx��gT,����/�� ���w�p�9n	<���&�T�/���}�+���~��+f`��}�����V�e+7}��V�~�Cͪ�4 ���45�l����@F�? ���Vx3)�w��z�O�p:���8�ɋw��8��f��.g�o"[ၥ��	��i��{�Z��+�P���vJsM�� �)�~�!��(�E�W�50�I�/5止�ngH>�4	UW���;�o�H�]H�
�6D�c�^H(z���7���&P 7&{��*J�z��d����>�����:�A8��*�-�e xa+�(.,D��Al�8c:�15�5a�,��tF�l��M�v~� aF�G��K3UG)p��s��6t����8k��Q�u������]O�Yo}��,�#CJ��؁�<�֯8���:U�֦1Ĭ\�f��uPeU^߳�"՞5����pP :���9%��\��ٓ� �H %�Z����6NU��07�Y3/��쟖�3��2�B�(t�ax���I�@��r�NB�8�6	��ڪc<1���YmI���22����i�Rd���2^��E���������j��G�XA'r�۶yXn�9�| ��'RR\�ʈ���Y�YEU_��@�Iє.�I�Yő����Tǁ*�T
�
����d�ĥ,����g*�go6��d<ʐm�y�B=��k�xZd5����ABHsa��4�2vΏ���R��ȟCa�v;��p�r�<��zq� 6��D��-<�p`��\+�f�6�~�m�ő�5��N��SūK+��Q���?솧�#�$�c^?H4�U�hG�g4�$Ntv��-H_�?[uYy�?�Z�2Ѡ��7�(]��Q%���A'�����݉�_E�9E�2^��,��4��x�y�G��6�#3�-�%L�j��}��"ٟ&���[���ۃ���R��)���b��U��\�$)ݥ.�ܬ�P���DW�l^��<�K�NPD��'�#��i�L<���^���	�+�Ԛ�Q��[��Zʘ���~��%�d�n�U���˜�<�O�]R�;1,bm�+t�iN�`�
�*X��r�l;��A!Lb�I�xz���t��I�?�id��7����NP���N[���$a̴{�\��m)�|G����o�eG�K���T\5�U���
i9��"r�����"[4�c���1.~shy��7ءS�0�W���Y��؊�Yu���q�L�z��y������[4���[���c(�`�)rq:���j��B������P+��7�eK?��o�'�Z��y�.F�ŏrh7I"��6���������G|��k��%��8��l��z$�����������+!L�{xF �;0�;��]�ɬ�u��}m��h�c2�<���c�N��"�mU�M]���2�NQ|�o�Nܠ`=���^�iSSI��$o#*�isj0�v�)f�j}� ��:���[�z_J	���*.g�D9�O4��o:���Qj�މ�^u�X��=b�2�M�0��w�!M��½N����l�T�$�Y���m߆�G��?��(�%��{�.۩����S"\o����+�w��+��a�ɾTP�n��ϸ�d���I��8�e��:"����gӛ޶G�m!0�n�cu�O]�~�����&색�ߢ��z�eD��=YJ췊a0㔂s�R۽om�"��@J�+���a�Y��[��[��TG�Z��.��,��oť�-���Ӥ0T,�2�d�t��t��ю�~�p�U�/��s�U�/���:꯯��0/�"x'&�c�\a�~k��_Շ���@�j���q9"d_(�xZ9�e4��ƀ�F[0�Mׅ�?�Q5uh��ǚ��:1\)���=�ܘ��Ћ�>��[a,J�+c��
r9�Eܥm� 3��<u��o�;'�&�ʨ�(��<�:�w�����ܹ�����H&Ha0��u=K��Wq����=J��u=qb�(��}�u��_���N4���Gl�/��N���{݌���[A�Q�Ŝ+��҅���a�6�D��p�{�y:����ԍ'Ζ05��y���$���(M
o��q���b�&3���T5Zq��~����-$cCߴ��,ƪH�"If��YX���&�70Nv�j�LS8��y?�d	�~w?�f�Դ�x�0-��^%I^-�aÔ����(�q�8���Y����|�T�A��ԙ���OO���������"gЧ��R��J*ؙ^�m��N�vQ6'¹�74힩X��H�j�ʏ)کٰ�p5�`���&O�A��k=���gI�]��A+�0r�2�N���:f��*촆�O!�20��X/��Q%E��3�5�a#�c���	y��aw¸��W��cP֓�X��O�0��K�-����=�ٶO-���J�ub�� Mh�~c��i�k=��� O���Ɍ��Q�����|w�f>QeCr0�V�F�cG{����H9P���Ý,7�`�����s5p\����!O����(�E�us��Ց�Dݑ`�u$���p��b��'\�&@[�]�F�j-�beZY5����W�"Җ������� ��'�j����^��N�������"&Uن�w q�F���ۇ#�G6�R�o~�N������5�r��{�k	���P��er���c�H�������
ܯL�΄CgY��	��l�Ѵ�����
�D8�^��BT&�X)s� 
6�t���OZ:��V-�P�r���< ���Ŝ���T��	 �-���^�x$
1&`B�"~�=ع]NS�y�p�}����Xݙ�]\\e�(.3ͶI$��Ϥ�H�l<��������y�����������?q�tD @%e	p��`5A��2S�6���+�8s���(D9���^ߵ"K*�`�"2�)#�;g󢿘A�V�ʦ��i��$l���x�$	��E?��#;�j9,p3� �Hϸ�Ij�&�$�p��-B_Nc�/��:@�����\���7Zr�H3���,V&�an��q'�"1�,��Uy�)�t�&:�o���3�EN'��ɮ¶���w��������ӨL�tF\��ٿf��<�ȭ�w�� ��~Z�b'£���7�Z�mz��zw���e&I��V����r���d���Xo��wH�	O��1PdU���g����"�]�ń��4���>�yVw�KB��.Ol�~xE��d��1�n�� �a.�Y�W3^<��l)1�g�<�u��~�IL�)~�G����m�\�j.�!L�l��,m-��p�*
�ێ~Y��Ҙ��
�hZ[��SX
��j��Ũ�iQ��,`��2�(�D!\-���?��S���n_�d*����K��B��Y�E7O~�r�͈x�~��*��ĠҲ33p��)��E7>O5��#��8ҷ�������s��?�Z�`1��
S���$��H�j�T$���	B���%#-� �j߶Ο"H¥I��J����l�Һ���U�E��[��n�rP���`�{A��xEz�s�Q�1�$��v=`eNSqt��|p\Q�P��!4ǁ�C����D7V��y��ʐ�3�, `@�ԑ�{���4r&�ˉTt(�"��� Lo��y/*���m�p�â�c�Ey�葬uč�q����_%#�B�c97�[�+���n���wS�V��ŋ��Ҧm��նcn��f���{G�<�]�ɯ&h�ۣ�ؤ��f���Ms=�5�}�ֵinCsW�Gt��,��,M�B���ƗH�F�2    ��j��E^5�2������-��^�CȥE�:�P%	҄��*U�����f��[��ĠT�t5���FIYXU3��IZ��e����̓�������fg����9f?���ضT���b'+��*�q�2[�*b!5U�D�����W�������{d莁�X�/�ëʒ�og�����ea�J��{G�b%BRD���u�am���ޱ1�Ed*�m��%VC�,� ��������՘>e�m�D��^��=`TF�7.�J��ۺa�_�������c�{N��jn7�%D�EKN�N���"b��L��hʣ�|x8r�r��Va���I�ŃW�5�}z���7x�T#��������k���W��SWM,wW�{|���n�?��#͕A��ݮu�,c�!^&<m^��X�v.Vw�J��#1���nxAB��Vd��l>�FW�G���H�kn�c%��8� 1;x	,]�:7>����������|V'Z�e��j8��� �H�nO���Q�Vʪ���.2�@̺Ql�D��nx^���C㲢��Y�dI�Dۜ"O��{ބ� ���~�/"�"T���{�q���(�@�+p��_=��P��FpZ.�e�Πե����ʲ�� �� .��&!ӖKD�� ������11&t�K���-d��e�	�3�zH�0ʖq^��n��niT���nE���j��\l����*~���M�"u�ն�������8�)Z&��9R�����B��n[dO�d��Ϊ� ���%L���C�fm�ϠL�I�d�ae&x'X�3�^�E ثu�U�����ꨤ�"����_��y$-vSm�5��J�0O���À+䰧����>tx�!����A�:tA�l@�A�ۿ/������J�Df��jJ=�-���.̌s�I��	�
E�]>�(�> ��6x־N�:�� ��G��*
E8?��g��a]�@�����{���-��D�
4 �l���C�����ɺ���Q����Rt�x��{=QF\n��S�r�0����Qu���hՑ'����ա��-'�7n��e����_�P�Ɨ����j���ᖯ����뗧E?�N)�O�Y "�� "^�ÑN]�'�ثL�79�_��-�����b�+�}Ѹ��Ĳ��7p6�X� A������[��A��.buP�k��A% �o��?�Vq�CՆ������� >�?�p��Z*woV��s��n�$���)�I���XHxp�[�y#H�s���=�d~�W\��
��6��p���cw���a�����q��L��n1x\ӗO:ϳ2l��#�e���{�o���d#�(�l��72삐s�#��ꮉC����b�i����oj����B�Ȅ!�&)�uU,�~P��XƆ�5�������!���+YJ�%/�l�$5&w|߼T�"�sw�P��9���T����'Si6�b���غ9/뤸~(��%UdWn�ȌP#�S�����Է�o���N�[�m�W��ō��[O�1xMnly��̢�p,�"^�Z��n�ߝ���! _Ǭ'U�Xp�:	g�Ȥ��N�H��n��9�,{��^��O@G�g�Z�2���C�uW�hlL\&,bE*<H$�Q*@~B<�մ�@�҄QZM�b9߇���9U��N��H��?�0���ߊi;�P7��?]�$������z:]D�4#G7r��D5���d�/:�"h�0j���A�F$�ꐰq S�u��OT��ŇZUL��ؠq�CLg����KpW�Dilٺ�ԕ��Q]{p���hc8��ٞr�4Y�AV�֩^�]Fu�4����f��V��D6	�tZ>n	��Tj'R�O��	��@�By��4@���f��[ī��Ŗ�yw��+�,��L[�"���򑣜>�5�i����kQ�q�pr�$w�nĬ��~����j�SKo?g<#ve����o��Б741)���I�[2�{c[Ha����$1�= =��i�F��zF��7a^���fY�;��"�̈́jB(sr��	l/�H�Eδ������I;W�����` ��/�P��`FF�A��@�D	A;L8޵E�� F��:W�Yr�K���޲X�o;ഹ~�����a�ۄ���H�y^�\v��0�wޒ���A�^�x����W6mM2�ʖy脉�����87���o�q�ϯ�$��b�5�*��_g�A�r4�"�d�!4��uFa�D��bZ�G������"b@w�F@��b�y�)�i�Z�-��\a]_��a�8�2
^��i�JN"4�]Ib���-���qx<�;B��L�4t7�"뭿�dIQ��:#fe��#�8x=�5�QГ�~X!�B�Q�`�]:֜i�&����5��y�˵nXϼ�O�;��q������:ȕ[�=>����P��(����Ɲ�/�쏾���G�
�����4h�P�?P�&t��|"��_I0]��?tg����"Z����Yo�o����
 �T��9_�D����<�'�N�Q�:;1��`À�mx�W�]�(LZu3�s�9ٹ2	n1��/�{��}���+�CKG�����|F�|6Fk�Fm9���*��ky���J�� �@Ϯ�{пԪ�՝���&^K�#��v�sj���;�t��>��۬&��8��k3m�'Q���f<��M91i���>����� ��*�䍲y����6�*�Q�f�Y0)�b�'�qW�2�S�!�J���h�#;Q�P��zk�S��c���;N8�A�W5 BӘ��i�{����;(ܘ��ȖNbHd]5E��(r�z����P�	��0������i�pYl�q={��:�x|��R�T��s�k�Z�xJW��Xn6[4}\V3N���Ĕ@@�����a�EUs٦�*�
�j𔫉�-G�*���1��S����C�L �0�~+S�#�ơ4/:�م�W%C�r=���@�Eo;�Ea�����e| ��k\j�;���P�X"�#P�v�S1���ݸze=����K���g���e|S����Y��[6޾��!M���o{-K���9ۓ�Q�$3�jaρv&��Gt8<8���]
��03l���#f��
>�ޣrY6}�}�tE%YI�ig;���f���,�$�f(;��۸᳉B��t�i�-苂Cj�i�t��f�b� BK�v>�`KA ��� 1�j���F3%��3��I��F1q��/e(�?�Q��q�e[C��z��l�z�M\�8U�٩�^��z��ys�����Yl�dRIc�0zf>*��;R�3ƕ"Tq���\�����NDhqP��˵0f@���e������"JC�՛�+���7������N���:��6��'lE:�T�N۬�݋�:jO!�X>��j� ��KS�J[E�b�;D��l��d>-'�:�:��厣WN�*I}���,��������˺Ogh8Ia
�����4�s�	��,�C�����;���U�<�h*���5P�4sN���+�=u�6�1D5��	��f΁^9M�&���3��I��3�lx�k0կ|�W�-���n� E �Ĭ�$�� +����(
��3~�>��[�D�O0*�{�'�g{~\��p{��}��sE��c�������BN�ce�c[����ѵm��|���)6\Ey�V�\���R3Ê�Ȓș��6�����f��V�O")u�p�k5O�znYK��˾����Q��BC"���lM�>1��,���dZ͛ �wNz �V���zؖ��I�Ʀ�9]ns�шE����7e
Tq o<X�ö�4GB�a�W�'��;$� ��ʂ�j��!.��9�o�O��*�"l$Z&�;L�=e�v/�1*DM�)G%��3wl��D������*�?�����4�N@����ΖKS��߆�ס���>�y���#�i�����loi3D�� U���]���X�4QS�؏�˙k�q�l�VNqT�*�����G�4�Hrx�GS8f0@p.�ͽ�ҝO�`��6��jÂ��?�f�(mki|�@}*N(n��e�(ֻZ,�    �n��RE�灂�f�y�N}�^�Y�j����` ��N��f�3����d�{\f���^<H ��l䁶Մ�M������1(��[�������'����T�O�S��|iG�fn�<zJ�d� /� �tP��w�QT�UMTYt��y��p~l`��gY<Ao���["IlYD�?��Vȥ�y���9��Ë)~�4���5&r(�(L�W��"\<m�����^�w�Apd�
|o���5jc��ҎX�ǴdyR<	���s���dY�Ήgi��Y�ŭ����G�3�?�<��tÝ��ܡ/
�sz�Il�W[m��\��A$�:�e�ǅ&t����ɔ�8�:���w4�N���p��l���e��*���o[p�zN
���W��,ƣ4eU�ק�2�J����z6��up���u�4Ů��������z�b�Bq1c�d�.��Kc\�h����Ľ�v��nb���P��"�L��\�����@	5Z�l~�Y�4RkL��$���$����6U�� 4`���(u�����	�<��%�ڒ��xqأ����SO4a ���>~��/l���!�\�~c��[~]�$�O,N�]K4�g��Ʉ�5<�k�GN��5s���|�EN��������>�;���]�.�����y�=䣵�6�(�$�m�+�֎M�ؽ�%����h�����S>I�,�i�N�Qv:P%�����^X�� �6�[�l��O��PZ�?�F���LA�3''X��yVcE,�
kڨ�am[�'+v7�6��@tp�BO�yN 	Wbķ=M���m}H�dh�r�y�$�Q���k�^>4�ti�HK�lt�u� ��M����>h:�����A�w��h5k��P���nF�r��������TVN�e�W�(����x�=A����Zn*k�l�^�T*�ȨRBe�몥~�@ˑQWW�mwj�[a����Ws�%ݢ1���0��ۄ�s3�����N��~��du]��9���AW��I� 2ʃ�������Ѥ�NЩ�0� eA�&\	���8���g���V�\����YEO�ǹ�_�F���0}��Og��έ3���4O�����1$f�tu<#l&��CX��A�=u^;��66N�e!.	�;��NfN�"儉��N�J7��du2�gL����jV˙3�eS��6ad{���/�<����?>:��t�n��q��\z{n��泬�T][ɉ]�E\��^�;Å̈́��J'�7T恸�+^��z2��zU�kԁR�����QK�v;W�'Y�o�OxVS��I�U7���Cc�_W��Qp[�+�91YD��[*��������#q_v~��~��̱+�������Ŷ�בko�6�m6EP��\Q�O�S��-#�f/�p�vxq?�L%i��Q�0��J�t���A�0 ��%�6�۳�lT[��Ch_08S`iT�x��~��"���Β��z��y���8>˻�0�q��,�1n�pQȆBI�[�Tl[=/�#�A~���7��s�Ɣ3dMf{�Z�,�z�q�i��O�bU�\z�C?i h���`%���Ǚ(G ���;���#fHD��^.^�P�b�l��*�a&����}67r_�NT:��4��;����F��Ԙ|)��G�� ����s����>J8Q�T�]Ᵽ?	Av2�ٞ����a��Q��,K��R���UlL�<`���`Z�٘�VB�.���n��IY���[�Am�.�q��Х�<��	�gVM�*�T<;�<VC�OXE������� *o��7�r%��r���C��@Mi��z���%:^�&��ɜ��j�)[�f��k�xp�@��O*�Fp���h����V*f�v��j�/�Y��.E�y�s|f`����_�� ��>���#/�zFE1��;����2�_�F	N��u-P�A�}k
��9\�/^��T�yϨ^�<	]�ʀ�E��0���Q�A-��?Q=����!�Ժ���/�~��ݲ(������p�2e:|�F��&
��C[��"�w�ᬫ�x5^bQ�Q�Ll⺙�0&v��Q�\#���a�}�䥢����Iw(�:�P#X6����G�(" �=E���(N*���@3 ����ܼ�m��b�*]������E+����S��b�'�|�!~e+6�0�"*��+���_cO<���/B��GJſM�UZ ���@�"�]�уf��݁�{��Ͻ�_5G��p	�����~]J]b`L��|�b����d�r�9�1cL�Q�L����ăV��8'8����|+�^ǽH�N�<�K���{4����ꬆ/Y.�d�}����aQ��(�w?<
�ݎ�t'Xs.N:����*j��=�;��Y��[�C���z��Xm3Y|@�D�Q�n���b�� b����l"� ���s9��h�2l��,t�J��;w=�֒Z�)tsn_��X�܍�*�K�1u|E,�!�E��~�ՠ�	�e�D��M��M��,І�֠�a�,�/��[��󳇧���*|7��c�5�_�HVq5�
�6���J�����8"�J�O5�id`V����ܪ�4����)��]�"�H��}gO9K��3q���I&�uA�fwi+�VA����c���T3�g���;H�_�d���j`�+�6{��A��d�&��n���ぃ@1 �IGB������#8�^���A1��X�����tP|'䫪���ۍch|p�㨒�̺�'#�e��n�uU?��P�C�m; �X	ɁT ���f��9թ�����Ҳ|��hj#Z3��l9�C�|�2������?����E�5�(�J9)�C�,����&lf��<#W)��+7�2�=ҫ�f��n\������#�
T�tu1Ú����@q�*Q1{���&l�Ńg�i�p����pt!��M��Ōb��B�VKI�W����|���>�u4z&�ݣ�0ԫ�k1�>���r?�gi����D�]x�4��b{��|P�����I�}�h��V��G_=ӃT|ɩ��&(T`�B���!!�����b�c��_���B��ۮ�������o�c���ݎ��бr����"�h��t{����Ɍv��9f��X�ڤ���Gݛ-�qd٢������G��Ӣ�#��Vfz��b�����Z{o�`ݾV7�"�P�A]G�@`���i"}�Z/����;���l��(����x�T��z�(s��H3-��}�N�Υ��BGM�/���ۀ�c��pU��2g:�.��LWe��[Q��:�}���5w���̐����j	(0�	8�Wkц,��+m����� �b�����;n`��G�;_�-���&A]dx̀a�7�����Va��C��`���:�����,4=�4C�Fi���h���bh��g�o!�G���8R�U��zN�yQ����ڼ����l'��R��P�0�=(�} ��w��If��1�)'�����+��</�a�? �ۖaV�f��A�����q���V��I��Z&��dD�Qt�6b����C��F^1165Y:��jڬˉ��U��(�]1X�Ɂ����D	~CzX��P�k2�gp��x#�U�us���S����h^R���	 �ګxj�ʯ>���������P32DVƆt����6ts�ѳ�Uc.��@�NP�K��&.��t��gȯ��$�y�C��jm�
�˳��AV�祱A�(x#�3���o��!�A��*,�ɴl�c�6��tw��;b���3ԴT|�?�Պ��lھO���C(dp��u�t��I�jz���u�g��q�9��0M�L9��)L�<Ïn�=�b'��8�}f�IY�K�%���g���Y�7|�t���!%s�T?��zQ���������Jb�gi�3q�2E�CAX�y`,���W��vq���b�0J
{�\C��e3�a��l�K�����iEYVa+DH�K_�Gn�yx����0�w+w�G�w=�R$6?Qb�S'1g�>����G��?�y�    c�.[��]
��eE8�8lQ�kU�[�<1V� �Ǜ��5?�Qd�&
Y��Ԡs���c=͵����S*�"H��l5��ņ]�T���8��Ʒ(ᑽZ�y���j��Ë9�~{�"~W��.���n2�����Aɨ�-�cuEW� f�IZ�|%��� \�N�c�&b��vޒ�7AZ�:.%v��Id%-��ۅI�ǘ�,_?;�s׶
o�e��M�À��'a��������d�l���=]Lu���vF_gqb,�<
>����!�(@y��g*�K"�����\��`"�w�j[��,����]��E�}��Dr�0����'n�t6�78�:�u]�{=�>5�9�hP#,HCQ��}"�5��N���9!�,?�k����t�-i�@���L����]��d�X�0�!���n(�ǫa�(w}v����h�*]�i�Ȩnq����ze�Xu|JE�;���$]�dfFm��c�p(�~�9,�8�1|��&����M��*"��Q�S�ۼ�%��n�Ĳo�oԄ9&�gwp�(�h����2�їTI�hW��1y8`��,�4������D	n�қ�|�@/#�z�A9�^��R�Yv��=	�ԟ�"�@²g�B�q��|E=��t8��G�_A{m���um���Uu���ث�t5����d��T���[S!���v//���	�r!'X���U����#�"��-��3�80�����Ӭ�n/��ȗ��p}W�t1IBx>�7�/�c���]��� ��M�[A�Y5�㰒؝0=bEȾ��zz:�G8%-h���!�/:z>2N��Q.}�s�ro/S�$IS���(�ݥ��n�����4�9�5��a{���Ï�濯�1x�����eܵ3na�:�+��<C�7"c�O ����L���'�f5��r�ƾ��r��V�>I���t9�Kj�)���U|���	6`��X��F��B�g7
������v2��	�/���}1�"N\M^i�V�S��*O��c9�☖x��,��ʒTH5P��=?��L����۸f����Ȩ"h� CW��`hu`���p�V@�Ҁ��`zJ��z!������C=/�������"]mոX��wE޾�M�<��B.r��N )�?���cG�1���+U .ت�*[��f)=����S��L���m�2!�|��G��3W�A5_��w���s=\d P䫁���I�C����Jry�  i��EN<��3�u(TD��"B���Ĕ!���X*��^L�����+x�,�_
(��� ?b���8�N8`s'O�iT5iHq�/�"�PޒJ�Ϗ������_�q[�C
��҃Ȃ(�@�ѝ�>���h����\�K\��*�$e܇���}O��oj������Q��Y��f3h�G�E�.���~`�Z�f��r��>���KC0�<V�R0��[+�q(�zȖ��~F�\�g�2���;���2�S��ԣ����Č��s�c�jsH�4��Ƚbڱ�Q����7���e����\_t�$�
\��q�mÕT�����d����ѻ�Je�#sj�ǘ_��6�u3�BNc׆i�(���E\=�0TԙE����T�8�WQYS1 qW�'���|�k���g�i�JR;�I��`3B�8>�Daf�8�?#S����z��![�����f�2W�����ڷb
���C�62<z�gQ[l �4��tb5̸%�_0e ���.M��`defΪDK"��n" ��hNq��`�m��2ƿ�Z;�T�LW�z�^UU�9l�[��Y��
�W����r�HU���I2̫G�7\���˧yZ�?�E�g�Iu�mq� ��hQ��%t�rǻ�@�Х�Hᣠ�G].#'+����2�i=cٕIa�ge�%0��q�{� zF����c�R��چ��Q*��Њe����̋D��B�w�czkԦ0�y_w*ߪ��Q�;ul$0G���wyŀ���=�,I���	I����E��q�̛�-���k��ϔ{���l)a�#r�F���y�y,sJK��2���)�7P��l�O�U<�t��(xW�] ��{���Xe���(��Ss�ͽ���f�˴� �T	פ��r5��� �Ð�3D+�*I�)���-�P�C�k*e�:������0�t�;~�����Rj°*��SiF�i�WQ�^+`t���a��w����Ӛ�+�=w�_%7aԴ3Dy����b���w��|�VXp{$@�� ��d:�R��z��mSa~�:9�4�n)���'��|��ƙvՇ�{}\`�.C�l2����'�G�������	�v�Q�fQn��G�[��V�(=�뀺&ד�I9{:>��Z�S��7z&�Ii���}���y[��+���	�0������J΃�k'H׺m���*Λ��@�`�Ώa5��R�\M�%a=�%�f��{��:X���	�L �}5�C6/�������no��h�+f�8;"|� ���+�(+�	p^&���"���s���Tǀ�ު �i{�F�/$��++��)f�O�zp��������`ѳ��OS�O�ˎb(*D�I�!��;]��]��j{��^�3��m~� N��"�Ϧ4;:T1��yc/ݲ���k�,�=��*��S&��$�����"��$�b5>�b��&��h��b�D�ù�����ۖE  ���bC�5��S�x8�/ӳ���Q�Vs*[0q4E��H�Eb�����^ַ}��q���'\5���'��]��AFb{��DR���-g��0\�ؚqu��'�{��,j��%5٠;�ݴ.%�T6lAlT�!R�:VP���~�ɟ5�`�tw�Ex�>qB�O��]EFc�?������|Qr~,����?�l& �^�3!&ʘ��||9�(�Ri���/����*���KVڧ����$@�yQ�	��A��F<����K�J��m�BEY�ʁXOm�i[��5��Wz�qT��՛0��_F��P(a����
�,��^����=��Ȇ�b��$17=����y���ʟ?�#����U�\��˪� ^u2g�ی�Z�����vR�Ľ�,=�I�zs�:����y�a��ߘ*�O��{xy׬j�6?�6� P~9�(�Ep�T�%�Q���~���@^����0dO{����#d������y}V�U�i�u��,nDn�;6c��M��:&ϯ��ܿz�rW�f����*��Ԁ%�'H���<�4���KHa�	}��ב}��Z#P5�7؏�\�G�t� U��fσ9���b(��!2��w�,J����ȴ@�^T�
������̛)���H�$R驀݋��0=�܎������=P�Hk�}�(Xf5}&@gaN狙�q VI�ǂ|XO�������.J�Oa���v�$�B{FO��VQ�q�N�3=���(���ߊq^���+N4��Q�T�P݉}>p� �$a���q@iP�xD!ϝ��0�K��(j���R�Ii�<s�"@�^�����ga��Xc4�۶�,�?bF/��7��Rb�B/�F<��C�Zrt�A�%,��VMjm��Z/M=��PWM����w�q�u�ǳ���A^�|�K�]�UW6 >w!�j�U�8
p�"���Ԛ�
h���
��ԢYY��F<�-�^o���w�"9 #Xe�%�d-#.u��P�w�"����㚮ƦZ�=��*�����8�Ӛ��#��t.�����T�����{�$��S�����mc�V|/W Ei�ķoW���qXo0�P3+1�U3����C���\�W+�B�6QV�јr�p�[y1K��V�P��l�9��٘�Wf���yi��6���G��9�(q˸C�z���Y�Qw!�&��b�*O�g�k`��M�<�TLW­z�ʓ2<$�ls��b��ޘ�^g� ��>cDW[�/&�De8Ǘ)ϲ\%k�(~�J�O�Jr�1�`w͒�eCJ��
�s!�X�ZC�x�9��4�y��v��V�'�J�tF|���8q_�]��tT�9���v�?t��?���1R�k����Ec����(Yk�h��GF��    ޕʝ�����aG��қρ�OO��x$H��}��f)�&j�����cW��P%�o(u���3�@eG9:Lh�\]��èn��;��b�x�<���R�]�ܾ�ˢ�����P����U�$Dv�� A�N��P�@zF#a�F爩(㸞�b[����9��r���1~��� ~�'�r���n�����S����
iu �ؗ�l���^�|1�9�bE��5��w�1'������6��	 �a���5o�����ӕ%�gl�Y�;Q��Kyf�Y���v�j���p���ú�������.Ģ"��n���2�+����`� �`������N��L�Zk����MGmTݞ��8�^��r{��=�i�:S���2`���Vq��a�����X� cW�esWfv��6y�JlT@QpN��
۟N^����;12u��jk�u�"�]���a�����q|:�ŷYp�XM���^;1ʢ}��gd�����^w�V��Y�gu��^�iZ)/0���=�W�N�Z�J�N)����_:���^`�����K��2֎ƌ;�����V�:-V��y�G3�n�d6܊����+���$��O���Y���؞���g���V#/V��e�D�OQ�<�mu'�q&���]�n�
�PR&C��Z�RvM\eC��Mٞ8N]hN��Y��ؿBw�N�5Bw������(!����9.�L��/x��z�i�b̐&��fN1R���q|��S��A�X��F.㒮���kn�ʚ��L��B�U���m 9o�OR�A�p3��R�[&\KSs�pd̲׏��ۡ��/��P&j�gsM'd��'�n�ܺ���~C�A�[?����R>M�GQ=�UU��9+�_�{�z�����o�3rV�
�U�ʂ�<�I��kb|��(	�#Bq�ʒ��-V3�_JE�����A�(�2�|\�{J�*�R\ʤj�yl&�"q�3o��6L?��qM¢�n���
�Z�%�¯vX���S�6�]>e�FN�h k-�XU�u�)b4IԺ��X�il�lA����y��;�r�=W��;0���0�C���d��n�&3qE�Ϸ:/�� �w���Tp���:Vچ���K������=5EQ��`�W�M,V�&i���d-��߾$���N�\��ӟE�g��6A� 4g�q��8«��.o�~�t���'P������rn�,�ۛ�2u���%I��X�/M̌�5�, ��K��'���Y/�@�R�Ď�k2��7ũ�>����X�S�ز;��t��U�ey���$��I�~�K�;�E�DE3ܡ�v���K}P<�ȴ�B��x��s>�0]�B;���`D����.��z�_!�w��WiAB��
l��۝�ߦ�R-�Y�Ծ6��h��,���!"��0C���m�3����ɓ:n�9���O�*���(p&PlU	�����C>E4�ƕǊ�^�8�^d���2|�}5X#1����%M�u3�fY�֯%U�wL)�,}_�u��x��̎�����l#��������WU�!�@�e��#�|���9{!��-�L�5����^e�<*%0arL�`
��t_H��u���!#sk�d�rB���"�?s?���=��5�)=# 5����@�?��G?��^q(]��]�8?!C`��3��:�R��M�6u6�*��QorJ&p���keKi%���r�I�RƢHͲ7�X-���W�F��\��5J�S��?����茴'��2ʱVt=A��~�L�SOi���/OJ�	����?�~ړ�5���\�����W�>�a���(���D��u�M� ���O8�#�\TY��M	 R�Dӿ��W����1�$]_�7xU�ƹ��H �x�{����+��nR�=I1w�v�d��M��R+����g�P��&S����~��f�V�[�)c�����d�S�zFf���'@���^�W�^!�|�\ǁ�����|����?����2�nYkF8-�o��� �<�kgI�w�O�����
�"|c�|4��q���X�P����¯����,�
Z����*ac[�m��n*�6��]� �e���_�s������c���JF�G��B��'y5����i�'3J�*�T[�4	��X��6:��T�E��p̅R��M�C�[e5Nw��o"ӨOg�L������}fq���pT��'`�u�.�E���䙁)t�9�Q�өY���	=���޼���f���6�zy\�p��g�gU��nF%5=AG��m���D
�X(	�@��I�6��||FV���$�f��r���i�l�&�c�	��o�pDE�Y�b�K����;્�$\F�-M�h��	��l"�f��Z�;#cz4�ؼ1yJ�PH��S��-��]1V����%t��֊�	��.JӼ�n��Ui��V���WR��Z��\u#�j���������᫦㿁j&w1� � c�bA��O%0��6~].�dC8Cs���L;�>��Dn���b��Ԛ��Bf٫�{� �"%UaB��=����g4�Հ��6R�@gD3OCv�e���p�5��7U�q�s&;�0��^Э+��σ��*������q�1X�2I��g<U�bb�*�r����1s�7}���ѥl7e
����ѯ]H���0��m>��h���ie��?�[���EX��r���磝�eW��}�S0�z�C��@�|�,�E6]'?���:S��y��ߏ;�ظ�1�������8�I�;-�A�.����IT=��G�q���7do�\?1�(�TA�Da��C�Ɓ�KB=�4j��*�0]Ϻr�UAZ�Y:#ie�㚅�g���$Q��E��I���Q�(���V�&e�_8��?���]x�����pF��å�(���E1���ƙ������L�͋�k���-��������jʀ�w��V{CӦI�v�V���$�j*��7��� 1q��6��Ц����jƋb�Z�˘��N1��J�	B�H�dX�Wo�Ԥm��*�Mxx���O�o���(�������M�
z�"���{�O#9�z���^�m"��s�=b1��2g���[9Mn�Y;���g��z��G\')bo�t�ۣ��B�7ӘԷ��$�YEl�c3i��k���R|�t��lƙ�
1�2��'���*�E��T��}���M�f,m��t5�b2�YX�my{��<�-����z�mR�V<0�m;눞�U�d��NY��"8�w�5e�a�WBi֭����Oh�!�bI>���֜��d�hV���gQt/2�C���	�QB� �t� +����X���X�&NЩ,�XչO����Y���n���a^��.E�^�L*��Z-�l=���䆳���#-R��g೮iT�VU@1�t\�Ng�P��&"��L<J�mΠ�~c ��Es�F����a���i�G4�����b��*G`�Sa0�С��;��Y����q,�?��Op���ow��$J�E�G��-�G�>�x{�� *�o�<r��f�E�V���L� ����[e�X)�Yskˈ aQj˘�Mr�m]r��84߿��|���8��]��'Q�\�-�$��r�2��'�(�N4Q�mߩ�>JP+�Iv������k�n���tY1��1ŪE��x=)��t~��o�BB�K�Lj������$|[=���)5��IV#j�u;,����:#+Wihb4y�:��|0���`y�k�O1]8��Tc�6�$��ztlw���\�����_�,kü����(�QY�wc�Ǣ���6_�:��=�l�^&���,�?�o�/�mHmP3z�{r��/����-����n���� ��g�y�$�#�'��˰Y�+�BD�X���gܚv0��P��(q�Uf�.���NQ<-��c�<���Dr��~K�x��a�My��1)cMy~�r���.�γ�Z��\��%mX�8Uh�ȼ����
!�Q����~̖Lj�]R�F�����fl"<i� f`�3�\;��Y�^�*�2!�~�[V���q���*jQٲ�hm� ó�{1;�&    ʡ������w�ª�K-%F�摌] ���7���ȇ��"��py�ZS����+Er{�:�T�8kyr=���2�����R�Yn`z&Ɯ+K�e`��?Zȣ>�1Z��*��B�ľ�H��(��퀤�4�|6�T�!u�u[�!8�����w�tVۙ,F���/f�/ͽ�c�a�{~$H�)+��=	@�oUe��?�w�������n�#�%�!��$���f�ںH���� Us�GL����~���N�O3�����̤Z�ן-6�ϳ$�gT+y��n\p�D���Q�����ʑ=�a$Sv�ܢ_+�A�+�ǲ�Lj������Q���j75�Ő���&OO�g%���<�M_�
m.̋��&�V�J��jM�r�ż(�r�1+�*�{��������o�y{&P�$�˨P&s��M`�G�p˱���䖞���ne+W�fӸ��2/����?�82�_Q�����p�YqB���m�e��^]]���9�x9��a��!:>�Ǚ���2��K�i����3�*̬�.��������Vl����)���=���g"�b=σ��R�'jƃX���U�Ƴ8�/#�mMoF=o���>'7�H�gf���C���b�����1}fI�����kLY�#"�vJ��z��܉�YMD9�ZޅM2#0�i��*��'v)٣���Vz:�ʹ7����(Xc���1¯_�<�~�*��0�x���\�l�r?�t0K3����7'6ΐhQFk!~�P�匣��	��I��G�g�7�T�K|��6�\6ߩ� �T[��(�%��\�YXl[V�Uݞ�$OR��i �$Zّ-id�G<�k��㼚��b�+��rFX�4��G��������c�t�[��Pk��eH�sG�a=^��7`E܇�g+�Ȃ�_�K�ޭ����Ӹ�u���r=���x�E�e;#&e��S^?q �?(4�S��ex�l��`��/�F�w�&h9M�"����ص��`�Щ�Xy��V~w��l�G���N��f4�q��fATV�
U�	ig<xS�߃��2]���P�Ā���a�-3�(����VFE���*�����
��x�M�X���;�����/2�&Y��m��S��Ű���pc>��U��ׂ����Gy�ˑ���J���1��ΰ���������ŜH�j���AU��NX�8���2��� �������H0���}Qt��f;B�|z�F�3�X+^�Z�_�����~F垸Pڮ���y�1���,V� ��(���hX�oL�j5�Ȃ)���hF�"H	h������`\���l���}%T��x���J^�hn�������*�L�X�K~wW�WVY�'���V��Ё�e"d�j�����E��3�I���k�~�F��t��k+�"���wߩQMU?���5k���ˍC5�O��!Wv��#x����&�}6����oOh���r%k�d�Q�����vDKU`e�%3��IǡE��=� �칢8�[R&��O5CS�U�.�sVF}��	M�㿪�O�l�f�"�"Պ�8+����m}zQ䡎���{q=��O��u�s�y'����bﾧ�۪��@��0�I��'YQV��K�?�h����¶qB�9SA�-��J�1�y�2=�8�D��j-�o��j=A����4/���]��F��(���
ͅsב�f�q��^L���u�D4�(�'��X��?ʵ��ې�Y��n���")�D��Lf/������!]��K$����F��h�̻���AuJu��I�+՘!�ɭWׄ��W���M��T���1\���~8���a�B��h�ཐ�mP�?P.��	�,�S߿����>��u��	�����#��4��Au9ǃ�˙9$�T]h��P"��Z/w�7 �6JME��y�w�����&������T�\�$�X䈉�o=e��u��"ǯ�;̤��Ԟ�tti�+���ƿ�D.W�+ӽ�`�B{b�g{(���S^Fq=��@.�F͌Ƭ*R5TK�,�f�¸��)䧗)\��\�\ �O:C��e�N��Ӷ������/*U|8��(cRՈ�P��"Gj���H�����7Q*<���?#�RuJf�l���i9�o�RɌ�.�˞��"��*z�d��W��3�]5�B��>d�>r?6�ƫ����=����f&��C��$�|5?���M�sۧ�ؖ���Kj֫(!��)b�E��(C7,՝ �js����qw|pO�E��� �*�DE����Z���)��Y���8��__8�x.U�\�<��6|U{/챇\a܇�rm��h��E�����T�H��mȡ�(��*�'�S��|6�jЪ0�����J�(�J��\ɢ�Í�V����k|�L|h�W�ԛ������?��{�~�;���BR5y�LT�a`&M�,*4�q�"�\&#ƽ���&��;OML��6v�'}9�Z�Kq�hvر�[��^�
��<�oo��%)B��Ip�r�hƤ�,�N�h�̡k ��J��A%��t|8��lt�~+]�)�V�Y�P �"no/��<-�,!�����i�����ؤ4���%FnW���t�_Mb�ev��y5#>ElC�$ʂ/Z�)3��{0r��{c�l���V=� g��-v��=�4=J3�c�W{�ÝT����a��d7� �D*�x���.�> :j��/;�{�F>�M|蟥,V��;�?q��Ю'��������%el��7�:�^�	��t�6� �E����"o��i���b;���dƝ�����2�I]��������ЧsiJ������q��Q�ŅM&�T�Zz]�X�C?C	'ô*5RU�x?,M����tV���}�ۋ�S�\�ք��Ȭ��%2��j�d1ZGU��Ro��O%�q�u�WI�QS���F�&�!D;�MO��\�s-?\0v����y�G��0�'(�� �Ϯ��[�1��Ȩ���+JqW;��C��}�J��A��G�@ɷ�G�?"Q��o���(�������7:���~:�����Vp���{r���,8�3*o�;b���F*�����x0�W�������};�c������7b�����j�����"E�%q|��'����+X4yܿs6�U��e��k�)�|R����L��zԐ�0���gWWm��@�fqjξI_0�b��w(�	f�w�_����ˡV�AXW�-y\��݋ª�6�rK�:�o1���B-�`wM���`g.%+0������M����$�>:�s@Ao#c����)pUy>ܾ�\��h0΂��
-�	'�""�J�"
₉�u^X-��^�'�vK���u�z>b��i�v`���� 9��p�Qw��Z�,+l���o�� �ܻ|ؿ ��^�����n�Y𧵌��M�*q���H-R��*���woDja\����	�B�Y^P�|<���".�'�RX0)c7�E4��\y?��I���6��	����Z���s���{�e��0�k���c�j=�"x����Dy��42uVY���_��e�m̘NXЂum�8���0�4;�p7.�xW�\./&I�<�b��1{��ћ8�[v��7(>�)&F\_"��`?��
>��>���\�-Bp^�n��(�n��WTz��'?�zy���ԣ�����:gTN�z��@�_4�Н�Ĥ����co5+^)�%�)���]��Z�x���P3���K�uEՌǴ���$���	�جi�آީ��;KX�
��EQ1t�ȇ|��Aպ�}��X�{c���r��:/�rFG�RK�$��w7�#��m>�����lҡ�C9]P�P8U������E����dU^f�>I"�ߟ��e�ۋ�
�pD�ɂ�즩�~�g�r���ci]������y�&���$���m	A@��YoވЏ��PQ������u�J��^�_rE�!�Gf�l��*׫@3�yO�/g��)ۋ;��"r�/ǫ��&j�# _��L�u��>�{Ќ��s�)S��P`�#(�4�j����D�YU��N�ar�N�aʤ ��J�TL�    �p4.��Si���[�7b~M��>�.��A�� Q��J�O��WO({"��^Np��u�b{��v���[�z�D�!�$	�)�)�����M)�\@Qb�y����ӷ]MS�F�%p�j<���uSW3Fy�d֑'i�6���
�?�VQ�v��I��4s�3MᏢ��t�$6����X&�����]���N�u��d�No�=΢�#��A[�@��Ϧ�M�զm�j��嘶u_�͌;��f��$�j��2v�t�p�4��.�����Gu�z���et�W�\1l�����é�6�o�0,܃��{�vS"B@��I7x��>ʟ�_k\��:�7k�$��ϋ��Y��$w�<H�=�j�+~�\����K�Ϯo��8Û>��SC����d5��p�v�o,�N�q�WQ�q5��-'�RO&eA~Da��`E��ϟN��/f����<���f�C����������AI���N�����=�8W�ߚ���"�ރ�8Q�B�`���g�U��&�֣/���(�g���
+iФ�H�rex�	����!Q�7!)V����9lM�~��%�r��$U@f��3����O��#���d���&��Բ�Q����+��T��3:¼H՚q�!x{}qY���Zj�*<5�������u���ǒ	�h��w��'P03��"�ٌ���Ol5��b��&-��ɼ�L�fi|����Du*�X�m��<�IAYo�Q�w豋�im�g�`�d�L�;d���Y��Y#"5YF3��JU#6I��^�K�i��;�׳X�q�#4SDldF5��H��B�<�ב�#�	_��4d�P�`��(.5ِd����To9��)�SS���`o�Ý�WE5ڠ�v/L���?r$e~�\���'Ȱw����<MU�9Y�dl�im�=���6�ZU�@Ė�f�4��.VO����y3�v�o=`��ը]8� ��*s�sN��屎V��-w�����.�WE�r)MZ�?�q��/�����M�6�qs$rk9	�H��/6�l�8���+ ������Э��@6���b�~I�� �j��7�Uj�4Yr���OS�Q7#PQf��]�%� �U�܎���u}��J�\#���eֻM��3j�"�	i�ѓ�EL�U
��khν�a��6]i���AU��e�������V��9E쮡�]E��q+��B�sݴȃ�]����S�s����ݴe���K�|��8��zT���T���� ��XH�y�*8E�CH���U�S/�~2�YY��KdT�xO�f�UZ����1.^?��q�{Fm躙*�z�Ar��-��mF�����@�
��N!�~v�EHn��s��[�7����T�,���n�N���f�:N`�J',P��I
�z1]@���g'y�oKh���hW���veW�*P����Nt�doDh�UH}������d�z�P��ю:���hb����~�|`������*_�=T3�]u;L�՛�%'Y|TJ�����l 1��㈱5\,�o�����d���_�m��0��<*,�fQp�U����y����̴|���g��MR'-����AI��z� wO쑨c���u8�(˪,|�����������E.��̃/�,��`�Xu/�5���/��C�O�G�3<��jS�ŶRm�6a|�H5�K��}YF��~4�6��mǌk3�;|�j>�E���"���b�J�W��bL��CK)�RM�E3CP�>&.@� �$�P6e�?&XuF"�`� ����p�5�!v\A�}evT�X����Lb�v�WQ�11i�:���L�\~�;�C�6��&8 F �Cԡ������j$=?�_�7�>@*X�3�!��`�f�D�O�� ���Tiv�e���cy�	��r�ԁ��f ��uO�]�0�\�IN���u(����K���kf��E�g���0W��\Lo�gm�L'.�(��i�N���o���2j�n"m.�=Xe)�w���r<�6��R�E��ʲ4�$+%ۙ����ET���1��������v�:����L�I��-���BM.�,�U|��M^?˽ͺx�}��J����f��Y/b�2�#�A��f��js�I3Ɖ���r�8Z����>�W�t-��i]uT���h&���c�p�����m>@=M�FeRE]hs��%{��%����-��Ֆ� ��*�,�E��������#T�N�����	�]t�A^%�\|}ejv92��iE-ƨk���1�(�<��lV�tU}�wG:�OP�_�m�]���� �=���u�$�O�����g��q�v�N���q���OV������'C�mnO6���{��e��ؿ3v�j�.l�z�S�d�~B���i�䡋ݳ�\D0r�� z��LM�螜-�\wY��>�����ԵZ����x�i�%N_Q�Lײ��xΗbP���^m_���]�U���2�"Y����^-�񖷘S�jc$V3�^����a�0/t��S ɓ@�vݛg�먮sy>��?��{����
sY�ǯ|�C7̸Ky�-O�? ֯���w��w\��;�tR@H�㍹*Es���Y��̿�*��a��l?����q�ǋ4]eь��5�v-���%��������$y���.w�R��}�I��_������j��\���e���ee�'���Q >K��	�&pY4c�řj�?��7��L�Ct(��Gj:��/@�P����jgq1pF��M4#�e�%��"�xuY�L�d��"�����M�J{���6��OXj�Ɓ�M��O�,S������<]Z3�e�E����� ��&�R�#��n�7�L�F��/�����f����g�e����@w,�U����{�e,�H�o���2=#��.a8�p�ѽ��:\G�/#8NФ�Է���ʞ�ڶ���'Ǜub }9Yj5 +)����Z�y�r��7݄�:�o����_����^�l����v� ���������dVH2 ��w=��b��]�%3 neU��W�W��w������I!0��*I�s�?���p��N�|���N�U�V����ܵ:�-7e�=�r���������▂{5�r\�����sT���sTD��~��8��5�Jx� �J��DL�Y�0���v�<lO���1��� 2]f���*���NV|�[4��s;j:]Ľ��L#̮�PYo�h>d�n�����	6�H�s*7Z��Yl���E<�<��+/�]$�*i_sQ2����`�����\~��Q!z��?��VC�.��5yẄ�����.��������qw���6?)>��q{8�_{8�E�#Z����Wo��a$����bew[G3�Ī4)|(���0T��"��unoDIZ*#�\��������柀B��>����0�{��]��)b.���u]4t^eQ��E�2��� AsbBD2�0�����#�ɘ�H�sOW9�{W��nv���J�t�� b�#F��E��v�
i���� ��{і���x&��G��0�V�2������^O'���Z�s9��>��>���c�2��o���ٚHv�X��.���(�fqVE���
������,��t�,�o2C��T}�����$�UVP{�{`��1�R�������^m���RAG������J�M�ts��'�����J�y�HO�qF �@j���U�����:c��e��Ƞ4�����/:N&\e*W���2�a�W�bd�i=�3Z�*�l�]�U���K��t����x/}��[�^���t�!���ehY�F,K\�����z���ɨ�������aR��L��r�lL���F6i6U��Zh(b���6#�&���M��:�ݮ��Te�5�)tӠ����~+����b�#}X`����5���#��|f�
��!��25:X��;�<�^���1p/ ,���_��np�ᣞ9a0"�_�x��u᪪��dia��~��`っ�T�Q�\u��l���q��<�    ~0bB1��cѬ5!���cѢ:��h��QT~D�W�� �B�	�#wL����99	XE5D�J������9dod���&��'� ��_��0�Ꝡ- C��EO��o[W���#`p�u[�����ť;�͍«�P�� �/�3���]ᰓ����i�#�9���O�j������M[%��'3MB��e6A/�sH�W��q KE�a�@������	��A_�`�M�o���q��02vbYTg�;R�Mן�_�ZE���Ь�J[jd��Q�ΨE\UeR{U�ϸ��r��Y�itrFV�*�p0@��.�;�#�qv��K�VQ�s���0�v��9��ʞ�M���t����2m��f�0#tE� UH� An��O9{��?��w�ަb��b��4���gmE�$���H=��B��$�7�b������(���Zo)�ؓ=�M�(e˲4�
������*��x"�����+cHW�a,�P������<TN���O�s������;oq�̶����@_$��g�l{�~�}'^��[�kc9����(
���ިʃ�� ؐ�qg�F}������qM�<���ߡ��?�WE��Ũ5@))�!Q��庱��`alV��[��5iڴ3bS&��Y�5<��,�n�g��d�!J"�n!�/>6��p��oq��a�bK��k@��(���dh �s�P�˖�%V�����B�pMM�����{-�Xw��G���
`|���t�"yA��*�qèd�3C��18��/���������hL�`oDc\�C�2�b�T���)}螩��da�3����&�F�c�㸞��b�dCY�Y}�q�sϟ�\�f�3$.ĖX��9Y<�E(t�u�NT ��m���b�tCU6݌;�$�/`�R�-�d����M���_�=8AQ���7��q{���F�YN�u��>���(��BF��<>��q�E�K�Q?�8�)���N'��\��ے,e�94m��3�U�I���Д�o�5
�� n�ȬF�Y�6�Ð�x����-2�~���t��r7nx�iz?q7U�O⥥������X�}��A�3��j���YC_��R-w�s��L�Ϻ�Uvf�$�i��D�
 �]����X~����3|Ɠ�L^��0�6~��,�k$��=M`U��,hdP1gW�
)x7��﹞s��|�c�V��,&�؆Q��y��$-,3����"��Ʉĸh�m��N�� u���US�țU\�����A�!I�\d�ΫH�^�I���m�����9&q&e�1)���4e��r�6��ذ�ߥȒ1M��Ƞ�6�Z��o�,�zF��8�*�
~�Ԡ΋aXA��6)�ql�=�D5��<{Q%F��#������C�u��q7a��|�V�6(X"nU�\�6M�}
P�p���"��k��]"�jE�۫����p���x��gE��t�+��3Z!]���y�W�4m�����.r�W�����IƦ���^g�Pj���f2�7st9��������5�x�ƥsm�֏6�w=g������W�p{{Gy���i��OD$�/f ���G�Y��0�Ԙ�Da��1f���kI۰��bƣ���N�(� �}��ZT�Z�h�W�/z@n�.��UL���[
e�G��ԑQF�V�&un�9s|}�.��7~�O:��Q�Dp��o�Z��#ם��|�: ?��
N]���_#�XF>��cN�;I��L�^�U�~�`�̫ʓ���`)��D����C�S#��U���}�@	�_�]�-�( ��8ֈ��_�~H�e(�&o�Y<��˕+/ȫ��a�3��8��i��]�mF)��*�˝��&�K5mX�C|{��qi�%�ϲ��D>�np����@�	1���0R��a����8���
�L#������qŀ�'��օ;�5�?��1�Q(��lc?��ù�`�R��6l�:�NO�M�,�W�	U��y�>�&��K��!��S��C�"�o!<Gv]��U��_EC��@�<�m��D$}��w�6yP��3N�j�ҥ�u�pH����ߕ8qhO{�fS^���~�p4��̨��-g\}��p�0���L��A��j�[��I1���A��8եs��x��$^�@f"Co�Sͱ��#N E ǋB�hǸ��ȝD�/�K�o�3���������/	��U&Ã���."�+�d�%���_����r�G�P�OתB�f�}F�iE~t�m{#W�%3��5�^�2�cyH�(4�bOh�m�<�U��O�O���w�{��a�>��0Б�'�h�ƌrI\�I2&�]����#�o�䦝�t����2�0��� }=#	�AtR��n�?� J}�d�����:謂�|OWQ��3A숹�Mt���J��0,r�t���vO4�hW�q����{���"�8����9��P׬ð���������XmG���!����qX��Ty�4�����h��y�s���t��q�W\<��F���e2^��4�r�l��=��0	�X0di00�F۽K����N��C+���t�8W;�ɬ6�]j��"m&���Y��c����h{��7�@Ü`�gLS~ǘ�v5��#���3"e����~Ki��&$�u�ĬY�2���_T��Zۮ:�!�7�_�+��._�҉�s��$�5�I� �0����O��˂PŮ�}�����,1��FE]��>%�����X�g"�~�a��2�aw~�ݓ�<���(Ʈ�<��t���̂�%U�b��*���Oc��o)�6*�4JgD��2{Ͳ�O�p�ppE�"�jCm��{���B�"71V�Q��=��t�|�ܣM�g
gz�7]o���\�a?q��yj��8��P���Hw�E���D�8�v����f��Zo���i}5I]�di��WP�Ñ�A�&U�W��ȇ�<��J<�����Dv��r��\���>t�U�ݾ�K��ؕ�L?[YG�pB6d��hsDE�밹��b5�r���Gq{p
Tp�*0aˋ��}��1M�]k���.��k�B�L�B7��r5����yۨ�9y�(c� �I�_��T/v���|Œ�zl/C^��
q����w���k��lKr���[�d�']��~M�֑�����7{�5��:b�bKP,05��Ѳ�l\&+��
U�����o�"�;��K�ے�M��K_?ʴ��zc������t��q��1��P���g'�_��_\�v�DG�3������dD�aX���7�!�tݹהg�z���m4�u:��.SS�Oף�/r�p��ȉ2�!��ލ��,J�,,���v��fӳX�GQZ̨V��[��H�d�����ʜ�6�^L���㤜A��N���$�^\I�#�W��Y�꽟�+�$
h�b_���J�����#5�����q�����_`��$U���QΕ �������1:#f�ר�����h5��b�K�Et����w��jI|&�3w�a��Ӟ�(Y~7gjb��ŝ�\��<�=1:7�n�>l��UEx{��Ʊ;�<��9�Pښ탍���B��M�D\�W ,�v�y�7��T:\I�@�he�"�3Ēƞ��/��5D�#��8̀��漍��kg�\	(�2�,hW�����!�[jw)z���h�.���چLD��P8��9%`<�@/E:k�*�]���3��������؉�0���hDH)̰��^���]���>���O�(O�K�@���I�"R}��T2�`�:]b�0U���Cr?Q���0U��F��[�y��~��Dt�=o�E�?(�E�,	��n��#��j����mܖ�6Y��gH��+����x	�nX�b�&��p*iQ��eلc���H�]�u��NP>�'���^����bmܹ�Ψ�\}�j������g\�
�酲��p1�WCn�Of@�2��.�4�wa��Z�P*����<��H��F���.Cp��1X�6}}�l��m�Gr��G7�`X[v�n$WW���2��O�޲'���y�rV�.�ud8?	���GBTQr��ځ�    ��=�^�6uE�w싌� ֧�7����-�h0�m�輽\��Ћ9i��\Z"К���"N 9��|�A)0Dp����6oPc�Hώ�p���6�]Mg�(è\$�&a\'3��**c����Q[;���1b�>�}諤����l����]��W�q�&Q����U��<�(��߷���!��di=�����j��b�C�I�,���H� Ʈ}<�'�n��es$����Kח�CmG�f�V��_�$U͈W��C+��@�������-�����~|8 �m����/F��r��N�A��8�X?��M?���I/�	Yns�B`�"ʟ8�%�6G�Z�a�� �4V|�\ЁC.K0��z,��^3�j�t�g�̭����=� �'��W���Xv=��6
�N��\���]6�ޑeI�8����m�QQl$���K��y�N�@�@��������֗-��L�2��P�*Uk�4K�߱����	�G���.�n�m/%��}�ySF�?<��,�G@���_<�,�=�������������}I �r0�S7W�>QyZ}<i�#\b)��l�d�u�o)#b�4���,�Qd�q�`�E�Z!���T35AI�jE�K��AN�;�O�C���bKa�P�q!BS8�v(-���Q���͙�G�\U6����k葳�h�J �ړ�m���t@ۉ�26�ja��䷘N���ݏq:֭\�t�1�b������^إ�P]���H`�)��8���G[)�L�:A��Q>��3cy�WK)�A��>��$�2cW���4��#M��bDv-s+/}�{B����o=��,_-d�m���]�!sMXeY�>Oܥn	�b��# ������O��Ƨx�[����ErU&�^��"�?mJڷ|㉵q���䆐>p���^��b�F�df�:��y����'r�\��g�e4M ez���2����
(%#��d|��@���s��>C֏�4D#"��:BE��N娐U^|�2]X �ݶv�Pqf�#sHQ�p<`��ب�{��=�/b'�1��lݛ �.\vb� �A�^����3ިC���E����$�O�_�_\� �B��hk@73�n!o��8�*�2ӈU�H�ۋu\t���qw|��硭V�.�QY,RL�q��{�!��`'i�@"A�|0�I�0���D~�0li|�3�mY>:W��C�!ʋ��1�uyYVseZl���a�ޫ����t2����zq�TT�,@�Pش����[�Og=��B6j�k��&��*1FT�h�1M��u�9����ێ�>��c�7`KX�4C����b>�m�g��<)B��i@@���dTR�NԠk�������㿩f�#pb��T����?�Q9i�,�����iQE3��y����{,�)�*�*R��Ŝ���!d�|�j��ńW۴,�~�)���pcy��;��~�@�г�[QH���b?u��^t����V�Uo1���j�|F���窃i���>tjˬ4|B�//2WT|<[^'i�t���PTP2���w�[@�u�3�k��j8��e𖅡�����G8�{�F�4B��BQ]�)o���&wD�;˻�����-�ܐX�������^*Q�(#[�,���H�����s��`�).OE��d�q���7x9o�tt�@�gm5.�iP s+Z���]-�Rtp��~���s�/�4dAY���u��wg΀.$�\܅�B��EL��߼!j�� �b��k�������U��`����)�e��6�#���Dϫ��piE͕HW�Ѝ{�,���w)�C-���2�����۪3_��^l��v�a�} �����a�59�5��o519>(��>�y�@�cX���������85���<�6�;.ƷZm+�\&��8�Q�eU��,"L���LdQS?`�N��d+�vM	��
��k5�T��ӎ�_/y�)�Z8�	�Xm������s�y�g6�-��+�E�YOTW�����W�1�m%Ϥ��J�B���,�xM�����(���S]lc��eW��)�����$еO�x=�#h�>�ҒQ��"-r���q�_�d" bBy�YA��
H#����.���w��
�
u��
a�>��A����=���w}�V�
6n���tJ��a���N���r6pv�*�͠s�=��VU� kWr��<��*�v�$i��0%�����j�t#�65�\�f{F�S�_���t�H�X
Ⱦ����d������rYT�3�ݣ�X�Z���r���{!��f?:�5
��Ia�B�OTt�d5��Ŕ7��N�zF؊ж�E�4�1"�3j	I�2�r�C,�O�I�HW�-6D˒��f��8+mJQ���kSXT_y^6_90#o�_�2(���R^�m��ќ��yf)��S:�)���S�ƹ���-����݇^�8To������/I���TM��?x�A_wO�'��?`���Ƥ�q��vO����'���(���ɽ�<�o��1��E>9�4�"��\����"/�(�!��3����Qft_AB�O�o�!�F�9�Ƚ!�Rb�_v�#���j�����	M8�] ��b0Ŗa�V�y�R�e����E�kdQV��x�� �@����*瓐r��JV�B�ݶ$�n�F���6�gY<�B�W`���b���p�,�q�,.��
��Q�^���e�^��m��_0"�l:�~:�ܿ�	�ݭ�r�a��M�Ȩ¥���}9Sd��(+���%�����B&\l�Q����a9�ݝ��8�:G�K��n+8�b=���l��Nf �\��l<��"�{)@�L�:��|s�a5e��noݴ����H�o�tC�:��4Bz|��s�r��
g�����뇛�]c�G��lɲ$��\��!\+��O�@�������-A�*�t��t�a�P�Ԍ�����jW��S�+�.�bq��W��īM�#�g��3��2�L��L�Ԕ����n�3�RsT����r=����>��N���&�`�i$�!<�כ紪3���H2fC���O)�0
u�V�ޙT��8d'�j+�ٸZ2�Љ.܊�����i��a5��[���z,�@�y���HEk�<�~�#W�w�����fX���6�g_YLM�$���,�?�����J������K�w�|�:��m��	*����[�~��<qW��$�"�}l���ۻ���	��UI�����TCX�~S���5�V�FY�t��I�ޞ�$�S=�U�B�S��Ӌ���\�X(\��Ǥ2B��ҖÓ��k�D(kM�(�B@B��P��y	�d=J��]�-����"�g<ki^fZLUq��,.�������LV:���+���[�a��z��f�'�|1r��~,�|�M3'r���,rI`"P3N#D�:_Λݱ�Ìk���C���'ʒW.��LK�*�ʸ��u���0��4\m5��GK�ut�6�>U�m���U�P�,�4�%�aD���m��S�DmB���F;q� N���_���AJ��[�U�jo1M��	����,�$R�u�uL='2��Q<)c#2��#%�����#$a���(o���q��93��
�:b��14�XC��*V3��D��ė۩������嫍�g�]:d�:�*�L�*�7�zb����{�����P��2����R��w�\qϙ��bXW�s,�{��y��3��~JK�U��V�^���& �G�q�XK������c�.��`IlL��&h�z�'�0��i�/zˇ2nn�W����?��G��*4��\��m�E��S�5�����'Q_?�"��k�a�?hF�z���E�4��]j%�\#���t�a��7r�z�2��?�&YY��'x%���}��Y��-u����+�Q�����?�5�q�z4{ �����8wt4���Я��̞�+�O�SYO�})W�D}>#HU^��K���G�i�(E���v�Ң����KD^E�	[�_p�t�"��k�*�sٹ�(� q���E��EН2@jO}R�h����C���rC�"K�a���*    ˛�Y�ٻz
ӵ���=}�'ŏP���Sl�\�(��X������+K�2�`��=K�Q�N�\o7I�����W��Ԋe�I�u��#��<^=��2�Z1�@UyTDF���2�E.&���^�|�>*LI�!��j��A����Q�g�:Ee�A�Wk�UX͠4Vy�����	 f�����6��7Ow
�O���LT}g�VkG�C�u�շw�U���*�o��>}�Q�Rm���:�i�|�-Ō��`F�3���j^Ī��j���j�&i�'�L{-�0x��$1��"=γ��	���w�Q�)G\�Ǳ�]^�e9�6��Єj�"����H��N�[�c�^?>���p����Tߩ(v� -���H�Ʈ�d����B�
��*�bXe(��?���磠š�ǘF��}WW���0�+�u5�*��t=��b�d3���5��B�G�AmO�f��ؑ�ں�@���	*8��F����j��!����n���+JL[?�������ȷ�Rڽd5����jit�aiEQ���8�S{�QT8D���;��M0Iy�zS�����̿&]�>����خ�,���B�B��3b[E�N��4g�'[,Zp�& �<��F� ��������	R����j��b+�2����=�IYd�qa���g�e�G!R�ȇ:�O& ��Kp�����p"�W�xFn�~b�޷L��f��4�4�P�( !����m�W�ۻu'd3�e���r�G��(s�z�}��QF�Ge?#�Y��^U��wUt�{0�
J���ߨt����ۓb����d�_|�a^؄�d���ہ�a���d�0����D�|9^�E�����ҥ�5]��#v�BY��~��l�!�.����{-�<J�E�&,z;�h����.%���q��O�1����ަw�MyY�C�\��0�h���+���t�%(2+B�<^���w�V�7P��	�]j1a-�O����&��91�R���b���C\v |���ǘ�@H�6(�F�Θ�W0X�ޕmն3npU�j��i�'^h���۽%��b��w�GQs�n��5����^t�T�LV�.�?�&�nOQ��6ӌ3�z�S����ν�U!@�m��\>U��n�g/ bF-]��Xl�^�}��ެFQ�W<1`R]/U�Q���������_��&���;q�h��e�߉����gDΕ�va��������b "6N_T�����Gе]���^*����-�����Z��>������lq��e��x��N�/�Ët$�ˡ���HTQe(���N|M��-�~��5]��T?�� ��@:���;���z4M���C>�S3<�]�a�}N�jUy��ݷ)��)���؈}�bw���J����t������$/�*[p�^c�B�U��r̈́1`#��?@Ѡ��pν�����\�^��t<}sa���2��S��.�0*�j}�b�*N��]1]T���-�T�X��p|* #L�\�����$�:R�fCP_��.�ߞԷ�s�x�eQ�2����,[\�~	�*�������4*RE�$a�/O*�"�
\v=����>�a�6@$�#�$�܃�����_g5���I\���Ч6o9�?��0�o�W�۹oMB�[��Ho�"�5}B�I�zg���qc_�ios��'��'㩎��U�Lt�D/�f^��_�����C�X�����^��_�����8/`r���w�
�@�A�%X�^\,Wiن��XE�����,>�g*�x��>sp��gq�-n�.�ґ8�o���7��'�b��@^���ؘ���>�QeE*�4�:R�,�k˺�(\;��`�@r��,���Wu=�����fI�X�\彫�n^���w��<Xn(X�<��3' ����'�����kH���'TBQ��rB��h�]FC9�,�J��?>a�6>��.�R�4x��1��|lC+�O㴿�~�vW��y� ?��t'�wU����a�nZc��L���I�޳0�\>j{џR�1��O�=%�p����S�Ȏ�ޣ|�V�]e�	<W�1q;��6�쩛��H%���% �E �_0a���:��\DX�9�}���^#�I��Ԃ�
a��0	{x�-�O��KޚVrO�ZӨ!�\L�M�z���۫�.��ۀ^��^�ߎ|(i�6��uUy�ݩ����<6YOp1ѻ�.�jF5��en�=�UqM,�UÁ����%�o�i��p��o-�l��b#����f�	ȸ��"�U ��j���ml�e*!R�&�60������۩,�a��a�#��7,e�K~C���Uj�%j�����NM����bX�������yAECU�ޮ��K��慢�*�'t!������i��V3�qTTJ��0��a��/zE9�ww���i#˟h���M��j5�bO{fI}{�yj�Y�O2�����4����E��6��)��Ȭ�x=7�ZAϧ�5_�AX�(�oV����8x�^��.3h�#ata�Ra�*�7�^�f��n���h\J�ޟ1$=����)�ox����]}x����	��@/|��{��8�$k�:ߢ� ��rIq�ע�ْ��nr�Y�B���w�Ljڬ�J�4C����)��"·��]�pX}a0�Q��D�[�t\c�B�,��un����w/�[�o �����BL�p(�	���1'�ap/x�l]��CMT
(�&cvR��ǠM0�Tz��v�q	�ǯ�o��k��楉Y;��Ee�[��U�Vw�W;����u\T31��tԜ&���&P�Ȟ�����"�Q|����ы��Ñ�Z9�T�2˸:)�x������4xe2�t��l�����F	�t��z��s��Sx��b�NL�*l��;�?�F���-�r��a�n	|Z�Й^�+�|��P��m��U*Uķ��k}R�^}��{�Ԇ_�1(N����r�7��c�kn���Q:�TņiU��j��<oj�*�iY���o��{%6\��^��N�G/Y�jo1_���bF�\leJ���z�ܶ.�=>Nz������}M�k�[�T�O:���)�ʧ���V��U�J�<𥉉�.�拴]u��3p�q��u�*�r'��9?���ټ�!��\��2�)D���~��K���D���������Y����s�t=��bs�:o�dFu��(di|�׎i��2D.��1?�:��kM,�P���-�<������p�A,��&�i|$r�5�Z�j�
"}S����-��UqR�>D��4�,*�g	1J4�N=�\#��alV[�.GЫ뼏gTmU�V:����؇���_�9�q���25Y\j@/����|Tt##h��~���������(q?QbQ�0ٍN��o�ך9����^�8�hyƄ}Gc1��e���饇g�jث��<�C����I�V�L���{8=���f}����}������P�����4k!�3U
Y.�%~�ռ�a�IPE���M��A���4q�1�=�]�Bb�}}r?�f/&�����D4��Y&�@-��B^��?����H��] 6�6?�u��o���صU���TQ\D��^���(�J�ӟr?�B©��D�%u��ϗ]8�[U���$TJ<j�X�?8�m��k?EBP�}=�(��dj¼�n\�$RQD�]>_l�$�æ����?y7y�u�F�uHʖ��VŚ���qx-�.�q�h�3"�6o]�N�F3"��z�����U;f��7ZO�����B�w��AT!Q��#��y|3���է���B@#&����+/�R�'~]����I��Q��#�Q[KK&W�|<	�MY�F|'��s%�~�t�C�g���&�g�r��y �� �F�ϲ��$�ά����d�wJ{1f�d��;��ZI�"�F^�h�z�����Z�U������Հc<�MQX�p���;vp�ɰC�1�i��̍i��e�NB$�[�I��F�P�:�
��v�A��1�P�`u~��cI��{���7������z���D���W�!    ���O<i�9�-�Ik⺨o�;�4ό���`0� ��g��5I�2Ī$���=$�ʀ#hu�&V����P�r���՝�I�5I�.�����8�Y�����=H����-�)f�vpY��K�e]�/�m\���H�yT%v����	�f|�y�;hq>���^o�%YkF
5u��>�,��7i�/�;�L1L��8З�?픒P7�l>6��'�̮y�3��?���
U����N�^,�7�� ��ǿ�WF�+8����g�=�o:��k��� �ڍ5�i!A7���9Cj?�7���V����"4��H�u�TC9�m��ç���.��K�Vٚ�����t�k9�,��Ɍ-w��:�a����Վy��>��8��\ۯ2�R32�b�r'�vs|V��}�5:�f�Vc�.Sh���SH��u��(���M�QU�	.j�����s=+"-�C����RS���h������������{�.bMnȡ�6z~����r2����g�Ɉϓ��4���i}�_c�de�T�P��<K7�����XӺ�|˻�����d�ni�;���G�㏟�5o_N��i����&�/�ӫ<ު��X��K烳�P�����֏-��v�r�5MG��c�XUݐ�;)�` ������[��V�qA@��[DvA � �T����b�nM����}{����殛����/�C1qU>�VN'�;Q4D�Hǭ��k��q����.�&�j4:}��r󗏢j�&�o���$�M(/�W`�v�8xSWws���S�B)^A�1@ML�t3�=�>=�M���V��,�k�!�!��dZ�������"�6y>Fv�G]�H	��a�3�PD�f����RrF����B����m���Q��ʴ�(x;Ωmt���#)�p�e-�#�M����\͌e1Jv�f��>�߆+wu�����x�2Qе��8��Eg�L���Jn$����uX]��a���]IL�h5*�ro���3H��`3sI�q�u�~2����;�$��r�h'�2Wǃ2{Ʌ�奼ؠP(��hv��m^'��5}Zqn�L�1E'c�Y�PE����d�DC-'-y���������KZ�Y���MH}'��8q���I����A������÷��,������������b�N o�Z&���ЌJ����C�?s�`r*������|8^X{XkMu������4m3DӪ�c�UE�sU��~�h��&
e{��M/�0�*Z�B7=5@�[O��֤uz{^�B�ck�@�z�O�"ɡ����(P#�~���F�~wh��q"�7��۾�&<Ct5�rX���!�/��{U@��~��wq����Ϧ�A��X���dn��(��Q���Km�ڮ,�����d-�@�L��
�*�D�	$�^���/��,���7��z���q%�(xŝhI��]�^,�J�껯ʹ�GW�嘮��8���\�_��N;t�h�����8����E%���i�&֘w!Us9�������p���Q�}+�h=,�R��.���.r
�ől&�v�y�:G��� @��g/�*� �����*�g�x��n1D]>#nY�G"e�\s�82G�K>�
�����ﮔ{���9����q��[��K�=�����K�s���-��㵴��ZC-�oM��8|����"b����v�y�Z�k"�g�O��予ca��RN�X%AE�=G�"m¨�&z�7�2c�.+�p�]��}�"�`�0�ְ����@{�.�y|M�<�p��(�E�c,��kk.�����_vy��3��2*��-�����oO�zy��3��*%��5@݀�ň�ɩ�I�ٝ��ˇntEu�(VQ��n	�����W�%��S-DT�b�.�U��u��:}��9��<����{�ue��o"�*רU!�)#A\>8@�;��/p�>�� ���~Kߊ20�/E`PN�^ƪ�*2��u��U�͐�]괁r�+�<z�����f.���;�R�S�:_O���
WK�]\�\�z�g�Q'�_�8�h
:�'������LF#z�:�]�3|+�M�J��Kb�
h%;�N� �R� ��vlӑ�l��K��<횥�S��*M��o�P�n�{.Q�j�}:��[ #�Dx5.�B&ൊqЍ ?��o���U��>Z���5��u`1j��l�_tV��z���:��)g`��4�L��]AA]*�+�(�]�(po,���^ք���T�w�l���b��>�$��*˵���೐�H��ލ���	��t��6��<u�tt�\��4�ɺ�������zz����f��c��~}���y�P}~֮ *�
�K�|F���>�~��B_l��դ���q� hx��^����Atd�<��(�%�`�{'e�T���,[�]�ܾP��n�?��������0M=���-l�[T�&Xn�Z�U�aT.r��8-����$���ൈ�"�"
 <�%��aC�-}@e>��0R9���A�����gw���%h��>�����պ}��1U��,�igU�Zv�"�Ǽ���sU���������9����ZO1a1Ro��Cu�%/Ⲑ��������r�*�§�4����_�az��N�G�t_�шt�o�W�T�J۪�X��^F|DL=�r�p�N�.����b�B���x�*.}ޥ3L*��]�J#'����K������ک�$�Q6A�-������׏X�flG�sN��a����-P�rbCez�H>�F	Jk�Nj�b�p>
,�n��{ې�=��Pop*��K��P��#-,���[U�9����ϡ(�l���� �:AA�	�ͧ��4y�$?�I�ς��+x�׳�FmA� \d�sPrߏZ����A�T�w�\�yfWc�,��e��h�*�g6	�,a�*W%����3uR^�מa��#�-ew����>�+�*+S���/GHj�!J2lw{o�A*���.k2c�����$��\3l�Y�y�������Y6#lqE�k\g+R҇���R���Oہ��^	�I�ThUAQO}~J��&�H���V�,F���6i�q,���8����$�ȳ����Wv1GJ�P�Ɯ;���N��i���"I�XcSoƱ�J���J�c4����`�]��'PA�%Uo���I�Y�BQDx�)��>���	����������"��޺r�׸?z ��[���߉�
	�ġ�ɏ챆$R���x��~��i'�*����~MD�LҖ;.���c�N"r��������𕫅o���e�I����
��#ר�8R��Ez��Q�:Cy��C�ZHCq����<��u����G*G�� ��g������kH�lƮ���@�����#dcE	}����2�0!�vӨ��@Ek�
�9%YZ̰+.�$Q�C�;]{O	F=@��z;�F�&����a.�Y.
���C�Z��\iȫh�Z�������������T��(��6�_���>����x��FB�2��*l#�,?�հ�-���nf�*UY�3��	�_D٦J�!kA*04��:/6#ʶ��a��-ʃ/�a5(OM�Mj��=y,pr��)w��\I��z���Ve}{Eꊺ�g�"?3��
ޛfb�c�u�J[���M}AE�I�
�m{uI�h��#�E�@�t,s�W��ĉ~��%�G�{!�h	���[��!�V��y����mTqY�<��{��O��M�[q�T�8�2�!-�K�F��������@�c��
LJ��Ϙ�=n1�m]%q�1��TqKj�x�=�O"��T&01[�,����&��3�ki�ڵ������
����މ����o�#����u�~݉�%Юb/G��D#*^�Z�Ж��W��
�U�u_/:�^�E�F�RI�m9���tu�M�|%%�J�W: b,I>0u'z��>����bm��ua1'�U�k��+�8�ݣ�<k�L�<������G@��PjS� ^t�&`B�y������9F��I����̼+    �餩�"�1�ͻ�� ]����=|�^>�ͪ'���=2����e~����G�W
2��dW����(<������:��5�LQ��E�[|�Q4p0�5�R��;q���iZ�*���7� >"����������oo��4/f��im�%���I�h���
 ~(�Y�F�G��	/�b~\w<���Q6�KL��0��xF)�g�R�,�S/Ĉ=��`F�K�0��2�T!��j�Oa5���v�]��Š2O�؞�$�	�+���O��{��Wx��8<㳚�b8�.L�nڮ,�������z��ݚ�џ��7ǴQ�J����P�]��.�� %�����H� ��9��n���}�·j�j�ōä�MF.]M{��E��:׺�34��*�*��Ʈ�EF`:AR���� ����� �;�F=)�� _��
P\�3�XVs�Z�e�ʹ����S�qj�Ը~����RK��!���)�[$)h��[i�Ă08l�R?�$ 3��jA]JM�˪n?�U&�ԏ��5�ȉsťx~,�ե!�'-�;e���ϽXSۅU�s"TV>BU�	�̓ �H��!	�6[O���o��*-N�oMj�h�_~3���^��c�c���d6i4�hR�.�iP�0�u�h�1~����$�7�G���LC�T99A��,��.ԑD�h�'7��������J�T��yoj:"��������`��w�V[�/��܅��n�W�GIul�����hq�ɣ1~i�4>�DA��m6��W�5@�9��Ôd=}饆)]8�C?�̒�Ro���Nn�=�m^�#�@sk�Ql�_��n�cA�v{��֥��y	1�!`*u69~r/����&Ko��+W�*i����[�LLj<f^�V�<�6I��}���Ms�vs���r�ՕzJW3�Zl{�Eqι���v�3Jz��:�.c��U��Q*�|����i�fd1�]�,��>|�ʸH��M���=�$����+��:�Cd�˖q�!*x`�f,1�=���~�l�Ɵ�+�)���d�c���1���Թ���?OF��;�"�zI�x@�Dh4Se�Q�_~G������*��.k���D8p�C$�A�Cp��e����jd�4�}^��UQ��ȫ����/����G O�ޤ<��$4�v��Ҽ��>�R����j �?�����"�wQ�d7׻`EY���*�7��'�[�x�2]?�v��,剙$	�Z����@<%�����'�P�*D�U��<;�z��pO�/�tdc-do!��@}����i�^�vZR�m~'�Kf�j���TRӁ^3/�m~k�'1�(��5�|���2��o=l�s��SJ+��`C�S�GH��M�j:�{�G=���/D:��,����\��n��]�r�G���~�Ffϧ�qpG�x2�sw��0YO�|)|wU}v�ȝ�8I�JL��ga]h��v�E�C�q��wxB:Ok�Xc���v����8
h��g������k�c��^���`��]5S`z�.�?s�H\�%
���==s9X�V��%��vT�8&+ȋ8#r~j�*@Hly���Y5�X�z�	i���fjd>�fr��e᩸���ptql(QhS���\��D�>'����L�*��q�N�ܫ���i)�K5��J��&aUj�O����EU�� ��a����C�rn��ٞ/"��@4u�m�济�K垮'�\�Ԧm:�Hʲ�><M��Zɳ�Eg��ͫ�i�.����'�P���ح�h/�"�e@�����K��-����*��{��A,)/W��=�5A�r��e��G��xgǸ���خ�޲2����N��c�=����,xO���ߨ[1����~��I�$w`�W�k�}&��g��w���͌k�G���\E�w����I�5�(/f���8掂����x	�տZ�Os=��b��8lۛWf�V
��-~tT�T�1��7��c�e����X��������qь#W@�A�T�(:���@T�?G�m�� �jY|Qw��zy`�"0v�z�K1M;wP�h�	+���׬
~��?~'��e���V��g����l:�,
9�T��R\[���F8[]��2��������4k����VQ��Ay0�K�0e�W2�{�wT��]���*�d�@&gY���t�ؓd⢍Π��^s�Ea�Hz��"�D�*�q�E����	�L�[�R��F�Y�Z����w�]W��sDa�z�8�L��T�BWv��kCȃ������m�>��ք̚V,��2�΢��D�}��2���'�Q��4fI��3UV�M��7 �"j��G������^��
�n>��g�����R@�.�������$���K�k�\������8�	V
���b�r�X\��0�T%�ju�e�����g�K�A���f�N<BiW�h�MA]f�2��N �$̼�w���W&����!��MY���W��gy�I�W��itP`���ޕ�X�?�� �}>q}{A�y^�E,�W��uo�5���ړL!u�D	d!��_�儳F����讖J�r���n�g4[��w��Q+]����ٴU�4�8����òk��Mp�"Ó��n���9�{O��EPI�znT��!	���%���լ�/�(U��B��l�ߒ�E��DRF���P�D��H8!�/ �T��=��sA�6�Z��D�X\�0-��+�������;�ͦ/7fQ�;*�A�������
�����U�&�A���L�G�p=����5���4�]!���ཌྷ�����&V��v��sU�?���r:��:��P��}�0>��/��/~!�S���<��m������Xߟ$mR̈Q���X�'�}�r��3�'���aSz�oG�1�1R�m�0�����>Fw5A��x]I�g7�� �U*�7O�ײ�4�60����&Z��o��uA��R.Y�)[HݫK�InOqXz-�<��MP�G0���������]c��o��3�R�rU��[�!��'�Vu�M���mE�3��jˠ��4��H�aFt�,T˦<σ��L�j�yT��Z*�{8��eV��'�u�.�2���q�D̋��s?�g!�>�7 z{�z��6հ
V�U��IUݮ��b��U�S��&����͒�A�<P�D�]6%`�����V�e6'H.	؁��_]���⌽0"p��0�O�'��c�����<Bz��6�iot�0���sg��I���]
hG	�KD�#����	(�uE�*���g�fnp���D?a���?�P�y��ĺ�����!|���- �_@$���ý�d����O�18t b�������bǌզ�Dt�,9�ך�Z
S�c A\{Z I�����6����/�\� �@wn�����*^�[Ԥ����Ae��˫jD�����F��Wط����U���Y�'���������>l�fr&��K-%q'���P��� �fEr�i�(�n�6�:�F)�-�A���v%��U3*�MS{�82QE[����Ԕ�+�i��t�)�ʯ=�-�������=}F'���G֚}?��Z��(2V
��6r�����NO������"!J���=����B�\���p9�	#oc�k�e+����PQj�j�^nw��&S88��U��"YC}Jvs����Sd��c�nV�w���r6������Gvb��t���F?6��������>i��틖��NcYI��OȮcX(k(�����z���ī����iTޮ�"S�U�0�"�K�h�O��Q{��}�@�Go�����4?�S��3F�q�vsE����Is��Z9���	�܅����O,<�"=[�/�
�K��?m��}��԰E�\�EČ)r/�b�"~	K����<Q{��֓'Zȃ��#��RL�2�b��:�Ҕ��}=`C�:.o����4wq/�79�p%9k��M����=kI2��t�B#%@jA�}u��g�4.�ݟ��h�	�t�|I    �����o�,�%E�G��Y]Ln�ᜄ���ݭ��4_'����(d��UM��x�D�x��x�:��O�vڹ�_}a{�bxP��3�s�`�r��/�X�/v��74���Ɯ�<�R��Z�<�[S�x�G��MW��v���_�y�ɀ�c����rh��p���"�SS9*��q�&�((H�-�S�����j���*����$*�����*��ۍ$��Ly�<��ép�m�&k\���W�(��#ѡ�2��Xź�b�ӎI�|��L��N�*�գ�Vb��dĬ�a������Os��Ҧ�tF�J/<VƦ�����z-Qj������ǻ͇-4)�iT 8��0����Z�m�3޴,�R�I��=�����%�o�<����20����Ï��W��a.3�O;wf\O.���i���Ug6=P�
��>�y%0��V�"��AZ�l9 d���7�H�h=/���#<�Ϡ\�s�%,U���\��Zn������>�H�8ɵ?/��3������7��\��g1������=R�'��@���r�^�X�Ů���ZU�	а���Ӊ��*y͑��ިPƘ���4㕯�o_�uw�R��3�U��+K�*��K�'߁N8��������=�Y���Sw�����+�:��?�^������}�\`�m���3N����(�v�w_9"(*�
O�۠�w����T?��Z�E�poa�rL
)bC�!��.X�_���V:s��������Om5�q�͏l�ؚ�N�r��\��X�Ҽln����t�T���W.�����[і��S���p����/�L�Ի�}�V�~����V�k���ĳ�*f�Y������*4!Q�Pu��d�AB��Դ������1<��)�V�|�2F��y%��X�*r�6Â�&���cd⚋ײ~���t|r�� dC�7�&	V���4qfE���mH���+_�cAU�T��#�;�ۼ��\��$���|����4ɽ�d�I�m��FQ�QJ��?�	t�'��I��KP�z�)�̞���G�j�z��W�]x{���㰤Js�! ��k�]f�{=���zYL����V1p�AD��������Y��ݗ|L���I���n��S�	��ڸP��T�d��(�����Ez5�(���Ty *`��ښ�$6l H�i�Q�0˔�e���2�b@��˻vƉ˳��9S�:7���wV{2�� �>r?�p4Qc�W�C/6,��:ofnEھ�*��27��g1�^�(@&���]��ȵ��#@kJ�mUF�*V/�d}���eT&��࣐0DQ��>�R�Q�^���E7��ۖ�b5e��[�,��ϣ���H+�o�|+��:]���w����F�\.��[fIy��Z�h-�9�c�gT�U���+
FFY5�RA��
u{�����^PetI5�;�~���e�PyR�3��,t��b�1S� Ȁ��:mή��t#Q�$9��,�(���S3f��</���Ӷn�RdQ&��,�?@ݛ���� 6 ���'T�TȤ!�0l��-��V���Y�o�dq�'��-~��+�=�hs�׾�n��c(I{Td�V�+�n�f*/�z�8K�4�5nY�fl-�ħ���_��1Tx0���������A�r�[ �w�eWS�_���˺����%UY"�RC�o��hͻ��O2NRWb��v�U���C[������e/_8��jg%K���Q@�Hh�D��[���#��D�Z5��r�H�õ� ��gFo=E��T������UI�jnm ���|S������ ���Ѽ���=�E9��� pԩ��w�}~0/_]!o�lF7��,5�U�K��EI�'tRޛ��UU�\�W[V�Y.s��p��m�IYDa���r
̈���s�����i L9Fa�u��FY,�sO�$T��4=mfO���z8�'�o�O���y�_��1fԲ��#6G���-�u��=�b�?�ov���'��Ľ<ɆȄ)ҹ������<�[����H��)P�,N^އ�n��������w)��T��A{�6 &�όݖ�"3������4�l�G�����C�-= ݁_m;�ܽҨ�q��8WbE�k:zz�/�s<�櫐|�D0���Os]4CA5�������[���j�N����{��Y����C��������N�bY5C?'fe�د"J�W�
L5�F�O9�ۿ�t��=��(^M�}1C�"	���l��E�[���o����ܡ�����m�7ywl�<!���1�G����_���UN�3��j�w�m�4���g(y���5PDY�s .]{ �0tbU�rO�RON68�Ac�ݜ�qY���Osi�<�T����Ц��V,f<Pd���V����r`;�
/`<j�7P�l��8� ���{�� vS�^T1T����-M0J����Y,y9�`@�	�#5�E��ۺr�
�S����f{��=��f���rɸn��G����d�7
h��7���S@��$��3O��i�K��|5���,ۋ*	�G3�5U0򲉘U'+ҙ��PB
�xyQ���d��՞�ń�������S���n��l���{A����e���uT�'��)*"Cy����Å?����j)��pt��7���j�q1m��i�r�y���z�8
�#	{�iM�� ��W�	H�Dݸ��W/^m)��M�.2�/�a���Jq�B�͵�E3��J!�M|PL�+!�pAe����C��G�g�M����Xg�1�u+;4�:��p|��||ֹ�S���42��1�%~J�g/�F��=e�W\0�Cٶs\�,@��gF9���� ��=���qԌ��mLq�AZoc���O�a:�#�ɩ��,�UV?�1�f�i=�*p�|c�q��x�����$Ö����pG��F��o�4�#?���y�?|ۀ�%�.�tp�C!��q�Vé,� �Iշ�/���|r-���'ݦ�$��#��@ /:s+�ud�J��M&���$�i�G8[
�]�U��8tq\�"\��kס�js�W�W�V}�ҭ����ht#���,c�ce�w.���B�=Ya� `2��L�`e��"� c���?�4�r5t�btƲ���"�bºXj�.���gwI��T;L�zM���5}�U����a������e�3��47/�"۟�C�үA(i�:��gg�^n�TQg� �x��eeU����U�ej\$q�Q��`A+�̏����T�T�L1eʺ��|[��2�E�TJ�.�$�DL��"Ƕ�`%��@����)�}��"����pA_m6�B�l�t��rg��l�z�,IB���{�<o'�u�A���vXVv�I�����%L�	�4L}�q۷�@�X�v4���|@��W��F��0���c$�� &�)��}Ն3"YV��I��������~E�S��{���t��֟/��E'74jMa�����"�Ÿ�����ej9]9㩫\�Z�D����>�\����nv�%��$Mw��T�;вE��0�K>RWEurx>^�H�wyZk:Ɵ)hfB�d���&�5�O�lS|��r��RëEm�ʹ]�|�FYtV�P�j(:��E�v��a�j	"?%|$��G:Q���YҘO ��1�;#R��8�r�����K�~N
��x�C��v���=��x��g��d5��Ť�(.g��a�0>)��R��� j���q�\����#m��C�VʟqY�Q#� '���}��?���̾3A��dgG�����r<�G4QS�@ٗS�'�j'۶�����O���䠰�)g�p=7dZ�	�����P/� �CR6��Zn���x==���A�x�LdM&ޕ�v��_q���2�a���Wa�	�
�Hp_��q9�hg�ɀ2��
-�L������;��1�ԅ ��r1
l>PV�!��ꗯoT%e�ݞqJX�hۖ��;ȑ�����&����~���    j�z�i'*��0q�T&�`|��	2w�W�j5�ŶBU�&3�˸L
���Q���5^�$d�a���x�� n��Ѫ�Ag��#Zm��X�Sem�n�(ղHC�X��F\�=zybo�;���@�>i�� E��0��|���{�2�@���������6k���<���M׋�M�eǷ�O�zP�ZQm�x�
�9��Z���-�}���B��*��Uߣ��W�)d=K9��L}�lyǚ;#a{3Z�y/7)��_6�8�و!M���my�Xwy��t5����U]&3$w�<+3P�y�wE\'�	]O<��b��TN���ar�*�1�B=�a]mJG]��s�4�mYx��"-���e����d3%����dKQ"�����d�dG�櫽��-��m���"{����Ѻ��H��t@)[�"p��v	U�(��p����
E���@0��a/&5V�Y2�;����0�i�[��VG{�TA�b����w��������F#�9�����C{���?^�/���ۖu_��*K��g!y�^e�����$�b$o�k
���y��o���fz��f����d�G��'���#�(�~FX�H%�]�>
�K�[�"��h�ဤ����P�Rd�:���dt��+���Kw��V��b��:��boU�G�	�8��_gՇ�E�i1�'�Ř����@�#;g�h��S[5���G� ��t��I�`��2���9� �҃��U�	a�K�+t�߉����lM�P����D3�ݘ�����*(�"t�����B�]T�^'��>9�b���z)2�T-(@�e�r>n@w��wQ�/�kkї� �Ae"L-؀��2C@~��2ɹ���9Ŭϫ�*a�d5��r�@�v�w Nc��dI�z�j���rN�|��MS7�����`9D��\<1?�/h��u�S�WI���M0$��x	�	�"��^�@�8�R�rtG��i�_������f�0���̢0Z��t-܌J�J\-jâ�mL��E���P M(��:���쿓c�=�tT���a"���-Ac�N�����Ē�\�&f�4[EՀjI��-��~d���_�Eѡ:?Jg����-�v=\�>J�ۓ:u�� �CO �-@D�@vFB��4p4�����f����������(&Q&B���K�� W��@nv|�P�.C(ز�v���C{�up+:�<���V��^�y�ϼ+|:�����`ď�=c��^8;"i���ծL�,l�>���ؕ`�x��P�'@9�x�'e���.P��O�ui_��-��`��#�E8�H��I$�����5�z�k���|���b�u�����ǡQ4�2�UM3���l-UW�N������:�f����=/v'��g���;��U�o��f��.���|���BP�q}Bݗ�<�gZ�s��g��jm����&i�W�] ud/�0��[f#�o.����yzx�`��׼��-��eD ��T�ȭ����c֦I;#re�x�G�kao��Y�F��O3��v��B��v�l=䀅���{�;�
���sYm5��|X��y?#�Vajb�!\55��u��ۺ��M)����WH��+F��?\����|���rs��]��������0��<L	垼���T{�����/�#��s}��w�!-#��'ّ�u�L��f9pԬ�_J�)݈(��+��Kf�N4�}p7Vٙҙ"L
8mM*\~�*�qin���I�ƥ��1^�k9N��vF��4Vۓ"�BATL��}p�w�$�>�B��c!a��zd����D�И���X=���	�MH?G���"�GP�3�r�'���*��^�����(C��ȷ+;�4���J�8D��d��h��D�rԛ��+�Tl�TOϏ <�g]��~��)�X�7�?`e�F��ӓgG1���qA�����1M�z�΋Ἓ�(����'Qeo@>z��p��]������Ģ�cR���	�ϑ�
�J*"���E<r����re�K�q?'��-r��W
�� �:�B)�df�r�pN�,�~�P=��g��/�ݤUts7�b��Q{r(�`0ߣ|��ǽw�`)"i��=]Gl�H��V��2[SY�f4����bL�&k�tF�I���xy�.��{p�a�|�v1����-+���]@�"��\�	��.p	�cJ���tS��O�GY��w����5�����g=.�Z����y����2{�f���^~[ؔQw���'$�(xG�"���F����fpzG�?0�!�B5������z�x��NS�EU�Z^Z��9��Rg��o~J|��9�Bה�YM1/�2Z�An�)��#S�7E�o��U/���Rt�/��A@eQz�ʣX��[l7߸�S͸oe\�v�hN�ՉQ8�4�9Q��졧''���y�^ŊFŋ��{kf��*NL�����~�~�؍��'�Ŵ�8={���^��# �׷�߉5�3y^��1l��I\l\��qS�3[�=by����H��׎������Q�Μ_��H�i�'�F�H;"��6ہgSA%HSu��^����/@J�CbK-\�G�����7�o�X'�3`b)��A���GJ��>�L%xMJ6���)����������<�fTc�KB����pЗ��ݶ�5d�a9�
h���o��QXF��"�h2⊼2��] LY&_�q�ڡ˾�oL�E&�S��� MPw�����V� ��כ01�I���}}��R� �V(?��:z�C-SǶQ���fQ���U����9��F��	\?�!*lw\�1��]�(v�x��H[�aj�>)o��D	ȭ�2�maJ�թ�Tb��ﬀ!�!�8�c�/��Z��i1��6o�q!`e�X���G�<�jB�T�r��Q�S����r=��b �6����9Q��@ob�#L�TG�>T�(k~��p�����@�����ݕq��-�W��V���ĸ���p�6�Yj�B��d��;su �"�l���碋���ՙ&�=�w�q��"Z���mR�>���X�e�ڣ��i[O�4��6�/e�<TL�,�>u���^�Xi _SX�(��1���#� �e��匈Vef!��̳�G��(U�mޚ�,\��g�:_D#�aJ_�jD[�u6�qMc���2>�D���&P�L�/�v�	���خW��M��cքM2#���ie�3�tG�h�p�P�J�����'����"�@��h_$Nc8mS�戚�G�Z�����m����y�Ȃ[�'�r�@���� ��;��R�u'��>R-�df�2��� �W+?�Հ�����.��9�,3�^�*��o>w�"�r�;�'nԟ$��2*���-X��y8�~{ﴱw�p܋�Fs=�Ý��ޝ���?`t�&iX$5P�)A�C��N�8V���/�
e��^��Q�j��"W S �>��w����e�'Y��\�����!�f�	�먛q�����U|�ZiS��gw̎�a:P��r'��be��F_������fx�9�}e+���kT�1��!�:uQ�G�hV^ɪJ�׀1�r�Ā��L��[>
Bw�Ǆ��v��/@�uI��nX5�l�R�|v`:�v�8�V�/��ҥI4c��I���}���@�1�l�À_6���W%u�%8I+S;]Ft�-�r,K����!΢�|��<�D�2ݣ�V�hى����gOx�UV��5l?�����Yՙ�l�Rv��?/�b�	�܃e�,�gS��t���'�	7P�g9�������_���sw��}��yh�ժ>���ޏ��}l�*���g�l�p)`��$?�P���Ӑ��d���;�b��p
�\ƸX-5,����&�o_hŠ�Y�Vﯨw]0�$��E]M�l��3�E�*[Ss6����О�;���7 j��쑫G�G��hA� z�?i�EB��P+��n��;öo5H��И�ѩ��|�B}���-n�(|�V��)/�l�� =��FS5YX�D*!��w�S�Ń[�a��h*��ܻo���#���dW8�H�    ���Og�r�I%����F�RzŶm����og���[�@e�UO��&Bjt�;�ee.S���:]~������S���(�Z�9\?JF=#E���n�a�W�=!9=�B��*	ޕ�o��@��}>��uǏi�\�\�ڴ�f��*7��2��� �S'����415�vϫ{1�́�$V2��$�,C{��nj�0��i'.Q�ޞ��0�*�h��{ۊM�s.ǣ:��} ���~�F����^�����Qmq5��f����b{񮯣��R*��4�`���	�L�	���Y�<�K�h0�w��pN|�eG04~Q���J˨�96.��&VzY"�Z�Q'kAG'�	0���R�0������ Qh�Q)`�Ky�y�$�>o��$=
�l�/*	�b��sߋ�]�*(K�o� �O�k�����ς��6����+���}}F`/����(����~y~��Kl���%�%q`tc�x��y��e�����-�,xe�HV<��s�BL"@���_i����,;`�oe�!���Ȑ���z�A��W%�'��a�5��(
�'R~�}F��+��5�"̯0l�����~���s\��q pE�t�����h-�~+�ȅ	��S�*�?�ĉ��q�����q�����m�~��{p*�78���n�A$��Gq��YK ��*�5ԴgePTXB� ��&.�،���*-g�2Ta�2̃�
�QQ�puC�~�"�1/��M��oKQ8]3��J����W���)YL4���f�2I�$��_�����U�� J����v���İ}c���d$C�IR���y�4�|�JZ	�c�享����=W�G����o��n��=�'��f�����6#vUUZ;Yޟ��)�g��E���[�P��ޓ�^܇�o2l�b���ʡ����2�e�RF!F�߃܄���og�z�Z�E)|�n�r����&"2�H�긋0��d�匓�g�B0�(�v�Y�\\�E+�	꭭O�������o�_�
�e�X��\#�b�6V_L��/�9(餈3b�Q��3=b&E���}��<1JvA_f���\_�i;'2�#�iN�_�1��Pr��jpu��z��^?rJ�Ą�CA���w��k$0���P.����ۣX�U�h��5����)���F\㸇	p{�6�+�Yy���C��U�)ٴ�5��B��|�y�$ut;�7�Rk�,P���x)T�087uH����j��̷[�va��g1�t{���D�yay"^S�������:Ұ ��Rh��16��([M�|1%�������+��0��Y�M2�<S@ϐ����� fط��f����j�]#�%E+H}��tQE���^e��>��p���b���f�Ө4�2*U��	7���2�&
�w�������D���j5�� �=��g�����"��eq��(�F��[�Z,;*�
��R@������Æ/�*[oĿ��w�#�Q��U*.������o��ß��@�z�r0���J�*���m��*� #���^�/EC��v�T�8��)�l>�,o����O�$���D��4����2�>���(��9�r�]yٱ,�@�y��蕫�9����8� �ۑ��uU�II4}'f�M�Y�Ң���7�W#'�gl>хT%�i�b�?�����(�ӧ�#i�&�u�`������3%�Z5��. ����]��~�0���Q|�>oC3�T�$�s�8T��p<��������}~�O�-�}>���/t��U5����4�mG��a�`���a���������ՔF�z���\��8Mi���8�@��|;�Qz}����Qcϼ�������L.'H�1�/�9bH�(�}��s��*�$���V���HE�)|;q��OF�"ts���ΌT���{9Z�u���4O�'+c8E�"�<*����9dm>O��^Lх��e�� �)��:Τ�&1���'�<(^�a�o��I>K���}:S����B�I%f�.�LH��ˣ4��s��<�n��?�Џ�n��m��i���N~OtK�V�"��3��p<yGcV'�� �~�R��!�u��N�긪r�4&'/�L���<����yv��:����".�g�]ree��֮�2�J'���\	�>�Y��ډ���.�L��yV۶.6��4Kg<�e���2΃�r+ͤLe_{-p!������ !p���V�f-���<���r�N+.���.�qx8^sH�W�+u<�E�W�>.6`�:��sv�^*F*��0bݭP�p�	�K ��g�jKg�{�ԏ�js�� �CSE3��Yg6m�����tb��:�O���ټf����V����O�����!,W{��{��>�o��gQ����'a��I<i���5� u�0��_ee'O<�+	sM�����aC,�(�����r����#�8wm*�(�G_?L��zL/���~U�T�E�Z���B.\d5F}�.џ\O�ɿnA�v�j]l�?Y�ߞ.�8��h������M@��-�X?x���G~����ڪ�a��3��Y�$� ]&I�Z�^�" ~S��~gm�I�+�����2��`(�OV�I'&8��X-�YR/29��?u��6�i��4�Q��x{�JS4�v=@��G�)�Ypt�T^<A��S��b�Ҳ*��K�W�n�q�^�m^U�C�1������_������\M�r?��4��25��4��ۧQYV��{S&y�y�$V���#9�����c��6�>��^����>t<����Y�۽,���I�����U��x����6J�/2�D0v`'d��R_VdKk�������h��"���tuh��x/)��`e�M)njf�j��1��jua&�T����x"�MB5P�`�ސ{EŚ�R�چ`nȧ�=/�=����$-s~��"��l1���+6���WZv��iq���3�-q��Tt����
E�����/_oޓ �c�g���ɿ�Q}%�"{v9bv��jB�Mf��^����E��aQ���\Fq�}n��7Hd� O����K��'a�X��eW�U�Q�S�z��K ��l�9�IY��H��x/��Uh��	iq�|�tn��2ep�c�.����z�ϽN���2���j��^����{��hU��w�/�.���qJ�u�^M[c��ڤ�PMf�:U�q�E�]履��r�Ʒ�-
ZP>Xw#ә��;�pYAE9!�" �hF������ۢ�n��(.���&�g:�����z`'g�V3�^�҅��S��G�kf��T��z�>�ʪ�},��_�J/M����<Bn�闅\��� }�����k"��f�{*�]zûLx�DX~W����B񛛦ҕ�R@z���v�5L�)�/0�C��S}
y1a>�	=�S�v(�q������~B���𔳭;Hg"��^��*��Y������f��`�ltL���!�6
�G�&	:��6f�,�I������!Kǚ�N���_�(����a��'YQ��*̓��u�Q��+��OZ���<\�j;���(J���"+O�2���\�0�����X���0-u]��WK��������eX_h��n�W�~��'�[x���D�¼,���?Q�����>K�0��9��& {�cUU�u� ����Q�s���STN�T3;]&07�������n$!��-��ԕX���]�Qb����Q�ȃC��kk�O#���"iP4�z�5�X�p�G!9�ol�QÒ��=r�Y�KBXqy��$\�a>�V��՚+C��م�:A�K����c#3�~'�g�[*�:�v��:,�VY7c$��]���,>��to�i�k�wjp{ߊ�y��+5���b�V-�Z�Gu���aZ�V�e�o�x����+�L�ʫY�P����jwU�f2 qS}�ޓ3֕��G�5]�PY�䴏�:��o.0?�D�v$�׬�����7�G���m~<Y�� <[�-W]�Z��e���m����Qġ�l�Y|���]Ič
7т�Ђg�a>֧�,BY�k�*�R6Z"    ��uK�n�;��*+�W�&-W<��=�gD��ly����I �rS7:�<���p���RW]�/��Hd'�1�����3��h���E�E���*� �14,�6���@�ND;d�Z$��rmf�E�"��P� y�. ���� ����Pɘ)�ʁ�V���P~�e������z�(<�Z�x��>ve��Ox��ZL�Q�`B�����������A��06�!*�uSv��/��*gX4YQ�t7��_��Q-�p5ˀ�0�}�4���"w���_��L����P�G�Q�3y�7pE�k��[������p�rv�C?��Dd�	[��@!�B�eFa���J�q�`�D��o�3��A��1s7嬒� C���;�>��T�<z4��?'�
��З1�����ۚr��"���1ko̓��f�ﮣ���?jo��|���rC��w��EQ$�W����gUi�zd\Ώ�ٿs����"��&貘���qj]k� Fs5ɋ��v�8����hQ��`���&����{�^�5��J��٦�V���k2�^�LU[F��TË�ݳIu����_*���3��Z#��z�ʈ�y6���0�=�l ��G\E�
<�����{a���`Y߈S
!�����dݤ��^�����3	GPl7��Xw�K��0Q	��G���]�
~���S����W�������5��R��kI?���'9}�}\���8ɮJ�9σO�g*Ly�w	I�I�r�y�_�/o�i�θ�U���n)[�q�wp��A�V��SkP�#�W�f��4<���e���	Z	ù���r��J�3����i��e0J�P�e(�44dδ���g�,��v��'d�V[g,�eꢙ��)��U��*��=���<��ݜ���/_E�i^N�M�+c
���]�w�R&���="��,W�e���2�l�nF�QFE�V�e_&9����>����{dS���[9�;�8r��E�����epL�{��Z��`"�(��g�=���'�k|�K�˝2��ɑ^&�\�G�u���J����l�ݴPx����@Q9���&���4Q�Y'�J��ZFI��z�Z��U�_{J(	�*�<��G�fީn��%�rnla�"��@�S��x#V�Yv�C3��S�yd;�"
� �M��,�� P��-��y���w�����莞��+w�/����}��h��$.m�^����tRv��X���	ǋp�.�0�G����fS<�a?#߸�0\T��tl�L	���:v�]�'z�����G>=�9�v�"B-�afr��<�zd���k�$L�<��"�G.�`S���	�L��\�щ!g9�%ٽ�W�zta̞L\J��Ž�D�R9
K�������ՕN-L���iJ]6-m;���/�����/���XA@܌)�n�C�Q�v�<��Pϩ��8��Nualxc$��@�+H6��ys��*nJ��j/�h�Âz�;�w�Q��q�z�s�͙�w��ඤ{eZkr���/�eXmG��=��}�\���iu�oU;�l�(M��:��m^�K^I,޿n��_��b �4a�-��ŧ�w�� ���_�H,�P������i��`���%[m2�?�毙#�7��X�,��\9��2L��{��=g�4y8ժ<�����3��C�6ۻx<l�Ry�S�_RN�'�.�WIƾ��Ax���'�OT��3�ó��s�ZrZ�Q���P�>�,�0�"��$l�9��z"�t<ȳ9�lsЧ���z;�������d�-PI�s�W��AE�ԏ�2h����n�n�8;g�Ws	Xl�dI>�a�,C/��������4�W=Ce��+,1Y�U~1"K����@Y���I�2b���L�c,1�[!YԴ�O��r��-)�9ʀ�{Lb�le0q�pվ7�hOGZ#��Cj�vR-Y����F-[LعO�v�n�Tab�yIg¥D�_LZM�2d(5zW���+x?�|�7Q�y�q0n�T�3~2�MYXp�}6X�"Ne��Up;�⛅�H�e" �?{�`k%����Od�z�\��7�ϛn�7�)���*�rcF�I�퍺���,:,]�Sʹ���b��z���<���� q~�`r��WY2���˸ƫ厥,�������*���nx�r�|�8"QM7@n�z�l���C��㎔&k(�E��3z�I�,�6I���n/w+����]f����p)�Y}��K�V�P�$*�$�o�vt4��,ϧ �j&H�m���=�u��V�-%��'C�
�ۣ�fq��M��M���T�{w����~�k0�L��z �$��n������6��0O��:K�M��d�[k���`�J��'⃅m ���_lӔFuS�^3Wy���,�_�3z��{�;3 ���,D&~(�5�M�"?������3�p�K��=���$�.�vL&���dU;n1���G>>�����������/�;$�E�Y��u��ss�U�v�cAy�:҉\��w̶cص����X���r��.��t��q���ɵ�U���d^]l�h�Ȇ����P���Q�����4��"U�'f�T��;yqx��. "Z���"nq��NG���k�zY��\WȺ���*�<Z�ж3:�2	Mm��L8��<�Y_/ı�vX�=�����T��5v�p�!�bD�4Ϣp�Q���j�*�9��ض���#�<�t� �nLfn�%~���� b���[��E3j���MʳJ�\0���=R!~.�QL��lS��$��=l�6�փ�.�ۧeŷ6��$�2�b�r���XP��^%��gW8�F"��m�����׬.,Q��ݗ�:<cWʓ�����R�=k ��*QW����j���� ����� ~><Og�����T?�'����'��7�֧������c�ҕJ�s��-6a5���͏���$+Υx��>?��Q==h��WR�?�ܷu���w�6�w��ȫ���]T��7�j#������:rWZv�?�#�h\]0��%V���^,η��T1w�լ��g��&̇�7��\ہ*~�ad����Ɩ8�S�;��u��#@�%HQ��$�(U���c1Pr�F���GĬ*�i�*����12
�z��Rb~i�t7+ӹ($EfK��)`�U�Q�8�?u��P/�o��E4���"�b_wU�+��)��C�XB#��JjQ��Ρ��c2~��ѕ;�}+��U���k1}�t��xF�t�_+���ǻ�n��9'Q8o!.jwM�J-
Fh=��b/Ovi?��Q�&�(�Bi0�7���ӵ7gUA.ڵ�ƅ��f�|�P����CY�͌7*/
����8�t==�_C��(��n�;a��O��*�
�?�#�2xGø�r��(K��fp�c�'�]�$���@�I
��6y�w�W~�	��r��� e#�����m�?�G�L*��Ua|��`�0��ڨu����(�5N���~�Pv﵍�Ԏ��ZVY��@$����G$7^��pD�NQ�2��~�������η��ӧ�>s��ѵB@��35K�^��«Ù����U:M�'���j}<[��n�4�|��IWZ��|$��L�tO<^����T����h���'b���s}�ۙ�v;�>����\�
�R�\|���T����pO�5��ʉ %U�d�FwfWc�/�fw�o�'fwQ�"�0���]A��>�	zX,�܉�JYD���.��� ��,\��JW��	�+����F��p[�o#�k�*�����������j�U�P�^sEQ�RVUX�N6��-���/[<h���.�3�v>n�F����YM-�����V>.ph�-��h�)��D&7IЦ�`Ùς
8�ŗ�͌�j�O�TM�����ᜧ�=�V�G��H�����	��v��\�g�����#T���םՀL�ms�hV/�қuY�>���$V�PE�����ތ)d�l�X������2[nD���&ΈH��/�����X��cPE;��^>�1�<�����(��������YL���A�ˊ����U�8    E��!gG�rX�kW_j�,~���7�91���b���(��9�/ܣX�@O�GK��ų����+V�z�&��R��1�1frS������I
�\T%�7r��~��>(��� cl���50�"���<���"�8R���IK|7�{==��S�DZ#3�zB㌱���^Ҏ���R7r�Ԙ�@'B.`�����D`�yw<�h�F�#qu;I������U���QP>�P�z����)���@�4�sƻX�qX�ΰ�ŀL,�u��e[�)�����4��Dw9Vt/6�ϓ!�f����Rk�j^Aa�VZT��]��V��@లWh�\�{�v�9��ճ7�	���n��m6� �ܕ�]���C�I���iR²8אvG�E����j9l�;Dyx�~ !�6�Q)dy�=�X�UB�SE�	�2~��f�j��t��.��ǐq����*��
��J|�=7����%��gy���$c����sbST���нa��%��'%�n^˚�ad`�Y�)eLW��,Ƌ��0�Q�ű{/�'�Z�y�a�#�_E�ýR�y[Z�����R�n�t#�V��i9ۼ��9�V�`V�q�	��6�����i��ҫ��QD"kNL��o!�s:�����(xG�d��̀F/w��i4wcV��8	~�U�S�5 t�t�B��D�oOԮe��q���Wlٱ80���:xS�c<���ۉ���TE��]�v���o���7�OT�:q��u�K�OGO����v��N�E(L~�j2\��X_B; ��ɨ_'�
����"�ޣ�MC�Lj�w�啳�S�#8�!�E
�|���30��A4y"M�F��aZ�C�I ����k��K���qF�D��U��BB��pI�L�XkX�_���\�?S�x�^"��F�[�?gF�gY�0�*�@(�np��?������<���!	��[E�ۣ)e��Oc��9tCs���]�k��s�#��,4�z�% �:�:�[?k�$�k�R͌�zb�����Ouÿ�\E�����;J��$~�z3 �j܋���ڮ�EKQ��[R����Q���<�s�Q�H�S�ƧXm'��j�H�x���>i��U�^��H��ϙ��q�ĪϽ���;�Fb1֫�m�� ����۷�q��6�I��8���kG�I �{�z�H3<堺��&�|��b%�$�j�2�+�EEV36�I�j�Q%Q����-�%+R�:�� �D�I�m�~�п|�h��]r{�K�0Q?�*��#*Xd�2����`D_+�߂g#c���6J2�U�f�"-l���I%������:��8���̺U8���J�� ���H�.�H=�7��L����xv?́�:ȣ[� ,E��2��L�Q�@z��>y, �}��,�F��TF�t 58;\9�>�'u5��rG�pP?�qiG,	~�҆m�������2C��e_L��U_I>��Y�k�������F<�{z�Eqޢh�^
2�p�ᛍ��<�'�d�b1W��Ά��+I���9F��\�l\�Qu�c�)�=x��Z�%���j�b�bES��s�$�L�Jr�M��A�w�_N�UQ�ғs���1�:��e�D̬�vǋ4܌j��8r�&�h����*����'S���h^RW�,zp����ѪG�6�!d����(�b�Q2���"/��X���p'Џ���>�0 
 ͗Qt�qj88zn߶�<Q��7�l��:��2�,ʭ���7^2i)W+�*�6�v�q�↫<�;\�#W�\�8-�2��9	�H"}�a��\�f�(��W�vT�ǫ�����P��� DcF�Z-j���˨����y����Hi|ܞe�>��r�BI���Na	w��j��..�e�i�PY�{O�@ĻE[����0�o�_I���!�Q���%�z��d��+�� ���I��W�E0�#f�����^�a��x���'�p��t�P��S�jI�'����}E����z�9�)�{}!%���ؗi1��} �@����F��M��i3?��9�BxW��4�~1A�k��E��N��$�s��ǎ�G�B���^U]��� �Yty�=_4#r���o�L�+�ax
X`W<ԧ��w m�͈S�D��?��m�=D�FKW[C-G](����6��{�mL������FV�,N09��t������+ۑ۸���W����QV�؁�R��� ~�:C�7����>uνERr��	���3�s���]�rQņ�*>���ux Z�ho 7�"�j�[PP1�?D�>ђ��8zQ]/aT������D"E�g^̝�WbXn����ԅ{>1+E�&�U@/�����70�P�������%����\3~Z�م
�,�r�ԡ������'P ��S�bbYe�#!gߋ�tA��O�j���h 	��ԤQd3�q�Y�=�p2/��ݏ?~���K��qi�Z�����)lZ͉���G&�w�B��P;_qE�z~q��R���o�w�)'b�x�;t�w_����܅ɤ+]�e^�.7m��2��I<q0-��L�de�
��8K�Y�����;*���6��b����3_�
/�2e�ϠH���b]��&�I=<�A�a�*�]��cW��9���,74U��P�q�I��f;"'��@Ğ�k���g���W��"'��ɂ��^o�����4Q=c�_�Ø,��~��n�x�f�8;*f�G ��W��y@':<�"�L�9�yg(�#�-f�`��~S2�<�|ǘE8�0����5#�R���rW��)<�e�]nt���k���ִ���p��+Fz]O������M��]���hm� x �P�+�٦�E�v�/�c+�fh�4�Z����Vá,�Y��
�_��&�UD�f�;��~-�:j=��Oޜ_x��)Wm?2��=qC~��J�`���U.�B�Q{�y2�WXU�Y���uE�9��J2r������䧫9i�8�E=�Ȍ�z���am�v3ha��݇�q�\����S
?S���w����;����U	�l�]]��2K��b���.#��zHV������0�ټ� N?����(�B��aQ��A\��E��F�fU9��Ȣ�5q�"�Q���#ky���E�Q��a�_�Z��m[��8L�,f��2�T�`s�iX�.p7o�� �1Q�CU�~�lkb;��Ŧ����n�g�n��SI�c.�uL6���G�P�+ĩ�s�'m��F��0hM'y�!h�Y�2��cM�����e�ۋ�'ܻr:.rs9�+X�72t��`C`/x#G�%]��$�ݶ�)*�q(�rr**)��J:���)�� B�kp�Y�RqpM6�`{<�LĨ.p��|�"�SJ��'�\N{���uK����.���mԪCS�s�����ؽ�͌��	�,2��$�w�}�л���O�w���P�/�%F�E���r"!�+�L-Ψ�pR�h��o9|�-����3��q����֓��;����h�� �x�sy|_��{���9c>�mT�E��C��x��l�\1W )ZD�	e�?
}�._0��$_��tY�'@3��^H�
�����߀�嗩L�����/��m �\�?iۻk����FGţ ��y�E���*P7ϫ=r)r��%^�o�)��gr3q�.����yUW�kф�|e<��j���k��-�lE��}���S/���3�����q'�����Nm�-�� @�����/�m�v3Y��j��oa-��>�,Tы�p�؂l~<x��q��B�QB����K���6+�TF�M<�;O���[cQ��sdF�0o~F�ca�0i����s����r�gەQs�� +
ujtMp�)��)U�&Ti2�����ZT3�χ��.����cX�
�rw {�`!?�F!ի�����B,P�[E;��y��j�Ϙ|m߮
��iIM�=���<�MD�Ww�8��n���z����Q�kY�%��X�©���/y���t`w�w���Bp<� -�kU<��I'`aY(q���5�G�$����Cp $  ?L��J���(�2�����hf���T��h�s˾ =DӞ�S_a���{D��z<J=D �(;_��`�Qv�I6�p�I���5/�'����L/VM*B�6Ee�<R�-G�/�eH���+�wqq}�H�2���y,�0ǒ���QCk"LH�@v�(����	�ﴎn�����١�Z$^u.�X��=���@���� 45M���g���LӴ�?�94�ug�����CJ�N�4�� �G�M2,��� �,����<J��`��p�+$i�a��N`<i
���9z.�(�vU��+s�P���8�4�tq�:Ϧo(���x��If�s�0�&��t�,l^�8M�ͬ��"�5>`JH(�;#W�xbg|��C�a���w�}G���G{��Y���\�]�:N�o�r�-��)��G1w$2[�����T��)Mw!U��	���1[yawx��\�zn��f�z��Ka�I����|�@ٕj�ms,�Q�FN��؝xP(���Z�����d"&�b�#�,��@�S�:�S�Q����|��_��֗�'۲'n�HWKg��:�gHs�y�݋<x��h!M*)Uќ]�����2�S<�6%��w��jE�r�TS�3�yn�B7�̵�g%,�U���pr��+�h�ŀ=��m5���ie�͌g�0��l���˰��]��$x!:��Y&݀0���1;��S�r]�KT��On�$��ʺ<.�̀o���
�C��E�[y�����jH��@�UT���H��f�Oa&�r?l1�A���O��Fű3�e��Ũ?!�Z�M��¡Z:1��	a.�Tq]�8( 3���L�0��UW	pر�}p�8���.��d�!2!88}৷�.�b��*��ۊ"�C����!c��Z��"�7,���̈�3r㙺x�����f"N�l�Ԥ��zF�Ka���H��2�N3	�H
v���������Pe��L���y�ܹ��	<.Tʛ���-��7�������2"`�����b(�*o���"�I��ZV�7뉽�S(���D�Ь�Y�`N4q���P��d|h@��3�,�H�����~8����itGw;-Д1^I��qbe����`.�"�/&�f�VCoQ4C�E^ ���e3\�\�3�{�<]��;Q��0��&�a�O�����5^G[��a���گ��EUmLz�Z����2&�x`�w�h]���Ѿ80�j��b�٪��xƃ��bt
dl��r��f}xޣ^P������J�PT`���=�mϡ�&�c�_�KV�����¤���Y�1by�JϞDIh�l���]�н���ܐ��e��G����}������ڝ�jF9k��{u�(xCҝ��qgrT��l s?0ƫ��P�uT����d�0򯜍��T�݋,��"`Uw�cXY}z ߗ��mN`H���F�q�3۬�&�ጘ��I�^�/�Æ*z}\�E]_�d��x��Mv�
|�
�N�t��DY���l<Qo��#w��/�Q��1�p5�lC:L�*B�ή,8S]{��-�V���ڄ!\�ôX�Pgq=�|!I�,��q=�Zh@�h�[ң{�P�7�%�k���z�U� Ba<���@�&Na6}�{�:/�0"�D&�ɷ̓�*F�Un�k�����۾�Z���^��Wc=���=�7��\�iw��t��b��� ��/�mT���Q�\���)7]
-�r���gG�'��~�����*�z�ۆ��)w�V�D�*N�_.?��ݘ��.�c΀��@�a �rBԑ#�i�m��A` �u�^�r�o���aC������d"�*%���Ȯ'[�\-l��G�FC�R�;���y�-�l���0�h�3�|���0��,�$|o��Q=O>�gr.x9V�.઱����0in<*Ě��)mԪ���<�m�3	�ַ�D_�@�H\g7o��V#�z��@rܿ��[O�<J:�ehgH���#�X���)��Ȕݔ�8��)A.'��3�(��$���G98lX5�B��6��3�C%p��r0v�T�[�p�QH\�y�1׾�e���}�� �Š      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   s	  xڍ�i��J ��3��~�L[T��$7����"bn�bQ6Y��/3mOf�G�ms �H��ᔩur\���'��h^�D�Z��Jatt��<b.�Uh���b����>=�I.����_�<	N��@��o�m� |G�w��E�	�/Ht0�`��a�|)d��@`)�H`1��8Q���g;��͟��(ȋ�I����a�wV��g�a~\���X�j综�<gN�0ZU�u�Ekc�-]��{6��ab��kq�r�:�{��'3��x4�O+��ϗ��_qYV@�7 �`�ӌy��$�ȳC���_�I��(�}��������9�̉���˿[�K�U����{wU��]G鈭�%
��b7��q�l���R'�`8V��{��b���-�%��̣̒���B��cY�i.�Y9�Yj���E:��j5���q=l4\s�U�w4ku���-�Ѳ7�oL���&��w� b����j�0��E�c$��?����v����k�I����{8l�d�Ǩg�����F<���멀�"�_��UH�m�{��� �C���þķ��I�1�?H4�`��,�I��V˄@v�|Fo����W����M�����T�6��])�!�,
�����aE�c�=���iA��"�/�hv{�a8��ֱY��ʙ�4�i�>&c��V趓س�>n|G;���*OK�TːH��yn�����N�=�K|���4q��v�ה:��b�E|k!`�&�Y�{�8�������<��abl�T���1_i;����9)��f��/�+�^=�X��Gx��r���O�vIS�����mk���l�]��g#d���{"q�f�V.kQ�v��|�5u+���Ó}���Zk��G���!� $��� �,�$~��8��\�g�(WV�2I;��;wn[ݧR|ڬ���)�,'�r��uL9�X�U��h*E�2̻���� ����ς�LH��5��cЪYN�j'S1L��;�񲮺�:D�����\�V�԰d}b���m"'�ֿ��]c�>.�o�^�zyT
D �m��������d�=��Z����w%���Ë7Rʝ"XO��.�'Pn�+����{i�"Ĉ?a���[��G���q�$��_Q�3�B�=݈��A~����R���`�xe���R'��pE�7�蔕X:�X��m>tK�N�(�!��Ϡ�_;oQRt�lo�Ǐ���l�EmXYl�^E���=f����E.?��8���m5��8�VԽ��i���'tC���!��|������OB�75.��&����)�L�qZ�rK��ahPu=z�LÃҋ}��M�'3EY>1�y���� �_M���<����֤9�(I�0�0����O����y�1�ˁ�M�z��H�B�u�:T�X��'��i`1�(�����L����O#�~-���0�$��HD��p�x�b�w ��K1��G��me�[�f�p|�]2vS}�%����A�,r_�!Z��F���S�sA�N��%���O����[��'N3J�� ð�Z�-�+:�wzYk+�j)_M���F��{����rI����#)��?<ڛ��4K�`E���$�I|?HrRw�~��H!�Z��n��㫿�c�]!w�ܧ��;E��mah=>�۬:���x�#֮��6}Ͼ���Ҿf�!-
��$�m�]bґ���/,� ��o����J���9�A��E�>EXM|�w���wu�x�AWz\j�ԟ0�	a�	�应 �#��,�_���I����h����<�i�6�	����Q)��s��&j�YV�FU�@SN���l�K���@ɍT$���КF����OO�߬�v�C�������m�G�����ȣ6N=���F2w�Uo�\w��g��=��.�ߘR��1П$㉤�^F�.^������"���4/�,z�s�鵓�x�A��lk��-7z�q�:���elm�]�IH��W[b�NwA�;i���<\b���Y�xr�7��9�(�?ȶ�d����	$n<��ae��������񰧫�4���@�Sx�O��e��x��u0\���'Y�3+4�]�iʐ�]�/��5ۚE
�O���"�O����� ���լ^_Nv�?�v�:B�f_V�-O(֪��TN�k�r�w]^�!�<�L�?���E�4����Ҭ��
ʖ�{��6"|����V|����Z��r��y�Li0�a���K���T:
7Zi�Dc�Y�0��[�����fV���'���A�����Vz�nMΝ~E�x63��<Ww�`�u�Y+�T�׬�)ܔ���a |se�"��l�����O��?yl+��+6���p���������T�      �   �  xڕ�1�k7E�繼,@�� 2�4H��R$�/���x|\��}���9��88p*|���F��m���09��d��?������	��A�M�>�C��ѡn��J�:N�J�٣��'B��c����ŷ�� �S�:,���=
*���*C�[)�n��Zy�J����+��(�{S�*�/RAUt�C�a��U���Q@��+hذN
�,�J�)����Iy��u^��q��T�t]|�:)X4@+]�]��kfJ����Q� 'hE�3��,[2����ɖ�L����yM�Ы�
^_?���$��*���v��xU
ܵ(�W�U�z3K��(p�H��,��Z�`.���g�U�ZT�X::��W��Ѭ5ߌ���f�mQU�Ի�Gݫ�q����j�["*�2�L��׍�HA"�]�P�Z__��Q �Q5a�0���%���ӢE��IrOճ�^#���v�Se+�p�$�e��J�73:T�+]��0�$W�E�;��2d���ȯ��ʯr,�C�������:-�j��٢:L���o���R�@EU���,gܥ���P-����u{GW�9��uOp�8k󻓨Nk���]���e�&�����^R:�u���s�����~}�Q�G�M���{��Uܔ�J�b�z3�E;
���K~>����|>�6Œ�      �   1  xڥ��n9��;O��χ��	���L�	fo��Hm!�$Hr�~�e�<�0�@�H������"�-��Z��8�g)��Q83�
���v��O��O��.�޽{���
��.���e���U����*�%��;_N�^��q������/R��������2����㸍�V�Q����6��W#n�TP@�M�*�S��3N�.��$�n���5ҷ�* ef�M��	9n�6h�T��o�	2��MR��^$!q��q"�6��T��m"99ҷi*N��,�i�lr�̒:�`�K�r#	��R��m�J��m
�<�m�Dץ:-�m"9�qn�T���y�nӸP
+'1��aR9�m���i*�^NB�Ze�m+�ѥB�Pt�Fncf($�X�r�ƍ�N߶Q������M#��3�I*�d��m�)�Vܺ�$�]�-�I�d�8�U**^NB�,�o��!�F����1��4�m��i*�m�Em���u�e��d�n�� �HNBR�BfNB��5g��6���⽳�p�6�6��MT�A��m�@-��틋���x���4r�$Cn�Tb��Y��V���u;�"��Rc/_��m"�;2K�TZ�Py�$4.Ȍ,�c��ވ	I���I�dk�q���}�ܦp��)qV�Q-�
�T�����*�ȮME눼�����,a���To=7'!�����I*YZ�� I\�m�͉$�]g�-T#�pw��d��H�MT���q�p��;ϴ6n��%�>5 w�J.u$'!�H��o�V*��M��T�ٷ��$��>	U�2���\��*�� mUۣ����u�F��MS)9)��n	�J�>I� �*z�hZ��6�B̒T��ykI"hญN�ވ)U8�+���#}���w�E�12�eKIѥ"rW�D�U�F�&����ȍˌ�q;��C�Z��Β42(F"	Q�%�yn��X
�����X��M#��q���2�oS�U�,8}�jBV���F���H�&���y9	�����]��ҥF�7'!���#��J���&qQ��Kr���pݦ�c�#n�T�2��­���o��s}j*�I�d#��I�*&Y��Dn(��]�PQY�b*�e�#n�T�J��6�+�υӷ����.�(�3w"Y)e�&PU\��Y�ȵ2pܶ��ވ�Nz�\�idWG�I�*�J�s��m=%�ⶒU�N6*8�̷��#'�*�iË$4n�4�n���R1;�,I#Gc�H$!�D��Y��E���6�;������4ru�È�4�l�m
W��8�I� z+Ԫ[�=+E%G,'��*V��z
L�f�$r��>5֨�n��U�!�I*EgxnS����X���]*F���D��qdW���e�܉�����vA�b�m��p ���b�oU��s�µ�z�q�*Qm�R�@�FY�8�oU��<�i�ܒKNNbsDե�wuC$ǠG�6QS�E7��8{����A&T�*9�4�OBT)Xx�$���?��형�}j
��%��"��S`��ͼ�md��ɷAB��,~yx�}_�J�G�&��˼���w�H�!���`9@\�idg��6Q%��[�и�k�9ng%�O�Wj����$rQF�m������n�)N�N�u6jK�7'!�-�U@U^ߦq�E������K��=QL%cN#�R4��b�=M�q��շs��	�,��6�\�SCn�T�0ݦp�+8�$���}"�M�����4�5C�.�*x�w�\P!s���Xjw6��q�I��Җc#n�T��̵$�k��!1N�,h�~r�Rj��T�S8�+EV	��p r���o�Z.P�c�+��6�����i*YՐYn��Id�8��\�V�أJ�c�M$;�j�m�JN�ܦp�5�fz�\`]o�Xk�ּY�Lv�ݹwݦ���X}��Ŕ�ߖ�>>�vW̷��8��i����w�J���+��v�9e�t:�36]|��ky^�j#j��TQ'Do'����e��/8�Zq�����t��:K�O�/�}���8�_k�Z�;��#K[:g>^.�o��~z�֬ke�W�F6XK�_%K畔��i�_o���m5����8E�.�:�n8]�_n#��&��:��?N���p)�c+�kiӒA+K*��]g����t|��&X��i�� �v��~����:���ӭ�{ѿ���G��:o�<�.�����<a�οU7Go=�M��N������/-����^{ۙ�P-Ȑ���0���\�x�]ϐq��k�6���`�Ut_9*�o���6c�^|k���uN�dȡ�>������8���o�|�"K��K�?cn�/\^vg��T�6/�M{*i%]�o"�����.?�[��Kmn�y�m�S9gµw8���#��ǩ�Ϲ}�bz)��R�o��	�/���ڎmFy�_˛6��0��Nƞ��_����6�4g��|�lZ�]c��(�y��	.����qw��2���ܪ�0�M���ʷ��}�?w_~mN�q���|�6���[�4=b�����ǯ���N_��j�Z�[m+l�	d�jug��e����6�׵�G�H��ouι|�������qr]*�ke3B�m��Itd�����q�:=�zz�ml]�l�����7����tn�tʯ���XK�<9��J��׌��$+ǖ�Oߗ���A	���Rs��nM����|/nF��}�tIe'�~A�m�0�^?�b>�#�7��a�����bO�S+�ki�a������V�^��|��[#6�����y-o�{�>����D�O�����t>�(�T����<W	4=8ȵ��7�-�8�V���V0(E �5�\�֞7�~m�.�y-�yJ:Fd�Q�Ϋ4���6�a=���t]��oշ�I)+�]���>�Fw�      �   �  xڭ�Kn; ���*zް��Df-=Q��%�n��3yϢ�5��	MQԧ�WM���!	����$Y:gq������ �f����:���WՎ�~|�!��~~�"��O����J�����-�&9="N�YY����ņ�7�0QYX`$kK�{�W�X���1�[|y{D|�����lS,�0@�ŝ Iq���-�����ɾ�K�ţ0?#U7bմ/f�/q��°'�u�PC�kc�i_,�3g�/�	P`_�	�M��F�X[���}���"@+N�x׊�:���8i[�<���p��o�[)��$T���\�UukW9y���[�L�qI�ˬhM�n�q6~���2�UVde�^���!��c��L�#��
�q�uk�}�c/�b~��Kܑ��0�P�*�;�K1�U�k
1ܭ[�2�ࠕX���,=��]ݺ΀�z7�t-��ˬ\���'1N�y=�.11��Qm%�,� ��
x�AW}���jxvKN�N��+��_��-.Z�="�6�m%nu_L���Ƣ)6�B���g���Bh�ش��Ĝ[N�@��w�#�PVŽi?;o�8�	��(d��N�C�-(v;��n!qh�p ֤;1uB!�Ae��$������qd�e��o=��mc�%�j
���U�`�	�wu��HɊ�xV���&�^�����YK9	�q�ql��47u�.ǑM�X�#�XCӕ�["x�K���^l����؆86�B�4��A����Xm���z2�e������g�(�|�S�n�c�qL��Nb����!q�;���P�;�X�;�v��j�١��Fv臧*��o�C#/&.	� +\Xq�L!4���F��O�i�o��/w6CyW�_+�6NAB�"t
2�69g��6�C��a�O �"�}l��e��mFk��@��9.����ĝN6�x�5�Ǌ[L�/;�1!Y��&����Db��S^D;��/V� VO;#/V�cb=���c�8&��b�s�ц8�����fb��h��c3HH����Z�:��9F��8p�^�������C9E��q�}vA����s����2g�G&������ۆ8��1�8ىe��>ፈ�mEH,"tк�#m��mEH�:_�/N	�7 C�Ab�t�6H��g��gӍ� ���2��Aq�j�s%V�C�L�F^6�w=�?�.����Au3���XH�����A��Sމq�V�ą䤭��΍������)Υ����gy!q�6HH|U���M��ݺ����8rGh�%փ�cAd� �ڊ �ԃ�Aa~�xf��'ڊ��!�$&�ql��sf;��m�CS^P\۵_*�0��mB�P#�|�AV�Ι��U��8p�m���Y��g�]H�v�#/ �<�Y���%���]��b�i�����D��-��	����7��j��n�-j<��J�p�_+6���U_Eqw����N9���'�j��+��@�\�UV�n>��X=�mŘ�P �11L�be��0o�b��'�x�{����K\K���m�uN!v��9e?��Aq�qB�缁�m�Gb���J�ft �k�t�4�W��3(�첺�>���=)m�CYK������Lt� ��܌��X�l��J<r۾z<�6���s��1�5�4��γK�G���#3��rp]�y�.i���>�Źuy���s�)b6�q�9S�'�v�4v��>)���WP^u�#!��~򰒱/���m&�c���>��+.n,��s�ު�_b�?{�{%&��W��g۵u`z�Q������r}D<�Uh%&�n��9|��?cGmnKq�,�3�{�������>1����srǘ��qd�t*b��y�������țmj��)�O�*����
��9�).&�כ�h)�����n�ͷ�-��
�����WxB\�vu�Od��5�+�����Ęk��CE1����K��:���A�Sq폈�]m_,�����?��J�T�0����|����v�      �   +  xڭ�[n#9E����AJԃ����� ���8�=�`�>����*@p����pp/E^���ɘ��,�=bN{K{G�v�f�G:>��9\O�]�����}������g���ZkPy͚ ��u��H�}l��E~�<9;���G]	lI>��	�M�3�|��������m�ve5D�J��28�-U�]�1q�����u�R������6�e�Ǳ	���F���
`d= �~�,��#(A�Hre%�%�^1&�
a�����qjC�v��
���,���ZdHh��3"i�8%�����'�% d���x��ܰ	AZ/F��0��8T�	��`�{�ج�X#,����=�����MF|�nW��r��F��`��yV����^sL!k5��s�Y
�*��4n��F��4!DWg�:�� �G"~��8)�%�)�P#��J�	�s2��7�&~��/m��\�X�QC:*Q1�,C��K�BA5�@{�<E���f�Z�{���j�&$���j���2���c&.�k�e�cK��D�J`J��G i�lKM���!9^U#VA0���Ѓ55�goY�r[&?���GdN��z�	6>��c��W55���6r���
��(7�b;]�dGCw{gd^/��s�M�͈���&����̈U��G�D$��,C��9R� !��I�����mv�d�u��C�A\�j�������$�l[5�_���	!�,�r%��蒇�`$7�*C���%�9�&��v�҄�ڹ�k ���<rL�� PcK���zc�P±��é�BQfq�H�lN�c�^^��u˼^al�~hwb-�u�G#�;���q��K��O��!��"�*/;��iI �Y�O��s�@����fo�}D��{9*��|,�dIQ�3)��8�@�F��<�#�<XiK
jW��2q�ֆi[��_u>�!�C֫JA����������7!d^�UbM5H��>�%@㔦y��oN^u	���mA>|���&�GE�S���������Rʧ�~�!��z.���$��trMY��]dX�珗���.��      �   /  xڥ�ˎ�H�׮�`Y��Ȋ����Ҭ{1��A`�6�$�����lW�Ԥ�J�H��k�Rǹ�qI"�g�`�Ǌ{L��F�¹�
g[��Pԕm�I�w��76��pw@�zt@�|�֭ĊbJ��������p���Q�T�5_1�s�}��K��3m_#���宨����,�YRTyc�vp���?<��7����ì�\�i�B+��t
):k�����ء�y6��n��2T�Mk�ģ� '>�74����պX�t�5��I��-l)Υ�f�R�)~	�6�
E)��{_�P��#T��]��n��=�A�BqZW���֯1"Jg$W���t�$�/
[QU�ѶP>I�w�N�=^w#�H���_�	��cB��F�Z�Efϡ�<��뫨��@dq��_���|Ӈ���R��� ��9���T��P'�T9cAF�H_��] ȥ֯���؅��t3 Y�w�bTR���a1�I��C�&c~�Z�)��u1B�Ɨ�^$�Vt�B8��#��&��2n���p��X�Xњ/����b�	ʑ�_Z|��'��	Be<����0���lV���K�V�C�����iS��)ܯ���| $��1;�B"�`4ʥ��Z��\�k����t(a����C$��������$J�M@JF��H"��s VR�:�6�酟|�|�m*Y�z���]�.|��z�A�>�~)�V��z�pF*>��e\.��5�]����k��%{�جX��nA���n�C��d�D�Cg�l���f<'3���s>L�ǽ����6n�s��"�~Ī�""0\H�t`tr3v�Et���+-��'Lƿ�s=�������r>�hD�TBĥK��L�$��N1�_n2�}Sg�b��^�{X�����6Ѕ��F���m�aW�X�1Ii��5!CP��q����x�/�����;�Oz�SM��ͩ���F#4^9`�c�G���y��K��WnS�f��</\�V�a؍G3��f�*E9���C$1�Ei�AYF�������;���+߬���.�T�w����i7���
��0��`��(�Z����M�����oJ�]������$e���'twBW'ٞV���ȴ�*�܌���2/�v^�>�>��.�S�lԾ_�� �(�n�ޮȄ(�ƌ0:R3�Ub̾�9�g~_����{H
X�5�L}ӽ��0��%�;�*����f�e`O��q>i�R�������Zz�Sc���?���45\F���?���|P�݆?>��g�����L`�%0b�������ۛˏʵ��߼	Ƅ�10����k`�j	P��=�w
@�O@�<o��N�FP%���F��J����)�g��a��%�w�h�����39l)�����[^hp�
��N�y��t6o���ĸ:�؅�qq����䲽�Mn��t U�����;�c��0��̛��Cb|Z�R܄��e|E�� �d�A�㯄����|r5o�Y�h�3�Cg�����ׄ�@��n�^z�<^I`;k�i}�M.�?1~�����;Z1���%�(����zF.��^�UH�nW�|�}�Gg��L�f���i�����l�lnVC������hcg �DU�� �	�0uP��3c�B�a��B��&���34���S�� ޫ�>"��ϧ�˰�X���_� CDf�2H$��I�'à�Qw�}8�߹*��&&�h�MT:��/H����syӿ��m�6pS�s���Q��|��v��	L7���VV�a��#ӂ0;��
"_����z[T����ވ�Z?���M\�HR��1:�(�EmD��2�߷o߾�FDu     