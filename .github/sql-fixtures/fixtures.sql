PGDMP  	    
        	             {            taiga    12.3 (Debian 12.3-1.pgdg100+1)    13.6 �   �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    7983490    taiga    DATABASE     Y   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';
    DROP DATABASE taiga;
                taiga    false                        3079    7983617    unaccent 	   EXTENSION     <   CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
    DROP EXTENSION unaccent;
                   false            �           0    0    EXTENSION unaccent    COMMENT     P   COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';
                        false    2            T           1247    7984002    procrastinate_job_event_type    TYPE     �   CREATE TYPE public.procrastinate_job_event_type AS ENUM (
    'deferred',
    'started',
    'deferred_for_retry',
    'failed',
    'succeeded',
    'cancelled',
    'scheduled'
);
 /   DROP TYPE public.procrastinate_job_event_type;
       public          taiga    false            Q           1247    7983993    procrastinate_job_status    TYPE     p   CREATE TYPE public.procrastinate_job_status AS ENUM (
    'todo',
    'doing',
    'succeeded',
    'failed'
);
 +   DROP TYPE public.procrastinate_job_status;
       public          taiga    false            >           1255    7984067 j   procrastinate_defer_job(character varying, character varying, text, text, jsonb, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_job(queue_name character varying, task_name character varying, lock text, queueing_lock text, args jsonb, scheduled_at timestamp with time zone) RETURNS bigint
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
       public          taiga    false            V           1255    7984084 t   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, bigint)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _defer_timestamp bigint) RETURNS bigint
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
       public          taiga    false            ?           1255    7984068 �   procrastinate_defer_periodic_job(character varying, character varying, character varying, character varying, character varying, bigint, jsonb)    FUNCTION     �  CREATE FUNCTION public.procrastinate_defer_periodic_job(_queue_name character varying, _lock character varying, _queueing_lock character varying, _task_name character varying, _periodic_id character varying, _defer_timestamp bigint, _args jsonb) RETURNS bigint
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
       public          taiga    false            �            1259    7984019    procrastinate_jobs    TABLE     �  CREATE TABLE public.procrastinate_jobs (
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
       public         heap    taiga    false    849    849            @           1255    7984069 ,   procrastinate_fetch_job(character varying[])    FUNCTION     	  CREATE FUNCTION public.procrastinate_fetch_job(target_queue_names character varying[]) RETURNS public.procrastinate_jobs
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
       public          taiga    false    239            U           1255    7984083 B   procrastinate_finish_job(integer, public.procrastinate_job_status)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status) RETURNS void
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
       public          taiga    false    849            T           1255    7984082 \   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone) RETURNS void
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
       public          taiga    false    849            A           1255    7984070 e   procrastinate_finish_job(integer, public.procrastinate_job_status, timestamp with time zone, boolean)    FUNCTION       CREATE FUNCTION public.procrastinate_finish_job(job_id integer, end_status public.procrastinate_job_status, next_scheduled_at timestamp with time zone, delete_job boolean) RETURNS void
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
       public          taiga    false    849            C           1255    7984072    procrastinate_notify_queue()    FUNCTION     
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
       public          taiga    false            B           1255    7984071 :   procrastinate_retry_job(integer, timestamp with time zone)    FUNCTION     �  CREATE FUNCTION public.procrastinate_retry_job(job_id integer, retry_at timestamp with time zone) RETURNS void
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
       public          taiga    false            R           1255    7984075 2   procrastinate_trigger_scheduled_events_procedure()    FUNCTION     #  CREATE FUNCTION public.procrastinate_trigger_scheduled_events_procedure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type, at)
        VALUES (NEW.id, 'scheduled'::procrastinate_job_event_type, NEW.scheduled_at);

	RETURN NEW;
END;
$$;
 I   DROP FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
       public          taiga    false            P           1255    7984073 6   procrastinate_trigger_status_events_procedure_insert()    FUNCTION       CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO procrastinate_events(job_id, type)
        VALUES (NEW.id, 'deferred'::procrastinate_job_event_type);
	RETURN NEW;
END;
$$;
 M   DROP FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
       public          taiga    false            Q           1255    7984074 6   procrastinate_trigger_status_events_procedure_update()    FUNCTION     �  CREATE FUNCTION public.procrastinate_trigger_status_events_procedure_update() RETURNS trigger
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
       public          taiga    false            S           1255    7984076 &   procrastinate_unlink_periodic_defers()    FUNCTION     �   CREATE FUNCTION public.procrastinate_unlink_periodic_defers() RETURNS trigger
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
       public          taiga    false            �           3602    7983624    simple_unaccent    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.simple_unaccent (
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
       public          taiga    false    2    2    2    2            �            1259    7983577 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    7983575    auth_group_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    214            �            1259    7983586    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    7983584    auth_group_permissions_id_seq    SEQUENCE     �   ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    216            �            1259    7983570    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    7983568    auth_permission_id_seq    SEQUENCE     �   ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    212            �            1259    7983547    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
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
       public         heap    taiga    false            �            1259    7983545    django_admin_log_id_seq    SEQUENCE     �   ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    210            �            1259    7983538    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    7983536    django_content_type_id_seq    SEQUENCE     �   ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    208            �            1259    7983493    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    7983491    django_migrations_id_seq    SEQUENCE     �   ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    204            �            1259    7983804    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false            �            1259    7983627    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false            �            1259    7983625    easy_thumbnails_source_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_source_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    218            �            1259    7983634    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false            �            1259    7983632     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    220            �            1259    7983659 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false            �            1259    7983657 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE       ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.easy_thumbnails_thumbnaildimensions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);
            public          taiga    false    222            �            1259    7984049    procrastinate_events    TABLE     �   CREATE TABLE public.procrastinate_events (
    id bigint NOT NULL,
    job_id integer NOT NULL,
    type public.procrastinate_job_event_type,
    at timestamp with time zone DEFAULT now()
);
 (   DROP TABLE public.procrastinate_events;
       public         heap    taiga    false    852            �            1259    7984047    procrastinate_events_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.procrastinate_events_id_seq;
       public          taiga    false    243            �           0    0    procrastinate_events_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.procrastinate_events_id_seq OWNED BY public.procrastinate_events.id;
          public          taiga    false    242            �            1259    7984017    procrastinate_jobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.procrastinate_jobs_id_seq;
       public          taiga    false    239            �           0    0    procrastinate_jobs_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.procrastinate_jobs_id_seq OWNED BY public.procrastinate_jobs.id;
          public          taiga    false    238            �            1259    7984033    procrastinate_periodic_defers    TABLE     "  CREATE TABLE public.procrastinate_periodic_defers (
    id bigint NOT NULL,
    task_name character varying(128) NOT NULL,
    defer_timestamp bigint,
    job_id bigint,
    queue_name character varying(128),
    periodic_id character varying(128) DEFAULT ''::character varying NOT NULL
);
 1   DROP TABLE public.procrastinate_periodic_defers;
       public         heap    taiga    false            �            1259    7984031 $   procrastinate_periodic_defers_id_seq    SEQUENCE     �   CREATE SEQUENCE public.procrastinate_periodic_defers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.procrastinate_periodic_defers_id_seq;
       public          taiga    false    241            �           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.procrastinate_periodic_defers_id_seq OWNED BY public.procrastinate_periodic_defers.id;
          public          taiga    false    240            4           1259    7984220 3   project_references_3bc37634963f11edba2498fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_3bc37634963f11edba2498fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3bc37634963f11edba2498fa9b3ac69a;
       public          taiga    false            5           1259    7984222 3   project_references_3de19a22963f11edba2498fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_3de19a22963f11edba2498fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3de19a22963f11edba2498fa9b3ac69a;
       public          taiga    false            6           1259    7984224 3   project_references_3e83face963f11edba2498fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_3e83face963f11edba2498fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3e83face963f11edba2498fa9b3ac69a;
       public          taiga    false            7           1259    7984226 3   project_references_3f974f60963f11edba2498fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_3f974f60963f11edba2498fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_3f974f60963f11edba2498fa9b3ac69a;
       public          taiga    false            8           1259    7984228 3   project_references_4147df5a963f11edba2498fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_4147df5a963f11edba2498fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_4147df5a963f11edba2498fa9b3ac69a;
       public          taiga    false            9           1259    7984230 3   project_references_421207c6963f11edba2498fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_421207c6963f11edba2498fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_421207c6963f11edba2498fa9b3ac69a;
       public          taiga    false            .           1259    7984206 3   project_references_7e864d80963e11edbc5c98fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_7e864d80963e11edbc5c98fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_7e864d80963e11edbc5c98fa9b3ac69a;
       public          taiga    false            /           1259    7984208 3   project_references_808c4c24963e11edbc5c98fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_808c4c24963e11edbc5c98fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_808c4c24963e11edbc5c98fa9b3ac69a;
       public          taiga    false            0           1259    7984210 3   project_references_812f7962963e11edbc5c98fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_812f7962963e11edbc5c98fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_812f7962963e11edbc5c98fa9b3ac69a;
       public          taiga    false            1           1259    7984212 3   project_references_8238258e963e11edbc5c98fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_8238258e963e11edbc5c98fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_8238258e963e11edbc5c98fa9b3ac69a;
       public          taiga    false            2           1259    7984214 3   project_references_83ebf1f8963e11edbc5c98fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_83ebf1f8963e11edbc5c98fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_83ebf1f8963e11edbc5c98fa9b3ac69a;
       public          taiga    false            3           1259    7984216 3   project_references_84a3fb68963e11edbc5c98fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_84a3fb68963e11edbc5c98fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_84a3fb68963e11edbc5c98fa9b3ac69a;
       public          taiga    false            �            1259    7984085 3   project_references_e796add4963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e796add4963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e796add4963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984087 3   project_references_e79f6aa0963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e79f6aa0963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e79f6aa0963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984089 3   project_references_e7a865ce963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7a865ce963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7a865ce963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984091 3   project_references_e7ae2040963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7ae2040963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7ae2040963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984093 3   project_references_e7b3c374963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7b3c374963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7b3c374963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984095 3   project_references_e7bad7fe963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7bad7fe963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7bad7fe963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984097 3   project_references_e7c2eef8963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7c2eef8963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7c2eef8963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984099 3   project_references_e7cb882e963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7cb882e963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7cb882e963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984101 3   project_references_e7d184cc963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7d184cc963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7d184cc963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984103 3   project_references_e7dc0fd2963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7dc0fd2963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7dc0fd2963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984105 3   project_references_e7e43ee6963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7e43ee6963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7e43ee6963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7984107 3   project_references_e7eebfd8963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7eebfd8963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7eebfd8963d11ed8c0998fa9b3ac69a;
       public          taiga    false                        1259    7984109 3   project_references_e7f5cecc963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7f5cecc963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7f5cecc963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984111 3   project_references_e7ff1e5a963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e7ff1e5a963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e7ff1e5a963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984113 3   project_references_e8068b36963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e8068b36963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e8068b36963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984115 3   project_references_e80e40ba963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e80e40ba963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e80e40ba963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984117 3   project_references_e817f132963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e817f132963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e817f132963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984119 3   project_references_e81de664963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e81de664963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e81de664963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984121 3   project_references_e8236c10963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e8236c10963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e8236c10963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984123 3   project_references_e82c6298963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_e82c6298963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_e82c6298963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984125 3   project_references_ed295580963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ed295580963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ed295580963d11ed8c0998fa9b3ac69a;
       public          taiga    false            	           1259    7984127 3   project_references_ed2dbf94963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ed2dbf94963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ed2dbf94963d11ed8c0998fa9b3ac69a;
       public          taiga    false            
           1259    7984129 3   project_references_ed33b4bc963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ed33b4bc963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ed33b4bc963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984131 3   project_references_ed92031e963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ed92031e963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ed92031e963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984133 3   project_references_ed976764963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ed976764963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ed976764963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984135 3   project_references_ed9db042963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ed9db042963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ed9db042963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984137 3   project_references_eda2b66e963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_eda2b66e963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_eda2b66e963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984139 3   project_references_eda84a20963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_eda84a20963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_eda84a20963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984141 3   project_references_edad1d3e963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edad1d3e963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edad1d3e963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984143 3   project_references_edb2cbda963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edb2cbda963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edb2cbda963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984145 3   project_references_edb7e778963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edb7e778963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edb7e778963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984147 3   project_references_edbcf79a963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edbcf79a963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edbcf79a963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984149 3   project_references_edc1f3bc963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edc1f3bc963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edc1f3bc963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984151 3   project_references_edca7b4a963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edca7b4a963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edca7b4a963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984153 3   project_references_edcf3f0e963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edcf3f0e963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edcf3f0e963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984155 3   project_references_edda2400963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edda2400963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edda2400963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984157 3   project_references_eddf50ec963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_eddf50ec963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_eddf50ec963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984159 3   project_references_ede49c28963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ede49c28963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ede49c28963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984161 3   project_references_ede9ec78963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ede9ec78963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ede9ec78963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984163 3   project_references_edf1d8c0963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edf1d8c0963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edf1d8c0963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984165 3   project_references_edf7e81e963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edf7e81e963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edf7e81e963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984167 3   project_references_edfde91c963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_edfde91c963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_edfde91c963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984169 3   project_references_ee0775e0963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee0775e0963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee0775e0963d11ed8c0998fa9b3ac69a;
       public          taiga    false                       1259    7984171 3   project_references_ee122288963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee122288963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee122288963d11ed8c0998fa9b3ac69a;
       public          taiga    false                        1259    7984173 3   project_references_ee49f58c963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee49f58c963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee49f58c963d11ed8c0998fa9b3ac69a;
       public          taiga    false            !           1259    7984175 3   project_references_ee4e7a9e963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee4e7a9e963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee4e7a9e963d11ed8c0998fa9b3ac69a;
       public          taiga    false            "           1259    7984177 3   project_references_ee5399f2963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee5399f2963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee5399f2963d11ed8c0998fa9b3ac69a;
       public          taiga    false            #           1259    7984179 3   project_references_ee57ecbe963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee57ecbe963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee57ecbe963d11ed8c0998fa9b3ac69a;
       public          taiga    false            $           1259    7984181 3   project_references_ee5e2af2963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee5e2af2963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee5e2af2963d11ed8c0998fa9b3ac69a;
       public          taiga    false            %           1259    7984183 3   project_references_ee641e8a963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee641e8a963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee641e8a963d11ed8c0998fa9b3ac69a;
       public          taiga    false            &           1259    7984185 3   project_references_ee693c76963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee693c76963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee693c76963d11ed8c0998fa9b3ac69a;
       public          taiga    false            '           1259    7984187 3   project_references_ee6ec8c6963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee6ec8c6963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee6ec8c6963d11ed8c0998fa9b3ac69a;
       public          taiga    false            (           1259    7984189 3   project_references_ee758c24963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee758c24963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee758c24963d11ed8c0998fa9b3ac69a;
       public          taiga    false            )           1259    7984191 3   project_references_ee7b63b0963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ee7b63b0963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ee7b63b0963d11ed8c0998fa9b3ac69a;
       public          taiga    false            *           1259    7984193 3   project_references_ef00596c963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ef00596c963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ef00596c963d11ed8c0998fa9b3ac69a;
       public          taiga    false            +           1259    7984195 3   project_references_ef596502963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ef596502963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ef596502963d11ed8c0998fa9b3ac69a;
       public          taiga    false            ,           1259    7984197 3   project_references_ef5e9dec963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_ef5e9dec963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_ef5e9dec963d11ed8c0998fa9b3ac69a;
       public          taiga    false            -           1259    7984199 3   project_references_fae511aa963d11ed8c0998fa9b3ac69a    SEQUENCE     �   CREATE SEQUENCE public.project_references_fae511aa963d11ed8c0998fa9b3ac69a
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.project_references_fae511aa963d11ed8c0998fa9b3ac69a;
       public          taiga    false            �            1259    7983758 &   projects_invitations_projectinvitation    TABLE     �  CREATE TABLE public.projects_invitations_projectinvitation (
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
       public         heap    taiga    false            �            1259    7983719 &   projects_memberships_projectmembership    TABLE     �   CREATE TABLE public.projects_memberships_projectmembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    project_id uuid NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 :   DROP TABLE public.projects_memberships_projectmembership;
       public         heap    taiga    false            �            1259    7983678    projects_project    TABLE     �  CREATE TABLE public.projects_project (
    id uuid NOT NULL,
    name character varying(80) NOT NULL,
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
       public         heap    taiga    false            �            1259    7983686    projects_projecttemplate    TABLE     ]  CREATE TABLE public.projects_projecttemplate (
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
       public         heap    taiga    false            �            1259    7983698    projects_roles_projectrole    TABLE       CREATE TABLE public.projects_roles_projectrole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    project_id uuid NOT NULL
);
 .   DROP TABLE public.projects_roles_projectrole;
       public         heap    taiga    false            �            1259    7983858 #   stories_assignments_storyassignment    TABLE     �   CREATE TABLE public.stories_assignments_storyassignment (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    story_id uuid NOT NULL,
    user_id uuid NOT NULL
);
 7   DROP TABLE public.stories_assignments_storyassignment;
       public         heap    taiga    false            �            1259    7983848    stories_story    TABLE     �  CREATE TABLE public.stories_story (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    version bigint NOT NULL,
    ref bigint NOT NULL,
    title character varying(500) NOT NULL,
    "order" numeric(16,10) NOT NULL,
    created_by_id uuid NOT NULL,
    project_id uuid NOT NULL,
    status_id uuid NOT NULL,
    workflow_id uuid NOT NULL,
    CONSTRAINT stories_story_version_check CHECK ((version >= 0))
);
 !   DROP TABLE public.stories_story;
       public         heap    taiga    false            �            1259    7983915    tokens_denylistedtoken    TABLE     �   CREATE TABLE public.tokens_denylistedtoken (
    id uuid NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id uuid NOT NULL
);
 *   DROP TABLE public.tokens_denylistedtoken;
       public         heap    taiga    false            �            1259    7983905    tokens_outstandingtoken    TABLE     2  CREATE TABLE public.tokens_outstandingtoken (
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
       public         heap    taiga    false            �            1259    7983513    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id uuid NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb,
    user_id uuid NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            �            1259    7983501 
   users_user    TABLE       CREATE TABLE public.users_user (
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    id uuid NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    color integer NOT NULL,
    is_active boolean NOT NULL,
    is_superuser boolean NOT NULL,
    full_name character varying(256),
    accepted_terms boolean NOT NULL,
    lang character varying(20) NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    date_verification timestamp with time zone
);
    DROP TABLE public.users_user;
       public         heap    taiga    false            �            1259    7983814    workflows_workflow    TABLE     �   CREATE TABLE public.workflows_workflow (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    "order" bigint NOT NULL,
    project_id uuid NOT NULL
);
 &   DROP TABLE public.workflows_workflow;
       public         heap    taiga    false            �            1259    7983822    workflows_workflowstatus    TABLE     �   CREATE TABLE public.workflows_workflowstatus (
    id uuid NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    color integer NOT NULL,
    "order" bigint NOT NULL,
    workflow_id uuid NOT NULL
);
 ,   DROP TABLE public.workflows_workflowstatus;
       public         heap    taiga    false            �            1259    7983960 *   workspaces_memberships_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_memberships_workspacemembership (
    id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    role_id uuid NOT NULL,
    user_id uuid NOT NULL,
    workspace_id uuid NOT NULL
);
 >   DROP TABLE public.workspaces_memberships_workspacemembership;
       public         heap    taiga    false            �            1259    7983938    workspaces_roles_workspacerole    TABLE       CREATE TABLE public.workspaces_roles_workspacerole (
    id uuid NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" bigint NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id uuid NOT NULL
);
 2   DROP TABLE public.workspaces_roles_workspacerole;
       public         heap    taiga    false            �            1259    7983673    workspaces_workspace    TABLE     *  CREATE TABLE public.workspaces_workspace (
    id uuid NOT NULL,
    name character varying(40) NOT NULL,
    color integer NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    is_premium boolean NOT NULL,
    owner_id uuid NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    taiga    false                       2604    7984052    procrastinate_events id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_events ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_events_id_seq'::regclass);
 F   ALTER TABLE public.procrastinate_events ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    243    242    243                       2604    7984022    procrastinate_jobs id    DEFAULT     ~   ALTER TABLE ONLY public.procrastinate_jobs ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_jobs_id_seq'::regclass);
 D   ALTER TABLE public.procrastinate_jobs ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    239    238    239                       2604    7984036     procrastinate_periodic_defers id    DEFAULT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers ALTER COLUMN id SET DEFAULT nextval('public.procrastinate_periodic_defers_id_seq'::regclass);
 O   ALTER TABLE public.procrastinate_periodic_defers ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    240    241    241            �          0    7983577 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    214   Ӛ      �          0    7983586    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    216   �      �          0    7983570    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    212   �      �          0    7983547    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    210   �      �          0    7983538    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    208   ��      �          0    7983493    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    204   +�      �          0    7983804    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    229   �      �          0    7983627    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    218   �      �          0    7983634    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    220   ��      �          0    7983659 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    222   ��      �          0    7984049    procrastinate_events 
   TABLE DATA           D   COPY public.procrastinate_events (id, job_id, type, at) FROM stdin;
    public          taiga    false    243   ȯ      �          0    7984019    procrastinate_jobs 
   TABLE DATA           �   COPY public.procrastinate_jobs (id, queue_name, task_name, lock, queueing_lock, args, status, scheduled_at, attempts) FROM stdin;
    public          taiga    false    239   �      �          0    7984033    procrastinate_periodic_defers 
   TABLE DATA           x   COPY public.procrastinate_periodic_defers (id, task_name, defer_timestamp, job_id, queue_name, periodic_id) FROM stdin;
    public          taiga    false    241   Z�      �          0    7983758 &   projects_invitations_projectinvitation 
   TABLE DATA           �   COPY public.projects_invitations_projectinvitation (id, email, status, created_at, num_emails_sent, resent_at, revoked_at, invited_by_id, project_id, resent_by_id, revoked_by_id, role_id, user_id) FROM stdin;
    public          taiga    false    228   w�      �          0    7983719 &   projects_memberships_projectmembership 
   TABLE DATA           n   COPY public.projects_memberships_projectmembership (id, created_at, project_id, role_id, user_id) FROM stdin;
    public          taiga    false    227   �      �          0    7983678    projects_project 
   TABLE DATA           �   COPY public.projects_project (id, name, description, color, logo, created_at, modified_at, public_permissions, workspace_member_permissions, owner_id, workspace_id) FROM stdin;
    public          taiga    false    224   ��      �          0    7983686    projects_projecttemplate 
   TABLE DATA           �   COPY public.projects_projecttemplate (id, name, slug, created_at, modified_at, default_owner_role, roles, workflows) FROM stdin;
    public          taiga    false    225    �      �          0    7983698    projects_roles_projectrole 
   TABLE DATA           p   COPY public.projects_roles_projectrole (id, name, slug, permissions, "order", is_admin, project_id) FROM stdin;
    public          taiga    false    226   e�      �          0    7983858 #   stories_assignments_storyassignment 
   TABLE DATA           `   COPY public.stories_assignments_storyassignment (id, created_at, story_id, user_id) FROM stdin;
    public          taiga    false    233   ��      �          0    7983848    stories_story 
   TABLE DATA           �   COPY public.stories_story (id, created_at, version, ref, title, "order", created_by_id, project_id, status_id, workflow_id) FROM stdin;
    public          taiga    false    232   �      �          0    7983915    tokens_denylistedtoken 
   TABLE DATA           M   COPY public.tokens_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    235   �%      �          0    7983905    tokens_outstandingtoken 
   TABLE DATA           �   COPY public.tokens_outstandingtoken (id, object_id, jti, token_type, token, created_at, expires_at, content_type_id) FROM stdin;
    public          taiga    false    234   >&      �          0    7983513    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    206   5B      �          0    7983501 
   users_user 
   TABLE DATA           �   COPY public.users_user (password, last_login, id, username, email, color, is_active, is_superuser, full_name, accepted_terms, lang, date_joined, date_verification) FROM stdin;
    public          taiga    false    205   RB      �          0    7983814    workflows_workflow 
   TABLE DATA           Q   COPY public.workflows_workflow (id, name, slug, "order", project_id) FROM stdin;
    public          taiga    false    230   �M      �          0    7983822    workflows_workflowstatus 
   TABLE DATA           _   COPY public.workflows_workflowstatus (id, name, slug, color, "order", workflow_id) FROM stdin;
    public          taiga    false    231   9Q      �          0    7983960 *   workspaces_memberships_workspacemembership 
   TABLE DATA           t   COPY public.workspaces_memberships_workspacemembership (id, created_at, role_id, user_id, workspace_id) FROM stdin;
    public          taiga    false    237   Y^      �          0    7983938    workspaces_roles_workspacerole 
   TABLE DATA           v   COPY public.workspaces_roles_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    236   �g      �          0    7983673    workspaces_workspace 
   TABLE DATA           n   COPY public.workspaces_workspace (id, name, color, created_at, modified_at, is_premium, owner_id) FROM stdin;
    public          taiga    false    223   [l      �           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    213            �           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    215                        0    0    auth_permission_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.auth_permission_id_seq', 96, true);
          public          taiga    false    211                       0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    209                       0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 24, true);
          public          taiga    false    207                       0    0    django_migrations_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.django_migrations_id_seq', 37, true);
          public          taiga    false    203                       0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 27, true);
          public          taiga    false    217                       0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 54, true);
          public          taiga    false    219                       0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    221                       0    0    procrastinate_events_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.procrastinate_events_id_seq', 84, true);
          public          taiga    false    242                       0    0    procrastinate_jobs_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.procrastinate_jobs_id_seq', 28, true);
          public          taiga    false    238            	           0    0 $   procrastinate_periodic_defers_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.procrastinate_periodic_defers_id_seq', 1, false);
          public          taiga    false    240            
           0    0 3   project_references_3bc37634963f11edba2498fa9b3ac69a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_3bc37634963f11edba2498fa9b3ac69a', 2, true);
          public          taiga    false    308                       0    0 3   project_references_3de19a22963f11edba2498fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3de19a22963f11edba2498fa9b3ac69a', 1, false);
          public          taiga    false    309                       0    0 3   project_references_3e83face963f11edba2498fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3e83face963f11edba2498fa9b3ac69a', 1, false);
          public          taiga    false    310                       0    0 3   project_references_3f974f60963f11edba2498fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_3f974f60963f11edba2498fa9b3ac69a', 1, false);
          public          taiga    false    311                       0    0 3   project_references_4147df5a963f11edba2498fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_4147df5a963f11edba2498fa9b3ac69a', 1, false);
          public          taiga    false    312                       0    0 3   project_references_421207c6963f11edba2498fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_421207c6963f11edba2498fa9b3ac69a', 1, false);
          public          taiga    false    313                       0    0 3   project_references_7e864d80963e11edbc5c98fa9b3ac69a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_7e864d80963e11edbc5c98fa9b3ac69a', 2, true);
          public          taiga    false    302                       0    0 3   project_references_808c4c24963e11edbc5c98fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_808c4c24963e11edbc5c98fa9b3ac69a', 1, false);
          public          taiga    false    303                       0    0 3   project_references_812f7962963e11edbc5c98fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_812f7962963e11edbc5c98fa9b3ac69a', 1, false);
          public          taiga    false    304                       0    0 3   project_references_8238258e963e11edbc5c98fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_8238258e963e11edbc5c98fa9b3ac69a', 1, false);
          public          taiga    false    305                       0    0 3   project_references_83ebf1f8963e11edbc5c98fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_83ebf1f8963e11edbc5c98fa9b3ac69a', 1, false);
          public          taiga    false    306                       0    0 3   project_references_84a3fb68963e11edbc5c98fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_84a3fb68963e11edbc5c98fa9b3ac69a', 1, false);
          public          taiga    false    307                       0    0 3   project_references_e796add4963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e796add4963d11ed8c0998fa9b3ac69a', 20, true);
          public          taiga    false    244                       0    0 3   project_references_e79f6aa0963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e79f6aa0963d11ed8c0998fa9b3ac69a', 14, true);
          public          taiga    false    245                       0    0 3   project_references_e7a865ce963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7a865ce963d11ed8c0998fa9b3ac69a', 12, true);
          public          taiga    false    246                       0    0 3   project_references_e7ae2040963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7ae2040963d11ed8c0998fa9b3ac69a', 13, true);
          public          taiga    false    247                       0    0 3   project_references_e7b3c374963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7b3c374963d11ed8c0998fa9b3ac69a', 17, true);
          public          taiga    false    248                       0    0 3   project_references_e7bad7fe963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7bad7fe963d11ed8c0998fa9b3ac69a', 25, true);
          public          taiga    false    249                       0    0 3   project_references_e7c2eef8963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7c2eef8963d11ed8c0998fa9b3ac69a', 25, true);
          public          taiga    false    250                       0    0 3   project_references_e7cb882e963d11ed8c0998fa9b3ac69a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_e7cb882e963d11ed8c0998fa9b3ac69a', 4, true);
          public          taiga    false    251                       0    0 3   project_references_e7d184cc963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7d184cc963d11ed8c0998fa9b3ac69a', 15, true);
          public          taiga    false    252                       0    0 3   project_references_e7dc0fd2963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7dc0fd2963d11ed8c0998fa9b3ac69a', 19, true);
          public          taiga    false    253                        0    0 3   project_references_e7e43ee6963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7e43ee6963d11ed8c0998fa9b3ac69a', 20, true);
          public          taiga    false    254            !           0    0 3   project_references_e7eebfd8963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7eebfd8963d11ed8c0998fa9b3ac69a', 13, true);
          public          taiga    false    255            "           0    0 3   project_references_e7f5cecc963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7f5cecc963d11ed8c0998fa9b3ac69a', 12, true);
          public          taiga    false    256            #           0    0 3   project_references_e7ff1e5a963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e7ff1e5a963d11ed8c0998fa9b3ac69a', 12, true);
          public          taiga    false    257            $           0    0 3   project_references_e8068b36963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e8068b36963d11ed8c0998fa9b3ac69a', 23, true);
          public          taiga    false    258            %           0    0 3   project_references_e80e40ba963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e80e40ba963d11ed8c0998fa9b3ac69a', 13, true);
          public          taiga    false    259            &           0    0 3   project_references_e817f132963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e817f132963d11ed8c0998fa9b3ac69a', 29, true);
          public          taiga    false    260            '           0    0 3   project_references_e81de664963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e81de664963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    261            (           0    0 3   project_references_e8236c10963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_e8236c10963d11ed8c0998fa9b3ac69a', 22, true);
          public          taiga    false    262            )           0    0 3   project_references_e82c6298963d11ed8c0998fa9b3ac69a    SEQUENCE SET     a   SELECT pg_catalog.setval('public.project_references_e82c6298963d11ed8c0998fa9b3ac69a', 6, true);
          public          taiga    false    263            *           0    0 3   project_references_ed295580963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ed295580963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    264            +           0    0 3   project_references_ed2dbf94963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ed2dbf94963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    265            ,           0    0 3   project_references_ed33b4bc963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ed33b4bc963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    266            -           0    0 3   project_references_ed92031e963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ed92031e963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    267            .           0    0 3   project_references_ed976764963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ed976764963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    268            /           0    0 3   project_references_ed9db042963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ed9db042963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    269            0           0    0 3   project_references_eda2b66e963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_eda2b66e963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    270            1           0    0 3   project_references_eda84a20963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_eda84a20963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    271            2           0    0 3   project_references_edad1d3e963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edad1d3e963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    272            3           0    0 3   project_references_edb2cbda963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edb2cbda963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    273            4           0    0 3   project_references_edb7e778963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edb7e778963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    274            5           0    0 3   project_references_edbcf79a963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edbcf79a963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    275            6           0    0 3   project_references_edc1f3bc963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edc1f3bc963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    276            7           0    0 3   project_references_edca7b4a963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edca7b4a963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    277            8           0    0 3   project_references_edcf3f0e963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edcf3f0e963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    278            9           0    0 3   project_references_edda2400963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edda2400963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    279            :           0    0 3   project_references_eddf50ec963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_eddf50ec963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    280            ;           0    0 3   project_references_ede49c28963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ede49c28963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    281            <           0    0 3   project_references_ede9ec78963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ede9ec78963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    282            =           0    0 3   project_references_edf1d8c0963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edf1d8c0963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    283            >           0    0 3   project_references_edf7e81e963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edf7e81e963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    284            ?           0    0 3   project_references_edfde91c963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_edfde91c963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    285            @           0    0 3   project_references_ee0775e0963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee0775e0963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    286            A           0    0 3   project_references_ee122288963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee122288963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    287            B           0    0 3   project_references_ee49f58c963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee49f58c963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    288            C           0    0 3   project_references_ee4e7a9e963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee4e7a9e963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    289            D           0    0 3   project_references_ee5399f2963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee5399f2963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    290            E           0    0 3   project_references_ee57ecbe963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee57ecbe963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    291            F           0    0 3   project_references_ee5e2af2963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee5e2af2963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    292            G           0    0 3   project_references_ee641e8a963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee641e8a963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    293            H           0    0 3   project_references_ee693c76963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee693c76963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    294            I           0    0 3   project_references_ee6ec8c6963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee6ec8c6963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    295            J           0    0 3   project_references_ee758c24963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee758c24963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    296            K           0    0 3   project_references_ee7b63b0963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ee7b63b0963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    297            L           0    0 3   project_references_ef00596c963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ef00596c963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    298            M           0    0 3   project_references_ef596502963d11ed8c0998fa9b3ac69a    SEQUENCE SET     b   SELECT pg_catalog.setval('public.project_references_ef596502963d11ed8c0998fa9b3ac69a', 1, false);
          public          taiga    false    299            N           0    0 3   project_references_ef5e9dec963d11ed8c0998fa9b3ac69a    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_ef5e9dec963d11ed8c0998fa9b3ac69a', 1000, true);
          public          taiga    false    300            O           0    0 3   project_references_fae511aa963d11ed8c0998fa9b3ac69a    SEQUENCE SET     d   SELECT pg_catalog.setval('public.project_references_fae511aa963d11ed8c0998fa9b3ac69a', 2000, true);
          public          taiga    false    301            C           2606    7983615    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    214            H           2606    7983601 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    216    216            K           2606    7983590 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    216            E           2606    7983581    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    214            >           2606    7983592 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    212    212            @           2606    7983574 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    212            :           2606    7983555 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    210            5           2606    7983544 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    208    208            7           2606    7983542 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    208            !           2606    7983500 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    204            �           2606    7983811 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    229            O           2606    7983631 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    218            S           2606    7983642 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    218    218            U           2606    7983640 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    220    220    220            Y           2606    7983638 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    220            ^           2606    7983665 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    222            `           2606    7983667 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    222            �           2606    7984055 .   procrastinate_events procrastinate_events_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_pkey;
       public            taiga    false    243            �           2606    7984030 *   procrastinate_jobs procrastinate_jobs_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.procrastinate_jobs
    ADD CONSTRAINT procrastinate_jobs_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.procrastinate_jobs DROP CONSTRAINT procrastinate_jobs_pkey;
       public            taiga    false    239            �           2606    7984039 @   procrastinate_periodic_defers procrastinate_periodic_defers_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_pkey;
       public            taiga    false    241            �           2606    7984041 B   procrastinate_periodic_defers procrastinate_periodic_defers_unique 
   CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_unique UNIQUE (task_name, periodic_id, defer_timestamp);
 l   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_unique;
       public            taiga    false    241    241    241            �           2606    7983762 R   projects_invitations_projectinvitation projects_invitations_projectinvitation_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_projectinvitation_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_projectinvitation_pkey;
       public            taiga    false    228            �           2606    7983767 b   projects_invitations_projectinvitation projects_invitations_projectinvitation_unique_project_email 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_projectinvitation_unique_project_email UNIQUE (project_id, email);
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_projectinvitation_unique_project_email;
       public            taiga    false    228    228            {           2606    7983723 R   projects_memberships_projectmembership projects_memberships_projectmembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_projectmembership_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_projectmembership_pkey;
       public            taiga    false    227                       2606    7983726 a   projects_memberships_projectmembership projects_memberships_projectmembership_unique_project_user 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_projectmembership_unique_project_user UNIQUE (project_id, user_id);
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_projectmembership_unique_project_user;
       public            taiga    false    227    227            g           2606    7983685 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    224            k           2606    7983693 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    225            n           2606    7983695 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    225            q           2606    7983705 :   projects_roles_projectrole projects_roles_projectrole_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_pkey;
       public            taiga    false    226            v           2606    7983710 I   projects_roles_projectrole projects_roles_projectrole_unique_project_name 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_unique_project_name UNIQUE (project_id, name);
 s   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_unique_project_name;
       public            taiga    false    226    226            x           2606    7983708 I   projects_roles_projectrole projects_roles_projectrole_unique_project_slug 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_projectrole_unique_project_slug UNIQUE (project_id, slug);
 s   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_projectrole_unique_project_slug;
       public            taiga    false    226    226            �           2606    7983900 "   stories_story projects_unique_refs 
   CONSTRAINT     h   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT projects_unique_refs UNIQUE (project_id, ref);
 L   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT projects_unique_refs;
       public            taiga    false    232    232            �           2606    7983862 L   stories_assignments_storyassignment stories_assignments_storyassignment_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.stories_assignments_storyassignment
    ADD CONSTRAINT stories_assignments_storyassignment_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.stories_assignments_storyassignment DROP CONSTRAINT stories_assignments_storyassignment_pkey;
       public            taiga    false    233            �           2606    7983865 Y   stories_assignments_storyassignment stories_assignments_storyassignment_unique_story_user 
   CONSTRAINT     �   ALTER TABLE ONLY public.stories_assignments_storyassignment
    ADD CONSTRAINT stories_assignments_storyassignment_unique_story_user UNIQUE (story_id, user_id);
 �   ALTER TABLE ONLY public.stories_assignments_storyassignment DROP CONSTRAINT stories_assignments_storyassignment_unique_story_user;
       public            taiga    false    233    233            �           2606    7983856     stories_story stories_story_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_pkey;
       public            taiga    false    232            �           2606    7983919 2   tokens_denylistedtoken tokens_denylistedtoken_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_pkey;
       public            taiga    false    235            �           2606    7983921 :   tokens_denylistedtoken tokens_denylistedtoken_token_id_key 
   CONSTRAINT     y   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtoken_token_id_key UNIQUE (token_id);
 d   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtoken_token_id_key;
       public            taiga    false    235            �           2606    7983914 7   tokens_outstandingtoken tokens_outstandingtoken_jti_key 
   CONSTRAINT     q   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_jti_key UNIQUE (jti);
 a   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_jti_key;
       public            taiga    false    234            �           2606    7983912 4   tokens_outstandingtoken tokens_outstandingtoken_pkey 
   CONSTRAINT     r   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingtoken_pkey PRIMARY KEY (id);
 ^   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingtoken_pkey;
       public            taiga    false    234            0           2606    7983520 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    206            2           2606    7983525 -   users_authdata users_authdata_unique_user_key 
   CONSTRAINT     p   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_unique_user_key UNIQUE (user_id, key);
 W   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_unique_user_key;
       public            taiga    false    206    206            %           2606    7983512    users_user users_user_email_key 
   CONSTRAINT     [   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_key UNIQUE (email);
 I   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_key;
       public            taiga    false    205            '           2606    7983508    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    205            +           2606    7983510 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    205            �           2606    7983821 *   workflows_workflow workflows_workflow_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_pkey;
       public            taiga    false    230            �           2606    7983835 9   workflows_workflow workflows_workflow_unique_project_name 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_unique_project_name UNIQUE (project_id, name);
 c   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_unique_project_name;
       public            taiga    false    230    230            �           2606    7983833 9   workflows_workflow workflows_workflow_unique_project_slug 
   CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_unique_project_slug UNIQUE (project_id, slug);
 c   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_unique_project_slug;
       public            taiga    false    230    230            �           2606    7983829 6   workflows_workflowstatus workflows_workflowstatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowstatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowstatus_pkey;
       public            taiga    false    231            �           2606    7983964 Z   workspaces_memberships_workspacemembership workspaces_memberships_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_workspacemembership_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_workspacemembership_pkey;
       public            taiga    false    237            �           2606    7983967 j   workspaces_memberships_workspacemembership workspaces_memberships_workspacemembership_unique_workspace_use 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_memberships_workspacemembership_unique_workspace_use UNIQUE (workspace_id, user_id);
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_memberships_workspacemembership_unique_workspace_use;
       public            taiga    false    237    237            �           2606    7983945 B   workspaces_roles_workspacerole workspaces_roles_workspacerole_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_pkey;
       public            taiga    false    236            �           2606    7983951 S   workspaces_roles_workspacerole workspaces_roles_workspacerole_unique_workspace_name 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_unique_workspace_name UNIQUE (workspace_id, name);
 }   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_unique_workspace_name;
       public            taiga    false    236    236            �           2606    7983949 S   workspaces_roles_workspacerole workspaces_roles_workspacerole_unique_workspace_slug 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_workspacerole_unique_workspace_slug UNIQUE (workspace_id, slug);
 }   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_workspacerole_unique_workspace_slug;
       public            taiga    false    236    236            c           2606    7983677 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    223            A           1259    7983616    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    214            F           1259    7983612 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    216            I           1259    7983613 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    216            <           1259    7983598 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    212            8           1259    7983566 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    210            ;           1259    7983567 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    210            �           1259    7983813 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    229            �           1259    7983812 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    229            L           1259    7983645 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    218            M           1259    7983646 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    218            P           1259    7983643 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    218            Q           1259    7983644 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    218            V           1259    7983654 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    220            W           1259    7983655 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    220            Z           1259    7983656 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    220            [           1259    7983652 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    220            \           1259    7983653 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    220            �           1259    7984065     procrastinate_events_job_id_fkey    INDEX     c   CREATE INDEX procrastinate_events_job_id_fkey ON public.procrastinate_events USING btree (job_id);
 4   DROP INDEX public.procrastinate_events_job_id_fkey;
       public            taiga    false    243            �           1259    7984064    procrastinate_jobs_id_lock_idx    INDEX     �   CREATE INDEX procrastinate_jobs_id_lock_idx ON public.procrastinate_jobs USING btree (id, lock) WHERE (status = ANY (ARRAY['todo'::public.procrastinate_job_status, 'doing'::public.procrastinate_job_status]));
 2   DROP INDEX public.procrastinate_jobs_id_lock_idx;
       public            taiga    false    239    849    239    239            �           1259    7984062    procrastinate_jobs_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_lock_idx ON public.procrastinate_jobs USING btree (lock) WHERE (status = 'doing'::public.procrastinate_job_status);
 /   DROP INDEX public.procrastinate_jobs_lock_idx;
       public            taiga    false    239    849    239            �           1259    7984063 !   procrastinate_jobs_queue_name_idx    INDEX     f   CREATE INDEX procrastinate_jobs_queue_name_idx ON public.procrastinate_jobs USING btree (queue_name);
 5   DROP INDEX public.procrastinate_jobs_queue_name_idx;
       public            taiga    false    239            �           1259    7984061 $   procrastinate_jobs_queueing_lock_idx    INDEX     �   CREATE UNIQUE INDEX procrastinate_jobs_queueing_lock_idx ON public.procrastinate_jobs USING btree (queueing_lock) WHERE (status = 'todo'::public.procrastinate_job_status);
 8   DROP INDEX public.procrastinate_jobs_queueing_lock_idx;
       public            taiga    false    239    239    849            �           1259    7984066 )   procrastinate_periodic_defers_job_id_fkey    INDEX     u   CREATE INDEX procrastinate_periodic_defers_job_id_fkey ON public.procrastinate_periodic_defers USING btree (job_id);
 =   DROP INDEX public.procrastinate_periodic_defers_job_id_fkey;
       public            taiga    false    241            �           1259    7983763    projects_in_email_07fdb9_idx    INDEX     p   CREATE INDEX projects_in_email_07fdb9_idx ON public.projects_invitations_projectinvitation USING btree (email);
 0   DROP INDEX public.projects_in_email_07fdb9_idx;
       public            taiga    false    228            �           1259    7983765    projects_in_project_ac92b3_idx    INDEX     �   CREATE INDEX projects_in_project_ac92b3_idx ON public.projects_invitations_projectinvitation USING btree (project_id, user_id);
 2   DROP INDEX public.projects_in_project_ac92b3_idx;
       public            taiga    false    228    228            �           1259    7983764    projects_in_project_d7d2d6_idx    INDEX     ~   CREATE INDEX projects_in_project_d7d2d6_idx ON public.projects_invitations_projectinvitation USING btree (project_id, email);
 2   DROP INDEX public.projects_in_project_d7d2d6_idx;
       public            taiga    false    228    228            �           1259    7983798 =   projects_invitations_projectinvitation_invited_by_id_e41218dc    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_invited_by_id_e41218dc ON public.projects_invitations_projectinvitation USING btree (invited_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_invited_by_id_e41218dc;
       public            taiga    false    228            �           1259    7983799 :   projects_invitations_projectinvitation_project_id_8a729cae    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_project_id_8a729cae ON public.projects_invitations_projectinvitation USING btree (project_id);
 N   DROP INDEX public.projects_invitations_projectinvitation_project_id_8a729cae;
       public            taiga    false    228            �           1259    7983800 <   projects_invitations_projectinvitation_resent_by_id_68c580e8    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_resent_by_id_68c580e8 ON public.projects_invitations_projectinvitation USING btree (resent_by_id);
 P   DROP INDEX public.projects_invitations_projectinvitation_resent_by_id_68c580e8;
       public            taiga    false    228            �           1259    7983801 =   projects_invitations_projectinvitation_revoked_by_id_8a8e629a    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_revoked_by_id_8a8e629a ON public.projects_invitations_projectinvitation USING btree (revoked_by_id);
 Q   DROP INDEX public.projects_invitations_projectinvitation_revoked_by_id_8a8e629a;
       public            taiga    false    228            �           1259    7983802 7   projects_invitations_projectinvitation_role_id_bb735b0e    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_role_id_bb735b0e ON public.projects_invitations_projectinvitation USING btree (role_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_role_id_bb735b0e;
       public            taiga    false    228            �           1259    7983803 7   projects_invitations_projectinvitation_user_id_995e9b1c    INDEX     �   CREATE INDEX projects_invitations_projectinvitation_user_id_995e9b1c ON public.projects_invitations_projectinvitation USING btree (user_id);
 K   DROP INDEX public.projects_invitations_projectinvitation_user_id_995e9b1c;
       public            taiga    false    228            y           1259    7983724    projects_me_project_3bd46e_idx    INDEX     �   CREATE INDEX projects_me_project_3bd46e_idx ON public.projects_memberships_projectmembership USING btree (project_id, user_id);
 2   DROP INDEX public.projects_me_project_3bd46e_idx;
       public            taiga    false    227    227            |           1259    7983742 :   projects_memberships_projectmembership_project_id_7592284f    INDEX     �   CREATE INDEX projects_memberships_projectmembership_project_id_7592284f ON public.projects_memberships_projectmembership USING btree (project_id);
 N   DROP INDEX public.projects_memberships_projectmembership_project_id_7592284f;
       public            taiga    false    227            }           1259    7983743 7   projects_memberships_projectmembership_role_id_43773f6c    INDEX     �   CREATE INDEX projects_memberships_projectmembership_role_id_43773f6c ON public.projects_memberships_projectmembership USING btree (role_id);
 K   DROP INDEX public.projects_memberships_projectmembership_role_id_43773f6c;
       public            taiga    false    227            �           1259    7983744 7   projects_memberships_projectmembership_user_id_8a613b51    INDEX     �   CREATE INDEX projects_memberships_projectmembership_user_id_8a613b51 ON public.projects_memberships_projectmembership USING btree (user_id);
 K   DROP INDEX public.projects_memberships_projectmembership_user_id_8a613b51;
       public            taiga    false    227            i           1259    7983696    projects_pr_slug_28d8d6_idx    INDEX     `   CREATE INDEX projects_pr_slug_28d8d6_idx ON public.projects_projecttemplate USING btree (slug);
 /   DROP INDEX public.projects_pr_slug_28d8d6_idx;
       public            taiga    false    225            d           1259    7983756    projects_pr_workspa_2e7a5b_idx    INDEX     g   CREATE INDEX projects_pr_workspa_2e7a5b_idx ON public.projects_project USING btree (workspace_id, id);
 2   DROP INDEX public.projects_pr_workspa_2e7a5b_idx;
       public            taiga    false    224    224            e           1259    7983750 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    224            h           1259    7983757 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    224            l           1259    7983697 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    225            o           1259    7983706    projects_ro_project_63cac9_idx    INDEX     q   CREATE INDEX projects_ro_project_63cac9_idx ON public.projects_roles_projectrole USING btree (project_id, slug);
 2   DROP INDEX public.projects_ro_project_63cac9_idx;
       public            taiga    false    226    226            r           1259    7983718 .   projects_roles_projectrole_project_id_4efc0342    INDEX     {   CREATE INDEX projects_roles_projectrole_project_id_4efc0342 ON public.projects_roles_projectrole USING btree (project_id);
 B   DROP INDEX public.projects_roles_projectrole_project_id_4efc0342;
       public            taiga    false    226            s           1259    7983716 (   projects_roles_projectrole_slug_9eb663ce    INDEX     o   CREATE INDEX projects_roles_projectrole_slug_9eb663ce ON public.projects_roles_projectrole USING btree (slug);
 <   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce;
       public            taiga    false    226            t           1259    7983717 -   projects_roles_projectrole_slug_9eb663ce_like    INDEX     �   CREATE INDEX projects_roles_projectrole_slug_9eb663ce_like ON public.projects_roles_projectrole USING btree (slug varchar_pattern_ops);
 A   DROP INDEX public.projects_roles_projectrole_slug_9eb663ce_like;
       public            taiga    false    226            �           1259    7983863    stories_ass_story_i_bb03e4_idx    INDEX     {   CREATE INDEX stories_ass_story_i_bb03e4_idx ON public.stories_assignments_storyassignment USING btree (story_id, user_id);
 2   DROP INDEX public.stories_ass_story_i_bb03e4_idx;
       public            taiga    false    233    233            �           1259    7983876 5   stories_assignments_storyassignment_story_id_6692be0c    INDEX     �   CREATE INDEX stories_assignments_storyassignment_story_id_6692be0c ON public.stories_assignments_storyassignment USING btree (story_id);
 I   DROP INDEX public.stories_assignments_storyassignment_story_id_6692be0c;
       public            taiga    false    233            �           1259    7983877 4   stories_assignments_storyassignment_user_id_4c228ed7    INDEX     �   CREATE INDEX stories_assignments_storyassignment_user_id_4c228ed7 ON public.stories_assignments_storyassignment USING btree (user_id);
 H   DROP INDEX public.stories_assignments_storyassignment_user_id_4c228ed7;
       public            taiga    false    233            �           1259    7983898    stories_sto_project_840ba5_idx    INDEX     c   CREATE INDEX stories_sto_project_840ba5_idx ON public.stories_story USING btree (project_id, ref);
 2   DROP INDEX public.stories_sto_project_840ba5_idx;
       public            taiga    false    232    232            �           1259    7983901 $   stories_story_created_by_id_052bf6c8    INDEX     g   CREATE INDEX stories_story_created_by_id_052bf6c8 ON public.stories_story USING btree (created_by_id);
 8   DROP INDEX public.stories_story_created_by_id_052bf6c8;
       public            taiga    false    232            �           1259    7983902 !   stories_story_project_id_c78d9ba8    INDEX     a   CREATE INDEX stories_story_project_id_c78d9ba8 ON public.stories_story USING btree (project_id);
 5   DROP INDEX public.stories_story_project_id_c78d9ba8;
       public            taiga    false    232            �           1259    7983857    stories_story_ref_07544f5a    INDEX     S   CREATE INDEX stories_story_ref_07544f5a ON public.stories_story USING btree (ref);
 .   DROP INDEX public.stories_story_ref_07544f5a;
       public            taiga    false    232            �           1259    7983903     stories_story_status_id_15c8b6c9    INDEX     _   CREATE INDEX stories_story_status_id_15c8b6c9 ON public.stories_story USING btree (status_id);
 4   DROP INDEX public.stories_story_status_id_15c8b6c9;
       public            taiga    false    232            �           1259    7983904 "   stories_story_workflow_id_448ab642    INDEX     c   CREATE INDEX stories_story_workflow_id_448ab642 ON public.stories_story USING btree (workflow_id);
 6   DROP INDEX public.stories_story_workflow_id_448ab642;
       public            taiga    false    232            �           1259    7983925    tokens_deny_token_i_25cc28_idx    INDEX     e   CREATE INDEX tokens_deny_token_i_25cc28_idx ON public.tokens_denylistedtoken USING btree (token_id);
 2   DROP INDEX public.tokens_deny_token_i_25cc28_idx;
       public            taiga    false    235            �           1259    7983922    tokens_outs_content_1b2775_idx    INDEX     �   CREATE INDEX tokens_outs_content_1b2775_idx ON public.tokens_outstandingtoken USING btree (content_type_id, object_id, token_type);
 2   DROP INDEX public.tokens_outs_content_1b2775_idx;
       public            taiga    false    234    234    234            �           1259    7983924    tokens_outs_expires_ce645d_idx    INDEX     h   CREATE INDEX tokens_outs_expires_ce645d_idx ON public.tokens_outstandingtoken USING btree (expires_at);
 2   DROP INDEX public.tokens_outs_expires_ce645d_idx;
       public            taiga    false    234            �           1259    7983923    tokens_outs_jti_766f39_idx    INDEX     ]   CREATE INDEX tokens_outs_jti_766f39_idx ON public.tokens_outstandingtoken USING btree (jti);
 .   DROP INDEX public.tokens_outs_jti_766f39_idx;
       public            taiga    false    234            �           1259    7983932 0   tokens_outstandingtoken_content_type_id_06cfd70a    INDEX        CREATE INDEX tokens_outstandingtoken_content_type_id_06cfd70a ON public.tokens_outstandingtoken USING btree (content_type_id);
 D   DROP INDEX public.tokens_outstandingtoken_content_type_id_06cfd70a;
       public            taiga    false    234            �           1259    7983931 )   tokens_outstandingtoken_jti_ac7232c7_like    INDEX     �   CREATE INDEX tokens_outstandingtoken_jti_ac7232c7_like ON public.tokens_outstandingtoken USING btree (jti varchar_pattern_ops);
 =   DROP INDEX public.tokens_outstandingtoken_jti_ac7232c7_like;
       public            taiga    false    234            ,           1259    7983523    users_authd_user_id_d24d4c_idx    INDEX     a   CREATE INDEX users_authd_user_id_d24d4c_idx ON public.users_authdata USING btree (user_id, key);
 2   DROP INDEX public.users_authd_user_id_d24d4c_idx;
       public            taiga    false    206    206            -           1259    7983533    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    206            .           1259    7983534     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    206            3           1259    7983535    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    206            "           1259    7983527    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    205            #           1259    7983522    users_user_email_6f2530_idx    INDEX     S   CREATE INDEX users_user_email_6f2530_idx ON public.users_user USING btree (email);
 /   DROP INDEX public.users_user_email_6f2530_idx;
       public            taiga    false    205            (           1259    7983521    users_user_usernam_65d164_idx    INDEX     X   CREATE INDEX users_user_usernam_65d164_idx ON public.users_user USING btree (username);
 1   DROP INDEX public.users_user_usernam_65d164_idx;
       public            taiga    false    205            )           1259    7983526 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    205            �           1259    7983831    workflows_w_project_5a96f0_idx    INDEX     i   CREATE INDEX workflows_w_project_5a96f0_idx ON public.workflows_workflow USING btree (project_id, slug);
 2   DROP INDEX public.workflows_w_project_5a96f0_idx;
       public            taiga    false    230    230            �           1259    7983830    workflows_w_workflo_b8ac5c_idx    INDEX     p   CREATE INDEX workflows_w_workflo_b8ac5c_idx ON public.workflows_workflowstatus USING btree (workflow_id, slug);
 2   DROP INDEX public.workflows_w_workflo_b8ac5c_idx;
       public            taiga    false    231    231            �           1259    7983841 &   workflows_workflow_project_id_59dd45ec    INDEX     k   CREATE INDEX workflows_workflow_project_id_59dd45ec ON public.workflows_workflow USING btree (project_id);
 :   DROP INDEX public.workflows_workflow_project_id_59dd45ec;
       public            taiga    false    230            �           1259    7983847 -   workflows_workflowstatus_workflow_id_8efaaa04    INDEX     y   CREATE INDEX workflows_workflowstatus_workflow_id_8efaaa04 ON public.workflows_workflowstatus USING btree (workflow_id);
 A   DROP INDEX public.workflows_workflowstatus_workflow_id_8efaaa04;
       public            taiga    false    231            �           1259    7983947    workspaces__workspa_2769b6_idx    INDEX     w   CREATE INDEX workspaces__workspa_2769b6_idx ON public.workspaces_roles_workspacerole USING btree (workspace_id, slug);
 2   DROP INDEX public.workspaces__workspa_2769b6_idx;
       public            taiga    false    236    236            �           1259    7983965    workspaces__workspa_e36c45_idx    INDEX     �   CREATE INDEX workspaces__workspa_e36c45_idx ON public.workspaces_memberships_workspacemembership USING btree (workspace_id, user_id);
 2   DROP INDEX public.workspaces__workspa_e36c45_idx;
       public            taiga    false    237    237            �           1259    7983985 0   workspaces_memberships_wor_workspace_id_fd6f07d4    INDEX     �   CREATE INDEX workspaces_memberships_wor_workspace_id_fd6f07d4 ON public.workspaces_memberships_workspacemembership USING btree (workspace_id);
 D   DROP INDEX public.workspaces_memberships_wor_workspace_id_fd6f07d4;
       public            taiga    false    237            �           1259    7983983 ;   workspaces_memberships_workspacemembership_role_id_4ea4e76e    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_role_id_4ea4e76e ON public.workspaces_memberships_workspacemembership USING btree (role_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_role_id_4ea4e76e;
       public            taiga    false    237            �           1259    7983984 ;   workspaces_memberships_workspacemembership_user_id_89b29e02    INDEX     �   CREATE INDEX workspaces_memberships_workspacemembership_user_id_89b29e02 ON public.workspaces_memberships_workspacemembership USING btree (user_id);
 O   DROP INDEX public.workspaces_memberships_workspacemembership_user_id_89b29e02;
       public            taiga    false    237            �           1259    7983957 ,   workspaces_roles_workspacerole_slug_6d21c03e    INDEX     w   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e ON public.workspaces_roles_workspacerole USING btree (slug);
 @   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e;
       public            taiga    false    236            �           1259    7983958 1   workspaces_roles_workspacerole_slug_6d21c03e_like    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_slug_6d21c03e_like ON public.workspaces_roles_workspacerole USING btree (slug varchar_pattern_ops);
 E   DROP INDEX public.workspaces_roles_workspacerole_slug_6d21c03e_like;
       public            taiga    false    236            �           1259    7983959 4   workspaces_roles_workspacerole_workspace_id_1aebcc14    INDEX     �   CREATE INDEX workspaces_roles_workspacerole_workspace_id_1aebcc14 ON public.workspaces_roles_workspacerole USING btree (workspace_id);
 H   DROP INDEX public.workspaces_roles_workspacerole_workspace_id_1aebcc14;
       public            taiga    false    236            a           1259    7983991 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    223                       2620    7984077 2   procrastinate_jobs procrastinate_jobs_notify_queue    TRIGGER     �   CREATE TRIGGER procrastinate_jobs_notify_queue AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_notify_queue();
 K   DROP TRIGGER procrastinate_jobs_notify_queue ON public.procrastinate_jobs;
       public          taiga    false    239    239    849    323                       2620    7984081 4   procrastinate_jobs procrastinate_trigger_delete_jobs    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_delete_jobs BEFORE DELETE ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_unlink_periodic_defers();
 M   DROP TRIGGER procrastinate_trigger_delete_jobs ON public.procrastinate_jobs;
       public          taiga    false    239    339                       2620    7984080 9   procrastinate_jobs procrastinate_trigger_scheduled_events    TRIGGER     &  CREATE TRIGGER procrastinate_trigger_scheduled_events AFTER INSERT OR UPDATE ON public.procrastinate_jobs FOR EACH ROW WHEN (((new.scheduled_at IS NOT NULL) AND (new.status = 'todo'::public.procrastinate_job_status))) EXECUTE FUNCTION public.procrastinate_trigger_scheduled_events_procedure();
 R   DROP TRIGGER procrastinate_trigger_scheduled_events ON public.procrastinate_jobs;
       public          taiga    false    849    239    239    239    338                       2620    7984079 =   procrastinate_jobs procrastinate_trigger_status_events_insert    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_insert AFTER INSERT ON public.procrastinate_jobs FOR EACH ROW WHEN ((new.status = 'todo'::public.procrastinate_job_status)) EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_insert();
 V   DROP TRIGGER procrastinate_trigger_status_events_insert ON public.procrastinate_jobs;
       public          taiga    false    336    849    239    239                       2620    7984078 =   procrastinate_jobs procrastinate_trigger_status_events_update    TRIGGER     �   CREATE TRIGGER procrastinate_trigger_status_events_update AFTER UPDATE OF status ON public.procrastinate_jobs FOR EACH ROW EXECUTE FUNCTION public.procrastinate_trigger_status_events_procedure_update();
 V   DROP TRIGGER procrastinate_trigger_status_events_update ON public.procrastinate_jobs;
       public          taiga    false    239    239    337            �           2606    7983607 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    3136    212    216            �           2606    7983602 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    216    3141    214            �           2606    7983593 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    212    208    3127            �           2606    7983556 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    210    3127    208            �           2606    7983561 C   django_admin_log django_admin_log_user_id_c564eba6_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk_users_user_id;
       public          taiga    false    210    205    3111            �           2606    7983647 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    220    3151    218            �           2606    7983668 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    222    3161    220                       2606    7984056 5   procrastinate_events procrastinate_events_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_events
    ADD CONSTRAINT procrastinate_events_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id) ON DELETE CASCADE;
 _   ALTER TABLE ONLY public.procrastinate_events DROP CONSTRAINT procrastinate_events_job_id_fkey;
       public          taiga    false    239    243    3282                        2606    7984042 G   procrastinate_periodic_defers procrastinate_periodic_defers_job_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.procrastinate_periodic_defers
    ADD CONSTRAINT procrastinate_periodic_defers_job_id_fkey FOREIGN KEY (job_id) REFERENCES public.procrastinate_jobs(id);
 q   ALTER TABLE ONLY public.procrastinate_periodic_defers DROP CONSTRAINT procrastinate_periodic_defers_job_id_fkey;
       public          taiga    false    241    239    3282            �           2606    7983768 _   projects_invitations_projectinvitation projects_invitations_invited_by_id_e41218dc_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use FOREIGN KEY (invited_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_invited_by_id_e41218dc_fk_users_use;
       public          taiga    false    228    3111    205            �           2606    7983773 \   projects_invitations_projectinvitation projects_invitations_project_id_8a729cae_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_project_id_8a729cae_fk_projects_;
       public          taiga    false    3175    224    228            �           2606    7983778 ^   projects_invitations_projectinvitation projects_invitations_resent_by_id_68c580e8_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use FOREIGN KEY (resent_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_resent_by_id_68c580e8_fk_users_use;
       public          taiga    false    228    3111    205            �           2606    7983783 _   projects_invitations_projectinvitation projects_invitations_revoked_by_id_8a8e629a_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use FOREIGN KEY (revoked_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_revoked_by_id_8a8e629a_fk_users_use;
       public          taiga    false    205    3111    228            �           2606    7983788 Y   projects_invitations_projectinvitation projects_invitations_role_id_bb735b0e_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_role_id_bb735b0e_fk_projects_;
       public          taiga    false    226    3185    228            �           2606    7983793 Y   projects_invitations_projectinvitation projects_invitations_user_id_995e9b1c_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_invitations_projectinvitation
    ADD CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_invitations_projectinvitation DROP CONSTRAINT projects_invitations_user_id_995e9b1c_fk_users_use;
       public          taiga    false    205    3111    228            �           2606    7983727 \   projects_memberships_projectmembership projects_memberships_project_id_7592284f_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_project_id_7592284f_fk_projects_;
       public          taiga    false    224    227    3175            �           2606    7983732 Y   projects_memberships_projectmembership projects_memberships_role_id_43773f6c_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_ FOREIGN KEY (role_id) REFERENCES public.projects_roles_projectrole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_role_id_43773f6c_fk_projects_;
       public          taiga    false    227    226    3185            �           2606    7983737 Y   projects_memberships_projectmembership projects_memberships_user_id_8a613b51_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_memberships_projectmembership
    ADD CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_memberships_projectmembership DROP CONSTRAINT projects_memberships_user_id_8a613b51_fk_users_use;
       public          taiga    false    205    227    3111            �           2606    7983745 D   projects_project projects_project_owner_id_b940de39_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk_users_user_id;
       public          taiga    false    205    3111    224            �           2606    7983751 D   projects_project projects_project_workspace_id_7ea54f67_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk_workspace;
       public          taiga    false    224    223    3171            �           2606    7983711 P   projects_roles_projectrole projects_roles_proje_project_id_4efc0342_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_roles_projectrole
    ADD CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.projects_roles_projectrole DROP CONSTRAINT projects_roles_proje_project_id_4efc0342_fk_projects_;
       public          taiga    false    3175    226    224            �           2606    7983866 W   stories_assignments_storyassignment stories_assignments__story_id_6692be0c_fk_stories_s    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_assignments_storyassignment
    ADD CONSTRAINT stories_assignments__story_id_6692be0c_fk_stories_s FOREIGN KEY (story_id) REFERENCES public.stories_story(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.stories_assignments_storyassignment DROP CONSTRAINT stories_assignments__story_id_6692be0c_fk_stories_s;
       public          taiga    false    3235    233    232            �           2606    7983871 V   stories_assignments_storyassignment stories_assignments__user_id_4c228ed7_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_assignments_storyassignment
    ADD CONSTRAINT stories_assignments__user_id_4c228ed7_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.stories_assignments_storyassignment DROP CONSTRAINT stories_assignments__user_id_4c228ed7_fk_users_use;
       public          taiga    false    3111    205    233            �           2606    7983878 C   stories_story stories_story_created_by_id_052bf6c8_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id FOREIGN KEY (created_by_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_created_by_id_052bf6c8_fk_users_user_id;
       public          taiga    false    3111    205    232            �           2606    7983883 F   stories_story stories_story_project_id_c78d9ba8_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 p   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_project_id_c78d9ba8_fk_projects_project_id;
       public          taiga    false    3175    232    224            �           2606    7983888 M   stories_story stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id FOREIGN KEY (status_id) REFERENCES public.workflows_workflowstatus(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_status_id_15c8b6c9_fk_workflows_workflowstatus_id;
       public          taiga    false    3228    232    231            �           2606    7983893 I   stories_story stories_story_workflow_id_448ab642_fk_workflows_workflow_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.stories_story
    ADD CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.stories_story DROP CONSTRAINT stories_story_workflow_id_448ab642_fk_workflows_workflow_id;
       public          taiga    false    232    230    3220            �           2606    7983933 J   tokens_denylistedtoken tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_denylistedtoken
    ADD CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou FOREIGN KEY (token_id) REFERENCES public.tokens_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.tokens_denylistedtoken DROP CONSTRAINT tokens_denylistedtok_token_id_43d24f6f_fk_tokens_ou;
       public          taiga    false    3255    235    234            �           2606    7983926 R   tokens_outstandingtoken tokens_outstandingto_content_type_id_06cfd70a_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.tokens_outstandingtoken
    ADD CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.tokens_outstandingtoken DROP CONSTRAINT tokens_outstandingto_content_type_id_06cfd70a_fk_django_co;
       public          taiga    false    208    3127    234            �           2606    7983528 ?   users_authdata users_authdata_user_id_9625853a_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk_users_user_id;
       public          taiga    false    3111    206    205            �           2606    7983836 P   workflows_workflow workflows_workflow_project_id_59dd45ec_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflow
    ADD CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.workflows_workflow DROP CONSTRAINT workflows_workflow_project_id_59dd45ec_fk_projects_project_id;
       public          taiga    false    3175    230    224            �           2606    7983842 O   workflows_workflowstatus workflows_workflowst_workflow_id_8efaaa04_fk_workflows    FK CONSTRAINT     �   ALTER TABLE ONLY public.workflows_workflowstatus
    ADD CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows FOREIGN KEY (workflow_id) REFERENCES public.workflows_workflow(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.workflows_workflowstatus DROP CONSTRAINT workflows_workflowst_workflow_id_8efaaa04_fk_workflows;
       public          taiga    false    231    230    3220            �           2606    7983968 ]   workspaces_memberships_workspacemembership workspaces_membershi_role_id_4ea4e76e_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace FOREIGN KEY (role_id) REFERENCES public.workspaces_roles_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_role_id_4ea4e76e_fk_workspace;
       public          taiga    false    236    237    3263            �           2606    7983973 ]   workspaces_memberships_workspacemembership workspaces_membershi_user_id_89b29e02_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_user_id_89b29e02_fk_users_use;
       public          taiga    false    237    3111    205            �           2606    7983978 b   workspaces_memberships_workspacemembership workspaces_membershi_workspace_id_fd6f07d4_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership
    ADD CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_memberships_workspacemembership DROP CONSTRAINT workspaces_membershi_workspace_id_fd6f07d4_fk_workspace;
       public          taiga    false    223    3171    237            �           2606    7983952 V   workspaces_roles_workspacerole workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_roles_workspacerole
    ADD CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_roles_workspacerole DROP CONSTRAINT workspaces_roles_wor_workspace_id_1aebcc14_fk_workspace;
       public          taiga    false    223    3171    236            �           2606    7983986 L   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk_users_user_id;
       public          taiga    false    3111    205    223            �      xڋ���� � �      �      xڋ���� � �      �   �  x�m��r�0E��W��.5�u~#U)<(c���]���Ԣ�%�8���BQ��0�8�e�f���~�ľ����x}曉Y����᣹��~���?'���C���i�Ǵm�2�|qA6T�� Kؖ�2L	ۡ(#�&����.��(���Y����E�:�hT	�����ip_n���[�E�,�kw)UEE(2H�ԇ���d�Z�sjH���f�߰vnp%UGՐ��b`0}A)��҉��赙U4N��Qj���]� {� ��n�_�o��7�؊�eߋq��h��q}\J��&Vhc�( ��i�;k��-_^v��<N�ˇ�E��ɺ[�%{�s1�&�L�P&M�Q��\�4�4���>m֌��]9\���L�%96]�Krd�2)W+���}-�����6{q}�Y��c t ,�AƂ7�DF:W©ԲX���*�z,�Jgu�D��Ce����>Te
����L��y��u{��Bi�oɪɷ��}@�o����rmy�w�a�����\�P�3��f{��7:pl�	�ρ#sN(�mL[�<�������˲�2�,�}1Xg�Y��`�a1�Cm�̿�5m�^ʺ�5
4o�}�I�.�\���V��4Nv�ǇZ5�o�F�Z�$�B�e��^4\��x�v��:iJ���M�(5M�)O�4���0oJ�]ڔGiS�پ���|	՝{�q-�K���lj�T�NH�{yR�-+p�6�2�+���}mB�Lүʶʩ�LdbuΛ�"�k�$ĺ�9Q�e?rk�Mw���� �Ӵg�Y:0�(혎�������Ű��o�c?��P�e��(E-i�L|� U��**Ű��n�k�O-�����؈"�b��T0�2^�.��z���t�]�ٳ�b h�McA��d��	W���8���\���[����Q:nAPg�D���4��Q��%��?���Q�`      �      xڋ���� � �      �     x�u��n� �3�,��ޥ�a�*]����틊J�����q8�u��%��²�d��y�F��B��>��f�3ڲ���0���Z|�paU��	���3:In��S%���$m�m��oJ��4j$խ?��O��Mi�8/x�X�s\���#e�/|^1ܷj	�x��H?JJ�ϻ�O��z��P���$iYS�~=�e�˄�%���^�W��д[��Đ\�)���@�42�WoM��, �`J�����J=&��!m]To�^���;�&/�
|~ �/g��      �   �  xڕ��r�0���S��F��o��3Pc[�,Hx��21�1�r�cΧݳG�iu�]�+B5���ۺ�D��?�z&��5M��I�
�Mh�kS:un��	)Š��n�.�H�	�H��a���']���C
�n����Ӂ�/�0���M�5��ݙ�>�M�g��)�l`�o��g5�fxbZ۸YM��r���f�RJ#jR��ur�t.6��&�Mc?L��]��
	Qz 鉄g������H���	î1�W)'ti�P�\�	J'�fԶOð|��P�;� �L������4�2(3xv��5��	"ϕm��6�ؗ��C4��{����Z�	eN͚��f�B��P>��7���f�ܩ�DQrF�b8t�0\>�6e�Rs�E�t1|��y�	J�]Mi�p�ի�K�RT��-]m_�$��EI.����d��м�9��1�H9��Ω��{���6�3�>T�!����,9J9ϓ,�����&-��<�Q�&���^���H9��_čk^�����'1�K�p_��V�����*=nAP��}{�ɦ2��k���d��zw��c��R�7)s}���C�X�U��Ҫ�ǍwKTZ�1��*cs��6�/- P��"^�wUË����U)��v�R���"�W�_�,�D��`�����Xs�82�?��~�(��^�V�~�      �      xڋ���� � �      �   �  xڕWˎ#�<�|���N哙�o�L�,�a���계
j�Iʌ���smi��[����\j���������߻�w�e�_rՙ�!3O[Zd:|�i_}�6�iN��͇�N�{Və�3����~�����P���'�_���I�S�i\W�&�?u�S�u�mF��W�ɹ��XI�Y�ʸyS�-t�@J%����k�!�
�b4רF=�ښ|�zq��$�����u��S+��׈�Ӳߐ����x��6�1�VV`���30�œ{m�eWQ�+-ƿ�.o �:��?ٛ��R���l���cU���W����i�Ųl%��M+;���N�L�}�_y�䵧c1+D&�!Cz��+N���r���!;sĔ�Qk�5$a������b b#n\�4���}���06��������9]�3&�����ܐ���&�ԯ}�9hjͩQ+|=9O��MUc�A��ch@#s��7�h�8ٞ)��C�]y�d/RP'쨃Eԩ��qÒ�s�|�?����א�R� 1}b�A���ه��I�%�)��{��f�EyW�gi�J�6�`�T������>a�	���c�i�@���&nwp��W�y��ޗ����`j���,�8�zRe�ឲ��S�-w�$_p��Ŋ�mE�X,IZ��5J9{{�	�A8=�>0�����9!��Z�,!|t�:x��!r:C߷�fH��e��/��=����5�C�)��i����F��8:���U��j0�g�κF�����ѿ��'.�݀�g���}oG��Xx�%���h���f����7�l�11V��`j�Ȯ�
��FW|GB��b��g��x8�����Ro0iS���&nO��u�����7컥/8�fH_MaՑ�xݝgC^ �}J�� ���#O���`�m��	!S�y�6_�R��cc��^���x�I�I�S���7�υp�X4dx�;�)њ�}���ɻbN�����4F-�]�`2$�=�>�4�� ��
���z�������ݱ7�{�1	T��rF�w�풼*�L�<\�ٝ�'o@�Ys�1R`9h%ģ��Q6�{ٶ�-�`�Y��GQ���H-�m<0+ܲ)d66���ݝ䎑��SD��ORE ���57
�L�Ԟ�"�x��f:��T�P&��6<P� ��h}P�0�5�nnM{��i�͞��|T���TP8*�����҆���aS �$�!l5�@i8�׸���$�'?�$�8�Q�j�N�C��QM'd�Bp��P�P��v%��=(���ݡѵ�`2l��O�x�����%B'2n-t��G*yL�.1�s�?n%12��Ԁ�L��.>�dw�rLA�Q�~�s�s�N_��Pl���G6�bQ�%�1)��x��~������X�      �     x�ř͎#���SOựS�Gfr������gv��>���֞���Ѝ� ��
23#X�mHn��e�v�9���UKe�$c|������SO;�)g_-¥��C;��4�i���,k�d�r�VQ��wY�J�������*���G����?~~���߿	��B��?(~e���w�$��I�y�3诠��J�7��������4���9��d�sZe����u)��ջqN.L������ɸ\�r��w���o�t�s�?r�`��ڨ=S�:�/���5i#���J��:a��Ὄ-=���8��Op�ԓE����s���O�X�&4�;
*�6ͱ��n4_FSf��n�J��'�G��4��Zw;�	λz&'�7g٩��X�J
����4z��&5S�4QKm��`6��,�M+'���E<.�t0=zW�����A�g�ʧ>[B�\pCuHEa���+V����Tk��V��K�ӢԺ�����h>X� ���@Ҝ�@ugv���R�����|�jJM�d��k͆�J=��|RY�%�����)�(��L��	л�Z�+�nL���T�y�V�ioM�O�ꊶ
��)���U��Z�Q2��\���Y�͞_�)�Op�4�I���X��&�����FQ��
*3������C!��,	��cO��䯱T�'@o*����EZv��LI�y�5��RtI�|�v�W�V`W�R���PwN#,5������+��0�!��]I��?����`��thH��:dehM��Z�L�u���m��a�ڒ�J:״�iJ�ﰄ�$O��������7^ٮ�DF����/
l
,H�+(6�0v�(6����{��Q�Q��bO�ޔ��rҍ�4`L�����!�1��8����k�'��b�:�!��A#�֝��I��ޥ���'Hoi
RS��!��'��߄�<jh�e[��L�~`/�ι��ӭWƌ�3IV{�Hm�=MS�����'H�j꒓}H7FT���Ca�Vd�d]4���Z�q�{��yu��4��Jf}�*yNZ��4� ��C�	қ�2%M�!�a���Əz�E����Tl d��;��Hb���N#�h��QU���P���!8*O����H��1�앜�\ʨ�:�'�H�4`�'Ï�)\K/�B�q�p˜@�2Ơ�=IS��^|?Ԟ �+�[�jR �
P��Og�y��r�Q���:C똰!�Ã#,>�"ӚC�FS�{�N�c=�C��75*n�!�QW�_��zj1|�w��GEA�e�ax}�uP��°d�,[���_�ˡ��]M�M�>�e�����9wT�R)��e��-��jBϯ¶L|"\�hs��7$�G�����똜�'H�hz�^A��5�20��%�ZC��<w��T|�.��$æ-���VR
�n0~�{���y��a��MI��ѥ>��)ʱ ���N��hX��uFvE�n^a����P���ν�b��i)�S}���	һ�j���]�#*�����Q:J]�R�VV9`�{�2%g�#-�I�V|ԅTү��lC���>��XB����-M���b�7��ݧ�Z�\a;t���r׮�/&F(��I�ѣld3�.k�rF��{xKS!d�7�O���TQ�>�#�Ч�{�������YцY0�%uZ��[�,Ea����f��cOS��_Eґ�	һ�&t`��n̨�y�3�Eܵ!7����$c�y��Z�6X�������0{�bF��ܧ��O��	һ�F�;�\��Cjם�3j�ot%+W��x�~�H�D�,�W�)���{G}̈́Q����4Uz%S�#��75U���@���8�����      �      xڋ���� � �      �   ?  xڅ�=�1F��S�StY�Ҟ��b�,p$y��_}�ڒ%7\p}<~=>?.�o��}Y���Va���&��Ϗ�?'�1IE������8�nJ��@`�J���$H`V�9
�c��E��܋�W�z�g�"�Eɪ��s�u�d�w��G���Y�P7�" ^�"V{�P��	Ǌ'�<:ɶ�"�ظ�҅�ꥃ.��ɹYK�hШ@t��/{�j[!.��2��U
�Ok���!%F���A,t��}!)}��X ѕ@.t� �F�b:����j�g�B�b�V���p {w/���b��["�l�o|�(�tZ�x�2�N&� f_˭kGX�2or�������G|�4&�n����|�HV��;X/��
�kB���s��i��Q� is4;'{����,�41Ao�� `(��Q,)uo06;h$m�7W��<a����\�A���#�,͞4�t��_�%�I�r���c+��Ql(�8dov�H��w'q��f���e<i�8�!��j
�!YB�4����>h���Y��7�dc����,ҹ�r ;Y+y����#_��9sM���&gO�)�5�e���Bx,��O�B|;s7�b[�4I>ޚ���s��~r�s2���R�cr΁��U���%x_+�i:����ݬ{�(4��f���"鼭�)kYA,h�HyM�
>j��{ΰٳF���g�d�`�	�W۸�ɂ�Wa�@�fG&���e�Jp�˞��٬�F�j�D��W�����;(�����W%O��4zf84;�~�y�o��Y�|��:|��*��O)�f���~�}�����݇6s      �   3  x��m��H��_�|��~�v@*>�W��e&� &�	)��l�w������Y+֩��s#��� ����'��Kn�CV�RzI�}��d���+��sn���_�N.���?���'/�>g�1�<?��o�c>�9����O���.�¢��/�|[������1�'����$߮�<��C+=^�~b$�fךH�ж3�jm-�-C��	kTf�'��A��<	���W�,��Ԓ�P��q?1��HmV�!��B�;����a���43E"�	��-��5�S�p����X��%�d���!�e��y�[zF�R�ݹp��"�8:#�c1�V�`4�'e��>c��ѹnX)DIsa�YIž)ңI|kG��8�'L��d��/SS$�vu�}��/����0�K$�_�G��l��m�~��qM"E0�#E�(U��BD��F)f���VQg��9N��]����=��~�����n�uw�:<�wX6gG-��C��]�u��1E$�ǳ�{�il'��E�1?w��]�jw��x��*�#G8�p���fsEB����8��ʟ���!(E��rE��?�������+�S�~>�P`��:��fp���"0D�_f�!�V��c�h-\�'�2[�Ӗ++�M�W��2x��kD�m-�+G_��N�3Ђ��rX��9Y�Z��O�Gw�Dۗ��Nh؛�n���y�����i���>=A�ൗy��Y藫$���.�t�PB�]���ʣ�5����o_`ze����t9��6_�����Co��y���4��e
�09����𼌫'#��A����?Kd���C��pp��	Ɯ	�̢$� ��)<HC�&)�a+�t�	��φc���8`�d��;��{��޽|(pH1��I<�R��]bkcH9~�Z.L�iM%:�/�g���3�)�&�r��m!��X����r9�N��N��;�	��pu�g0S�C��9�����2����izY�Lx��l�2��>��T���[8�W�ø6ʰ(��e�M��a��}�S=��d��x
.�?C�E���uT�:�_?�UL�d���SqTپ"�z���2C{2As'G�b���N�3�З��c`��U?���v��-��|Ͻ�QR �?IU�p�M6 ~?;z�������7�*4�����4��e13,���pCe���1��lt�� �2=݌�ayHQ�h/�.���{�9�Nk����MF�h�K��G������1ڹ��ޑ��K�[.���@d�1�BP0W*�|(94	�.0��ԡ�zƿp�H.�7s�,��V鯂
F��/Ma�����VTk��Y�OSܿ��s���N+ιW<�f�4�&|��G�<�0���Rj�MCU�����	�b��&����v6-�fMl���7J}�;��$����x!����gix/6{f��l�{����W�Y�}�$�$6��ۆOCP���7��7�	�VQn"ba�^<���'������Z j�eS]��LT=��Z���A�c�D�,����p9Q��n���<��2c��'�cxPQ�_�����7��Ա[�>�P�C26M�"�E�)`+���S`��9UѨP�v��'�Y߽V�h�t���4��aܭ+L���Aj%Q�0���NQ��
���
r�7��ه��@��,N7�i
.SN`~�J:�:�(��k��o���F��B��rG/�IO.�y>�O�ʘ��+��`Q�v�Y,}$PW:�}	[�����܄�~��e��BY��̕���
UD���ͰVV���a&�����)��y�����Z9�<�w�Ӄ�ڼ���� �p���8���\DՁz��#rtrez~��N��������il31�·;���מ��p;)�et,�>u_��b?�߄���ji�xn�R���(���A?IY������	��]\�۝(b��ke)�d8���c\���JEC�a�_/�,�P�����u|k��V���1�D��f�D����{Xt���R$��#О
�)���)�|�Ӈi�~�B�<v��d�ڛ��K��,6,Ь:�03kjȵP�X#�Ψ�C8��=o�䪦H,�˞w�"�{]����A�σ��v����f@���{b���b՟�i��z���W���N�t��B�ߴ+�"u���.�M�H� �W��t;Λ�&k�wB'� ��������*�">���3hX������\L�DQ�N������@F�������;X��`im��NY��6�	Q	�ݔZ�i��?��e^���!��-�y�3"&�z@�N�wVM.�^�إ�`�wja1����>����-,����eU���.�Ta�؀_xY4J.N��)"W�8�z�Q�u��~5-R+�U�`[�1Ӈ��T���fmׇ�K4m���@�򠾴���v{w���H콫��9՚�+�%�-�m0��̰F�p�3�n��	[�����)�[7s�,�����|p��I��1�v�HǋuG�lE�f�=�H�S�4T=mw��&`�m{`Ӏ�J�찞b�pz���cWU*��g"C��l�2�$�(��Yq�6G3ܵߴ�ՆNʈ����������țo��;m�"�nbzGL@L�62����:�	2��,E�*m�?U;�U�]0��k���)Qv���+-a�[�J�Y���\����$�����+Nʽ�D�hc��t>J����cp��6��Z��UPNNOX�׮�+\k�k�z�g��u�n�s>۫���ڬ_6�%�ST�qy\��]K�w<�ͅ���{����=v����]��_�����t RA �@S 2z��RN��P�k;6��@��4����]k��L'�5����]�Zw��|�lsUD�M-=��8l�,]��QQć����G��S|�]�+���ڢkѓ+kEX�V*\�'Q��P	��)���B2~��nWQ��if-������%�]�&q"-���W�YEN���Av[�t�>�{�����|+�|YiMRC� XM�?�lJ�:�X5�����́ �������5/-��T|�%��qX��};n�8Lܑ:���Y�B��8 )��;��>�H�t�j-�e��h��W55Tz���D]p,��
x�s�; N/m���x�f�u�a�^�aR�g�Y��u���]&g�ﶽ�A~���WU�H�8���́��_�}G1e�`Xf�Z��q�˂�:Z� g�8 ���Z5�]T��q�Z�kc�e��y1l�l�C>�6z��X�~�s$�����v���bڛ�s����� ����+�B	Ţ
[
*�.��[ ����lbK����j�}�Ap��%�v����.�H�1([CT˭ێz-η�m�3��ӝ�X����_�_��`(      �      xڋ���� � �      �   �  x�͝ێ7�������4HQ�Wy�<Ant��� q�����&e�Ś�Qp<z�#%�'�R5&�����>!����)rO1S*>�w����?|N���n�}��.��~���;�� �0������Sp�o�w�������ʯI���_�B��V{wЗ��+us��|�=�to���<�6�G� d�[��O	D�	rg?�<C�<�G[M��#�����\g��S��L��>��'r�f�oB���o�{��m�S���#���%R�{��+�����e��B�y�����[�b�s�rD>>D��|��N��~���{tH�h-�2��.R��{�v���&��4~,�F��1�zP���~�����w靻 �(����?�����)��+?'�������˯O����|�8�GO�����:.8< ���3{�����W-���!���̨rdp��e;O~D0zju���ǧڛ�Z�œ?Z�ߛ�?�K�3�/+�kiLM1l|�󽿬�֕T��0�朇�o��`|�L���	��IA÷C;Dk�Zf�����5a"x2��u!V|����.��/��b\�D����!��?je��oͣ�o�GP��#�ZY�_�\`�����$h��C�l/�/��#��^��ޝ?���ި��X��@t�oW��a2{�b$��3�ո.��e�V.��W(F�?�j��b[�1���2��-AضG�Mx0}�x�22����JO�/�/i�E�Bh�^�~\[魵X�"��)&���:��s�f�r�
�����Z�`��s{w�v?�.���"�bkr*)��\"��y,��U�>_��Kw�땙+>�w{O�����A1e-��/�/JY���߄+x_TeWt�I��^񝹀�EUv2Ə���'5�;�D�G��%�R	�F����t,�O�����*)��D��5jI�oc��^��C�`�ȶ~�a��|��,��+�	����E���V|�t�K��D&%W�Dߊ?R��e����V�M��{wzI�"�5�5ͷ҇���)��7�{�z�o��.�/�|c}��x5ͷ����~��#�4����]�S�%;+)$d�eOd�o}����~L*�wj�(���o�4����Q��c�����}�{
�(��@�#��W�(��	
+�����k_�x�8�7u�����D��q�=��=����;a�/�T������7�!�ηsq9�q�Ԛ��1}T���z�+�~|0�+�kl9��.bSK�+;��)���%U���7|���Rz1�ށ���EA�� ��C�!\ _�y5�<���cϏ|2=W��l�*���_�}Y%_�wFrŧ+Ћ�l��'g��蹍��������*�7Y�3�/�.c�Q��ej-| �a|[�j�WٮkGYC�e,<D�N�z�������3���_� =�>�
�eЧ�Z��|���וm]ET�S^ሌ��2t.�o�J��{�R�B���X��"��a���>~�Q��6xKJ�k���+��V��;��p_��;��Kj�l9Bn:�����~�|ɦj��B�L�����˒������3~s|I1�m�����|:�oY�qb�S������
m��)J6櫛�dp�K8g4��stD�(&������#@g�#������C*��<�Zֹ:��?;���:<��C#��x�!�v��sa����y�L��9��Q�VV|�]t��zlVc���z �ȷ�_���ȗkkV��3��+x_�u��j��`��w7����j�b 3�	��/W�@0z�o� �{�X@Y�����(������ʏ��%���G������-��_���X���7��%�2�>j�vx���:_�b���fY�C� �D��d[�+>�B���8�s�IQ�-�t��'�l��
��b�����XF���Q�=?x�CO&�Og���us��yqW�HF��h+jL.�0�Q�9��wW�= ?��+�9(.`�քZ�y/���L�&�$�w�����Q��ڼ�2�k�s?��!t�>�Ћz��Y/���aw���m(�W-6�&���E�/�M3�q0�7���Ɔ|Aѭ�l�i�h4!��ݳZ���x|Q�BL�w�g���luz[�h�)i|�-�bm��=Ew�,eq�Ԋ��f�s�,gEJ�W�n��
K_T����)�b}�w�||�XO	���_<���UN���B7�'i�Wb�D>Q�-�6䥢\]����&�����¶;�w\,�K�*���o��ś�2�Zj\�U���z��?��D���*�������/W]U ��ޖъo�
ޗ�Ձ_�e�-��]b�KrV����Z_�5���>����������H�Vpl�U��+��Z�s�%r�B��>�}M��/{p���R�B߶���=��?$]行���m۸hi�w�����������mw ? �F@uoxCRh�G���M.��_����J�;C�L}���D �I���Ä�x�|�ݡ�R�m�Z�/����7��G���|�������o��ŭ)zM1;��6����w�z����3�al��a}����o�e~{���5��-�a]�['�Ëa����73d��ῨaD9�����tV��ab0nݐ�}���%fQ����x?���	��ݶ>�֕�9��-���]p��h�	췬+,�FОZ�d���B4��sc$�2��J��-Z��$H��������u�$&0�,N�.����jk�c������(|˪�gYP6�����=.א��o��S�;K��Ք����L	���T
a�:I�ˠ����`��r4��(���'���䴤˯M0�����;C@ly��w�����𞫃|#q�ݡ"�M���R�X@"�������E�6�C@�h��0��-��l#�0�����{X/�޲@f�{�m�֐ K[�<��:�߲�jg&�S�HD��a^�?��!�k��nj	��C?wMg�Q)޼1�xXXQc�4ITj�M�m)J��z+�x�uEp3ˋ��L�eH���fS������[�U�Xr.S�h]j���y��p��Iƒ���7v�ES��(�u)�F*�	z��ݛrv����
��[�2�h폲ظ��D&���K�;o&�m��%�C��J$�������C}\      �   �  xڭ�K�%9��Ǖ��y[^ʵ�D��/��<~rR�G1�4���?��=+�?3c�`�?���g�Yr��8���� ��Oп���0�����!�K���G� �8����^��n������I���D��{��˂�`ì��Ʃ�%�\JX�P����5	6VFPgb"�mE���pA�
�M�LZ�8��9q�tB�}���j\sH��ƙșXh�51���m�X�M�"眄��+S��"�X�9q��ݏ���Ċ.�	�z����y2��O�&ΡpZڸ�v�#*}��(�6VĹA.�6?�S����[��0湮������WL����5�6/b�d���n�[3�b*�T舸�2զv�B1��
��+�	VY��J�!���RH��)BЛx+�T͒��	�|B�b����:�Ebr>8�i��S��� "�6�RB5��/f^Ĕ���[5H-� ^۬N��[u^-<��X#��W��),�u��h
_�(]V�Lj���G<na�K���[U��c���& zoŊݢ�1����G�X�e����M^�!Fv&�SBMZ�犞 	�u^�c%�mq���:��ۘ"�W�m��|b���E�O��+����P�͒�q���{ѭ�$:WB� �N�7�U`^���6�S�����
�����[5HD�X �W	�j|�[G(.9�s,�	�?3��Rk�g��+��]�GĘ���Wh��<���Q�7�V��Z��1#�7�V<�9ެ&ở�F�W5���E�Nh%�x�xKWX�$Ē�k�~6�� ���.�)��>�#�R����b��~��?�j�^�ċxL�;�V�A3_�X$��y�\n��nu��>��b�?)���{�mD�;�I3~�?o��$G�g^a��1�&�?�l�xK	l�Əs&���[9od�W;&f����
�p�դ�5v�LG�p��Ʉ���F���FT�1z�xύ��M����G̦�\�AF�]8�ɠ�V��^pk��M��śx/I�GW�s�����T�p
�Y���[z~�Q�.�M����^�)]�51+%w�-41��ʦ�(�;�F���w�!au�x���U���L���f�x��lZso⭙7KዚI(G|k���XVyS��⑤gj��X����{3��L�B�����.o�iq����3������YQ�m��@�<x*8ӷ]���[�b�7����o��9�H�M&�&�Iy��"��+��^�	c�.g�L(��h�!e��BcP8"�g��!�ɩz��5�~o�p��Rh��~�OYj/�u���Af��54��B��~�G���xP�����f^g��/U� �X9?�]엪��H�#��Z�B��"䧽;�ăB]��Y���W� � ,�bq��kc��X�țx+T ��8��~Go⭉�:^���x���[���ol̈�&�n�0�/�do�-6?�co�ؒ�
�IQ� N��b+Gó�9.��m�t�w;5�B��"�䷎�w��(lmP��Bܟ3���B�]��#�t�./�B%��,]�TE�Dp�
�~BP��y�iE<IZ���(��8'&L�%��mu�M#u+e=2^��7��8A�� 7�=?��9�q��r$�Rn1w��HJ1���jeݝy�,��3�fg�==K�㍱��"�7�V��j��
fyW����f���"s��<���x\g��n�]ts��<F���G��8g�Ǐ��9`ԅ�G��IF*r��`U@�&��c���C`o��O�#]c�3��*q�T.�9Pv&ދ�A��Y��&��҈Z�<C��[��yŖvC
4.lDw?ދ��y��XX��xK	��)�]�"���Loe�cNI9�Ǣ���{6���5w��ʻ�k/]�b������гN�����65u�Ju!:Ҭ\�+�|A�@#�N�0�Ҡ]c~�W�w}��゘孥7��x�
#�~���緧i8�e�!�u�΁c o�M#�o�%�-�6A�q�x���R���-�i��Ո�Нx+I��.B�&d�y;�gc�ژ~�&��8��\i���=B'�e��<gk������Zj���8���vxKڇ8���۞�e��ݳXl��ڸUF� ���&��J�=����c����:E��D��V7P홸H�r������ݟ6��Y�^(l.�-�p���K�TV��<w����e�sb䔾�:.m<R^��ٸF.ω�"l>6��z�@�j�O!m���5���}t1�h�vl�s<"N>&���yp���2���Y���Cwr����?���F�P��)M��5^mS��)���%E7����1�#��D�6N��)X彲�^z�R7�.���<����n�Ī��ǣ�p��R���R�������v���򝜫
K�黂�&ΰ�[=P�.��j��6f�1���-��#�N������ؤ�Rn�[qI }L���ϵ���c��i�ӹW0��\^�3��vs�u���U�]�%�b�\b��!��8gS��A��U:i��"6� �sb1A������KVĦ6���ǌ9\������@.�b&S��B���'tm�X11����g��ǒm&��Բ�1K԰Z؜u�yN����=e�r�mf>dvP� F�o��$�Y���#D�q��j���^z�d�5y� # �]��?3o�X���k�z�r��� #����e��&�.6n��9�s�g��Ж��Eol�����x���aYN�41��z��iH'��x�&�B9'F�S�iu��quk� --�l���vN�A����X��Rp!��S��λ�9��C9U	>&n=�SP��u�$�Օ�S�e�%�K��bN�I�]���i�&ċ���qH���OK����K��}�<�gb�z�M���S�������\l�tބe��T bSDCW���P� *�"��.�h�Ǐ�x����������>�1��խ��6����w�����W�6m,��cb�A_��t�~M�t�x������X��q�x`s�R��q��.a�Kk��l&ZuI�Rf�vA�,�K[]��i��_�»�>�ZZ���ɟ���2�sYa�!�7��ϱZز��:����l��
��R^�L6�,C� �q���q����M�h3o����3uK��X~ ��'���N�պ�L���b��X��:'�D��>�7,=��q�;9�����+��s_�(�d�y\�8����"����o�JO�/�Sz���w�獸B��x��ܶ�9uh�6iZ� �:���w��gy�5�o���1�{F�� ��p���'��I���8'�?���&n!���k8�c�$O�X��U��&NQ�3�N��C\8�����nOo4�?ĳ��� ooR�'5ʤ����j�$�83&Ck�x��A�ﵦ_<���̳G0����_>�9��O��r��	��:��A����~�Ǒxg�>��O�G,�}��,[7z�_>��	���76�� 
H��pH?#}N+�)��x�kb@��-�7f��H�C��S~��m�VsXo�<�"b;$Ɵ�V�~���)����6�6޷I�]ӱ��'%S6pB\t���BqZ)X�!1��|�k*Z���0`�z)ua������< ���6�=M�/�������XaY<�$�{�|��w��1��K�çeӞ�b	��O�A��e�_�r
�0�-���r��qG�bU��&�
!}���# ���گ��@��N�ol��C3��"�q�!����=����_M���)6��&X?�)�	0G*q��q���z1�Kz[Lqf�_��ֳA:+�ܸ�
#�l�M<!~R�C� '��(���E����s��/a����km����@Nm�tVX^�[T�#b����`�0��>R������� �      �      x��\�r#Gr}����-�u��m4ދ��]�J�}q�F]�� ��nE9��>�����&W��A�A �䩓�'��@֛����F�+�)_����w%�(C2>,>�n��f��&�]�_�au�mw����ж���Ň]n�R��m�m����گZ.��k�4\��t���ut1/q�_և�b�1��Y�.
������EQ��"��A�t�ioڅ`B^1~�m��7�|�Ւy-��Ʀ���j�������!��.zOVq&r�����@1!��W�WJ'H�)lB�P� ����zt��A���Ď�msֻa��i�ܯ-�o�ۦkCnB7��fD:�n��8�<���)d����##�Ol���Nt�J?P�w�*�n{ ч��j��m*?�����p˅8��L;7�:�F�S�=F�9�u�^̹N��ˤ��¦Y=�n����vK]�i�fx���f��%�Y}宽o��H��&�!��:��G�I�aU��n[͸�q;�$����Î��u��C ��_�������k8������C�+���v��R�a�0���[��k��"��=5w�=�[����MZQB���P��M��)���rʜ�$8%��
<�4�Vȶ\��?�]�A,�{�JH��xj��u����D@W}l�)���~��n��,��#q��M��uH2[@ҷ��Zd�������Rų	q��J,�<\R2/&��Z�z=`��f K���DU��W]��<�����j@�]�Ϊ������)�n2}�*?�6�l0��漍��^����]}j7aX##�w("{�d�kjm�7�e A��MZ(B;��ݰZ.�cy�(�%�⃙��R�X���)IIN"����H��,�gΰBYX��da�<+ŭ�DV��<�Ţ��KI�*]���_�#�7;�Y�W�9���6��Y���(Ax���G�~����\��9adaĐ9d�Fq�r'���"]��h�R�U�g.@��v:X�3&/�l�iS69��/_�w�MM���;�W��4��J�O5����b��D�~d$jz?Lf��ez��j���bA��q��$�̷�Sإ�z�X�uu�>���ȿ(oH:{$�1���A���j%�[�Z�y�Z\b/
5r�2
�X���9�e�s��|Be	��2������c���LaZ�����i�%�0�)$��+oD��ɿĊ�UD����UxP�k+�����Ax�_��էz� �i]U8G��ea�Hf����;|I�8�3%�-�c-7��<�Y�6��\��;
���V�'a�U�U����g�z&�}����c�� MSZ���5 5�)��|�(�yD�+�[5͟j}���\s�[��\�/��3��
5���V`
ѡ��Z��������AKߵx� 5���Tf�X;,\�]6ÐV�<�U�>'�B�j$�"9�4d�Ϩ#:�\:Z/�T�p�<�NZ��<��WF1m�r�T�z :�5�ϥ���̪�3.��W�����@/�t[ye��.ܭ ��j���LE����ʻ�b�o��l��*�7�ݺjҺ�}@+�nO�	��˵��s^Ţ4��,j��ȁ�'����2���(	���i��pFNj�j5�a�����
��Գ�b�2�+z7�.�u������� %n�L��w�BS�
�W��{��@WT����V��Zk�e���{��$��)��[D���u�ֶ�Cs�i#(��ݱA'Ph,ݧ5�i��}���o�횻Ue�xF��G����n��k��!meL%P`N��b�%�bI�3K�ĨkM���[�"yu!j=b�M���*N7X �>��(���������۴U؆aX�LWm�F1�3;\��H56wt�75�'����a��g;/t���\�$�f��:��&�U��v�m�LCXo���=mJS	�ڀ���������P�1�sf�gƵ���Sx`DA�wA(��
��-�;��P�����[�&���jO����۠�I�90�޽�?z�u�as
����2�hh�����Q���cE �(=H6��(����F=\_�ǥI�P��Ա4�Z��gwi�-,��O���_��JJ�0���L��m�H���v�Z����zsܲ�[5��ŗݐ��It���s���*�k7n�p��0�#�W3�jle��@Z~O�v��X�~��G�s��nnBn������
�V�PS9�����:������p�?s|��H�V�������ß��C�o�;>8�u���������7�Wʨf���m����҆Z���Nz,q�&�W"u�S�AP:6�������y��i�28l'#�����~8Y䫈��]���a�r���~j8_��P�,���t�v���9>��S[�F�ND{F����&H��1RyU"�`#c�[�1ª�(zDt6�RKϦo ��\2��y�F+$�	`YC��9�E�f��)�0�2�@�ab�}��h>�xe4cj�gX��ȷ�9�9EZ}�}F~����?�ُ��ٴ��O�%~Cn	��L`��J��F
Ux�*G�O2�}�����2рI=M ��������fј��S�$�O@��P�I�-��QC>��7 =�`� �' v����Qt�e�Lb�!d�A�h�N�^K��z�3����o�-髦"`^�t���K^��P�rQ�Vs�|�m�*�ds�iӚe�,wA�s/���$ԝ��dU��nժ���L)^�	8�;���`�^�$tP�v�O(S���-����V�%����I�5ţ�Q��B��Jk�'q�U�n��u/�ͽ��
z4��
.J�vIh�,���Ȣ�A!K{�c��Z����e��T�%�7ӸY��;����/�q��uDq�&�z5����ڍو/����zj��'��ԭ�j�en���*��gr�����ݧ~I_�/s�Ok&���i?B��6�5�'��$��>�,L&�'�CqΊ(���.
�9	]�F��[�uV�y3��l�>TO���/��X�7�v�侷�]W�e�Qڔ��A�.��K�H)m,�BN�hA"��e(1�%��ty�F�_�e2%$5�e���g����Y�7!s��lj+V�]Z���"D�@��z���~d���k�7�ʔh�{ZGp�m-svȞ�{�4����K�f&ͳ��N3�0�.o
�j�����s�!�P��9�&��I��k�f�u��K�
SH�ާͶ��&����V�u��D��. &����a=
�WI�F�'�f{mo�9����2�39�c,C�B�e�{Jv�q���Ɲ4������	ͅ���@V{osrH����64q�c��e�#
��{�d� �f�eJba�O6b��³K3�K��x��#\��p���_Î�b��"~]�_5�O�q�7*o��\_���Dh',t�s\F��91)F<���V).kS�l&).,��BLn!X/�x�T�����Bb͔We���ĉ/���7�����bO.K?�,��Y��_\K��14��0o�v�p�1n������8��(�Xbѹ�-���e�NM�b�H�N��L�g*���R��0���~�k���㋯������&��Ʃ���<J�g��ma%D����㾄��� �_��T#2~�5�����K
<Z�rQt�6x<RIx��;%��0	^7��HMs���I��V���n��)���:)_�婼��	�qN��7]�m�&�����ՙ�aEۦ���"��09��p8�s<��6mO�}x@���i�:H;q�O/���O`5Z�ݻE���i?;�I���3��Ͱ��Աy��������Y��ŷ�k�gT̡٭oVC�Ӿ�͟�=4��8O0��'&q�J��⅐p#䌮 -�/33�?���~��� ��ŏ�}��&w��x@�ȃe��q$�0��\���X^�����t�j~�B�#�)_'�R`��T`Q�}�*������#]�69?)*�^�X{���I'�@�R�㧰}��/Ե͘��p�d���ngWN�}�s�������揈�L�6�+%Du^�����|��K%�3LFg�j�z�L-TsH�3\�#P����ط����mH�M�C:�Ý��'�B X  0H�^X+��<g��6Q[g�{�TI�(H]'Hxݵ`!m��iv)�r���j��`f'^|���`L�Vuvg��v�}>Ex���C�M�N�}WG��z=�Ч:r����nO�f�����=�2�T�*/�Q�	��\@�"gb���B�K�A���3�r��Z3��9u�j�NP{�.�9�	��a\3����xL�0��q<�v<'��u��+�	T���v<gR'9��_�U*mwCCӯ��g�(Q߇�ay�����	G<��dPO2I�3sN'F#YZ��F)�(}��J_ �V\�I�at��mJ.]�c����8��<��o�G
�϶&�Ňtx�96���*SZ�E	�WPo@�*���P
�]��[d^Ji�%K��2�f�,Z|>���@̚Rˡ�RS���HBSm�hu̼ζ�%S/����Zбb6���¡���+��)�'��;"`�]�Gǃux��y���9$�=t��8�Y�M�ޓ䃕?����h��^>�=bBO�X�g�n���y���"�_���z�I���Nj/��8	rjo.w�C�p<0��-V���>��K?D �4��;�#;7��&�}w|*���\�)�z7$K�?���8��=Sa�)��:��)\e�����ɝsSo:�����?�h��̈:�k�Q�̈����+}W���������Q͚���
���tP끉p��r=�U�=~y�
���C�D�KrO(r!y1"�J-"
/g���ˉ��Bz+XJ�g)9R�� �'w��s��v��gں0�/+b`���5�<s���6?U[�hW���{�c��]ߌ���%�g%U_C��ȅ��KЁ��`��*�xDGBP8�Y��t0GZ��e/`A45ey��c�%�o���#f_7��%$�P� ��n��-�$�(��N�ec 2��^{�����\&�� �*�)�K1�h^���� T��rzB��ּ�2V�����.`����G]�Y���6~���l���'sI%�[�g���By~>�`��KƵ0W�+�g�ވ��/�3λ�ތV/䫿t�%k#	9��o�YJk�:O��վ�$q*�4o�]꺋.�{3Z���ߚi2&�5�_j��ޘo�Z:.QZ�x�^B�/���39�L�!��IW�F����'�y�1Y�OJ9s�~U�颞|{Ko�RaŌ>��h��z�7K�[:T9�􍼑|)d�:�����]���nf�@���7��ɼ��8��=WL��)tNJ��7��E��htP��S���(QyH�7�,��<դX:#��M7�H*��
mW.���oE:�d�Kn��u�*�I	.�M�-�o�0��{s�Z���?�_}�����*�      �   5  x�ՑQK�0���_��&i���	��胯s��rW�d�f�!��&m���?�ڞ�����Z��V1{�z��_%/�/�f�x�7��e�PR��_��y��`Hr�������p��cZ��[R��s���9�U�HM�\�O���ܺ�!j��s[�j7[t8je�ܝG�Ѯ*��>EE=��@Qv�Nl.s6�@�ڴw3Z�y9m����g�Mz����o,���}�w$����<�A�˭iM�]�i�"�s��ш�2��$���mc�(%H�H��Y&��so4� 1�\%��ŏ,{�Ͳ�9Q      �   l  x�՜Mo7�ϛ��Էx,P���C�@��ƍ'�&mZ��w��M�C��s�0��^Q"�n�W�x�5��x]u��.gTq�Y�ׯ�������~7�v���_������i�t�����ᇧtw{˯����7�����ݺ������ˇ����ˏ�nN��Oo�/>\��������s O����~���w���������K �;��ҫg��e}E�:���cG��X�caw���P��:r���V�V���W�XǙ(5m��%��UG�!�������L��U�:Z)WZݱ�����k�:�W
ó=��=��u!�𪣅pE��B�De*��Sm����������~�Dȅ�z֑sb�e��6�0
�4]��SVW)g�^� 6h�:J!VGi(��-�`P�l�"���(��u|�6A�~u�P�LU�쵰S��2���g�Zk�WM����~��&!E�r��!�u�Jn4<븸֬R�j٫�W���;zL�h�%2{�G�j�س�T#v��b`�:W�S�x�cE,��J������h$d!��u\S0k��3=�_�����j-��,���Ji�Ie��9�ꌄ�&%9��ǯ�}�{��ջ��bܾ�kK��62�C����a��ȷ��o�^��n�}uE����̋c����a�P�m?��K~qw�6���\_�\�/�� �������)�J92:���}���E�V�.D��%)��T�dh�s5�	9����0n" 9^�˕U�,���#!��g{T�9�W{�rAϙ�5VXIm�<��G��P��ZkF�k��%��Wm�˵=�ƭu��`�^u4.A�+��$i��VN�"�K��BH)���_� IM6P�z�G!E��mf��R[��M�2��< I`�9���)�&���flQjP)��D���������� k�7���������g��9�\3W�ᛍp�Pѳ=225�������(��%��+��m��87�V p�fH�N�	V���Z>V��(I�xN+�f�T�>R��
5��gi���� Qb��Z���Bۏ�
1��UJI��BME���I6�IJ'�Sw�R	���g�S(.�F"�:��l���rI�5ʲuN^��F�q��Y��4�֊��ia$��<�-��q���B��_���8����R2��h#�E�#&jU��0&x��B�`�=�����N����k#a�|�-��Y�l���g#!a���fMTJa�{vM�a����`%�2n��S{��Ai9�ec,5��׳���[��9~�¸�R!g�^u�	ep�>�;׸��P)	���&�ƽ7���yH|x�q�yO|�/�e�Ag)�	$SQ��pt�\V�@����|Hu�GT��o6�&6��1DiX�JI���&��Wڧ�1�X:k�#��]��&��k��X��S�t����.WGa8�1�$��[��}�h!L۟�)�"���C�����ZM���r�Lg)U��V��T�qϔ�
][�5����R�R(/�0l��ˠ��0�'�M��(k�#���D(��L�ul[%�P����2�U���%ǳ��R
���FC�V�_c�Шj�h��G�O_=y��/���>      �      xڬ�Y�`7Ψ�l���������`Ru�r�� ����RE)��� NΫ���#����8��p�?«J˵���#���'�����_�W)������!��s�����GL�:�����?'C��FH�f�������k`�I��Hy��09�F�&�l�)��?�1�����K�d�ѩ�5i�p �6#��76�)�C2\b����J��K�������bp� ��I�RSI��];��7���/$SҒQ0$�`t��.Ş�rI���WJ��FM�x`$`tjj3v��0���Rc��f"�d��������f0�@v5A��>5a��Ol�;��k3��'jB��3�	b4��$3krW%H����Uy�M�eۍC`�`�B��f���ÌQC!�#�3[^�%Z$#�b�_`8�Q�6�9f��Y�jz�&�kN��d����Ư�I�;�	!!����]��@����c�Qř]w��L)-63'�����J�L!'L�L��	� :`8c����̎z=8l� C6HFg����0vm�=��%|������7�hX(	-�5���O�O�]Z�l�NK�����`t��d:�&J��AM��$�k��ʱ�lF��r�0�B1HF�'%I�d �<{<���٭�Ǜ@�-�J�R&;V�v�Dბ<d�'��%�y�)�Yt�-;3�`H D�����#���&U:R��,���G���\t��-3�x��d{	=�QM����[EE��[	/�d--8։E>�� C�J�"eG��[l)h�QYL=	�a1&�*��.�ٛ�e��fC�I�_G��|%�-�Fi33�#aK*�� �s���G{ȓ��AMJ�Ym̎25��d�À!���*�k��LL�����Qe��R�o*����U)���=&S($��T�x˛��ٸ��l����ls�vh���B�K�o��/�L���i��� �ż��7�����d�|6�wa��,���풉q���f:�(�" ���r� ��>&$x!�;�ng)�=�Lf��0�݆̀;̮�n�)/x�=�+�f7'�Pg�d5N���0�mF0*�����sn?g����d1z;��v�~���h�'afª��a ���$Sv�	�[ͨ`T�դ�]2� ���;��|�&���)?I[���٪f�	0:����=�䔱\ȑ����Q�IJ1��$3X�Àw���D9{����̔���T��$3g��Q�Fe3+,F{�˘s��Y��ɹ�e;�� E�JM+e(���`tj�Ȟ����O2+�]���ٿ�H�1�Fg3x���aD�v���f�tQӮ&e�4�s��NM�#���0^51�7k�����#��`t�1f��@��n�ޜ\\�wG{��d0�h�$!�0�vD�GU�	�	LBv,� �05I����3�]�(15x��(q7��g�l����f{`J �è6x$�)9`>o�IFe�q@F{����� ��Ɛ8S��s�� ���WdG{�k;"�j�\R
�Q��Ȓ�zӪ1����K53�9������e�X�߹��b��oR��vx�,Α=7�t�U�I�BC'�. 'u9XR�w�t0�Ԕv�&��N8�<{���3�_L{�ٽm��(��v�p�	0��E��RñAe�M`Вα{m���$�y��~#[LF�Lc��H�H�FU@��rt�/mO�63a<Y�i6�d�L�=9;#9%Ɏ0#�'.��r�ٱ�GR�	F���$�%s�|��%g9=��0;`0�FW@d��j��vM*������C��U	F�2tl�q���t��9S��XC;�Ŀ���=�i'����}����٭�_�E�RS�}9� �vH`=��fVώ�3Lr/i�$�����O��� ��Ȼi�KFBNߦ�@�8o`��x`���0:���cL�rF"�h���f06G')��JŢJ�-5{�ہ��Dޟ�ɞtp �U�� ���0���NG6���E�����`�t�<��T��Ȟ6�u������Q��6���F�fo��9Z�I�J�ż�LB���SR��ƘR2�0�90ȷ���������D�dTE�)s�<0D� ]�)�rH&'(U .Ԓ�780x/��lF��
��d��m
lF�ڲ���ٖo��.�5��#�g���0�I9�{�X�ޔз�,8[~StR*�gR���p������1��1�3?�_��}�)\��:U��J�pBL�A4�NM����)Z$���4e���H�m�%u����ZTRr�Pd�JK��Xv���*w{G�3�Sv�d�hIe2�S_vg��[��y�Xݓq~f�&�dҙZg���pj����ш�E�K\��o,�#��љL�:��%ܳ*�31wrH�����.SޤI�G����:��ѩ�Jn���i�/`t�4vejO��厉;H�DM�A�W3y��z�/�n�p��
3rN ���w	l�Qٯ�e߷�3N�^YIi>�Y*-�t��7>OŢ�)اݱb�m�J0*_�]9���{�R�3	���wBp�'#�D���p&҃(U�"e�T��:�*����H%ƟD 3����y�ƞJ�n]�!=����6��QŻZ�o��@A�HFe�w�r�L	�.i`tn]q	��#U�����ޡ&�w����$Ԛ�ه�B����8���	yd��y�`&�����G�/.���I�a�J�X��߅%�mf�0��̷��kg�0��,E�T�oKg�&C.`�Q�o�g���D�NMX�c��^zh�e�'j�T�!L?��T0*_j��F�,���E��{bB�|���'=���/��ʊB�b�����f�S� ���;
`:G��O��bH����s�Eg1}���!�\B �NIiMN�{�A��2�hz$�=���^ʀ'�:]�c���73uZ8�$�^�
�H��0*Ɍ��h�%���XƮk�#_��X�sf����Ѹ:�bH��0*��LG1#FՉ�19N�H�?�*�����CK�<���?����RJ?[%U2�1.�B����fA�'��̻Cu������{$ѓ#�Jw�L����U0��7zN|	�t��U0*o�<X��kֱ�B�V�,�bF Z�y�����p��"Uf�5WG�>s�����c|c�}�ճ�F�{�h��5�\͍���r�k`��kd���oV�F���T��'�t,�(�Ⱦ��Yr��`T�i�5����0����=3�'1o��;�f3l�Q��Jcu�dJ�{~]����56S�Т&�g/�|z�0�)h��JO��.���>s��F��Y����9�]�W����L�ZJ��[t�`4I����8`(�#�5䖞<�af�N�v�Fc�5���o�0�𛘯���LT����K�:Mn���{:8�فAM�ڪ�I@�sf��p�6��Q/�k���б�L&���Bw	B�
31�$���-꤇љLLݾ��avG,� U��EB��ɴ[��%漞d��Iv�<��0:��Wv�����D�-�'���H�v�����&��]�Q
f�,{��(_�I�~�i[!��
b�6j�]�|b2������p�o7p�z1[���Q0�/4�h�&7�lO�E�7D=���d�2�:�$t����R6x��������*P/�n3wi0`�7q�_�:0g����U9��� ���M��=��O���-���Y��M���+9Դ��o�K�s�ȱl�%ҷ��Q%m�+'�7�G��F��"q�i�m�T�Q�Ck�P������I��1�:-��vI�=5!��gR��+U�`В. �F��M��)�S�����e���NM����bGj��w
�"�Ջ7�+R\0�!:U�A���w��րu0*oBat�Bâs&<g��E翇�u,:�m�~�l��r�	�S�ʱq[xfC����\)����m����=2㓔MٗCxgI2���D��r����gR������%�rk�dT���\ ;�A2���rg���Nؙ,�    ��h{E�ۯDL�h��s>d~�L���]M��}A[�4`��ض��ߛ2:��V��p5�_�"��l'��t��dq�d�Io����I���@��w5D�3n16���������ɚ7ǁ��R��:Uf:����^�0�լ�Qji�<�! ��;v=�d���L��ٜ8X`T�$aV������F�&�E^q����� �7��v�a3g�E6���`H��S��� �Q��TZ��?*�7	����(wN�4`��|���`�N7�$�3`	��R	��ř�����%�`�U;)��a�����Ǩ2�Z/&��g�dR�r�!��$T�4�9;���}�U-u�'�w�ys��7���F�αw��n1ۓ�7H'��-�C��˕L۹�?1߉���w<��Ee2-�>��mv���3��&Nphi�UpkN�*K��cw��xGu�`T&ӲP��h��yv�<�^sfp�L+����\�S�q�.�4�e9l��ڊ0:�&�LA�.>�`Tp�I�9$��go]��]�8�������I��(˞�����z��FM�����;�BǢr����n�0����MV3	؞�AR�+�*�g�E<0��QW�n;p��Yu-���!0=��i�8`��'�F��#Kp��$h���fp��lPr��F�
F��1
��0T�EM��7�Dǲk�(w�h��6�E���󽅡����m]V�'��1A4���L�����`t�X9:���;m0h�70jp�P�b�Qżz���o���Qy���.9`6�=2w���:�D>��n���WŢ2�	mLt�0��<�.��I�=� ���Kφ7wTj��/S'�dpG�+�ݝ�ڌ(gB�{n\�TS�%�f����
F��f��؃CN��F�M��ǀ��h�ձ�9��$;���ޤF��f��.
Р&]�V��y�M�Ϛ���PW��׳7L
��y��S��]]`t��ZվoK9�{�U��VI3���9`u��V�rz�i/��1�O��=�ε��K�7�-�d��*�I&��hk���V�載{w<������JM��'��:� �Yh:Uq�*v0	ݫg*]�[�v�p�������i�Ŏz�#�{�@�	z-�Y{��vߔ0�8�Bl�+����RQ�h
�R�bwmλ��M�l!��F `TA�s:vk��$�P(9$s�|����{�E��Q��9C�0:51t��8S��U0J���hU�0~s�u0�D�B+�;�$�����cu�DM=f����(`���+T�k���v�.7��0�?�΀g&�I����hJ����X�0���'�-JL�����Q��"p��$8`v{�є�-�]�;$#�\�V���D�2��_!�HL*���JKmU[�L܂��ΖD��q�r�6�/L��*-��I:�)�fWS�rG��`t��9d�dJ��gљL&p�����r��dHF�=������_��2���4�=�wY�����0��p�$�r&�d�:��g�_H�Ŕ�Vp�K&3���d+��zq���D;�� ��Q�V�GF�b�?0"�$�*gJM���?%�F�ݖ>�0�0|q��
<Q��Ѷ��&�!�U�)�y�fW�`�Qu*e�^j��� �r�3~�M�v&�.��.L�g�l2HFU�c
�'�>�o��N2*�F���p�_�{�t�'xn.ɜ79�F�M�#VG���W:U�A<�-�F��P��\�?0%P�N��`�\KLv.��dtA�I{�+)�IM�D�#`�p�)���t��.��\Β��q���)մ�v�����Fg(CNJ�̫
F�M�6�7#YԤ�3T��`�_�x׊T��p�A�-0�t@LƉR��`���N#�u(�ր�$�]{7���������1��e`�dtܚǵ1q���`T�u���ژ3F�2Μ��FB��I�8`v�X��k�h�ߞbQzG����>��Q�N�<�D۝,�Q�3穮�z�廫��Qyc��zr���ye�O$Ci�ݛ(������l�V���pW;U0:o�@�L,wt�
F�XVt��b����΀��̎�;PIF���ߍlzT��Ao<bO��$4(�U0�at���+��P�/Y�$��3���n6P	F�L��;�;dp4�E�K2h�}y�A�]ѓ&?QR�Yx�ܝ{�dF�70�%٣��O��a�������GM�?<*U�Y�DT���{y:��*7�;���&�W�P��4��I �3*�dz*59`~��`T����in��"��d���|��6����=|� Kyb�m�)19`���2�&��C29��Q+�3���/:X��T���ԩ��f�����3��2�,�w�h�-���]�]�FW��Z���!�A�yp}r��P̻��p:Um�[+��aJ���:��G�ʆ9Sp�r��8�I�볌�0`
U6�	�I�n��M#U�o`
�n7�1}��t0*5\���m���40�83h�a��)G�hI���)cph)�O5��<{��g�)�agZ'�'x�D����0:g�3Sw��|��U0J�]�'���0�[ΌQ��[�m��q8<[R�ƪ�`t���\�p�p��UT�Qy�L�n����IM*U��%�iϓ9ʏ��\Zz��f��T�7�B�r�ɑ=0�<��� ��d�h"59l2}��u0:���r� 40J׮�	z��Li��΀�͞(7J��� ���>�J�� ��/7��ν)�V��a��[�ʳ���
R,%�at���Y9�v	��A2*�^̓��  � ��(�_O��`$�����jR���;D�e�*̬&�k��%L5�iH-o��ÿ �Z�k�R�= �.���1T0J�^y4��H`�Qz�:��0 ���
F�M=��?�dJ����b�8S��O��6|#2��,�/^I�0=:R��R��"�NI�t�=ʔ�p���8����L)�-��Ǟ+�+����\У�J/����N,�S:͆J�3�c�
垈S�(�4W��`!���u�Q�o
�8n����'�����mO�S�M���ϱS����(�pu���� ����c"y�l�O��$���	vϦ�񻈡���DQO�����D��6�')���1K3[��]�L}fG-C���`��ʀsd�v5q�sdy�;�3����f����s�#�8_�s!�0Cɔ�0���1����"]��d�d��`��Ҁy�?��$�J�Yb
�#�XԤ*��L�7�wN�
z��\<0Bߌm�.�44N��}ۢ&]ٙ{�dO,!g�t�Q���{	!	
\�^->�+�pL��F�!�-��wD�F�M Q��"|{�*]4���0:׆R�9`J$���`)�t �XlF�ڔ�;$s�d�&]q��-��'a��V@���;�<�3��E��fZ��F�HFi3�GA.�7H�s�c9$#?�V*��ż�;e+K�B��Ut��e�Yļ�|`� ��칖y�^:��;a���*i������`��*�
FUΔV�W�7̶�oD/�O�'j*}[��L��Fm�`t1�L1>3�&���dF(�����,.�e���Oj���Ԅ2�|�tð�g��O`F�.���Nۚ�b�_��Ӷݵ�n�S�'P1��S��a3)���N�R2q����)�ѡ:ɨlfW��� ̷98�y����ݛ�;|����͛N����$��Dj�(��ҀG���M���&j��U�&� ў�2�|�~�e<�3�+,�koW�o�u.���T-'�j}:�o��}i`t6���a�Y� �3���	����s�;&�'ZZg��u&�NK�L� �;<�%rOb�@
+8`
�F�&�}�G2�'T,J-љTdga髀��T}#�v�7Ô��)h��U�]0%d�RK��ew���}��(����:Z��cĨ��9v��n2�!�%���WT�!v���)�mN�n٪�̵:`~F��$�Z�jyz*+$߫:�7������m��O�۩�<0;nG=�R2�U*��    ���E���lf���ew{��s���7M������M
�R}[���E)7�$���=d�vצ��0*o���=�t�u�vi�d�����k20��N�tbr�3����- �ʵ�\`N�D�HF�N�����1�7�J����#EG=ç��\���I��3�nz%��&�қ�|�9A�����ڍ����L�Fe3#�*���1[$���G����`B������#��U���o���Q��A�G�3I`�+�ұ�-��aFRI|%É�g�^��:7L��CE����Ԫi�Evg�r��F���Q��
B�J�c� vo��7�3�*U k�����`3��j���k��dT�=�&�gS�`2:Ϟ�x���()Uo0���=��'�xR���x���ͼ�f�)�at�4��y�*�3��.��`t�$2��a���R��Y��0����Wf6L�r�wT0� |^0�<0��0Jמd�A�a�ՙ�c�'��\��!���W�N2kct�yT@0�8�"؇v��'UjR�Je4�7�e�Qř�w�sHf�d1`U�YE�|�3���q�O2"��<)8`��Ԭ�Q���B�&�t��40J��j_�90��s������a3��R2��\[28eL�yo�*�s5����������5Dp��?ZR����5D���X$�KMSJp�/�r��J2�a�L�Ǽ]u܇GM�\G1HO�w��
FfF�e�B�G�u���̈	�ѩ��,jR�'�t�d��m2�h����{j�1󷿳�g��� 荈��;`���S�T�9k�L�]�`4Ćٵ�t�0}�u0:ז]��k�)�k3|�=�M#V�0���0��2N{s�ˮ;� �z���Û
��@�&����a3�A�F��`t<f�xJ�hI��v�/�`t1o�P&��b0�ĔvG��D�Mg0�N1Ş�!�����3��Clc'�ܻF�Iq*�['؞�`�n*P��T�-p�p�z~��~�x�f���`2�T�P0�'�ҟY� ��oC�uoa�b^'�0i�좇Q����ـ����_:M-�pFa��v��m���������O��y��Q�(%�j�͔-O1HFe��B*�_r�'6CiNsaE���h�Ca�i�L���Z�AZ-��.����F��s��f򮂾A�*�Ȩ��)�)W��Taf�la�d��K͹>I��G7?BA������_�!O��R�p�i������ǀK=�Ι8�VQf���H�F����a��s���n�����,˞�w9��R��Sp�$��9S��F0���پ�m��`����������F���C����IFe3�Fh�3���l	�yR�In-&f2�(%5������l:ɨlF
�=�s���	F�L"��C0����I����X�b�@���T0J�m�|�f�L�HF�&����)�L0:�9���D9�(`P�ʙj������J+�eW�O`b*���i��0:o�)G\X$X$��f��v��u�J2*���nwm<g��F���<�e�F���� ��Jg�8�=5a�y�@��g	���9��!:��H��PSF��7��gw�tm��1��pu�>�m?��I�����3u����E����P�輩���=�����$�J-�<6ÜZ��o�M�CKr'}��2ߖG�v�?��R.o̷�>%�-�b
�7P��$S��d"�7�X��%�)%��+�$��%
����{TV'�3miw�3��J�<�i=t���!^��8��|X����o	�\��ݬ?���`�0G�#x�v��N�)�L/���ՆI?w�u0:5��̙���=3�'m�V��f2}�U0J��f?^J�Q���&��f2�s�@��[��������#��uU�(mf����E2:��188\�w���͌�ٱ�Βؠ&U	1�ǂ���OaF�������=�H��M�d ѱq �7oۯ��ʵG�9�� ���ʵ5q�8�O�7����
O��q���iR:���
ؗ����,J-Մ�,��sc:��<��i�vL�����<����ga��TF�!�'0��cqF2&��ff`@���V����!Z���>��q�ݓ�M3��{C[Ţ��	��%�c��"ބ����� ��s��������w��0�1n�|Z{��\�yQ�({0����0��䫦�!s0��3��䪂��nSR�{��}�i����3X�tsk�Yv6��W����ja0�#��k7e�<G�%�l.��w�H�4���g��p��T0:5q��L��X�F�Vg {6�����&��	̔D�0w?��M��vs�8��:t0
^!p�՞��y��ԴD�5�i�����a��������aw�Ĝ��)�?�_�D�����c�dbZ��?�dZ���+�R2e���#���R2
��?	+d�7���@v%�ʛ΃�0�wB�%E��?IR����Y��5��7�$���`�oCP�����r�/s�[@�Q�70��l/  ���7�=w������a��Y�t�`4���o�u6{.�D!\�^������ȴWV�H�ߋ�:]�٭O\���f4�ѩ	p{ȃ]ʔl�Q�o�]�9���c�Γ��xv�^ 0�Oz��� �g3�F�Mmاm�� ^��t��[t�y ,!$�2���p�)�^��0���Tfr��"��f���s��d2P������@l�W�u0�0���cq�P��`t&S�.��α�`��/��t�ò��"���0J�)���,0*��cs3�|�۹����	�v��%0��R��:`�D6��l��8l���6�.� ��X�����X����0`�X�T�N�`��όλ6�$�'0uk��M���F����Nq����L�L�(`��΀G���O=�4��fv5�/�	33�|��w�ԒC0���_�[X��dJI��ـ�XT�����H��yŻP_(q�i����x{�m�K�O�-�4R�����F���3�O�n�g���'�$�iM`�P(�dpd��sX;$���(�kh�S=}��D��FES%�ݵ�?�n?��Qy6h�}9�s�Fg���d�L�3S	��=���8���y�y��g$C._���
/lf�)����³Fg3F�����
F��I�������/�)��s����.4`tZ*�>Lj��ja�)�ԶJ"
`Вҗ8���%I��!L��nǶjI��]��Uc��"MR�lرab@1�(m�5��A�Ι�`��S���j���(��C)�A2�����0�X�
�v�ޞ��:W�c7L�0:�p��1`,w{���G:�O��Wu���~0�Fy�����H�IM*U��s~�wtw'�^y6����c�0J5�$18`80`Tx���I����3���/�!1��B���ڮS�k2K0<�Ж�Bw8R��*�d` 8$�1��ϖ�!>Y��;$�� �s&A�1�0N�$�SS]�۽�TV��'Kh;�6�)��r�JU0� ,}���b��f���Q���,��j'6������a1����|�ιˇ�Qf7,��љoe)bw���rtE��FMR<Qf7)I���H�Qsf�c3Sy"��J�v_�tO����㓞���B����1a4���A�8`��z�RMT�cm�`����C<�e�݀��)z�d����4׵���O`Z����nj`�j�>�kÔ������i?��o�zz[(�aA�RM��#7�ps�
F��{I������/��E�ę�q���[�kPt��e�#ʔĔ.�,�d;���`_.��ֿ�B�'�o�c��a��F�&������᮹��}>q��ݳ{X�d���E��28VC
�?�a'�'[p#����weFŢLn�Qr���4��o�7ʨ`T�w�e0��S3*5�Bޠ5a��\GY3<9�rF��}�a�H��2i`�JL�%W�g�A2:���L�������1쾄�C    Ԥs�ާ�}Ò䮌�����D_*��]E��ff��e0�(z�7Ͷbw���C3*���S�:�D,�c+Oz�f����7f1��\{�<j�M
~��L1�'�����Sؽ��a�6Sh��)����fol)�t�U����s�V;P���'hO�����CM�s=�R2�1���F�d�6�9;����%�JM�t0 :\���8�לO����g{:8���ڸ
Fe3����̑�]�\��<	zk��lO��\����x�:0�� ��H�_��0��g��*�'�֎���x��ӯ�����Gq���U�ߴMkDD�`���Q��Lf�B'S�{�T�s�9�z`0��J���xNj�CM;��s�k���	��v9'��J&�4Ǔ�Mf.`L���t0�a��%`I���aTa&�^BpH�f�jM����ݩF�T0:����n/�Dr�.�0'���cĲ6#�X�0:��y�kB���M�{��'2t0�ʷ6���p�.�`t���:d����V�S"�x�b�$�`���fw���Qz�k�`��N0�0�Iv�f��M1���C#Z�[4�$4�蔴���a� 7���%���=�u��?0%a���;���;`��Q�oB���3|0	J��D2aړA,�J�Fe�I*�݀c9�J�0J5-�4%s�b^�O��p�H�.h�`t��1�C2�L��HFe39GL�)���9�'ޔ� �d2�wp1fH�/·�x!��Mb�Ψ`���\)8`ʵ_��dh��L	)`���g�l�x��k2-�'#�c^)9*�m�w^R�>Q�1�ݙr�|�솲�X����L�� f�N2 ��[��w��� wO6�0�`��I���ɕ�sN`tj�I܎�wR��3��"G��wN��)OnĒ��N�yy�K�%?9G�ϻB�C������Tr[�89�7�R�󦲫|���L�cљ�o{�����p���Z�5�^A@��*���L��b��
'�RKg��=�&�hI��J-��4�p���Ўë��oD,!>YB��#ʔ�S|#b�%�'Q�مs��"z��0ML��d�Y������CY����t{�+��[�\TQK��!�fĠ$�/Q��S����߳˚�fe�炝\�;���Q��+7���.3�F�KU:9B��A?�� �5uf���"�l��i��7!o�Y�#�'�h`t���n3���R��
�m�䀑,�(xa+��[8�ʵ)N��p�7����0�+X�_aΉ�'W�"1�ꀡ�(��D��Փ�<��(�C����Q0��jO�ȩ�b���L�u:�s����`tA�5ǎ��G������#��]�� M�=I����7mg�oJ�F%���!�� ���y��I:�s�79`D,,*g�-lG�G��d�?���d=�)�# �F�'�40:�e���7̶����L�[v��"���Fg3Ғǳ#��t��Vr�I��J��8���Q[q؊Jz�d�`���|_g���i
;\�O�3�(�i!.{���I�;�*�7	l�R��{���=��mgw�
Fg��y���;s�lO^;�q$9$���Fg�RSq,�d���L��8���{�- >�ܕ�=��j���;�{Z}�e���"� �TӪ�f��F�*��P:W�HFe35BO�0#�)/:�Q�ɚ9-�cK)��N��G}#@��`����蜩"�!�s��nT����X)Aux�.9o��Q���XC��5�#E*ɨ�L������wSc���tMu�h��~`R�$z�ϊ�����.A�`T6Ө0u;�|/�5�+���[b�ňv���A�d�OV�[[+��c�"���If��l�Ios��Q�̌��5�� ��T��C�`w��p��=ҟ�E���r���=�b�i�gjݡ%�_��`z��Ӌ��1�l��@�" w�<�1/r"����D�~_��H�HF�L����̆�e�}��������B�פ��yv�v5�����¿-�i%�S��l��=ޤB�Y�c%
�t�͑$��J�����%&p�H�g�50:�1atH���r�
Fe3#.��!��t�=��ؓA��sn��1�����`:$� w�S��-:j�$ok���yS�8�ޔS��q�8x�z�M� %�{�V��̴?[r` �7���l�'��6�w�p�J�N�o�g�
ɜ�@b�Q���&9��|z�����&?��I��݀!�)Ұ(�ĭGp��O���*�MAv�=�mo����*̚RC�{�S�����<�������sv�'y��Ɏ�"@�m��Eg2+����R��NKeF�v=vw�Wn��4�{v�-��z��h#����J2:��ɞJd�dtxI�<0���JM�̔v�0M?�p�����ļt�C��q�FMfq��d�QyS
�z\�L'6��lf�j:�$~0#�'�F�XR%{j����3��jx2=E,��O�R������8��먭(�����\;���ՙ���O������Ԫ�s=�ε����7����A2:���96T|Ct�Qřx&��LF���G���;��ߔ��9���RJe8�׉Q��J��L���ɶ�h��ʙ���l����b��*̤R:�-jRyv�5��ҷo�aOʙT8��9���V�(%�v�n/�n.P��|)g��K,T�s3)�����s��0�]A�������o�V���i{2���{�%���|3��X[�-���R2��	�#��A2:�ఙ|f&`t��x$,��۔[8��L�ɑ�db���A޽�8$SX�c�:��lfϾ���9Y`t63sGF�ݵAM*׆0���h�f��d�5��lr��zQ��L�jƓ���xKȫ<N� 1�'@n�]�^����\���!�����&�����F{��n(�d��� {*qٗ 6�p�q��O���!�+��'�s�IT鉚
t�>�����
F��rΡ�aR�g�t0��Wp+ߡ��?ŕJM:��0͋�J׀q�'O��2g�kG�i�J�oU�'<�i��	á�E`���(g�j:`������iu��ȁ��m��`T6���'�(�߽<�ͨ�	S�aO�<��Iwe��Є0�#k�s���ۯ
����
��H֣(��-:�ﹼ~[%��r���0@�C����%~��v������Q�_��M�d
Ż=��Q����(��yy2`T�ۜu:`�Μ���{BK��pS$��M�[!EG�c滈����̪�٫�$���y6���!!�[M*�����4�yw�w�_%U���c��|�-}�M�`=i�	8N�dv{͠�Q��ӝ���F�LT�r����d`QE�C0����3�gs��(�Kt%�3&��l�X<0�w�K�t�Z�Q���j�N.:���;ڷ���ت`t��4Gģ�EI:��E�_3�҉z�ɱ��K�Yb"�NM|���)X~�t��=9v��_e� � Lz��K(v�媉��'��.�À�g�V��j�S�Oe��ѹ6�*��7fv����'�y\�!���a�&�pL�t��dtZ�<��?/��$�ʓ<s�ϖ]�~a��6�� ��	.̎OE�4��2سA	9�x�Fe3ڬv5��`t�$���kV*��
 O�`r�������'m�H��-�1��e��d�B�a���d�iRf��dͪ�`?r`���t0:��ٚC2)�VK�3U�oE� �{
�"��$TY���ܗt0:5�֖CM���V��b^ml�}`ʝ���e�ڳ�E�#!|gt0:�簟�B�{ڵ�:�<I�aVl�!6��$�8V��; =�ε[��6%
��R{�Xij�'��J�}�	䉚�p�4QA�ͭFgeplƟ�p*ɨ����b���fvG��8C�P�輩rU!��v����.)8�$�0:-��;M�����50J�^$��q���i�z��瞔��C�N�S���*��z�E�CK�g�
F���i:71��3bO�+v
���    1��K�*���8�f0���w��!O��h_��֓ɘi���S��	��縷>f�O�����9`r�ٶ����4��C��*�7� ��Jv1~�����k5�nzrF�ڣEϺ���I�������BȩX`t63!����R�Om5��3O��1��ɤ����Fi3�5���mT,*���9 o��R�hI��3;`P�u/�dT�;s���{�~F�OM�lN;�t��Fi3%4rx6�r.�$��ށ�0L?I{���)��rlv5��ڷ�����g[�|E������QJ��h�:7L� u�Qy�ڥ���]F�&3ۯ�t�Y1�e3R���F��gdGt��.�z:ɨ<{�!�f"mg���1�ٸ]�����Nӝ��aQ�/�E��3s� �3����9�mo�ڪo��}y`rL��F���}�� �QәVXi2A*Ţ&�3����C������xS޸\jB��7��sw�����C	+�SS�to��`���P86HFi��B����p�.�`4����j&�66��輩v����k������Ө��O��PK��9i��=�εcܑԡ��saV!|q�a�;��L� ��LN����ΓI�3�x�Q�AK���۟j�,���r,�$D�8���&�F'���MB��U0J��`���ab�K�:ɨb^�����p�X}�;�OԴK`Gm���F%��>�fÔt_�R��l&�i&�dT���ʲÛ�A2�Ԕ�U�� ����=3�����x�G��0:o�-���Fvyg�Q0�8�0`!���J2:������%�.����J�I�#�9�]v>)gr$B{.��%�Ӣ^��E~�0ow��ѹ��a�ǙBPnۤ�QySG�Y8��&��t6S(V�7� YlF�M��6��	�7'�\d/�$�)ٗgܲ3�R�"�҃C2@��W�(մ D�c�xk`�*�@��iW�WM盟�M���D��U0*5A���L߹z�NM�����}�*;l��ވVM�q,��`���Fg��Ҟ(鬢%�*�����n"��{�-�`�O�L	�ġ&D��3��JZ���'�DY��5����T���pa���U)�Z����6|�]��ON��2(;�+.�|��*��̔Ju����Q�	33ؽ��_�`lП�B���C2B�l��I����(e��w�S���s���N��`⓱_kH��d�exԳ�ֆ�,�`t&�Zqد ��g:-�L�sr��RB��Qz�y���s _w��`}��Q�ɱ�)ā� �r&:������3=�$��F�.\i`t�M��\A�9�.w�\�rm*��a��M�dT�Dȩ:$}�u6�3�.�S
�8C5x��i�D��`�ߥ/�қ�y���,�Qy����26���G��7q�����7�p���x�ݮ�\o����1��\ц������{<�g���D{Ћ�|�T,J�a`��S���
F�����rw�T0:��A��L~�wT�����Yʎ�ח*�'��2�K7� �����n�[uD�?�����'�0G������*���,��%��{,N�r&����y��/�$z#�5R�;�NpO��s<�m�<�bw�$)�U0:���<�e��)�H���ۄM�go����p7140J5������+�
��>��-��i"�tp-�r�Ie�`�a�lH�sFO��O ��C�`Tq�mw�vt�iw��l	�F�a���wuQ��L'�0��.�F�����t ����s5���y���RO3�>��֦]Ke�W2*��:6A{�)g�6�at��%��L��r�p���k�9� �Ff�iT�1��|��+��d�dpH漅��0J��� vw�u�`t� 0t�	�Ԥ2���f����2R�7W�F���8ҿ7y�Ʈ ��N����N23'G�A)�B�GO��9�]��e��K�CV*��f�ߞG�O�����Lc�ORӤ��f�0��Yv�$ O>Ӂ�0�������$��Q��i�`T<{Kb�&������<�n��H�{BO�3�������C���;*]Л+G�V�Ӓu0*oZ�s��N�>����<9yp�[:\����PQ��\{��a�ڼ��{�jA/oΡ��~�C2��a���b���ax�|޴8�y�o�����**�w��ɒQ�t�]�;V�%�p׭ֈ�I�������6��� ����-��o����ҋ�a�W�@*���Ƶ!�(�=A��@����z���J�`����8q���ԯU���X�*Lɨ��F�;�$)}G������D`p����V�(մ0�׊����e����94��o�]��ʗb�b^�*g�i]���Es|`�n	�`T�5��S����<E��I���2&�P� ��L��;���]]�IF�&��|����h���Λ$����:]�i<�Lta�f�O�{��!���0J5�q:0�ߞ�N2:��bw��|�^t�Q�L:�m��A<gǿ�*�rF��(vo�P��9���l&�V�ǭ6L	w(�F�S�0���n�� ��F2Xss�6�� ���걙�no�����1D�k�d&�*ʜT�!.w�NI:���/��
_�n�~^\���{2��߾��1�����#�atj�9P�'�Tb�u�
Fere8$Sv�#�*�d�EvoJ�#�AM:��X�8Դ�o�?�:��:�wGJ��wT0J51�F����*�K,ݡ&	b�Q�Lo��%�#�W?�Aғ��<C���#w��(��(�=��(XT��N{��-�e ʌ��@����$�o0�yz���z�G��\����dJӱ6�;��.B	��L�����H�\�V�������
�\l2�����ksH�e�z]�+��]�O���7^2�j*������O�0J��s^7����e�=����.�����K;�O�[�&3�tPF��ds��+e+'�F'�TJ��d0�U��e��� U��ԫǙLF��rg������'[M�[MEv�=�RM�G���nn�9q:�����3a�D��{�9��6��<��+=�ٸ��<0�wmF��������]��IF�(���;X'�3�W���aF��&*qy���A9�7��;1O���{XV��&"䰙s�4`t�C�-�{<D�&�ksq,H��'oj�	\��V;cr�l�/z��Xvf���-~S�w~{r��fI����ΓQ�T�칉��[[��tp��r4M�cJ����M�/��s�6柘��QiIb���r�yR�S��P��~��#Q�70-u�����U0�<)�ѱ�%���Rv��dy�-�= oi��Y"J=������,	 �F�ڕ;$��9[:�kw�i7`�e����p=Y��KF�oR�(mf,��8#�SA�`Ta����_�0^�������=Ռ�.�D�s���s�0*g�)��0��Fe���:���?��wK*`2��`0����v���{r&�V$�՝͒3�j\�L�QZ�rQ��r�vn�u;m�+u����F�n11�<�-�o{�J�iسy�h�D���50:�n�s��)��t�7�`T!�U��!�L��Rh�<�SZ;ӻ�0�LF���ߞ�C^��m�T�QE�6B�)�"�3�(���x�t��%���zr���0�����F'�̭�f���蜩a�{v�Z;�,�b��s1:lp/5a��%(�ቫ�����Մ�G��\p�!(������E2�7�R�<9Ja���Q���|2�+�ʃ`R��Л�؇�)Lv?�!ț��W~0`- n5�G�߼��<�h�0�d�pў����`0��9�����L��` o��l� �w���d|c����DO��"���A܂݀cа0��d8�p�*��&Z��'�]F�5��oq���j�5�ɤrO'!�`��R~(�ws�{)f2��z���ZwM��$�ļ��    ���d2����DJ�zc��?9��׾ǃ�v��l��lf�s}�)g0=ĂE��;؝)9�&��3��`1�6Wg�3c���M�Jy��K{|�a@�0q��o�1�h��LF|����0�c����f�B�9v�8�&E��i6]�~R��Fy�̾�x�S������T�����8����
�rA�}�NbZ��'���a%۝)5���f���V.���w�%C�e�s��M(,֨� ���"Ѐ����h-���f0�^u��F)�f~�$�������[Z!0�7u��!ΰ��Ά`0���o��s��	s���'F��Ǔ���%�߼�?b>�'��>���a)�l
,��)���L]�a��<��&�Q��8eG�J��'�O�T����NQ�`���0�e�B�����vvu��`�Jc��l����C��{?/���q-{u�d/!8�R;` V���8�9�X0�������S�-���{?v�~=�z(�8IvPK"}���l:w�1�`j*M�iA0�gw_�$�p�05.>���E2�|`0���\��F��`jҵ�����q�����컮�%ٹ��@�(q������	ɅO&������J���o��y>��;����&i�Ì�_�2�|����j�ګ��[Μ���&����S8�xrL���h�B��)�k�|nkc0�d�V��F�Q��v��k�˂骩E���LN��ez�G����ɜ\쟴�V;Lb���aD�����=�s���}y� (�؃y�~�hN�@���P��d��` �N$�y�
�G]ɤ��7jb�s�a(D�Y@���ʃ3�ܞ���NݼS�0E�ȅ���Q9���n2޹;� ��$3��<��T,0�g����$m�����D0�g뺿5{��A�M�i��I/���t%{6�1"�c�ޔ�?7L1�@6��r��d1�d �V����s�ȳs'b����לk��(��+�T�����4��F�4��`0_�9��\V�`@_�k�>��1(��n��`2)��I�����̲�<�R��K8�KD�g{ũ�|�D������,yH��*��M�I������E�������>�p��?�>��O�ESӊ��(CL�ʣ�B߸�Z����0P�e����
c&��`jb�y>�)���d�5�=�z�h��3V�FM)5y���3� �����'�(�p7�8�Ondp�#>�hv�GM�Eu���h�W�+����Ӿ���yPvvN�����'逧kE�0�df?`t�����^���St�1`��*�9���V7�	rm�����ۏ�ΥN�����5�4~Q���{�s��H�K�L�����\[��߸���LK�j�{v|��g魏O��dy�@��!�5z���p��N�382���v��9�s�?�_����
��v.w�N.IJ
���_|���%��%�x��ܝ"����)1�1��M�D{kL��6�t��`��Wz����\�;"������\F��=��	��L.�mf��~RSu���h��q���'O������ N�\9���QS-�y>�h��8f3������j�'*f3�'�`2�
zu���̺��fjkS�70KV*o�[�K�-�"� ��t��h����`�p"{��_�Z�|r���P���'PM������݇I
3�����$!��!��?�٭?$	ş�h2Õ�#�[�b���4z&���HM��N���$2�`������'po�u���_ҿQ��`H�`0-u�����}A,�c�}�����Ƚji	r��?D<ɑ� ��o	���O�@��9�v��L�~��091�`��-<8S	�$�d0�n,��T���/E`@�M6�t����`�Z�r��ϼ���`�9��,Y�f�D��ɹ�`-����?�e����Vg�4�CW��x���IF��~Ȇ��g���w�1��&��3p��ǿF�����X�͝��������y�J������S���Ӵð���I2�����ÅѬ/ߴ��{�ペ���i���j�!���gy� LM����|�-j���$�旜&2H�3s�X������C˻o$��v��!�G2 (�J��Ӂ���4$̀�.)���]�@0X��~<�~��0m,�d?z.���f��]?����R��d����
���$w�E��\�gZ��`��P0)r�,�ݢ�&Q�v�ރ��s��S�>���㓻/̱�J�F�Ă�Lu3�Sv�1ܶ*K��,�Vm�=&���LK�폢&�Q F��*�]��s�Ş�I���2]�/N�ɹ��`8�qHK
3SL0�@� ĳ��b��0��$�����ÚI+N9Gp䢬OZ��SE=���}N$̐S%=p�B�;�y���v��Aej�mfo�ڗ�QSS��`�ݳ���JL���5�$R��i���j�鷶��&�IM�d0�^��=5�b2g�� ���||0�Π�n����:�D��ZJ��1zs_��$��zX�$�]��@��2r� C�z6��Oݥ�-jm��9�v���Y���.\?q�*��n'���j�{v"�ν/�-��I��5z�ew�m1�f���S܏� PM����O/42��GY�TR8�^jɻ��'0$�����g(=��L���>�)0șBj�힝}(7iCZ��dدe������IA�O�+R�����*�8(Iy��%&�~�{��M���V�d���*]`8� �`af���1/k�*��Ւ?b��=�/��m��@������Z�$N7`�Q���캻��ñ-��~����E�ڍ]��p��c0��F�>`�a�`�(���0�O�L0��$��wC��=�3��_lG+̈;hT؋`�,���f�a]����|��*/��=Krp�` g��es��V��fR���4JL�'M
�K�[Y!0�K|���c�Hsm��=�)��Л�V�l��ן���\�����Ƌ7i	��SS����Ȝӹ6��j���8�A2X�Yy=�tr	�o��?ym@٧�pl .�r%��Oj����������L�e;D|΅��l&�:�Lp�%&(d��pqQR���uW����,aȃgwo�A0��dj� ��5A0�7��AO�|٢&�f�㇭z�tp�)W_�'Ǔy:�p<)"���.R?IyN~�:���$��5�öUٯw���D������r��9y����[�(`��t������w`�/I��hk5��L�@�f��+�57s&�m>\�)��h���>�3ZY��"C��XC��n
{\�hv�?1��A{ V�?6��6�Ǭ��j����5?�9��Q����{�%4��y>�vɑ���������Ԅ=љ�J&�|z���R?9+�0�m�6L*gR��G��E2���̞�k��
u�/5A��ir0r��a��X�t<�Pq?��:��Խ�a��x߯C0�7����ϖ4$�~����$ݖ3f2���R��|I��ig���iML�G+�8�����Ônf���t-9{�v����ul�_i#f� #��E���vg
!�=�5��WB$�J[a��h��&K}�I�t��`05�Ã����kh�t�co�09�{s��5�'A�h+�F�$����{��}�B3�Orv��{����qP2C
�%��}YQ��}s]��D9<���H��\{����}�1�0�ͬ��n31�r�a0�kW�����wMw�7U'�t���D�w���T��}�I;�0X:�)����I��yvM�>����g�b@0�gWj��~)��H����;C�~K�dϓj�tϚ���I��5~�_wS�it_�����I'5ն
}�&Շ8�~l�={/�F�� �f���! '��ЫK~kƙb}0���RS��
�q&퇺ǛZ�}rG�    e����J˼@� ��I������gB5����M�� �:S~�Ne��33��þU��V�֜K�8Swu��~s���0����'f�'����)r1�~�nc���3�c�rv�9<Ԝ9��2����ݥS�V3�DP@�d�9��)>���N�z�����ʅ�LCL2�gי�ݙvg���i��pVJ��d��|�T�}��$}�'*}�����p>��'f�õ�PS,�� $�~�O�fʒ4D�`��7"���I�L�)�z��ļ�|����SS��as���0���jl/�I�m�K#�?ٵ<Bz�l!����&���4����b��M%����EMX �qϽ3�0�t�~MOS>Q��QNn�S�����C������\p�` o�=��$K(�Z2ڌ
p��;Tc�LF\s�l�%�[@@0Pj��m�}�-N���L)~~���Ӱ�Dcӏd PM���l ��=�$�yv��1O��� ��^�ٝI�����c����r!����LK���%�����L+�>vJ��7X>��ɢi�9^�����d�+-yH���SZ!0��ȹ�����LN3`�������C��'�i�6g�c������Æt	��=xUW��m��'�5��ۂ��Q��rr�$*(g���|�)�$�d�9�ot���0z;�K��4���fI������ 
���P���'mC�eM��$џq��=�Q�DM{��C�����$.[/u��iEv�]�Q�Ov���z���;���$S���3F++2��6���m�@鲔5}�$��ܭ��6Kt�U�ii8o���>݁X���n��,&��s���i~�T��~�%r|
`v��'C(����|�ɡ$�_'��wGO�*�Oۧ׃�J��	a��g�����G0��OLFz���0�?!�%�$Y��o������dv������ ����`@��Ҁ�aƧ���^WL�A0�HI��ٷыݱ��҉������d�'7<��q�`0�	��������d2!���a.g(=��Ld�!O���d��d�g�����B�ʥ�� �Q���@�����T8^����ŝ�!��J&��1��@Z��{��P�?m��{J�f���sBf��:���{x�/�Y�Z�]2�'ǄÀ6#��Lp��`0��J��>��y���$�.��y)F�E2�7ʹS�ob�����Z29�l�3�5Ҝ�[���O�A�!��``��)�փ�Hr��`Q&eJ�Β\��8P?�s�XL�uٗ)�;��Sn_��p�����sQ���w�����|�R�{�$��~g�>������l&�Z2�3S���8��>��κn���v�b��8�XBx�ɷ��ř���v�Nn�h��Z�#�Y�݀���Mh3�$�8J��D��V��w�{��O#�B>�hʕ�C����7�@8�0V�9q:S� Ѐ�Ӟ�r�T�A2�w�m���a4lLsug���JI?�`8��Q���8�����[y~�6��������C`0����1)�t�Ec�����x��Z8�G{�0�'��T��}���`Z5�����
��>ٶ�Y�ÙiQv� 0���W?�MZ��ڊV�� ��
=��@0���0?z��h0��$K����F�����'��kOy��t`d�ovǹ1=��k��nm�`�=?�i�B`@5���c0��A2Pj�)��p���{j�ÏOZó�L�~.��{��Y�rSP����4:%�a��'�-��T�p�{�I�	���~f�JH2�7I�^`J�� ̀[
� C!���,e~3kLa�|X�ii��%��.�a{|�¸jB`@��NnE�����l��H�S���"�ejz��D	Q�����LM�bB���G�M%��칩_Lj�l&�N�	r�cj�rS��^v�D�^�*y���آ=���6�˂f3��úiO�9�9 PM��CA^�p&��}�� �%����	�ؾ���85�{�����BM52(L�ل@X0���V��	e%��I������{�ռ��I9�Rͮ%��OB �~[�`��� �yv�.�Fn7kL2�7�|v�09�����=��a&�X���8�'��{�ַ�F��ٕ{�}�%�G���0�g�Jff�vo�.����@��W.Y`D���y#����#��^�g>��H���:6LJ?��̳G�?�0�N<r#���ZE�3EI���`0�i3e{ҎŇ����`af_�&9Ow=	�`6����ʆ�!�EMP�����*L���U�g�'m)xF]�=�hiu_�"0�dR��[m�d�d�3Kv�֐�s�)d�X�0�����I!~syfξ����������oZ�~c[aBp���y���=�����$(7�,�۫ΜE�d��.��ĢX����)F���~)<��$XX ���3�`��V�f2B�?���*%d2�3�/�=���Y2|�ƙ�*��i7):��ja�o`F�a���:гg�jo�}c� ̳�wޞ�(��A2���E{̣����k�%_,nf�i�&J��.0J&���&ǟ8�H���[g}��.�&����/vg��?������D��H��O�	��j�.���5M��3�M�͇̎����2�'M����xX��>��͢�=T�{��e��<������x:�=D���;����_�_(L��@��o���4�<nw�����e�`@�~<,�%d�A2P���]x�)Y� Ȁ�o��aF�𹽸5�����`�ZY�
�����>-�zz�d�^��`2e��2�`Z*R��d�sw?��<;TZ1<��Kq�`��z+�n1E��?9;�9�|3z|8�+���C0X��1·4���v��g�bBa�˶k!�d����u�ɔos��Uv�];�Fbb�L���'�q.�l��l�o��a�`�lgm昧0�v���]\�$��$�`R,����Lr9��I���r��b^�(̞"j�L&��ƃ��goP�ى|���=�LJ�F�D2̫�k1S�dI����{ێ��|[�L���
��QzS�?~���L�$��d6��V�}n{%�[�OVpI��̓�8f�٥QԔ�}��@j�>��`J��3�Mُ�\�R����)s�`�{���%�CDaV�v�	N3l�a0o�u���a�F�+ɳ�O`Z7�����s�a@oZ���U����i�I�-!���AM��3�`j"�ƲG�@{��A2��H� <H�J:1(����fx��3�	
z���^�G-��gSN����km�`�wr�Xa0���lϓ1�1VF��O� ��=O�Dt��������A29�	��%�?H&K	b��0��=5E�r�f3��LX;���̝��=+�bp�9|��Z�C�N��{��I>9��&l�]��x7�哪sO$zظ�E��;<�$>���'���p)` ���aG$I()�0��H,m<�L��&E`��烚���|IJ�~rr�!kT�kg�s�
���TF}�g�ƙ{�@?�[qReDz��tIC0��Z�i/!r���0��ڬ4`R���������\/�)Q0`:����T�כ��ov�euZ��JV���~�{�n�Y���8f2%�������fJ��|��-��g�l��7�`jҺ�aq@^]� ��"�?�Ñ|b^aO�>��O{=N9�=�/�I��-�N��"����T��,�n�A`@-�D��}>0(�T�0�yp��	
35U�v�aGt�k��y�Rs�f/����0��=��n3b���5�6��������50��h�G� �G=]׆`��WK���wy� ��L�!5��r�T��3
�;�L�Υ�`@���>z���=G�$�ř����v�=o�d�m���V,��� �������on!��L�� �ϛE�� y��tz�c0�7���LP��(٠&ȵ�FO�'J���N�i�C�d�ݖ��`W.�i������ם��gD�    m�`0����j��Rb�%yS��?����7kw�|��H&��P��B��`�I�?\E+^n���z��%h�(�t�/����[$��p<���nOJ���7׊����K�to"0����|I/�q.��C0���(�	Rq7ȼ��ЅB��~G�f>-�,�� ��d���-���ud!����������E���=()I8p0�`J*�������$�|���/0��!�`~݆�R���;�8��K�����]�@0��μ�C��UJ�A���>�(s�v���a���L2�?D�=�$` ��.�B0�5'�����K����ż��݀}Jr�m'��Ʉ����Ԇ�r��M
��L���p��Դ[m`@��J����,y7�g�?�1G�� �r�	��ԴBh�C��'�N^���o���>���4b`�Lf��ǽ���
�����ۃ�41�5?����a&�Ġ&, ����!�a��3�7�Va��TK�&;�pn�c����M�>��\�6�`�Ź��`05��˃��uW�y˻�`������Al���|�p�B�N���|`3e��{p��!�	�A�Lq���	b�A�8v����O�)琿H�
��aqs.?�A`0VC�0��v��R�a����yc�_��'���e�X�N|�`@�ӹ%�?8�'��\�7�=��=$ML̕|���-&��׻���$Y��o�M�.Z` %���������2���#��@�/���%$?�y?�/L2iz_`؟]W�2���j�|"]$d��c�2ٝI���hIb�_�ӗ0�|��)��U�͕��8^����zд����ʡ}R����2�b��J&j�o�y����d31�񰲥$|ާ`0P6�4�{6Q���~�ʓ>���4�IǙ��`q&ϒ`
���Mսl�k�� ڌ���Mŕ�C��\{��q��/.�FR�'j��=�{�	3�5&���Nߌ�`��͇�u�Q�L�;{_l����q=��o�D���8qL���9��~���'����&LK#Egw�}#���.���C�Gz`ُp�b���ݥ�ii���L���%��݌v_�H�șr���s�nnt��]玜>�џ�p6)eN�[�̿����0tێC0�g��Ԥ��)��@����lΈh@��	�Z]���D^.�}ro��F<�0Z��K<(���C�+�݉���÷5�鴣�`0�#<䦢�y�R`6�6��ҁ�C�yI_�L�o"_�S9&e��R�{H�`�<#�`@5�{e��<�DY���L�y���������t�'�
��ܚm��g����j��������I3����&&��4���I����L�W� L2��Zd�I��$y�z�<�~È+l���8��o��ǳȳ�'�kEe��O7��|���\����P�l��LF��d�l�i�k�O��-�/�o�|�@0������$������$�U��<���^<��7'��{{����:!L2�Jx�y�a�8#Z=���̎���c3�g�`/?��0�f��`Dn	���jb����;<��*������_�g��E��R��i����
B�F�/���+�H&�b��l�����gBX0-�f���D�މ��4�'�L��2=���`DC�= ���yVZJ�u�'�e�����j1�i�9S�mQl&�����l��kz�,j���n�W�Zw�>q�zW�'٠F����8���@\c#�0�7!0�'�����~�"f����Ǚ䳜��6Cϟ�Z�+voJ��\�B`@����d�m⯟SE����"US��=>&ѽ�	*fZ��ӹ��ߗ�Ų>YN����~^���� E�F!=d����i��-O������*�4�+�e��e-� #l�f3R���b��o��$��6����+��.�I;��fVϰ��PN�|�L�?a�B;�2;\5���'�U>?ę̜�SS�N�kK�����AOn=���r��	�����NQ.tۼ`j�⌒ć�$���W�2)~����h�0IW�	�x��0ٝ��`0��qzy`�{�
�d1�gb�/�+q��d�Z}r�sz0_�� p,��X|�;6��C0H2�Ae=lkb�w;d�݋��pq�=�����LC��Y?�$w���j�s9�'�ͫ&�R߼�M��?��;��!P2�ׇ�S��ˤ���'��X�Ãd8��0���4]Uc|�ٷpLM3��p�i�ӌ�L���bE�1���sL8f33���I[��w��lFk�h�39��� ��۳�<�]��҆` �,7���ȞXz`���'���"_`��N'�%ʥo<�L���p�$řC�/0���f3���]M��l��{@�&�v�e�_�t����A2م�4��}�O��zL�&�l�]{����:��d��ɭN�&��(��Ā��ћ{�}-���.���(�r�y�Jv��9SU����{^FWG�~��:�ޜ&�|�QB0�d49�����f���5���(L2H����*0`@o�i�o��E���\��>2����������L1ou*��t��1�f|�ٜ'7��W��L��`g���j)�
�'0�S}L�]�q�d���A2��+WM;�}�����<8��!�~��s>�p:0&(�i%��=5y��g���'D�kU1�G>^ɬ��;5�U�d�!��À���>�u����c��l&�@�A2��4��` �=�aw��w�TC���'Z������ (̄�k���C�t���SS�#��_-J���o�r_b���c!���CSW2f�QB�0���=L2������;
C���~Os��
"6�܃���d�L�\�I[�N;�]�|�6���`�Q�`0�N��������bM��'�p5�ٝ݀S�p˙8�O�vJ%?ęC�+���N����A2X�L�,jʞ��(��勧�5I#=���-0�͔���?�\1̛j��3��A0��>��8w^�c0��X�&������Or��y��ޔ���v1ț�/y���+z��L]����漹�9����0��Jow����MY��^�c���^.>>���؟Kz�MZ�y��2s�9m�Ԅ��/�����3��d(Fͫ�n/!���� y���y���LM��*�H��*�6������V�AM�k�3d�&�%���s����Ã�迺6���jjbo�a�܅?$̛z�'�T���@ޤ�<,UX]���t�q�KYF�vg�����`@�h����=��{�mf*]�/�3q���b�̗��J�ө����}F��h�i�eXRv0��Ҁ)NN��h�G���� 0����jN�$/L)\?��^���c��4�*��B�����B��w��U�N�'�ĕ��L��11����:[���%��%	~��������d]�<���w�&�����h]�D���!L2�����D��*R}��'u�i�K���yn ����O���s��7�`Q�o�"�0P�)�Z�����m{[�k��� m�����7�@δ�<܁(9���
�������]����d�%��P���� Z�0C�O�ʹ��'�L�q��������Lu\��i7����L����ɒ������
��v��5�����Ze&zP��3Q@?���E�ZKA�,n�C`@-�:�]0>����T�'�TW��n�~�(�8��ZX\`�յ��n������_Q%;̞�R0�dR�}>��r��C0�c���o�7L�;0(��\�C���N�r�VZ�`�s�^Ti\s�d/DQ��n7L�{��%�R1*�w�<*�`0��1�����f�#�f��4 `�0ӣs�N�!��v^�n�O�dO��o��֮��^�J�l������Mf�-;�,9�9��ٽ�B0��M�i��    �^@��L��&̙&��2/�;)���b���bx������S?��'�Ɍr�g�H.(�Ѕ�R��I�LC�2��w���W2����iP���3
ߡ�(zhw�0%�d�����C�)��gI�&av5%��Y���I�&��ƨ��''�CK�e�3)�r������� ЀW�b�3)��w�c�>9����CnJ9J�ț��������`ojN����oj�F�_��̹�L��jC��_o�R��z�C�'`0�R�L�#���i�Lq��ǫ
�H������ma�O~"���|X�O� ��v�aH���h�;�V��؆�%�q��s��h(H�����0���@Ea<�ҢF@�Enj�S0/(&�;U��$#��o'7�p�8h3���0��1�@� V����x7)��O'&,�ԙ܃�&��S0(5�cw�!���x�Nb0X�[c��0�%]������&ת�r��H��L�m�L��2�J��� ̳�.R�n2>]��=��G0+{2�ۗ��LI�5g�l��;�n Л�O�AM�b6H���rxPS���rv����s�Wd{����H&��'j���C���i!ݨS��J2��7����&Z3�]�
��XW�(�r:��f��ɕ"�Ys=��ԉ�`6S�ϧ�09�H2Pn*MJz�wz�`,���(O,���%șJ_���r'�c0Pܸ/�`��tL���Oδ&���'mQg�y��l���jx���T!PK5�h7��٭9{_�Ct�laZ��o��>a�o0E�t�wZ���'��w �O�p�0�
!�:��ʩ�˼�"���E)��Z)��ҙ���@Yr�����p,�,�˽��c6�	2}��';L�L@�ݹ=��%u�����G�yI&���ӹ7��ѿ0����dȧ`�A�L�)����G���qJ']��/�o��!o�s�	��$úz3�)k�5H�3�}��Uy��d������n:G;�����w�c�9������I
3����m�=ޠ%���������W�u��~��9��}����V0��J��#�߄�Ǝ�@1��c�`�djm��ԔC<���{���D2���C���`� <$���
Cޝj��M3�� ]�G��0o�c�ɔr��bj�xM��0߮��d��$�7�K&D�=:���_]2`)S�=΄�qp̵����ρ &��)��lOq���M����b��K���Ug�^�c���L)kM�7ŤU���#}�8(ur�{�&��,̔�8?��R� �ٯ��0I�q
�%�d��q��73���[��}�8hӻ� #�K=��o�sz`)��A0�ɴ��C5�w[�b��2Sw"��P!��� ��o��O� ����	
3]z}؜�2�>�읝��O$S���.o� yv߯�$Ctf�`,�g�&1أ�VV�d��<�Z*T�],v#|W�����p�b��b�U��9�?���Te����r�ހP���[`�������������¬$�XX�֒���Ö���w�H�"}�&o�}�fO8�;(�cy�)�w�$������pz�`jB�¬�δ�}E6�@�����)�AM�>�H�F���ٍ�,6���'[����q�w�sT�s��t�P��c�Hp�U4�I�h=��C��;�`0�q�u��a���0�@q�����
�s�s?�h��.�P�jڻ!���s��]�����Ǳ苝���� �B:��!(�L�uV� Sl0�O/��d2���SR�L_f��,o�<2�Г�I�m4�����t_�)�%=�wv]!̛��Y��$
� $��0�w�������\;M��������h�XS�f%s˙�c>7 ̵�>50��"ț��zYpÄt�0������0щ`0�V3\�AM1�Sc��\;�$�"�r��c����=�����O��I�|s'cR)���=��` �!
�c��%�附�@q�hFkk̿0���S�0�880��+�/L���0D̳yI�<�$�CdS��:���F���6��kS;L��f3�3ɠe��0��Nԗ�G*����f�;�D�_}2�c�&/�-^��VA���e/����[A@0�בҢ�B5a�]g��&j���'�
i>p�r�$ț�s��ηЃ$ř�J~���w8�l�S�DK-�ګ�E�t�.b0�`F��M������-��'�4h�G�+�����ż�E����P�6�@�4$Ӫv~vg ( �_u����� �~��ӾN�'E����ױ��ˏ�����`0�����w��d��d�T�,�4�����A��
�.��<M����$�d���%0���&�����۾	�Wh��Y(�?w:��X<�XN�Е��b:7�!�dF���ݹS�	�Rb׫]K5�_J�Ӑo`��6�V� �i)	��`�,�1�@O��=�d'����T��Z�T�KNL2�c��V|�_ڏ�0P�Nc�i/f�L-骩g�����������`0�^�ڃd�3�����ul��y%%>WW�u�/�WU^�)��_����~JJF�<g}��&��
��\��׋d
����YoHo��V�-�V?�ƛ�e���0Ϯ+�p��ǃd$�s���Դ�=HFC�� Ȁ��K����[\}iR�$k�\�]6���`�/�Oΐנ��`X�C8KMK�2���?�H8��5�E�دs>���U��a�O�����p�:�d2�Řڿ�L-��?�}��"p�����߽CL�D�� x���?�й�� ޴߳����2�$��`0�!)�e�$2�����K��zd�`�~)`�d�\��d�dr,��3��}�_�Lj�]29�3��%�}��F�d3�77Ԥ���4h�� Cr]�����+�c^&�ŀ� ���:��¿%((5Q+sؽ�s�I�T&����V�]M%��͈V��tm��.� S¿�I &�6�@B�O��`�-#�C޳�EMPГ�τq���� (7�
g��E�7H
ze�Z��D9^�URr_�������p�#�?#�����!�)v�]2�@a�G��|`�[ZA,P�Q���.�L���;��_b�KS��)�a(h	|,fN��'���J�� Cg���}�b�)~w���}��3]�v���(O�� �����3Lt��8ٌF__܃�"ӿ�Z�d�4�0���ӿ� �|�m�<�H�w
�	�3^KG
���y�� ����C������ _~نCX8��.!�:���T|����@0X�	5�e5�=�1��e@̛Z�f��0��ca�8����`2`țt���������_�u��������0D�������T;̞��ț�����!�r�������[5qM���$��@j���{S��td�`�t��� ����=JP2�͈P�v���^�IX�����i�do�����y>���ՠ` g��3�x���Ը�s_�&��Q`�<` �^>�`5�-x%��jn��V�Vrv$�@I{���A2���8��+V�d���t�	���IC���	%g�d oZ9S�v��]��R��}�7�d��,w������	��ޤ)�0`��q���9�`�q�V�)�����G��]�fhݙ�0�|.�����A�#�f�Q���V0H:P�6܃dt�r��!(΄�9�$S\8W��H.����zcA<[Yj�/��,(慑S5/T�q�ϑ
&ȳ'�}��)A�����5����L�u�L.�` ���wsթ01�E0�c���x�R��W=��j�F���8J>���Z�3|��t�z��/�Z��Lt-��0>���_����忸�)���0�b>;ґ����*�(�e��{t��Hx����-	3*�ج�F�ɿ.��#���;���#�Z'����[�F��a05�J�FӁ7�@D�ނ���� �  E`]��d=L��KE܁�jb�O\��$��arJ�p�eX�Sȟ�Ҩ�v�/
�X�97�?ޝ_f4I�6X�_g�` ���Uo7��n̫�����j��z��a�K�8���w��r���)��uv�=�נ&, WR�~�I&5aa�25��ٺ�=K8
�Ubl0�
[�	J�u��q&9���G���70k�� 3�a0ojn�a�3�	:Y`�8�kI�.�݂�l�Į���^g��Z}x�!�q���L�97{nJ�s�H�M}h�� �}G� ̛��^�U���AM�7�٩��[E�d�ܗ:�d�S)$���؞(��3��R����JeD_������C-�쫦��>R�`0-�=����y@	�`x�*/�� � ̙�/0��yc�n�f���]Í&��*�δ��۝)��l��R�X)�� �%�2��\�vo�ٕ�0��L7�C��y�g3�@�4����".�rfJ��o�uu�s����l���)�a�����q�AMQ��`��r�>y�Qh���ewm�G���"��^���D�\�H.?�p���b���':=��G����fR�-�մ�b$>OKS.9�r�	��xI!3LJ��k�=�4���*�������`0���ƃd8�r&Q-���Dc�i�߿��r&���a8	�*iO�v��m+rlv��-���LKH�8j��0��&�~����L
��M&O�
�kZ/0�8�d@5e��{
u�&��KL�<xS�j55AɀI�p/0�N1�`1��� SB�,}�������\}`����X �G��Z���1�@J�lw��a(e�d _߇{���%	��� C\���_���P?����TVe�/zS�y�%�s�V����yS᱈`2e2HS�,�"
�A2P�+�����$�l�3�������yv��g*1�0Sz,-|�����`�E�q�a@ɨ�&{,.�s:�I��!4�US��YJ8xPh��wyi&s��0{��0�͌��l�
S��$$(������/���ޠd�03�4��	.�9��$y��c���@�$�y��u�|��B(5ͽ�dw��������'j�9Dy�!5a�a0��ʋ�����lf��L������TDMf�:�Z��1�s��^`�3�@��v�-�[�0���\��T�{��%Ck��pq������Q[��H�[C�A�v����yM��l&{M��oʾG�uW��)�����Fz�������)����=���A`��lfs�ۿ0���f o�^}�=H&�3}�A��߰�=���'�Aeκ�"��p��sv��_,�rN��=���2�,��&�q�;ah���US~���H�a���k�� 1$��1ϼ�aT�� �6�Y�M�6�˩(���E5���nmm�E<g�K��W;���	��|IK�h��0bb�����`Jt�0���������R��h������2ɃZ_<-x�k�=�"�4J��O��R�/����O�8J���������/��J�a�T@��zP�S/o�A���|PS�����R� ���'�K���Q���4Ã�v����@1�rI�:�Aa4���z�2w
�.��� ���>��j/2|x�)���$����I�8�>r��	s�6�z��g|5�&țHj3��?�<���\���:���n���&K"K�T��� S�"̛�qʃk��L�5Aޤ+��F��(�` o�%�?p�}\������Nx�&��.����Z\Ix���%'���}� s�LB}HMB{Ȣ
3F�M�,0X ւ1�OҾx�1��K�dt�b������!�K~e�BI�
F����m�aM3L�t{�Sk���X�����N5�J&ܵk5��g�B������L��`0��܃d8�3�p����k�
3����a:=� Ȁ9���]2i�?�܄>yI�y�䒝ū��_�K�L��:�x0ș�嚃&��5!ir[a	��ܥ�L!zo3)�?s�15Aa�bv��9X
3�˲��N�������sq�03��b�	��9��!c}ru����l�
���4��3z��Hf1��7̞Ё�`���tk��C��E�`�<}�Y�0��2��UE��R���կOlf5o��aJ<Ͻ ,�S���Va��W�� ,�c1���?j��<���dr�Fh��D� �������a�����ϟ������ɉ��      �      x�ԽْG�.|��)���)�}�;.b�Ӣ��M3��Y�&�D' B�O�s�����ʴdx��Fbk����[L�QQ��U�Q�_A`���k���"oˢ��:-�U������������$wA�a����*�����=x��d���l���-��+����пm���1^S�＿�W�Go0�����ú�{S�߽���OS�޶o̰�k�=��s��>tz�S]�����aO���Mw|���>��Jy�*C�����{ݵ������7S���7̀OA�jM����G{Sҗ_�;�c��w�@��o[�'s�o���P�n��?��o�؟w^c�'�������{,�M��U#�~K�n����4�eM_��`��[+�?��wޯ���}���3;3����g<t����r��}/�cw8z���@���~��3��@_���r0%}KowM��kN�F��=���F�x�Ӱ�����r�_��s�4w+��w�oeҬl�&����dEJQ����,�G?S��?��3ydQ�N>�a��(9\}Z���6�ז��'C����{�m6����E��O�����ܭ������Eb��ul��&��(��D��C�:�^_�t4��끮oM7m]~���sG7���Dw���"���P�� Fi�a穟H���Ks<�cB�����-������Á�cG���������Q��)A��Ts.����.\�u�������.\a�jƅK� $`��EE)�CUVt݆ӆ�6e^�w��R���3e�]����nw쐫MYS���x8ޭ��t�m�V���>����9{g����|�w��x��#�����-=`��q:z��t��k��=�u������vm?l���kg���������5P<w����°^"������~��)�V�
�w6����pp�~�U=�@z����/�=�粤�FOy�7��S��[��_�(�xz�� ��@N�U*���E*B�1��UD9Ǐ���I|c��t_RaRw{*ts��*�`̖b|O�֕��uW����y��*�nǎ��G�S���i;�>GqǙ�X�8R���є[��(�Q��T�Qi��w�RP���ϸ��%���a[n6w��8|y�%��x�Q��f�T���N���Y�J���� Hh�VУP� A)�̧%K�z�����T��>{%^SJ�k�|E��z�VM�����ޝ��r;���?%�V�!�ԁP��+Xgq6#�T�k���:1��������Cr��u�n#���OͪA�G�U�ŗ�@�2%0
9�'���Pn)����M�iNc��al���lz�+�H��詔޳���R؉RX������6� 4�k�Gd4t��SB�Z�}I��ٟ�w���P���G'��v��%R�d���!�(�^4�W�;:O�~p�t��u���r��J�PK���[�������w��;�7�e��f����q�6cK�<Q��F��QX��?�)=���-����G7HV��{<�Ѻ;������ōG��6��d��o�&Q�����>�tĽz�g�>��e��ޛŎe\�f�{�IR�G8]�rá�̝�;i��ο��9��`��g�����)��4ь�&Ej�l����O=�����(͍9���C=���5��d�L7�=7�3~�j����a,�"�E�3�g�&Y�q�WoP���oG�`���*~ZS�w�`��`� BZ�Q4�݊�,RF�zg�nJ��ݬv���s�:���P��L6�ɖ� ��(j?@���UY̸zE��Z����O��q�9Q�Y�G/������?=���c��o��>�t�I� &�fd���3����/S������[V�ZO�n�gIak��ߨ����`Sp�~G�v؋�b��
�����X�5v�o6�:7�����ժ�.�,��۴,�G>�M>v�� O���0�}��aL�"Hr�j������C��~˥�����ޟvr��������G�胫c��Z�>(TOW�����'�20�#ӏ'�2���L��iV�yv���B��y��Z�kQ�m6<*�(��}UmA=t8q��2��a��Gv9�1=	X����0.�ϙt�)7�`]^~��� v�te��v[��)��UI�DE��=�D���ͩ�;[�ƕ:��[�{c�P�5'���eTu���$]��2*�Gߎ�E�~mٌv�CMABCʫ�{�A{�:Q�Ｗ�:X�S'ޜ����G�B%0�uPw�{���I��,"����8_&�q�.�&53�ay��H��>�<�3<�t�����J�oq��ļ���/�q\�Z�`>��{�S�;��5�����Ḧr��?�������Ɲ�<.ܴ^ٶ��Rn�	¶Z��N��	}�T}�I��	���q�{��;�vt�{<S^vX%ꡫ�#�S�]�5x���}Z��F��e:#����9�SSl~��x��3��Sͅ� ���6�<��ǖqmP��/>�"��vD�By���8Ԋ��o�w��S�?�`P�p܀���&(�܏��zM�֯���<�2ۧ嫟���7�/��Qt[lt*�X�Z�T���z�Q���w��M�ۚQ����(�gL\�T �S!�j-�d&]*	�~���y�fyl�B��q�Pv���VS�<(c�@ˍ���;���{�]�k1�f
��>���=�������gb��y��$̓��^w��D���;���R�r��~rk6;ڗ>�:5��RH�����A��������i��g�P�qS̸�)�Jn����y��?V�%E��e��Fp�w�=Z2.V�Y�Ϙ��y��ٸ=ҵ�����c�0̐���oc��%��[��nw:����R]~�+��B�,�:�>�ʋ���+�����N�}7lt���)X����O��GuU����1��F�a#C�k�Z�boRV�	�d
?�\��}�7�����v�T��	`����v:r�r����",w�2uI��l�]ؽO�
�z�w�xl�|y�B�W 5�;[ �k��V�gũ�u�4c(�����7#^O�Ǉ=ʪ�ǃ	{��Ǟ�1>��B��D��>wW�Tȝ�s�"�j�Ӏ.�j��Cw���o`)-Dm݈������<�r+6��B���mO �bx k���q �N<�$��k@��^y<��g�Ώe����Y*KJ���赩��xpѳ5��R��ĳ�^�-�'+0��l��/8�aX�v��O�~���G�����sd[Ͽ����#Om@�������֦�M�>��ܝ��c�i�h0�4�MU�?�Ae��camc����5�#��?X���w��h�yC�`�} + �Vjp��)��t���->)�>s��04U>=Z	�v���	 �K#�>�c����ሊ4]$Q�V��p����Ř��~�`c���% �a_ 8��T#)������bk\�}���ύ�$��7[|�R��Ӄ�Y���;����r�y�����;|�{�PsH��Skd�R�}5f���'A1�Y� �/��v�C]n�%N�?�n��3��\XV�^������
߼dЪ�*	ZG�'
�]da��ͯOJ�������kX�c��
�c���wz+��9�Է��c��-�y�'2��x�p�e9#�a�m��T��Rz �0��XRA�B�K���q�g�S?Е<c��9�8>�UY=\M�n2�5&g/��Ё�?�l����6UY����U��X�bƥ���_xL��LdAL�{����s�my=�Z�h.u�?
�79.�(uc���9�n�{Y�T����{��Y�b�~^���긾�\��En¨����A�������,07��T8����qu��d�=J>{��+��췐�[|a��4u:=hY��j}�
�[c�n%9��ʞ1<��\��i2��w/�S��V
��G�!h�gN�`�҉:1�ד�ү�@*��\�g��\}iB?~�y��ʯ�G?(M�H���T���&I�;"�;-+�Wm���pAZ��:`o��=�`#�J4��,��6DOrc*�a    ��C%�stHw�	0b�����T*}=�)��T�`���n��?��g,5ю�noU��X��w��������LU��S8���s�u���?���P]��&hg�}�x~�;�=�Kyk�|�~b<�T>xU�ۚ>��H5���Q����D�'���u��U�:�>��Q�/s�¬	f��p|���-o���h�������HR	!ݿ����`ڄ�w���j(�<(�c����FAj�Ǳ���A�^����S���gQG �;�c�Y`�����E��t>��VT�щ��� ֣Wŵn۫�~���aX.�"�_��FT���U����fI��7f�!��EL�/���-����V��K��כ���PZ�ˠ0��8�uh���2���6h�
o��i����e]��|��y˯p�����MIr��I��[�
Ijv|���������6M�G4��,��eZV�^��w�oh����y�Ͱ���&���<�nÊj��1˒8K����l������y!a�`S�̢xI����y�->�m�pz;A%n�2� U�тE4s���{u:{�ZE�1"��#���7�<\\,-���[���8��W���BY�o�"�%"5~�/S1���ī��>�M`�Sa�����ww�Ƈ�ㆽ?x�f����uM���%Mbh T�����'ލ��`���Fjy7����`�pIG�3%��`�y�O B]�����zW��[|"�</��k�8�CG��W�bxc��R��%�Z���/͞I'��3������������J[3=��QXd����U�2�y�m$U	�w0�Ӱ�}�d�2Q�L�Uq�gq�F��A�^n0�Ľơ�R����b
nک!$`Nuly=Y�X���Q��ӂԦyR�R�F���|���2�HØ�<c�`ߢ�j�x��&y�R��8A�3Vi��g�â_����d�0�Π��@�鄙����Ҹj�Y�:��UiԶ��LI��cQi�`�n ���&�p��zl��gX��^d*��=� �U6'����.�ʘ�|;͸ŰQŚ��7�Rl:�����B�*$�'3�2�h�뒑HX�Dl��q�ٵ����xWnͨ�w_�_��,�㨪�	iV�f��汉�g�,��c��H{�V\ \�bL�.w<ߟx���ˆ8�B�,��sG��͌�P�&E�\�6�j8�X����+Y�'�t�u�Y����6#?��,Rq����i��g�Z�Ռ���"����%�;Xf�˝�7<��E蹜�Sx��Dq3	�y�v�Syx����D����F���	Ò�X*�GE�ͨ!�(�G�5���R�hE��0���]ʭ�ځR�t�%0'J�ZA����o�K&��5M�H��-�78yǶ+V�{J�X�X�:�䫚X�Z�É7$�O�T�֜s�D��Mf�8���X᧹�?2dڲ��A��� f+�'�fu��V|��l�8�EL� (Q9�>h1
X�d1t�THb}��uw8�
X���6�o�'Z�
��հ����a5h�� ��r�A��a��dW� ]�r(`p�tFď��_P�|vc][���Q�%��1 ��ێY4����!O�l��񈋾�G���+����.է؊֊��Dvϲ	�=��ۦ/*M�q�p�07u�ٚ((oӢ �8�m��ӯv��A>�7^P��49н�u���s@g���"����I�ٓS��m��JK�ä�}��%>2���~��h������JQ��fg����_�# ����Е���z��	�3?�I��T�ʈ �S�Ez1  �U��)��sE\y���붤�����A\�V+"���U�_�����7�]�ɑ�9�����-//��E�}B3J2�H~W���4��9�s^ua�N��*�Pw%�5�o�ރ�"R�l��80MF���t�'HB,�TmJ(TQ#o�V\�i%K�� %t;}�)�w85�A�>�U�vJ�ފ� �AҚY���4��0��.�_���V��Ic��ye[e3n^R�Ѩ�'ښ�R� �����3֑�uXJ�Q|���:Lq+�AK�_�������eQ`N�cݒF�s�cQ���.|{��w����TQ5=(A^d~1�kk7�*��"��-��r��c����X^��֢�M�x�;y�_�U��?�?Y(���!N2;���<H�V�LTۡ�"�������ݗ�y�!O��e���&��(�-V=ZY&&}�@u����m�*�V?z��da�Qq�X>���=�y�Ӡ���,ˣ���ފ�(��+m5��0��_�K���k��)���Ϫ�����A:}ȓ��������y�c{Di����wL��ι�Jg�Z��%�>��!|�7�C���w��j5�l�u�BHŨO��7	�!�Z+��w��O��[r��c�n'K/c�J#gV$+!�FU�����"b
Q7� *�ʠW��zo�d:���唴�@:��p�x81��g*�����#���̦a7��L����/Qѕy`�kʟ�=���n<�&N�t��L=݌����͚�)�VN�d-+�c��Qa|���4)���Dk+��W��'��<w�0�ܶS����TT�q+ŉ�.��� .*}鑭�>r�;�ǅ��ҿR�xw:�z��ƚiN��J��h�Y4����(��|��5Z*��C�Y��=�B���� jκ��pׂ�n�g�C�No����2G}�����r:��@LGH&�K��]�:���"m�p����p�潱�[������R��X�qD�Qϕx��ec��a���`"	��s�YI=�B�;v`9B�w������Z�R[��z?^+sq1�����U5A�ψYA������)����y/E��IG�= �p�bI�2-;��1K��<�9b% ��3[$��>F����񟬫^��\~�M�N�����ڮ�K��"��?}�K�,u;�x���KG/"��-�:�Ls�SZ&� ��E1�s8R���#��w^,��m�/��pƱJ�G�ܤ���c>�(D��gЪ,�	:������My��lx�I�\�xo��,��	��x�Y�n��b�?� ��Y�Ȅ���%Y�^ɞ� B}|۝�"�2!�\&�N6^-���$����%�S��A�8Ls����Ӳ���	9^ ��6������O��R�[�s�%o�R���Ӥ�~�8���<_aH�����Ye %r·cm�N�٢D$�
�9t^��,�T,/h&O�vi&�h��3��d8'�1�1N��ho��,�c>�Sjs���f�6�w��u�R�/O�2<o�V�����J��,^>��I��U`�^�9@2�l:�CQڣ�U������mBG��k;�G΋�>�LYYO�d�i�#�0X����,=�i��k��s|�C�X(���=�vo�+�1k�N �n%�W|8p��� ��:I�xz��Q�f��a�z{d�_+���zHĊ���Av�`6_�A����@}��R%m�����(fY�Բ�x�ʨ��W/��fj���� �s��|�d� E	�H8�άU����1��ڊ��~ ��n�XWaQ�8�E���&��� ˑ�Kt�?b�_��dVNA}����b-U�z־�X7�S���{���g�\v'����)�����MVfz9�gYP8��_E��4��ya0�7��������:�Jtn�� uhL��ѭ�6++�$j�s4�6���I���߄�O=�b%��X��ߞ6�y��կ6B!oLk@�:���C�4L�`��C:@/�>g�矧����թy�'F��6=)�&(��^~[�'�����6���m*�����ȓ�f�X�SPd�ϋ��=C��-pO��Kq����RҞ�d=�i)��J4<��:(�%���S��A���Fb+B�#��m"�ŉ��N�X��+_��)��J�c�����i��)l��ψl[�_��h��c�U���g���W2k��d��j�;HS:X@z4����� �����άx�sBe���7    �,�q�������$F8�[��>'>G�Q|�֩�������:ZK
���o���/#tA�>*�zѽ�&kߋ)�����t���;���[R	(� �+�`B�*��u�/;F��T�2���T�?�[�?snl� �LA�S��N�i��3)�++l��Z-#$S������6}� ������'>_A���EW�8�7�$��yI��(�:)��XC>8����E����q:e����iӴ�lg�eT�٥?K�XAco��� K�ڋ	����ґ���{g�𤙪�Nd�?�����	[�Te:=lE����L��)�ϘF7�o!8�o�"x����W�5hqp6�VӶ��]�������CݖaVL��T.#1�z�C3�jF%W'ʑ�WM��t����?�C�R���y*�-�����߽�������(ʧ4"�%B$	A���Ȩ4���|���V���&����fZ{=��n�����0L����x��K�6�FSJ=�5�	��
"�4
�s��m��3��IX8���V�M���dS�[+C.��X��ҩ�V�W��	�iȎ ��Q�M�6�z��yO\��g�8K�_�z��� �Q���Y,-�g1���S�9�e� �#����G����b`3�ZG7D����L^CB� s=i]��ŋ=6ܲ��;`&��X�}��s`T$�M-wI�:n���;�1"f�?�H>s1�(D5���6�<ujU��=e�j�������������V�E�Q"ϻ���D���I6'�J5a�|",�0I�p��L�ĩ�����T�◯S{l��㩬�s^B��a��-O��z?��4��v�GU�Ӄ�Ɖ3$�V��S��O�E��/��gu0�i��%�BCG?����<r�UWe%&1���2����Fy��p�T�gb0��b���O�~�Zo�X�":�B9���Ƣ�[��lj3�"�b���Z��R��
xq�'�**SO`����_L{TC~��\�a��T�R�f��ҸL��ʖ_��v�^�{�c��~�OB4�>0Œ�8՛���6���t������7�#�C?��P��*��LO�Ũ��rec���T)=����mz�����i/3#��r����o+�1'��4��3�t��쭇��_�~�`�	�R����F� �~I��u�<ۉ��dP|���BEwDQ;�	�4�.�a���"�a1ܼ/~���E�8�3�}x
1;�c�k����e�����!;�ˋ�ȵ#���cI?�Ͽ�w�����zY�HD[&���}Ce>`�[�Cm��x�,^�ڵ�a&��Wy������;k�-�얀	5Q�%��2~u�EL��M�ŉ��c�tT�B�dt�a�$y�!w,�9�w'�F��G���&�3��� ����"l��� $�^I�4<���䍷��\�w[t�L���$EZ��"��B��$/�����[��J66-K��YCf.����@���93�j�CZr�X�TaN��F\?qH8q���"]��#=*C6T�YA4�"^��n�Q&J�� H/PE��.Hi��0�2�Վn^*��%�����O�`]F��Bo��f�d���A�;k��{��*���J�%C�Z +���p9]+l�y�`�Vfd�Տ�'�]W���W�I��1�Uݴ���"�E�����q@Yș���u:as�vVbo�`]+�HB��eݳ*�<dГ��&���SU���7�0u#/*�q�mE<ɨ�e�.�+�B��Q����I�:ְ��7��j���c��+��_$�M��3�p�E�����<�z��7���P�F�TY q_̛$w ��E�x�"\��-E�DAbIB��*"_�x �!Õ�[�C�r��y����M޳75v�����l�<�S�j����LQ�g*2���&TAZ��[�-ev����4�������.��pJqH�>D�̮�ݓ&WOZ\��^Ч�h[3=٥a�\��+�1Sv|ό܃�c�xD+ �.pΠJ�
��c�c���l�9��R�a+��,	kGQ2}R��8#�O���oy�TY� >~@V�ݮ��-K&�G����W�M񴐝@�r��p�Ƥ���%K�GQZإSѭ�����@�XD�T쉮��~�f�u�z(��5$�b���uhȯ@�Ozs�;�Yj�q���5]����|ej-��.,3��~7�"63�~T���S�����W?ݽ��x��R�^k<XT�U-�C�/�����y���3�!I���d�%~�g���_!ע�����IS��m9���5��>1Pt�H�L]��+�,��&v�>i�y�/�� ~�������;@�\�Ζ�5S�� }OZz?s�R?��Aˀ���pPG�v��A����q5�v��<���RP���&"˃Q�"X��������^�ܽ�zk�ً�K�� ���6����"u��p��v���͏���cH�u�uL���>����/^얬VPL��t(DVQ8����O��$�����dJ^��]Ǻ�:����ŚK*�M0�Oʓ0NF��d�p`��a��Vǲ�$"�5������2�W���ł��i<�Z�Qꤞ+ׯ�{��ϗ�s?������]�7x|�*|��)�f���E��]�/|a��8%� � ��'���a;E ��Bc�����$�4�z�*��U�X��������ľ>��4���v��*����&��� �h��}��W=��,���+!�c�������8`W�y�3 ��-ԡ(��⒭����z�Ux�;����t�݅�q�b�{=�4�f�����yg��fh7��/���6O=��jO{j�}t�ٴy�=z�M���c�4���PX:����	Q���?�� ���?:�=eMb�:[��[�y�=���iᢺ�Z&\E�O^�R�b���r��7�4�U\6C�����!uu�a5��Kc�Xx������a��!��bi�4]$�����X�q��!��PEa�.J��>@�Z�5	6��U]Қ�!�c�Xl��:�<0ܢA
��=��z��aL�|+�?r��d��ŵ�!��`�E�lW[�ƴs꽚���y+�8l��A	�8�T�,[�_'�b��`٩K)baGl������MR��被���*�g�ZY���[$Ij5O�����΋�PT�0%�&幊����S���f`6K^1_���R�CQ���6E�푛��{��We]f�=�	z!�q�N|/�@���w�]�c��,���>aMݶ3b�ř%��_)I3֎u���Kj����:w�+E�1x�ۊ�G����b�Z重?�2~h�Ձ���j����� �\���ц���⻝���Ռ�����n0��9�W&�O,���ȪGTq�L�y�P����%HT���AY�_����sE����I�3��l���'����hŧ���w�ZD����>���8K� 靥�ӹ���M�h���0�� q�18^0��G��:7@@]kO/�o��Q����P5E8� �Y0JO���|Hh�æ�I�Cs���z�`���11&f��<M��e�z��͋.��(x��Uq����O����0Ǣz���}��i}`�d��<pĜ�"}�b|��W�~�L���Fs��gF��}ǖ����x�P���L&�s�#)�x��E~��b����U�ǖ�5%��L�-Lc��f��������։o�%pL0�gf�\�o1�Wu�3��E�d(V��6�jνx����*�I6$N�����[���&�p�#�
H��t�%����m]m==�q�&��_}�~��`�\����qe-�Fl���Q~���e�Vz\�1_1qd�c�5y����o$��|$h������V�GE�&�ﺦa�^`X��:�8�����{Ur �[t2YT Rj'9od��qK�&��f$q��-Z}b��E5�<�2�VSyGu`q8,�� ���O6����O�%�G1�O�^����H����
K#�D^ʻ�TE��    8�{���| ��9�A%IX?b}�SXk���$�\]�_�����w�bR(��q���Ӱ�]�q��!�t�|������Z�[�􉔩��u�.��&-&4֓��~q��7�|Ȇ�c7M�}����V�ߦl�OGn'���9cb�q��X"�`l[���(��}�*�l�-|����I���Ʉ�[�{�E��������#<���SO�`�='���W�N�	�z�������k�R'�����	�#��P>��8�I�{:�p�t������'���r��6q���������;��Ӗ���ӽ1;�=���@K2������J�T�U�2��s���3��iO?�i���O"[	���5d��25���]��Ū�-�=��Y~	(�Ѭ�-ByϜk��2�����,/������O�� ���
V�'Ղ*7��l ,NIԮ�_���Î%�~�I
����&�n,�wy���./��)f�,PtyE�f��jm:H�g{��zhU�����s�vu�	����8��K�=��מ1�l��>��EZ׊��q8z�Y��H�E7�ɧW�i%vȘ�^t7���0����� l'��٫~���N���%P;�K����"��t�'�]�U��dK	 ��\��(�{4fs��,~�v�V�6�Kg?e����?@; 5�/��`䃒���c�5�T��q4%:�م١*W�/P;@׃��*��q�\O�~�B������Q��pFP#s,�X�W�LY�?�F��*;`��G�g�;Ӛ2J�?V�ǡ������]����
�:%�Z�x�{����պ�I�g�Uea:�外!p�P��QNb�Ug[<Ԍ+k�p����(�0�	����P/�Qx�"�V�v@Ŧ.Ga;��:��R9����qVzr�K�
��z�D����^e\y�C��a�QF�I�?%�C�	B=�-�ƪ\�%�d���Q�d۳ѵ"��	��"�Sꘃ{N������^�zY��.�v��2����u��F����}|����a�_N�Q	_���E�A��l�i����n��2�v����37<m�����W���������=U��Ip��q��^�sנ:d?�����4�)OT՟���,&��CTFx��l_�T/-u,+?��lz�C�r�D�VT���X��>�z�R��X-+Ta"RF쇝J_��B�&�Vd�6<���i}�0�eMl�W�/m"��S���s7�zF�:��n���y'��o�8���� q%K��%�U[�?�qAC�%���w�K��Uৱ�~r�0I�q���B�K�hx?,/R�Nm���Q�P����y_������IK��}� ��o�Q���V,�a�Qv���c.q�|��������nW���1� JM4��-�$�Gs�,�l��[Y��m��,'u���� ��a��@s����6e�&+Ⱦ_ѱX ��(֊$�\�V\peqgEJعC����:F׬v-��_��z?q�.Z�bh�e�պ�i�t�}sSh�Lf��v��7��(�=����@��"f�����N���v���)��w`�B�έ��(��No���°*������������A�����W�{\�$ �^���6�_s?����M���GSid�	@⃂���Z◾����3���?'�"ֲ�ҫ�[Z�I�Ljଢ଼N�~�SX��J.�k,��I?�F?)�aX��"�L��8w�%�F�.s��Z���G$+�c�
X�iT*?����:t������bXmZN�aDIh7�vYqF0di��;��k������n;�8�Z��	R]�i>9H}n[�$��ʜ
ٴ(1;��@!_M�9�x���t��U4���6t�x�2�����ES0�����yss��!.ף�(E��`�<̻���k�� ld���*.d`�{��>��L��#}�:�M��N�=O��,ֲ�g˴�����y�����M0���^2�M��5S���29jaL��n�7���~�+K�/��ؠ@ƪ���}�+E�M�SA���2[����鲸S�C�)��V|�Z8%�Pw����K�����$�w�?M}bd�{�%�ReG����h�C��[&��2��m�
n�3
�Hb���:�W���b�1�C��+��b�b�QQ����S�/�)�}���>@�u���������3:��(`!�HX巟Т�D~8=�E�2�[��=�Y�vt@f#V��t��\�����#T��7X'�W���b�a�:=�a�n�`���(rΪ?�g�KV��t5��g�T��b����-����r���N_=��,�*β��3��[%���z�d�����(M�?a^�]>���"��z/�?G�9������h撍b&aɀB?��n#�U����ע�����6�z��F�s�z\�����a�ǟ��oa�|��o�^	/�{k�W����n��� u.�ZJ&rny�fcmF~S�E�7��<��+GqA�/;t]�_[S�bS�~UN�D���N��w!�d5��]	f�o�m�Q@4Y������՗�91��d4 ���{�?�3�d�9��mR�G�ڼL���ڬ}�ᎨF����a��)�Jm�P���P0�1�Wx"�^�S��_f��X$Fy�[<���~f=0�t�x鉡�+�/J�D���	L�S�у��)��W���w���:�k��m&��f�w�N�o�����7�2�,k?�'G3�(Ů�~c������>�%���N���i�<sx�03�8��4}'b��$�H�{��8 t��Х���G��!���������<E��]S����DYf�_�����S�A���}�Bcj�nE���L9�4j�'�ў�|��ʽRY�Vۚ7zy�<����Oo�z����Ir��o�\�2��" �d�k]�a�1o���c�%��]��,�������8���WpYf�]�2(�F��+3_��B�F�@AX�xe�hb��5�N�2X5�0.I� .��_�ޭ�ش\*����A&A�>�	�3�%����nd�HF��;(�ţ%�km_=x�S{#�U#&��4nEsec*��:]�CP�)B��U*zU8�\�Y���i����.�[���t��s%S�E*	I�ɨ&!8ԅU��Dl�$���2�By/�Y;ҍ���%:t]-m����1n?27J6ށz<z�r�g�6Ѳ�*�>Ϋ֞�3���؞9$�������'���\��鏅�p~����.>x:�8�7͚�	�F6&���w��2;���U�	wv �}�l}f���}��9ѹ jylM�� 9n=�7�&�Qل��xb��6o�Z���gL;��r	�j-?_D{ǂ��3
Z�=K�ꙏf�Q6}�������`���Q��8ʇ��*�*����^�+�ٴ�a��os���·��%����ƜZ�bzטEa����?+�^�����Ntʦ��]�慇ccT J_1�ip*xȗ�x�V�9}|��)oߟ^�fq�AG�z����̝�ը&��~3A�W�n˹zZ�|���7�� �G��gW�����Xd�� |I��p1-�ZZ��n,�PV�l\�:�,.5G��m��*��4}D˃>(H��10Va�4��$������2��4�����te�jECʍl�.j"k`s�p6(��J�b�8��#G�q,}�G�k�<Ӥ�ӟWJ'�2��
�V���{$ī�����������i���a^Y����*F'�|v�=]�y������N��~��b���ǻ��
����=1�A�Ȃ�L�`"����b�z��������Rȥ>�"t�hD��d�09��Ug�ys�'�+��"]$\y�'�K�"����s������Y�+��.C���lq�kWӛ�<Tu��x\�����No~����6:�)�yyR�r<5��""�0�Ƕ�7��f�����d��K�(s�2 d�"m  ����)\KI��	���l��u��tY:�u�h&��kqs�5!l���� ��
9�:�L�9��Bw�&��}��D��D    ya�:qm��Z�F�Ka�;���ȡ8��[hd��G�z����m?�9��q����XBi�<�Y Y0(aa)�Z6�1AV8ދ��O�=a�7�.�6�� 4=P���z��9�-����h�豠�9r0������u��3D�O��Ry��S���~`0W~��E�a9#�A���oC��_W-L�dĽv���o�ڳ���W����;!��#GŜ�X���M~�m�\�@�xXXQ�+�1A��#��t�و���z\Q�Qº7#uF��#�2�K�v���ʪ$�Z�P���τ���PSj� ���X-�rc7(\�OFc�oGK6��.r?k��»�;����I�x��<p�X���O����, v��ӥ]�M�Pi�l�AE}���m�=�������C�A�[����W^�Ϋ����V>�S*�Ÿ
�,��g��~���2.`.���<���i^E�~Pa��<�Ay]>�^��&1���I9Q���0�FJ���-�1]17Cy�k:��I�4�*��jn�f�l��2
�p�8�M^�8�Q�v���Y�0>���,���v�G젾�t�U���m��-��:0���$I�4z�ze���*u��@�`JˉcY�;�7��6�Ԧ���������kO�����-���/O�z�;m�V�8�Y�L����Z5;��V����rBU��!<�be�,��S�E��������pz�r
Vn�/A��=�Z,E��[�4�Ϣ����et��g�	�z�&Q)�[>�rHD�y��|7eqz,B�G܈�ct����ގ�u*��Wb
�,?�mxm'�B��1��TiC��{�Ov)S!&w��m �c�뿔nu.6�x��bo��T<Z	ȭ@n�	R����{Y}���l�\'�k���=�����Kܷ�P�3g�'te�F�D^߃
u�ٓB�ݜ�;`8^�â�w��C�DK�B����HPv�ʓO����b7!��3ޘ"�
7��4�J�&�~���V��� ��_��h �کN�Mq�� �~�q�P�ٌ�;����X�h���=W|UmE���3�,LE��XY�����"f�AZ��������$E�Ng��E��6��tFlZ�+�յ�`U��c��
��#��p+Syg�4օ��x+Q=S:�ޜP�-!��,76�r�a��0/F�E�7���Ӡv��>Z�׊��O�����,�"�E"Vߟ^�Py7ڿE+FU�A�")������2��U'S fi�ަX3�m��]���d��Mf�1�G�]�zϐ�K�!�^/٭���j���b�*#V;of,ß�
1�~L���-�4I{�E�	5+qg04��tPz	����D���R�����|F��7�*~��Po$~��<�ꃖ�Z~��Mډ���8,�p}�/��s�(�O��rV�Z�n��R���U����(��b��fa�N���(���)��E����۴��jy��,nG��*��{��$���%���z8B�Ŧ���G}a��O_��;��� �c.R���1�i�s.7��]�����E^��6;֨9�Eg�Q3FP����n%n;���r'>��fA*o+ϋwnұ���
��g5��P�s��YJ�L@��u+����w J��3nɤ��խ�&����4O��	��@�ۖ�ԍK��ZU�t��5�v��/f��=�$���(�g��O�pr�<��*�EC�yn$C)�R��3m���r`�v�j�ߪ�`����/��.	R���eC7_�[<���+I�d�njޝճ���������^�d~65����P[�q[����IXX Y�^�)�HG_��`��|GfY�*n��?��UX���%H���C��>�cF���`�(�͗�u�R6��Fb�F<?%�sbu1/�JW��]��c���~���}��W��xA�MO�i�'A�v��XG��j) ���7�X`"�f4���bT���@���/�l���(��n��(��@FZzL�>���]E�Ef��R�]%f;�����/��
����He���I���*�	nW��Dy� �/��<Ym ���3#��/�yX�c�B��R���Pz���J�)��羺!}A��5K�$q������T�:��Udk��e^�r.�kh�bEi���O��y��V$Q=�&�C�R#	`��r��MzE>x`s�ڀ!l�S��@@���˻�q^���Eo���&�^deE��Nl�#;�v�l=q9��Sre_{*V��;�Vl��Q>��z�Cf�jT#���ʤ�bV�DD��y����@��h`m���PM0��a��#\ɼ���Z�0��u��J�6���yL�E��)W������7�y�=�+�\���v�1mO�LY�R�[3>-,a�/��ʂ�P���丰a	�sDI��_��Y�Ne��8Ul��5ax��J�OD���� n��D�(c�X� >;��)� �`�
&�
mh<g
{<��[<����Jq��ZB���j�	1vb���h��ZT�C��G�D'Oț�uqo����R�� 0@�Y8ZX�&N���t�b`�H���t���]�xץj�lc]G��VY�F��D��~��G�4�d��XRhy؊P ���f�i��罩Q[3�&]�$q���lE�H�ᕶ��=OU�_�8+�`z�S�ɸ���Yd!�2�Qe��
�=��l���ň�k�ZVl�+��*M�d��J��I�ox�z��d��z8�o:�ϣ�b��J3[%'���@���o�=ԝ�	��c�S����C�~�����`h�c)�����AYx�I8�[�&����������>�DQ��&�K�6�_ʡ���~�6h\a���H͍k��ƛ¶��	�y��:�����{�T��KgWVց���V�b��8�Q�����ot��c�7���?E��w]����Q������ M�x��}�X��Gr���ʔ35�\�� 7�vw85�e��V;�nq��$�jf�Ɵ�b68O���|3���Ģ'o�����bz��t�;��֔��\b�������?v�L�Ղncս����b%� �f)#��88}c
�3t;�+ٟy�e� �o��}跖�P��|��� )�(�N���N���{�jdgc��V�ƸpIa��������>��ۥ��&�=�1@:�'?�D��t>O�ت��h��K�ai ;�h��b�8��$�����Rr"�2��f
�-���h����cT�{^�8ϝ�e(0�hc��_�����E�w����A�u�%�8R��a5 }�E��34�d��3vv�	�@w�5
a_BQ.��j��*"Y��J�d�C�X���zN��0ʜB���=��­%��'t�p5�\��X��$Eؔӣ����g�7���%`�5��.�c�H����7��Ҧ�������������OB�RD~�������%����?g|#�@����uɟ��������V�n'��x[f�N�غ�1��'i���Q[��r���
�d�<����{x��X�(���>��9��˨3ۜˇ��ηl�$���C���S�d����>�3#��S���?����'��h���6�m/���㫮h"�I����p�g�*������c?�sH������!�{����_�%�0 pD����	Nl��r��&�7�.�Y0C� (��EL-��>�]�a�:殰p�;O�t~8n��t�����<���{�QҳȪ5���6��0��}߱��+�=iQ�I%b[iﭛ��q�j���;���:5qV�YH�|7?�� ��DA՟J�g�f���i�e���F�԰������&�7�g��M�q���4�
�8�٠�3���g��PֻbJQ��J���}E���ܦ�n��}k���\,�q���A�Ǝ<��f��ޗt?����C�����{:7����b}��A�N����d�"���c=�����#VZyR鸼V��    M]�X�Mg �9�-6YW<�E#�T�� .fD�H���>T3�֗��V~�܉��(L"��a^(��G�Bp����������}s��CuV5M4����,O#Ǿ��X<���A�Z�hHe�$̝����у5�k��MF��m;=�E!Ȁ�h���Ҁ�>���X2��Nz� �����R�θ�'����!���y�L/S�(�-�%(V*T��6��;�;l:O�d�[�i"9yf�I[N�R_�E���b�.�9�(NK���k뱷�f'����D0����`s݃���\�'[�I�t�H#7��ȣ�g�۔�V�X#��an&j���x�������G{�o�!7�B�I\esTdQ��!/��i�rЛyM�����y5����x���V?󔎧c�l��H�Xn�{��:��(��P|zD �8*���?r�#��N�t�H)R��h�x��X.�n�v*g�͟�CT��a��5��J3>�3�7q����3�鱊G����2#��~�hy;9U�������<L�DF}�4$���>��F��U߈h3�5��֪�h�Z;��Ĺh��w�(��:���W�'#LT��i{O��=/��i=|v��L�L��1pm��G����)`�9#�Y�q�l�v  9B��nl=t��l�l�_��+n� Wp����M�b]Z������u�~�t����d��9uç�{���Rg�D!bQʫh��S˭q�K�gH��rwb`��/	rS �wL[��P�%̰���(���ô���~a�e~�Xx�Ԕӗ�i�'��S�:H՝muc�CJ�b�֔��N�!��a��m�]�s�'j����6��H��"h��b�N�8b��QR����'����
���{/Pj;�bA�Y�:O�W��"�*[�L?�Yd�#�H�5�5� X%[�YGKE_��Nx��~�U�g�YR�A`�'��Y��rl��t��2�Y�ND�A��|aN�,x�Ei�ɐV7.�n��Đ%U����,��|��K�"v~99��\CM4/�_�0-�T\�t�d�	�ǃ�:��p,|Dd��'�by~�����fU�_e4ù�����RW@��kU��gb�<�b����NC[�U
r���7
�v����(�ʴGB��(�GL݄���w3������_�llT[2y���k,����S)<������`�Ũ�>���'V*u��]��W����f��錣	e�z���o����T�G�w�~c���s�DƝa��x�2�~�G�.J3c�C�i�G�����ӁW^jˍ>�[R��d�@!I]0�������r��+��M��*���/m�Q�X('A����f���,���?�m�.}ZY��zy�-gl��Д�6:bg^u�ܐ�1�=v9ÿ���f(b?	��^y�$V=V��ۇ��~�p`�6	�1��� %�|���N�g�ȒhD�H��*�fgM�X&����N �n�z�M��|��.	x* HP�K��1����b{�� L�+�by=�a�"`�s��DЕ�}")2LNc{����[���.��=�%� �U\�;�������'��%�
������(Z��*��:�e#ł�t(�-x��/�8@/	_ 
ibVnIlL%@Ou����:?ɬo�u�p<\�l�z�~K\�^��l(i��S}��9�j(��	*LX^�����/K�RMYf��4F�xf9<A��+�{��nԨi�Hz�|�|�&���<��3�V�L/Q��l#�n�)���:L�@��Wc5�wV�z Ϫ)H�
�j|	;[���fF؊ ��j����((�G����N��j�!3F�Q���5|f�i�R%��LM����	�4|����K�-,�J�W��C���5r�HW�IY����
O�$��s�:�&��P��(��A�r�x�-�~|冁�N�K�eiB.ps"��}tU��*p?���k�[�9�q��3�Z�'w@�_%�9� �IV�$�@��7g����%u��He�ԓ#DA�Y�BV.���Q����C�U�m�y>#��=	�?�BJ�ޔ�V7KN���y��X�����e�����<w�Zߟ��NAz���q��o������9M��	糺S\k�#z��3���I:����2��	����\���V���1�����̅e��ţd�&4�~���\�@5ULO���8�S�Al1� m�0ʮs�5O����h�4^"�m���|:4N��s���T'	����&	{S���ۑ���๺������*�_��;�t����*��'-�c�����I���ߍ���c��f��=��=�Fj/�w�H����Ίa���[��-���7�?#zy�*�k]�P��Ey�&&p��T�/�뽒}Z�Zl��Q���b�6���Ft�Ya���K����]����J ��e~$�-
��;�d��{m����&F(�1��yx�C3>�JxcΞ���#��;�8�
;��R�tj����x�	��W�ML���N?5u%�iٷ�_��y,~UOvO��E�[8��_x�U���vE,T<:k����6��K�[�Ħ���렼��*3D��ն��%���Q��8�i\$�}q��k��e�om�ۓl�J(�}t��z`2� ���y,1�u�0���z��i�r�ʛB8f������~*��9�}J���[�A�%U&�e�LkTAg���"
�ԧ,��Y���|�WkSf�pN[�wڪ,R]N��L��c�W$��DE��p�8|{N����%T�Q�l��g?�Q53`�����^؁�e�/ּN�}r�I��Ԙ;�|���"]�	����jɫ�T��bST��H�_�"[��j�4�A�� rh����?\�����]�Y j=��W�%V�~�H��(*���ڍ̡�~a�g�Ī����Z�����[������T!e��ϳG�ɲ��?�$��y�p��Ժ��r��(�W�>�N�{ �y�2{@���������fτ�Y��Oi���"!5UUO��Q��SR]`��Y ��{P�T^3����ܯA���h�yY8χ^T�,��V�٨�����K���ȷx�E��Rg&��"���`�:<�J��o�>�RFއ-ꮲ¬CdC��aO�RXA$�xw0LO�B-�S,vܲ:�Q|�A�ǣ/������ä+�Y-k��!�䬐�.�L�^k=֐B���~
��K����jz/'@]�Wө��:��U/aqH�isE��9�Y���:3K��n��+�K
K��{[���(������j��d`ڬ�L���E��� XDJ��fA�ee����<'�1e��zb�����aV7=PY�]�*��r�j�Q'\$NOLPz(���*�x��4H���U�a�;����OA���e�[�
����+�J��q���ჹ�aqa;�eTbU6<0b�j��*.�cw��kp�-N݊�~lH�oCF�[�e��%�����IJX�Wє-E�_
�˷�1�_��b�����S���n�=[��07]��?=�iZ�z�Sbs j�����1�2���[�p��v���B����r�E\���76���rЗwR��>�e�Z>W�)���w�v���~�\�Y2�����z�,_I�,�^�:���U>��q��8�7��=�u��}�y�ٸ�m��ڣ�ki���O�q��dgk�h�������x﹏�gi�쇶
3��J?O�y!Q��;>���-k%I�\��/�j������/�$�Q��i��a�z4��L!�3?:Z�O�������]G�**C��.��+(%�B���dZ=t("c҅Ӆ��(������o�!�wH(:�c	y��������(���\�H�T=؏U�����|m&B����y~����	�3�b2����k����"�g<�tp��(����΢N=� Z>([������ݴ�6?oRT�@�AW2B��
UT��9�E��Z2B=��{t�r�6$B��ޠ'[�u@��pG���T��6��#�e�h�^[Ia�����d�wpZ����jv��Bt'_�����0�c� �/9D
�ʸE    ;a�/]���{A<W�W�?�G�o1B�g���tW���ʁDlJ~b�8oe{duY����ԆD�_�k��%��R��*+�hz��E�s���ϼ�FY�W�V�|{e3�ǁ����͆̔\v`��o��S-�2h���,��v�%Jn[N��*�yp*p%�S{�td8��v5���*>����!w���=$�nLi��5+a9�qQ�5�P*�o�M��K�n-?L�S�dp�b5���Gڜ��*���� P:+5�}��bŎ(a�w��r�P���-R� �)e��|�� �&Ƃ[%�_̣���6�c^�P�����$3���t�(C���* jw�
�hz�� �5�ki�$���Ks�I�f��e�5�V��ב[(H���0fp3L:����A'ӻ��H�4�T8$!�Ɔ�P@0������r�ܮ����1[�S���l�δ��L��~��KV������U��Z��'���v+����~��5?6��c��l:I魝���PIe�C�{4�\��,���T�����5ty��f�������W�3αD�l�y �vC1��u$32�b:E��?��X��LM��W�l&:N��=�t9T^B2���gvW��(���� ڱ�=�Ii��CD]j�w!� ����^�TS�[�u�V��F÷�*ԉ	��lm"�ؑ�������t ��)���FR�̓��P���瘣��8~1����u.:���Ew�:�.�$����IZץ(X}D��f��U�`
2�΍U��������uU%��T�ң��n�ީ��l��|��Pb4������;X�G1Y�ۍI�8���2JM
���7����L^�-`�� ��������Tܶ3bP���E�����l�ҿXnkCr��.���V�_��'�+nq�����M�N�����G��gm�طzp_����c�%��u�Oo٢�]/��2 �HxqO�� G�П<\[
j|���֏cӤS[��.M��r��b��VU�M�I&� ���ate��h�����y+�o��ԥN�Y��Q�b�7���j[Z��c��Z�w� ��oA�Ȋ4���iG�>X���O����Oz����#>��{q���x�cI�3(7x���LD�n�+�rsgH�z�¶J�	�KH �W�rz�s�C_w��].E���{��ˣIˆw����7(���<j	�����gQ�,�w�[,ٞUR�RE��'����V��d(�Wd�l�
��`t��lW%���a�@���'ŗ��0�|""��=����_��$L'� Q�"������5l�I �U�nwR�j��Z��*�`�U��xE:�i8�tEEd=|�b%�����cmQc텛��0Oӹ)�[��v�7�IB�W�����J�����E`&s&��J�z������i��.�Hε�X;Q�+/���k�z���/Z���KC,�����U���;4S�~3#�)��JC�������1��.B����m�;���B����z�;�j������v ������P�R�ȍE[��8\}8�x��&0c-y��U���~����|#� �څ,�/����qSL��aQ*�"�V������ןG`�+����f&VQ����J�ग़�"l#������a*���1���ǫ7�0U�K̢��D��U���H�<:�~M\�Kv���	F�;T����],�Efz �(�؉Eu�Y���ȏ
[�:>����W�}ud�� g�ؕ~/�>kh�K�����.�̷�/]�������S�#�)y� ko1��� R�n��aL�r[m�����Q�~ʳrFL#?��-q�zS����Fr���U��� 1e0�u�Ԋ(���=\�G�����[,�j��C4P�=*dl��, 3D��1r������V��3=l�5�����j��RFW�J���:	28[QI�RWn�q�7z��\~��=��M2�D�0���%�X���E¿pd�\�^!��l���ŠUE��"f�j��V~�q��D%	�:DTG����=Fvht�U����4�.�0����;�i�\�u���]
F�ze��KzS��a��q��m�v��ZD�Q�`Iq����btH1��DP��T:Ip���VP֓]F)Za�Xg�$�q���!�� ^N���踰ͅ@R'KAo�����m1c^�dka�ī����G��t���T��i�D!^�3c[��B6�	sB�1�U�����HG4����@��Uc�������n�ꘫ���	藺��Mk�8߰���A�ry�0[PD����>a!������U��w�f�>�3z���Zl�c³
�ب�a�cd��p*_(�G_����i�-c_�'�.=��ڰ�^�2F� z�e.���؅ےD�������:�^�Dt�<A�������q�Oخ	��n�q��(���Â2��!Ɋ8�ҁ�G�/���'Cn�����"�m`�:��B+q��{���a	��rm��(�7�?� ב��?�� ��$�7��Cd�ၠ�g��6������)A���6�<��8�m���[�8�����9���5�U�q���N��;�HYA�c�'��R��[��~�Q3}(�ut�b�7�7e9ttXe��n��G8���d2هV��C�/<8H�۟��?��l7n$���[�$#8]z���r�O��F��(e+3���*������~�� �3t�`��Έ��Ҽ������q�UB��WQ+�z��-:T"�&�[?m��5-�m���/����}뿗iW�W,޲8�}I�'�P�F��Þ��.D[�ʷ��̙���.�����1BJ��O�z��`�byΒ"���<�h�LZC�pX��ԙ� >ֻaR!%T�i.L��SClҶ�wk���_��&R>hݺ-w�8�'������&��u�vHF��.��	[���@��A�>�џBj�(崥��P��o~�/�m�.BY��1�&sw��]�&�˲.�f�Ҍ.�e���kV���#Ϣ?sA ��r��'E?~?�umd�#����Y�dA��sP}w���6|�4�j׾>sm[�-/��8+<u4��~|�2�f��$�N��
F�߸�о��@�툀]����B̆;�8�$���s���m��MrEE��'��"z/#� p��I��t/؃��a�7QT�!bM&����Cj�z�y+J�
pt���Y��);O��2�,�H��]�!f�/'���}7����b@��b�;�v���E[4�Y���"/
[Go��\|��+�g/>�5�Q�e[����^��� R$��<�U�"|2�0��~��eC��?=�B��4=��M�YF3�&�[k���$+�4>���0����J"r�0CW$o���x�'e���%����R��L0O���H5=��Ӥ�v�ư��n ��}���x��ʓ�V���*��U�eD��?:yQ �Ug�/� �퉇`�n$������'R�����ǋ;�E|w�7E��,*�\�]L�B�[�;�(-2X�zJ����*�a63C��V�ݎ���5��@�҃}}�qw���(�ORH7�?pK�
 z�;J%lޱ ���G"&���2]VΒ&��!
�Z_�6�۶SWr���J��.�믬��5���ȫ�ۥY4�|�ͺG���}KH�~���B��D�}�6�ǃ�����Z7��`r#P����81<��t���8����'^��[,�L�!�8BC�2Ş�{�ྶ�x�.��K��
�A��;���� R�vPO��&n��FD�N~��Y�h���W(��
�<�ɖ[%%�RB�Z��ve{8Ph�-jR҆��/�8��WV��ہϭ;�v�讬H�+�6���P3��ۺy��4�v�uā�hR�����)����_��L��uQ��K>���0��܋Q��d��M�W�w��,e���=^���\��4e]����2Mb��2���ѻ�n旹�sx����"r��lHjsED��ʺN*���^�ᢷ���u+B}��n�(�.�2    �y<\���.��3����^��q����V�\�"PB,S�_]"���ɮv�[���]�t���P�i�3���DM���*ft��]�~�~_�I�y���a��&GF���X�X�����5����<���@�{�����;���� Q�u|�1�#��(r��I�v 红���[-nxh����}j�t��j��#�g1�T
oe�ɔ@�����鐖r>0���{.�"��Պ��)��o����^���`��I9���_Pw4����޹ÿ��./��)Yf�/��tV:��o{���d\�@�Rݺ�UX����Ȼ����*Wn����^��Ĝ�
<}�zϱ2p����	@]2� V�j2֩+�b�v��!.��\1�lUM���~� o�ז�'
���U�.��ծ���x�N�}>�C��|�w�#��'x �A��#�B��u���i�{R��O
0���g��o1�#'�K]i�I�jrX�m������b�,������B�q�WuB�Ͻ<4^��^������pr)�$2Їi �3���C	1�Ƶ�2GY� ��?!<�'��@a=�Î�"���Y~.�4��P�IJ�Y�Mz��
/	#ݦ2�����P�y[^��U��48�+�\����/�8OB�z��1�Ѝ�$�C�m���)	5h$÷�k+���T��Z�G��ծ���u�p�L �u!?-�8��'��[j�>D�SƌǙm���R	�bR5޼?�3/�L}%���ȹ&��6þ�I��E�!�3a�h�p��&�1o�>�;n&���CPmA�N�! 4�"���A�E׶��)r�O�*�@���*�	�Z��T�cA'r�.$���"eR5���� b㛴�A�\�����c��)m�
�@��%(,%T
��c����Ϝk��OJS'�,&Ҳ�>��)\�yO���ҫZT�nq��ũ���V\�\�*kt�S��/d��u�淌|�u�"s�в��vyd�y��*�ޡ��DV�P�=bOW_g57�f�w�7]`��.�*���A��^�*�Rbs���������?p�L�������L��-�m2�WB^e�D�J$T0����!s��⓮[�}��~��T[��F��I:ݠHN냰�>�V��L�賷F�,��D�NY�-!��H�8��ɗ�����Y?+�*��Z�4.�`��E�cb!�w[�%������Ҫ3ApD ~��9:",3�ҝ�{h�#�Y�v�nY�^��_���E�ߺ<z���������V{�RW�$3�m��󓸰l���m�g���~�T�E0ˍW���苧����;�V�pB'�-%��,U<� �
:>Sk6�n �Y���K���S�>S�����G�k.O#�\�����@�*#4�'���йL�~���Dۛ�s�����C_Ӳ������dC64Jrԏ~'g�����r���i��R����%�����o��<��	�*��[ź�����R�}Ϭ۾�2����%#Z�l>��?{G�_����U���jH��ͤ��z%q��ǧ��	��i��^�|����z�l�~��?��o�iV7y��WĬ���k�N�^AP{* �[��}P��2*Y�D�;�m��1�TY�#e�ot(Aa'S܀�t�k��$FhR F7 Rɐ.��Lf+o��6�(߃�Q��a?��T|7
n�"#��u��S���_�Ԛ܄M_g�?�tW?}&������ S����]�z�=O�6n�jO� JȔ�.D̫�@��@1���Cl���V4}�ܢ=�%§���7���������ʮ|wH�T��~�(+]�_����{���v���55ܙ���D>��F��g�~�`�'Ղ�3~�B��'q�&��G��(|�9`�W���v���v����V�	��q}�bt��n�����<CK��~XCS%�o�T.?���g���)�;A6'�c*��ѕ�\��W�e ���pN�4D�!�3_���iM���ᴱIB]x�i��p�����h�ci���j=�߫���\�.��/fd=8aR8�����q~E�b�,�C��"���05;H>|'K��젇B�}Ħ\?��M�$]�آL�^���ge!D��dPDAr�U����9)�M�dZ��QB,�(���˦�xt�q�֏�o�4%Ѳ0i�#�D�����vJ�M��?�+
�<���%�����6ob�|R��eQ���
�����	�)��!�����Kė�u�/�+���7mKך����A�7I��.8�˨�k�Oz'`3lY;�$������6��=3&����F��� �y3 ��f_ǟ\���� ��.o��UG���	�I�E_ǑrӋ=A���
�)Қ�mގyŻ:ȱ5�D����M��U�W������I�%�T"٬�W�Q,A0 �oh�1�zO�tG��g�r�t�C�(f�G=t���˟�<��<��"zW�^�XT"���R���SY�RV:p4^ڗ!`7 ���^�qͭ�U8v�Q�o���T+��X��/�8;E�V!VZg��K6ΪЁF5\��ʹl��}C��?�=�v�KҼ,�Pa�q����1?�l��>�iE�	^���w�/O�ERa��&�8��)r�X{�A"?��h��^X�4��dsAO���_`�ef���]�i ��2����p�B��s���@�Ў�P�^O�s͐����w�\9����@�d �y�}};���w����c���D�F�o���o�h�0�y��H<o���V�����b9�=@`.�_�2؅C4�x����M��(+�</�M���;p�(�G�O�;���I�=�QY�0�h����2b%�
i�����!w@{��3X6����#z|��$��R[�����y�Qd��h�΄%�	^��;4� ���r͍?��*��Ql��Z�*�@��f�Q�ҎTL�ٛ\]?c�D�AX �?�����
U��3�5�p���� -�7Ұ����I���ߐ֥��fWE�}��4�ܦ�B�>C7j��xRQ��P$խCJ�ݢ�����-4���
@���h�"������V.l:\1q�&�d#�<�5p(���u������9oZ ��ك����l��ʯ9�>� ��4[?q(��
�H�}2S�B`�J���1��P�8����g}��2���
U���?���w<>#�7��j[^��6��$i�������^�$ �p�	��2A�l�O���i�/b�2�L��U���3Р��'�&9t����_^�el��b���8����b�WVY�v���=�מ�L�+*D]?(��g+�����%����I|��Ti����z��j�X�$N��l^�Ɔ:�$�7�
�n��^�0H���,(����"z��%��U�'���&� ��bL��YV��#_^�W�M��g��iE��R��͵���2���VƸ�aP"�x�V
�t.�ₑ��i��^��:A���ˏ�:m��˶'q9�|yz��I�Ki�����h��N�C����h��OA�G_��/��L}A��l�6�Db�������Re�"ŸZ>�V`�+2��S��Yݹ��^��I��su�4вǇ�$�-�0��=�COl
u����3�m}��-�"�#}�G����H��NO�k��p]4jN$��Zԝ|�xS�����I���]��Ue��~�m
��5�e�k��.�H��dջ,��z$Xtp�-!�'�|�;����ŘvH�ċ&����|���A�B�y�M��뿂I��KU!w��V�Tћ�|O{����Q�8�l��7�_&%Ii{E���V|�l}'뺚�#���;6 �����NN��HU�K��4I�<RYؿM�/L��1�CfM gO�h�o.J� \v<�hM�oc��U�d��"V��!V���� �?����"x���Ĩ��� �&��%IWf�^������X�)l�3���B��I�5Q��k:+��{cyD�z�4)�f��JbS�p�l��g&9Х��    �ly�jw�x�@�u�tGفeF	I]�`�d�0m�tyѐ�ߘ���f����[���+(���:�B�]��m��l�6B��U��m�����գ�9��lv��뢸�v�6	[D�tk9zWǠKP�
�6�+��H�"g���w����3~B�~�B!g�ģ��~���m2,�u���h�2ZsM$����.D	��*���B�S[�@���4�˭�L� �����V=����$J�_dۯ6!�����>��7ㄲA[�kz�zō�S�!��-W��L\k��/^�^4/�����,2"�#�hɗ^��>�����
VT��ل��-��@�y�\Y�DɎGMj��yV4�V��*�p;�e���!��o�M�5��)3��qM�4��t0���/���7�V	0������3��l����V.3.�X�ƙ��d�b��U�Ӌ�b�������Q�j��L�n�ۼ�m�!��W ����Y�i��.�g�"�B��l��ʮ�%�����R�S�m�V��o��;�J��)�q̳��
Ӕ �U���կ���A�kYx��$ˢ?)��DeϬE�v�G�R�\��X���`���51C54�Gh&N��.���'��Ul�x��5E���Y���gd��#8�����I��)\�d���3h'���͗�vbm�2���dL��b���,_nm�_1�7&+�P���=YErl�)f*ĵqv�n��q���� �C���o����<�:+֟Smޚz�4T����*o�8q�i0
��LK$e��{�K~�?D
H�R~M���>������Hl]e��^�&�&��%V���b2fq���� 	��R�����9��� �E����g*�LŅ.���^��T*Ε��y7��O��8!`������������f ��#�
��I��D<^��U3B����nL|(�0��z�q`���g�ˣ����>=�*�녂#t3�e�����T��a{tW��2�=�I�����_1pڞ��#SA����F�?Y�x���B��Ԇs<��p`&zK�#f�%ނ�7׽�O�Q��<(סغ;\���{\�f�Z�ϯ�4���g^N4�����_Z���QE��kɤ�%+"�0Y=����U�/��m�fa���r�#����X��Z���E	�����]������cm���:��ˠ��*�aP���H�Y?���]/���ܕZ!6����O�sl��K�+n*�����{�i?����Ri�RF���ũ+�%�;�5������
c�.�"� ��Ga��K/X}t��\XX;�q
��KX�dLĶ^�'���~&x6{��QP}��K@��ɯQC�	�F>��ݗ�[����/� ���x�ңi��8�V]�V�thw��P8���%�P9_��Z��}v�$ƺ���K�G�3*@W��9�za�V��w2��%��_s-���&��4ī���l���?�������Z�ݾ|���#�`�2��˳e�Ŕ-�胼�^[����!��Hp�M^V���Y����yy�h��58@����p��yf��p9(���ǌHE���b�ge�-�@e�ʽ�OR��=�=��Fm��5dV�8�Ȣ��y�p�߷�}�ib�Wal��"��
���Ќ���KUP~Ik��,�����{����u-�P�t����\n��5q�^�Y:�67�-p-���Ԁ8�ĸ}���y�t��Q8�:���Z�eտD�4�M������|�+��(?X)L�'�$b� !��>��L��lD���Y���i�]q�s�%a�^�荇����H�)"·��.}�x|�(�� >'��=��q<>Ԯ�Vr��"��ؚ���
���-w�c��*���H��h�V�`�gaOn�P�U=�7��:|(�Q�<���m@�Ǯ�ʣ�i��L3���H�p7�eV��ܻ�=Q��.�7��/�ؖ�U^�B�4��C���e�wLr�]?5���
,b�	稌�z&����\��x�2������"z��]�#Y�˟�"͂�LRT���A�����"��ݦ�Ay�C
h��'��Å[�g�k`�ؕ������˳�L4�2��q~>h���E��2��6��¹��e=�����E����
��	�E
 ��`�_y-)m�tW\��TAסL��������#��SSF���#U���"
U�te�F��a�[0?Ĺ�l�} �n<��E�n��RmE�^�y����~d\��!Q(h�,DgNN��d}�sy2X��E�n �V%qq��*M�ʪ����rV�8���#�&yS?L�U"l�	^�CxX!���ro{�WD̚���"�  �F��������(^����9C4C����~U���}l��!�� �<�ӛ�x���Y��bA45�j�z���
�}	�W��R*���6Poe`Ih��k"
e��:o:"��'*�@�����UZ��Tc��/�]�OJ���y�=`�(������<{�ӹS��'�ϣ��3ΐj��Vl�6u�����z@,�d�?�غ`E� ^�/���� ���� ��U�X[�eE�=��A��2�����[��k?'U��W<�U�da�Z��Rpz�^��6�4��ܷ[d8`��h��h�Q^M�;x����0�v�R��-@]�A��>ւw�ч�W��n�Ez!~�B�j�jL3yWʅVw�~Q!x�e�@:��[-���j�ރ��G�PC��#~#�����A��|��`���d"���?�(�������c��T�BV�[3�Ow0���[1p��t�̽�dRAuQ���۶'u�vWd���iqYB�{nE�yLЈ�� �F�~�Jm��Z��U��lGB����;x�}�* 
�]��|��"�!
��$�͹/x�c�6��)���
��T��F�*���L�
n��*�G�j'��{/� �G�<Qm����V2	��i�L^Wysٻ�l��Uꊻ��ܹ��W;��W<���O�N.��=%�?I3��0W%�g����6m�=[��KQê*��vFu��/'U��zf@�l�O�w���� ���d����?�s�AwM@HU1���cۣ`�]��S���4�,��]��NE]xd�\�s6"{��ل-r�nĔ8�M����Y����!�M�Y^�2Y�l���r�?Wf�ߞT&�����ƭ�O�	u3��������(L{߇0j�@�1�v'~�{�z0f�a#iҲ���Ҵ��RG�6j���|$�M������03��h�Uf�Ô&�Ŝ-@k�,$�,�� s���	8�Y�����Ƞ����1��_�4ig�+b��e��'U���Oo#(I����Zi#��&h@ꈗ��˔Lc�@PN+E�x���yD+[�g��@jt��w{�Э��?�m����x�ʪ�å+���ӑ�*ŜRz�$�&�^k�*֯��TYޔ˃U��	�[}Cᅘ�zW�l�2��o�@����z+�"xO�'�v�M��}S��.N�@U����4���.�f�ıG'�&�>�NHP���"�?�UC�U�-���s�)������xyY��DOZ����NM'��|_�[���k`ŅkU�5�[�Ҽ���&wG���tE
�O����"�5ۭn Q�&}j�_�����š��A��I�M`��di\�UK��8�u!���y��U�����ȭ�R��0��@p��2����A��{I��>�5�"B���@E�����������PAY$�rM�0N]m��ϳ�2����k����}u%z#R���@�eNC/m�篿Zi��6˫��$�	Ϣ�����W���m�oev�H���t)\�&7��jt�-�Qv�*j��=��nE�Bwʓ�� �~���VY�T�)� �;x'Te�	��J�����h�15Yη��]A����W��AW�*��\�_�t�`���ą�BJ-��Ԛ�<���8B��O���DU�v�G6������c�-����$&0Kq�� ��O�]�¸<��T�];���J�
�8�<#��u�#�S6!�y�Ɲa?.A����w:�\q�l��!    T.�[X�o%oJ1��:��T�VwbM뢽���']\,���ܦ�&1�O�I�kI!�@BpQO)����5QF�{�����"{c����䩯ג$�O��D���%*�%ִ���a�� �����ЗWܹ2��� M����B~f�\!����3�P*��\	�׵{��Ʀi���D� ⊛W<CT���QI�?2�ۤ���Q1Ii�M��A��>�^D	Q�2*u�KS7@��Y}sXx�Z��J�~�Gg3��[俺�A})ݿs�L��1Ib!�qf����[��Cw�I}�$/�L�ѭ�~/� ��h�,@��*�=|%���F� ���ܪA����x_��� E?�E��J]T��)���PՁ��Q�G�H��E���(<pO��/��ʈhzȀi��Xb�Q�	�ۜ!��iֿ7軲��_zk����3�~�>�#d6�h,�3+Y|����'?GS
���S�KW(R�(ϡZ:�R�����H�nUx�4ɣ�]��~l��}�z��2v7�}DE۸�����+p�5�h{��V�~��`�<]ޠ�2	:�iR���������������A���c,�z�V@���I�c(S%�5�cX�?Ԧ�b:�����4)�/.��(��	Hh I�v���m�#3���bT�_�ch�&[^�d�&e�����*�X�� ���ְ�:lM���J{(E�ן�.����l���7�1X��3kU�;="�zՇ	����=[�k�����QEÐW�	�+���U�&�;lJ�e����2ث�Q��3��HEO×څ|�1J���+b��i��i�B&��pE���<kc&�認	�vz
s�d{�Fƛb������9�!^��{������������[wgR���E��#u�}��U%R�0ok1,�_����G�֯��������-sM[���:���{(q��u��z�9�G��i~.L�������m{����*�{�w�fW�"c�� (�[<ay��
�D7�͑;S��v���<Y�v���{��$uM:bY_�!�J�VÂ�A`�ՏNҸ��]>�u�@��i�qu��i{����G��!�Y�����B$�	���Ѳ�W������4-�{�'�+��>;q����N���rhUn�4Uk��M��5�ӏ��ٕ��h$���%������]Zs�j����2]�!ky}�4�M��tRG_g��`ǱdS��Y�$���p?!�ʈ��W'i�����H��7��U���MM69��iO����;g��k�`�Må�o9X�A������i��qqE4�<-|�n\���A�.��vw��'�/`�(��w�O�ၾ���p��x�����n�FTŰ�P�I���~��&���F�&6�׍�>HwN�x�h|xA�K�{v��&>���uܧ�+��𭒱ѽ�l�`�!J�*��n��L*�z`���Q5�B�bI�*a�񵩩Ɔ� �~�V�}6,O�E�&�7��-�������>soz�����J~���纄�࡟/�q9\�ɺ|�p�D��W��u5X�t�k�ҽ�Yf�^�g�- z�H|�_�H��f(�r��ޒ#y9҃ ��o rM9\��*mO	�t����'B�����݃��!^z�oGg�"� V��JӮ��x�<1y�f����6Rŝ�a2����cKo�g�����6���8rĭ���Y�]q�\:	q�q������_�ZR��g���⥹x1��
f���,)K�%!TI��@�'��`���V8	�����Mρ�ت��;�s�C4 ��y��w�hV�{s�2���9���<�l}%ԭAߡ�3�X��9���4��xj.9�� "\��@�l�ܚ��2e�Ӄ�	*��Ѐ� �_�qyQJ�<�p��509�Ǎp�ws��ǃk���x9"����s?����0�t��Q ���%%nQ�����^�I,v&��=r�Ǘ�zy\U��c�,���ֹ�-{�a�j-:D��������(�����0�l1fwõ~�d���YC���i����(²�Z��@{��'�u�l���CZ�˃�U�p�"�g�\��z����2G�����mY/罸�c[F�#;�˨�D�h�_�9�M����hd�Ѩ��4r���g=��0�ęt�m�^-Q!�����c�l��&�v�i��q�� �J�bΊ ��.��d\��]p&mh�B���x:h����Ш/:׮���Rl_g����ֿ�������ױH�$�I�����JV��I��&D�Sz���1����k �"�+ԗ��' ��lN��=�x�ȴ5��;��B�I��J�=���9=�׌�d~M?�F{:˹O
9t�nt'WWR���4�L=r��'��WjR�o����ղޢR��O	Ǿ�3��ӥ���;�p�\� eQ�V*�����,.Mq�YVe��f����&g)�V����n��R�x����IQ�����~�.�_�$N3�������|��TY� |�>M���V\�U�������τR���_|e��.�hN�O�C�𩻣�L��Pp�'�s<j�Ɇ�wyg�3��5T)�j�d�N��� 2Y��x�U���D��b�-c[N�,�ޡ��U�L�{%jM�X� Y�ߗm��gW�|�$���B�	���\��}M >�ovO9º~��4��2^��&Y����G�������L+��Gns~���.���U�����G���@�f��_.Vy���-+�/���G�Z�Do�w]��K����IC�n`��'ib�8]��}�J�sX9R��%�,0e��s���^���|8��"Ҍ�>;�CRpDxs؞a'��k�.��2=�D�څ��e��Ϫ]�6�����%�W��v�(��8A
��~R<u_�C�m{�Eg���Tܽ����pe���+�g�e�l��r��z���+{����E�~�.y��jo�H@�ql�)��pL�OMJ/T��
�t�a*_�Ej����Q��������m�pفH�G=F�g���= �Y�z�R�iS.�SS��G$��+�+1����i�j�i��5ox�wv�{mo��zA �6N�| 
�T�0E��Kܽ�Z��./�g���=�ܕ�l��g�u�;�G����g�����}��Q��呲*w��	h���c�o\i�_D�1L7���?I62�R~���?�(�(Z�Xc�m�~@�RC=	TaH�c�?�#z������o�a��"ݩ��|����YZL�-.gE��M�e<�T���ӟ�/�mhԆDE���٬Q�	�=j"��d�˱��l�vX>�7q�~O����x�kw�� �I��Tw�O"Չ�=����s�_ݵ��%�kR�2H	"����J�+{�0��4Ȯ�&��� �P9G�6oN�dT&��e'��6�g�@0����_�I���1+2���K���0����;���&�S�^d�T�:�g���bH��8Uy�mg�<�>�i�T�p��4�����伿�L��M�n�%���1�E������b���E�j�<RH�8oESB�� n��d���H;Sg��P�*�UyB]#���\\p��;A��i�]�Q�o�ŧ����t�/�#��t٪�~�dɉ='�h".A�Axa+^G(Q\��/4`41Py��"n��G���������8TpE�j�b�*�!��G�1���q���e��b�e?�ߣ-V]5�ƹ���ab'���DWz���}<�~p�ݹ���A��~��o�(Z��\'A����|��g/���k>
�����a{�S�N�z]���գ�K�5�gkr
rCR��_�V�`���G�E|z�f��
p�?\I��~��b�,�'��Q�]�Q��NO(��!X���7�\ݹ�]��7ؤ�&�+������ӹ8�PDҴ���J�fvyeg@H�P�ѯ�;�b�����k��#�M�,s�"O�j��|�.�<(ߎ+rI�L�n��բ����p������\w�瓜���DMӃ;U�z�q�G{�    #D~��C��M�����M�	+��sߟ����I�w��Y��:��3��,�(Z��y~���]^�d��c���6���L�� hv�1*E�Hw����Xe�4�"\f�RK�4�W��V��@�x �(�"v�+D�,��+Y?,�r�|sE�l�Ua�w�<V��xw?$�@�K*�#(%bM��eN��M1Γ����#W�=������%��ɟ�a�a�3�*�g�	�t��&˖?{�R�.�� *����%���UA�w���&�;�c���oZ��j�e^=�G�����?^��L��Z|?�*��E�K�rU�@��2�k8��oF��K���k�Y �6�C#�Y���N_���<�>N2���3X.M()�������m�D��n >��2cs�c������u� 3��?�S�L�z�����?FA��B&}�!� ��9���i�aV܀�J�$YyųY��	5-���	������gƝC0a�B�M��0Q%|J�	p����窵�\>v��܄HQ�����1l�X%�h6��'�^\�Cz�T��������
p~��p��>�h����sc(��BO��r�]�eN�5﷤8J��œ�.�?�x�@W�E_,�J�̂�NQE�E���Ox��CeAa�[>g�3��94���H�`�~�km��^>9�m��9kG_��W�$��r��ӘB,��&v��b���i���Y> �3T��)��B_bԞ G��L@�'��k��v1�-W1�"��h���O,��z9��E�2�ϱe��QowlԤ2�cFW��Ä.���=(��'.P���IQV셑���p���� +��Ӧ^�E�$�s�EJ	
��{w}"�R9�r�d'��7�4K��)�0q��J�֟A5ea��y
�J4�Ѳ��}�CҞE��	f]J6d����y8mlj��w��iYz�e�E�^`By"v����NY�}i��}9s�t]��_7T��k��S�W��5kj?�W?��n�ک
�+����,T#\IX�#�޲[9��nȕlK�F� �|�� 6����J�^�0iaڠo�B�d�$���E鷖B�8�3��v����.��������.�	!6J���{m� ���Q'� ��%5��n��� aS��]o�T���8�En��r	�}�	�1n;���u�����:lL��?���.A�2���9w��� � ^��'�֏]m:��,p�I0,����I&�(�dD��Fx�=!�O�"��@3z���+*��H��˴�ڽb`VW&�6�,�o��]�8��ô�ӆn��z3�b�qn/��s�]ހQ���5�и���
���k�U��6��f51je���Vk����0٢*VU�`�W�9�`,���~�����c�B&9��_�ܑfSV�´�-��m]Y�*�RWI��̙�7�k��(n���q���o�BUmg��ei�=���aН.��EdO$	7����p�J��x�1�?��\%��n�b���%0W~P��}p�TضL������X�?����PN��-	�ǶL-��y O�ΐd��P@G��3�_��k���RU�&�<�Pȉ���2�r�o�.-p:X��v����$�`�A�S4��9yOz�����
�Z]��f4sW��: �� I�5#�e$%P�W�;�C����������#Ӻ?,Y��WI�%��F�P �^�y(�_�?s�9��F��@�3�8�ڌ�*�&��bh��ti�6���$O�P�ʠ[�=�b��� ��H1*ȩ2{gVv�u�ܔ���cA�ͣ�Գ0{>���w��^��6��v���d��Q`FN�DFtz0�F��j�D��XN��W���X^�܇�e�x�����;2S�C�o�$��)����\�~��D�:�\����T`;��.о@X%'�%�YO�uI"�$&�����Иp����!�7 �͇kF�U�j�P���;����B��T؈�8i�H�N�"����BC�b�.Ł�އ=������N��W��	jd^]E�E��,W�^��B)���:� �έy^�Dr�~�V�pO�p���6<�P&n�T%GFF�b) ����������r)~��`�տ�9<�q}UCC1��s�wL4VhvP>pU	]r�G��W���m]�*���)�������R�͆մ�A�F�]� |���q������J�]}d��߄>�����ٸ������a�.��e�X	�o�y�n7��R��"�E\U��I�Ϫ,��C�煗�2q}��$��������A�W:vh}���Q��C����S�������[RӶ�e�B搈o`A�¸�����px�*)�܇�9f��:�+�IR�2!��3_3Wx�����;ۤ�P��1}�.݁ތN� T� :��Gl����Dg/���Tp^٢�����7˝�\��xV���ѫ''��_�����g�D�_Ǟ�'V dJ|#�@���&&E]}	8�5!�6��7;��>�y�R^ǋ�(0E@��̍2)�x�|��>�$��8�y�ĩl���	��o<�	��ˈ��ˆ����_�*���*�������V�(R�S0Զ���r�,/��Ɠ�od��D�O�;��:��:��A��{{�~ݽL�_�֠fQ�#�r����e}���c�LGk�E�Vr�T�]k���@�>d���cRΖ�����j��W$�YS.�bfS�Mk�$�H��ڃrp��~�:u�������Oo����{Iw1�Y��*�x��$�A{=x���q#��ͽ8z����'ܻ�[���!>�8nu����~��7��4�R���i�D9�0&H�l�LŏO���H��n/H���8\�����Y����H�돣�^Za�`�G��������h=�!�MDt0@�X�5��WT$'���7�a�~�B���K�{�Æf��@�<����I��S�>X�s��q���,Y�p+�IR�g�7�Q?�0�<��m+`<�����/�|�����A�����Z��p~�o�a�����c��f�?�6�u<���M��B�X;S�W-��O{�m���f�4?��Q��=À������:dE��66����$��A�q���B�_|��
E��(�,"v��G/�kq�)|@�z��1Ϫ�y�֖�!K&}WJ��{y�\���0�?���=p��G��T����R�"MktE'��Xp����G�~8���F���;����!bFvv��t�J�*���/�Y ��AU��xn��9�ؽ��r�#��.Ce%���k��=��!p$�����NQ�v����&Y^��@[C��/����'+�i7x�۔��m3I[�fy�fӼ�^�2
�p^�[(�t3Gj��E FV���pi��c6b�z�I�>^��sA�K������=b�'5Jd�H�5�ʼ�>Z��Q7��;�ݧ���"-[��*����)�#�%�,nǺSM"�K������v���_��1Hb�X=�Τ��Ζ�Y���K����8��O��q";<�F��A����ћu�RK��dV37i��W�b�)������=7���׭1t�6�D��p/H�����ߺW�+�@C������f��>Ÿ蟑p��CM:]���Ͳ$'�D����t��N��s}��@�~�Oc���ج�����)���g��d�0�#�I�n_F���L���SH�h��?q�L�ry2��(|E�fѧ0i�io-��1��$ N0J�k�Hz|�L8E��������ħr �w�D.�&?*�U��l{D{
5���A�K���Q�T�8��#&����(ʣg�8��z�����DT�	�wj�j�
���\���Ap���$,��l0�;h:8�ld�/STİ�:��sgo��6Y]/��y�M�G ���P��:��D��ֻݼ|9�͆�DP<]��O���͡��?r�f믉2���=��i[���g�s.��Tw�)�|�c�CY��1�� D��!kml�QY�EH�e    4���h(U���	� ����\=`"1EԬ�T�I+� ��գ�Y_Wd��L�P�U�=�9_�ͫ��
�
�;���k��3�����>�*�y��#f�ۓ�=�\��b[d˵��]�q꯱�#?O�YM�Ѥ�f�kl��!1J2�^O��a��'d��0>�3uW�<j����8�4�`x�z�Ic��Mة���H�P��9U!����91>��/�����
�Sa�*4&��BDǏ�E��;�����D]�<N���S<υ�\`��n_\q{�8��uc�
�����`RJz*>c� c�ځ�y�a���z���L޶�gE���16z/�t1�#-_tziR�����/�:;�qBe�_�dY:\Q�U��p���3iI�x�U6�TH��}�R�\���W�
��ƃ_�l�a nM� �iן2w���[We 
�<q
1|�ţ�����)�w�?�k!��b���eY5ˋ�2�M�i�"����D�=f M�D.���[��3WfJc+�Q�_(14k󃰋l��GI�
Vߟe�,�2bO��'[J�����}����J����p���TH	��#%E2�J���Ћ�f��S�l%yɹ��H�w�����Y�=΀�͗����,���A������Hd��� j3r��܏"	��+����r�T$5d��U|c�|6���"-���ܝ�[�����~IE��m�.�̖y����bM&ˊ�R\H`#�m>�C�#Ҭߘ�e��~|�Z����T�� �C,��O��8m��EK�*���zGd�(��"1F�ޥ6�(�6�(`S�ǘ�N��8��17Ђ�Ic�+�o�Ɨ}6��s|��q�5�&Z�s�ؑy��\OE Y��)Tp��e��<+�+��U�ř��4��{�!A�Y�R3� }]&�W�)��SVؤ_��WI^�5ї)r5�҄���)�W��/m��t�=E��e�<+T�����Zx��
�݆֍{�E�X�H�`�?K�����!xf�㹼��zy5�~}\�4�)C��eC7�F8�n�:Jt�U �E��~7<S$�������R�y$
���?к�M#6�L�p�
�g3��R�!��j����I�`��Lc������/�L�Ӆ޾H2r��xJ�D�M��]o�BZ�<�p��[�`\ 'W���)^f��bUU1�ޞO?+)H͝jp)�����^�jN*q���j��C,������f1|�]��
��-"�rd�$b0]�)0I{D�3"�q�V�4EY�q�<6&Nb?��e�3Lź�Mx������B�����痚�6���d�"�b-r�Hr�8��
[N4���{������x�ƛe�,���"^�T;�o�fR�Ah���֏R+��0��Д�	8�,qE��F�(�)�(�{�[N��ңKC?~�iTe�J2��Zi:�X���%�)2_Ifړ�d(�B�c�u\菉��{��A6B��!:�-Fu��SXb�4<ә��g�$��qc旹��N���U��8E]�f�/�k�r�en2�c:��|��`N�Τ�Ewz�����>��>�Mq:]|��4q�J�f<n��v/�_>#�뗲0�P4����$�
g0�� xEpsQ��ǭ�)�(��b׿��L���4v��/2י�/�BU�M�p=�Gl+�)�y�,[�����X~fҤ2�7��z+����B� �ʖ�o�O�Y���_)א�I�<���#UF��*I���$3u��?�0���um�t{�<)Q��8MAD}�KŪN�,]M[Uq�E����,�T,�w�:ǉq&��0�G�x!M�<�1�اk��҃J��9���3!$@�.�Z�&�0n.,_�����{"���JG���D�~��Qs��E�E�f7������c_x��R��@y�l����Pl����X��)��⧭���`y�EP�q�ED���r��
�����Hg�'%���� ���8�N��G������ry��橻�zd�8��
�C���Kju#�QNxD�w�TbUĜٟr�In�.���޽ԯ'Q�/J�D���G���._�"��y�2��iA�V<���>���"Ϛn��I߹�"�c�,����b*�CDK'2 ��A<���70 ��,��w���.�ݝ�����Nzv���!ul/']!��
R�(ڛ�m��;���{&8�X�~�gm\w��15qU��vn�{Fa^�c:p�O�k�E���N�lIZ܉�Q�~�v����^~ڌ�eXd�K=ð����I���W2qT��
������m/��:�V�l����>�pJ�ER����wA���;&q��yI/ wĹ� ���Q�.�֏L[{*"�%<y-B���V�}���}ݫ���tW ��{���?W*�5�QR�G����l	3�'��)���k�
�k^�����M�o#W�\O�<�s_�O�ɆW�q6S���o~��9��ԑ��ܬ?W���-�k\A{%}�g�;8*:
S���*d����a��[3$W\������ �y�V�'�ň��*.��4�����@���nNl��GK �	��o/�5늏XT|7���4���3e��^:S����MNyJe��tg$f��_�{��c��z��`ő��#�k�1�"��$���xuO��;�aR�cĻ�8&�}
8�L�� ���L����o07����;���d~?��}�E�^��a�~P�?����{���A��ԅ^=m	�Dǥv6kh����%(~�>6o{$�Ic�:)�+iR����f�zh�v�T�T�)C�/]Q�2����5q��ڼ���Ӝu�9'b����+P��!��P��MR�vy�lc������x�|g#/n4w�A8�ʵ(��z��_k���Q�[N��LNM{�^8��o@ܥɋ6^��ZWo{+S��G\�V-dD�W9�'�'ur%M`�-,����4�i��Ŏ�Ef�̿H"�(G*���t�/V�y~�ݿ�D!�~%�����ŒW�ā�Y����c3,�!m���9/��^�!8�xz�`ٶQC�H0| �Ǟ4C�uW\�*O��Ea�\B�*x�4X��=0�8'�[З=����t���T� nM4ɀ�ޜ���(��ٜ0���w�s�SQT�N���!�lP�$��̡�Ob��x緯��#�x�����Z-�a�c��� F�^*Ոp�α�Y�}G��&�@gU&�r���y�Qsq%��!��yr���t���-8��^3�%4��ⶪ�������l�6��v�y��(,�����~� �|�<�\���̵��5'�Z	�t�9mڛr��4K
��J�Ȣ�(�R_=L,NOr&�DA�":v��Ͷ��utf�8��
�G{�ZI�E^���hP�����+���*l�2�g�,�ᄊ"��V�"g?�M�A?�W
���W��җ�1�f��K��CS��Ey�$Ux�`���かH�˓a(�_}u�m���+��Ox�*��K���ݎ��-����d(�}�A=b����i��d��wG��
�GL������-��B�&�o_��g�10��sb�����������S]����]�؟�2�>~��|�.�š��*�*���S�� ��p�"��
��a����m��as��М�7���4/�g�<�� OP��l��ؿ��]�0=�WD$Y?٪+��+��"0�KQJ�,��Pꎪta�F]�Z����v5/'N��W�ڴ���Yib�x�v�
��d��j�tǈ��)zD��ʥ���_?����
�H�I��,��v�@gZY�L�8A��VX1���\��Π_��J�v�g�d��p[r��D4�=�YlDݧ���=���Ul��<@
mj�����!B�����?�ǆW����8'w�������p=Fb�!���6�b��|._���Ť~ �������{������Q��A��FQ,�����Z5��w��I�dy��[j�x�̣w���S�:� �!��I���nSu�����|�`�LZ���W��_/J�S�!K��cHEꉀRH��� �d?>���W�ɪ�[�R�Z�~�~)������UN�1�
>d    lM%��`��YԨF<��nl�Mʨ@\�����e`�]ᨣ��{2Y�Έ�ۃx�=ŝV����������\f^�Dw����y�V�Lj�,K�X����/,�"���P�#���H���D�6;�Lt:)��31�â]�)��������㹢(�}		S�D�����"Rg����)\�x�n`��MY-.K�Lt}�3\�v�����A �J~	n1�K��k7�z/�v�1U�]C���Q����~���[����I]���س�Hb�~<�`��
�iim���V%�MJ�[���
���K�s���'�)���t�`<����5hX�Z��n(��Z^k�yn��4����૤�ù����#0��K�+^��*��Wz��t��M�f���a��4�
�t�Ʊ�!I����*�>0�ǝU���lI.��/x/��*��a�P���u�� v?�������@d��B�m~�M�q�RV��ds��2w��8�������U�?��"�w%%U�D�O]�PJ��u��_Va�$¨��x�AJW?��q����J���F��b��EI<u��0�;|�2f]?�`\͝�*��M���<�U��2��W���<�Pt�����5��_�Yo��D�i��L(�[�z��UUt�߫�L�04�rl`��u���{	�dЛ�	<ҖVu�������G��]N��	?WV��v������h��\��p2T�x��v,R� ?�;�r��c��:���y���"	,�����򨾐
����qx�~Ի�h��8��j�r�/�B�9�PeD�l�y'X�G,ĉY_ZW,�'�.�%i1���Gt~��g��-�.t��w!����I�>�l��9I�1I��N��UDb�xj�[a*!���B0\ᤄ��(�1�PW��
qRf������RnDK�
5�{��;ڤ*��^~ �,I|�YU��h��*8t�%,?wĤ��K��P.�I��ᒺ:&z���*�� ��JL��J�Ti�Gw�::����gX4�t�I=f�32Ns���[�[�b���k�{m�D��aKW�_���G����w���7Zy�>���mF<�^Ww���ZђZwį\f^�Ʈ�����wn�~T�$�{IDN@FHa��3�t�{�߁k��"J 4��w�1.FP��_vwC��9������|P���)�U��7�s���*8i�wÞ�'ɻ� ]������{�D�:"����u6m�b��cv���Ȇ���+���/<�򑮘�B?�ޮR��݂z�k�8L�vu�_��:���ޡ�R)V/��̤�4�d�{C�e���!��0�$��>���*���I�G��M�r�(�i���;���n�r������N�	�[��ʚ,m��L�gU��E�}��Q�[n�?��[x_zmq��# ��,�uN@Hݯeq��4�W�'�����[;�<��U�����;�(&�g�B���'Z㾧�_��⣊��������ِ��{��X�(�u��o��aqg��6����'ύ��{|0>�k|���/���j�u�o㋷��/cmc7�j�@9kӼ��z��A�$���L�Ȩ��i�E=-�������HY�>��%�<����I�ć,�~c��F�j����_	Y��mX�v������Q����)�*<Z��&�L��q�pi�Vq��ZH��t�$\k����O$M�����}��'�uB�O���0"��'ڥ����z4��m��˛C��WӰI��.�à3$���8���O6�|���!��SW���,>�M����7b���x軺o�?�.?TS�̣/�pai<�����QW��M��gbvH�k����7���0���;:���|��b�� �j�+\HO'p��f�E{� ��C�,�-���Mʈ��^� ��ڟ��� �BT�� D~	a��Y�w]��V�e��&
�Y�*�-�Kޞ�;��m�u�H���8�5I�牂ˁ�}���b~r@������,\1V����f���A+4����@1��Uh��K9��A�1�H��R��ay��e��4���Y�m��d[wȰ�H�E�o@ㄪ��Ċ��B�����Cn�:��p�*$aK'}�A�,@T���>�wB$^��DN���]��?�ȳ��"�f�1^�ߦ:�.����OQ.��[wQ��"%����;i�N�hR�ϵ ��c��0��,;m|J���U?4�;�<I��h�a���U�l8��s��9U�^�|�c�S�ȑ���g/&��.����l�TmqEXӴHC\��#����#����P֠�".�.tg�tyq����G�i�U�6Q���`�\N?+0F`�A� Dw�+�"�k�f�A��V}��
jH�-���㊁�F��^o茑BS �R��i��b��Xa���i�e�lZF��9/@�؛��)���X�o���#�|U��*֏C-��V�G�ER�Ux���?��qב	\�Xj�:ldr)�-��^�:���u�m����;k� �������mi�j$���)Ϡ'����@�vU�|A�b��?�$�����.�':<S�c[c���xy��=�Y��w���f��2[�h6�S��t�	�ٿ1
+����N��Ci�+��� {�p��a�9�L����&����,`���T��EM�\٥S+9�W�+J���CL=!
B�����J[fy�-hؙ�t��v����RD�1�筫O �UCB���hI�;�]�� ȵ�����@��3��çs�H��w�߁K���->>���G:�h4t��������}r�$���f,�=\�>*�V*�{- ��A����'n�Ce�����ds�O����4�o�������8>�(����HB�w_J�l8���z��	�"�K`Vl��E�l�We��B.��&�e̢���E+&FL��f���Z��e���'h�����c�|�؍��cʺ���f�U�M}���-����l�>L�3�r���EP�z�������ڋ)��)��/|��/��ֺ�][S�ި�(���ǉ@޽���bo�O��w����k|F���C}^_�*���B�XF����L���g�J�����М���Z�����
�i3����UR5��^�^/�J}����k�#�Q��|�>C��
��4�|	�:.�x%[ UM�5[�����_�ϵ�IR]q���bYG�4�tiT����0zH
_B�`�jK=v�=j�c�Q��B8�CnN�s\���~It[eY�/G��7���&�|�$��(Xa8G�/ՙN�����P�;��S�e�
�M���J���g�}�������a�s�%Y<׵ܯ�tv@|�+1���*UD	oXz�0�?3��p��Ip  ��w� �B|����w-?�I�l�E�Z�ԝo3�ͥ�A�(
e��!�-�b�����x�˫���������I�-�$����_2�R'܏&Nb��D�'��%7��!�*�1��eM���*ze\��]8��@=C�� t8DP*�u���ϛly+�^��
Ѳ�s�����	���\!aWh1)�a&X�e�b�n��J�r{Q�a���d�X�:��+�DUiL�z6S�I��c�m�YD�ԥ�E}����y{���2��Ę��~�� �z��g�����Ec���.�j-[?@�γ�]��@T&�c�螮\n���#~��ԃ�5��ˏ(�7p�
�W��(%yV��VF��W�8EW�^Pj�������tz�M����dսN���x�1m�<hY<=OUtO��#k)t>[����C�!���H�G�y��
�)^v�H;Q��ٱ����gu/+ɠ�r�8Tm�f�/ކ|��BW��A�*����Ϫo�m��;#p�B?�C��q�T�u�9(�����a�~�����;��hU�ޥ���r���� �]�����6(w������n0L��5I���S�[�����+h*	Ӗ�_��}]'W\�ܥ�fq�,s�.9�(j���#���t��D�O    DċhI�k��L(��ٽM�����4�>e	�	;����8�&��m��^Ni�F��-"�O��zH�#(��{vkG;ߋZ�h�s�O�bk�.�"YW&Ӕ,��輝�;�������;��u<��G��I��c������Q�#{q��`��޻�6�M{��wI�����L�� �{�;H�C�hp¬*c:G ��U��K�z�/�C�+�������>�$�$=��pzG�+MQ/�p�8D�Fo��e;�>A���\�	�ls/�Ŵ�ƾ18���;�	��Rb����E��2Ц�}��ߍ4���@R�j4�Y��p��j-8�R��K��`q!)�4�ڬ��	=MLtY}�T4��O ��vY&���|�0K�ڇ�z�[?�����'�wU�8�,eˏ�f�}�E��_�4۲B&_/(Ya;D	�K�ZoQz�e|���?�E���PT~�M���@ey�=��7z<wgES@�U��tQ�&䅨�q���:
�H�:�+)�ָ'ѵ�����翵]�%˳K��Ʒ�Y}sI5��p�`� '����iۡ�w�~��R����M��2�j��^*-�߫w&-��'�ĉ��<&|N�_�[n"f�ar֍��ї�2�t�H���WJŻ��wy]��Y�����X��E5�m`8�	�����4:��K�#����?c6�u�ݽ�ʻ����I�1'xw��gq]��r��7Ya�V���W1�%:�*����޽�zN�HFj���z��$w���W�&y�~^��г+&s��IX67�W�]���h���!JB�Y I����i���E� ����؉[B�!�N���	U�p���
XI�1V���9n{�wϡ��z�9�<�
{�Q�@+x��~�����i�~+X��s��|��T�X������`p�pt�a0�	�3�l��������s�I�Q0J"?"
�0��O�5��2cW.�������ոM\�ۖ�F�}�����K2�D(���B_١�"�H���e�R�����l��ۘ�GA��&�?8�^b�ůA�E�"dM�p�N�~�Q���,��0��6��7���ԫTLq�ց�5�b.���	�^h���]V]��A,�][^���=����N\���9.�ܫg�h�����7�||�g.�L&H�7 �7Ķ���ѭ\��j}�� ��]��DI؇u^d��ұLyw9��n	1�B̊���Cڷ���#��*1�"�ϻZ�"�~�)��9�n�	ճ�Ha���- ���ǩ%1u��P���^�P&�.�62����8����@�ٛV�O����P����[�$�OA�=�%�`�����N[%��_5��ܧ����P٢��fɄ�*���xt5��X��u!�0��W^ ��s��Hݣ�>X��[?0g�3\�2�0�|�ɰ"��`^0J����Q�f�m$I��u����{F^j�*��J��.Y��&���Dc�~�?�q�Hp�*a3fɛ�im$���*-�:³|�"�}58�M.�*�=�,�����x�Al�9>�@>p��OA�Ƀ`��_�q����U�U�B�r"q���0JVS[�K`��;�"gɸ����7��#��~뫿�*����TP����HE�%���L�<��U���(�ǉ���Y�!ޖ�O����0�S�b�s�d��qJ�]}�D���4�v�*��@��J?�NL�TFRm��&����dLe�U��Z���U�ί��*��C
���؞��w��#-2���C;)����W�ms�Ӱ���^@�P%+�׭������R��7�;D�|��˳�:a�ےT.z���t�ߋ�<��e~�d������X8|P�,��9?Zu^�!Zu�g�B��9�����4XybD�"�蝹����l���qMQU�t��BE�7�˻*K�P��{:��@���C-[>O
N��4�O;���lT����j���"i�!�? ��*5�K�]T���� V��?"4��mZ6���Mw�'WU�W����(Y<(tF�;|H��i\wn~���:�޸4z7�e�g>	�1Ǭ>B��
 �|����^@'��>�?v.���]�����al2�zFi7l�xǮ�e=̸�����굱x ,���p
�إ��a(R_��7?_���ˣw��P�����bK�R�4^@d\���b�Y8sE$��z�������l��iA��5T�r��ݦ������ўs�xq%��`,$����\��®�5&S.t  %������iWV���Β @wU􆦬h�m7ܪ��uh�)@H��|Y\d7�%�$��t��^�UJ�@��z�3$����������40S)��1�4>��E쏪G��,�|>5���9ʊ������+�e�5�ꭦ��#V�����%9���'u�\�O�fVG���$"T����]JB��8��Bo�m����bv`V�Wl��z�&30�g�:�������d����?�@  Zv;�Oa	Y��ԩJ���.߃��ӡ��$�]Q��CN�/j�Ϣ�#S,Ͱ�T�YY
W��.�#�fl4�nAM �_|�����y��nE�����ul��"͢��Y�~Z ���=�SG��sFW�9�k��R��B�H�忷YZu��a@��.HI�:z��C:B����E^Cr�y /���hu�K�+��՟�@5���+T�T�t�=����+z�ɿ�Ԅo���&ck��Ή�lwUz|��3�	�:a^���N)և
��r�}��5l߭����B~ҙ4�{�ss��*M�8�wi���#�8(m7��&umlh�S{0�g����>@�����QA�k���?����d��+��@��ǽ?��Hu�\��/���"���f��m�Z�ч�Ha�TT�A��~g�)abǷ����@�bV/��jW� ������ư�|]�	���(��|}9�ڀb�je q�-�<qc�Oc���l��70Aj����:�^��u�_�'P�&�.M\38`X���Yi��NW9w�cR�$����A�x���e�����9��o{�0�d�e�X
P�9��K�������������Aw��#*bn�>{A�Pz3��p�|�"��v�_��I�d�o��H�ǲ�>p��@< ��I2���Fr��8��-��ry����')ĺ�4��l�Ӫ���n�8(��X{)�����]34��UI��*��4��U����r2z�I_@�0dzĸ�.��r����kj7��������E��G�ߋ<땣�v���|��+rU�Z_��HS@k���� ~�u�x<r�}7�x��K�:L���4�Z���oU��h�=�+Uģ[����W���}?`���`���	�"��6E�fn~@��~?���]�n�7�"�q�����r6�+$K����O��Ɵb�֓kV/�YU��7D��Kk�8�����nl�Y�#U5�w G?I��ߚ��Y�"s��e�켢����_��Ͼ��]�Fﯦ�LzAG@P�ƕ��x\����q�l��uZ+�R:�����Q�bɀ�������>C�����u���
����w C^�:>������ѻ����`@���d&���T&x����ǑSHUT~��(xQGq@�,)fJ����8�×;��:�����V<��y����d�%���\��O��?�3��W�P������; ©��o��5�i�b���qn/|g�+�Eę�F|ٕ}����*��?c�������C����_���ϣO�Mf�/"M?6�ر��T#A W�� ����*nj ����w��b��0�P.OB�>I��� 7⋍kډ�Ԉ������d!Gz �ϤBT0M����S @�t��t�qD& )�$M�z���TiDj��H( �dG'�����lNx)k�r�1����d�� v)��,h�����!���;�HOJ>�כ�P����1��(4���d�l�3�2�􆣝�>���.�WGo�F�|TC�B�G 1ʗ�˼l��MdZdi�Y����w"���:T�Ih6�7����G��    	1���@�Gr7�F�GZT��6``�/�Z���LFB`���F���ˢ�����r����3�|0��lۍ"v��	'�fJ�(�|��ٟ(���z@7CqFf��m9�,�_@�]v�+矟,I]8>u�IT{9�xƨ\��
�����$O�c��ӊ*������M�đ�X�k}�:��p`�z@1ްP�����fȼ�B�w�^���ʻ�l懭Lr�Ij�<z�z�RS��8�@��m {ŋ�P����c����U��XUu�$��
�6�	�"�E\�O���4��������Y�R�j5��a<�6��h�F9E6Y~QV���L\�:��V$Y��[��l�@~���t?<�2�)��Ĵ[�f�Ћ/c�zç�x�xQ����4��U�M�<�������W'�����?L�|
����t~��gun��")�B@�q��Y*���)��G�m�bQ�>��?A.��z�B-/*W�@��0=j;cP(��cG��l��W������d&���<<��q��r"���e)`��̯D򲊭JK�b.��	IJ������	�L�u�O� 	�DJŔ���ޮ,�憄Vu���L�|فk����N7����Y��J��I[� ���8����yT2ÜI�D�ѥj���5�(���A`�]���B͟�ڠEG� ���-%�HMD�!��ҋ:.��h�IiZ2E�D���T�'雔�U)�+: ��7����������sP�qb9(ͣ7���<�F���'k8����׿鴆He���u<�����sk�"z��b��^�"�w2��<�C�^���36վ)gc�
~��|�ӿ�o�䆳�A�"VF����m7�z��k��HpΛ���D%�˙�͉f��ꌚhn�����o� 5�&�n����$.Y��re��e��U�;�S?6�(�=M������rM'�:��� �~�v�+,�򽱊&+����,�C��0���@�J| ���t�8U���&�m�6�ezO���z�sY~��Y������
/G�
FX3��ᗑ�mO�2����WN��[>����4��~�IY[|�82:�2\�1Y2�ʃ��2�^��#��}�����cN��2�>���߷7�u����*����,��P��w�oTg�o���~�rM�:���8�)Qp�y�Oh��Ϧ/�~�|��\\ڴ1���1�M���6����D�e�d������#�TW�P�@�H�8�����C'�e��<�%�ll� C�
��-�Ȁ�%c�c?u�G���_%�↻ZYaer����x���[�߀�Ɩ�}"�I4Ƕy���E6��������L%�O=-?e���������zc�`%+���_{��8M��+9�f�M��~�f�T�{D�?T<	�B�s����谋���tI<�cxg0# ��gd���v�����؎�"�K~NO������ׅ��9�n�6�t���տFFD��y�˟�3�t��U��6qʊ��}���GU|!�H�*Ɋ.��6a����&�<��5O0�E?v=�˖�g^��<��M�\V�!eK��{�0z��q/�aޢ6N�|Ⱥ�z~��#��iKVE���,Mڽ���ԣ�`a��vR36�`���~۷M�R��6IYQ�SX~e�n�u6����L�P��$k�������%��I_����3����͞'hEK��%�/k�r`m ���$�<�L�DY�2�����W�-�W��%5S�@}À 8R��%��+	 �������LCw�s�$
JZ�?�\-�)@-���Wl�e����f��"4���4�¾&w�Ls ¢D�����?���� "�[4�>�L�� ).[QĶ�ͻ�/�:���_k��,](����E���b���iS��<�Yq������`֯��h�S`��w�s<a!C%ty�)��"@C�>9�V⓾������H��%���P�+��&�+�mP~nz�l�R��Ih��`��q�� Ŭ��٩e)�Ե]����כ{3����}`m�,�v�v ����RK�Dt��0LǸ&+���������S%2|��R�r������T��\|��n<�Y�"C-���Y���\�WV>���"��
���"h���,=��W��i�+����Fk�*�%�څ�]�D���O�,�U���8���C���oi�"��o�8)�e���/+�|�YZoS�]�p~�U�cʧ�:�sl�OMY׮��	h[����6�o@c�YZM��
u&4R��=kU�t���o��b�?�������H}
�~*R}��~���+<݃�v�;-m �|��bP�l���.^�t~���|�B�`���R T���(S{�(s������.Ёh�0�B��|2�3�4�n`�U��v�C�A}�%��BIc*p%V�6�} �
2�$ݯ^�N:�4�^ӡ�a��i�U��!���0�&S��&o!ړ^Yg����D�z�k�)nI�ͣ�����r�,��X����J].,�r}�Jv�fu�L�`��GŧУo�x��'MUل�7O(�\_��׷[E<7i��?��8��5If��5�#U:���at���QJ?�ә����b
�9d�ˡ�	�Li/�.1�ߣ����x@�3X�6[�Ow����t�_�����\�\Z?�9N�c�|Kd|�����qZ%��
��������E0�	���+��.'��	�44sڑ����F9g�&����,�	|�˗�C�,c-5�Xr̓��S��0����]���c���Tđ�R_Im���7���D��Vjs�%)Q��\���v�'M���H����E�
���D��
i\6A�J×#�u���ɛA�9���I�H_�	���6��sj,*C)�YN5P�5�௢� ���ps�$���Lһ1��������p9��>�6�Ycb�bPe�'�d�&�����Jش����F���p{כ{q-PJڳ��=����Kr�֎�{E�"�+�W�$��x/�j�O7ۼɟƪ̲p���#"!���nWq=K1�����*O&u�u�Hz�C��d�����x~��U=Wd�����H����!4L��A1Ex^��_w�l�O��a�_��;(�2E�#sӏO�`T��d���2�n88U�*�(�+��G��h�iCB!t7�{<���|���!o�٢�>h���������`�$(4���0�ϰ��/�C�������0�iVŮ���˔��PJV���@�L;�l���A1�"\�w�.�����ElZ$.�q�|�f/~���g���m����#��+h�Y}2�<Y��'cN�"۠�����x]���i�I��u��T�nJ4:�o��H\d݅A��.ÔyR�"�K�->Ӂ�57ΕInuEG��߰Rz�lw@�Y��чv��2�ܐ���:��e�;����U��I��Vz��}Gk�s/�R
,(B14�Ã;z��2�����䲬N��L���l��k�-މ���с#�N�$#�h�)F�O"FK¥���7O�0j��"����_Ͽ�����LE��r��ZK�;H'0K*ť�L[��pj�CE��z����<^?�}������`>Ħ�7���e疸bY�4gJ������*	t�x8�u������]��夗�Æ`r����a�T�P2�)�R����6 B�B(A�*�]��\A�؃:���ˋ)�n8~Rp�
�-���L�a���?o.�C\�Phh'���`MS��hꙐ���������3�K
҈Ɋ����+^�Iڮ�|~<�2S����q���pP�+�e8�D¸8L��@������޺j~ǚ�u�ض�,����A��²�n@6q����_f��:M��/@^$Yh��*����"�1O���_ � �����:������~�yפ�y��`�f��	a-�7��')��Պ�p� iQ�Hp����%�+�?>`%h��t�	�d�d�򙔥o���4��S�PG&�&r��ʱ�E�Mty�v�8.ݧ�Tp&(�ar�Ǳ�    �E���5
4;V�Uq�*YA��?��sd!��^�'����#������o��"If�J�O"������kw��A�e�n��w��N;�J���Ӈ��R��fF�^��k]�!J��p�}^g7�ȧ� J�2�\(�x��HPq�q�6��+�j�="�.~�Tf>o���v��4�)��Ъ�+@ߩ��r�|>����}ߑ5��ku�J��!e������+(�4J]�o2u.P��cZ<��̒��a�V�q�Z�V�9U(�`�S�S@ MNwޟB�����ۆk�k��j�8�2˜+緟��B��m�����L�F��/}�Q����o.��C�4/�d�W���eV4.��1�i�{X��<�X��0&���r<��.��ơ&e�$�z%<1S�Aߵ9_�����9Ex��{Wf�zhno�TIxa\����z`�M���9ό��&�f��۞�0���M�S�B��ydeV�����q\Z�U�CºYh*lkM�� ��!�J-������^�ѫ��/o��s�����q�?6;�~���o�{�eB+�rp����ͺm���¥���Z}vW^�W�}�n49=�����_��k�ٛc���7�s�ɊD(��;-�S�@����xߜ����Z1��!Z���$�)h��'Ayr��%�O(���aӮ��Ov�)'Ծ���n�g�O\c,�E�M��6D���o2R��V��=�=�*T]Ў}�M� �|��-@��n�ᬀAN=e���ٸ���	d��H
�q��{|�K�x�f�������Ϻ�;.U�/}7#`vg�����$o����OTi0�qMaHv?i�i8d?6��);AL�T��Z%c}9��m�	E ���!(>׶.���4s�D&�{�k��I�"R+׊_>ޭ>��8yQ�Μ��p4Ń�6Dq���e^�MyC������"���$�k7�i6*�'���坈��D��ĻT�)S�1r�|��g3۽��O��U>�S����!-���DXCd��fG�Mѯ�a�[�!��@�!�P�@��p�����@x�6UvU�(��4��/=��~���H���k�'i?��p>݅M�s�7q��8>�4��U:�j�ڽ���#l)������]�ʢȚj���e�v�y���/}{aoɕ��V tM�h���[עI��G��� -��������������9Ѥ��=|�ARУ�-�k����h�k�?�������I����3z l�p����d�kb��<=l�n�Ps>�|�!��"-�!K�?E��`�V�d$IY�QGn.���o a>�X���^�}{;��+�Y�|G �0ϭ��[}��˫�Zt��[��A�
_~�*�u����eQ�T�Σ0|�D��4�G�?���`�Q:_�[���Un!?IcӭR�/XmQ�L :�ӨT`|���G��g7}���I��4���dC�zGUj�F
�;B��fm�S/�=��Ѕ����v�C7��S�@&����=������^=t�����J/�$�@#kA���
}2aY�*'�����u�݀W�+�}����� �E�(�τ�*��&�&������]8���]�rpe9��GY��)��џ�e!�WW�
��[�b��I�#��U9h�3R��g�U��M??RI��H]E�m{�K0��m��=}�.�_�UE9�N�>2y���ډ�H��.�B��� �+��T����z��|���l�U|���y+z�{�Y�j����ʫ↰Enfc~�j&��j"�,:��t~B����o^N�������M��8�]��7\��4oJ�_)�D���#�M�#5u��/�)uo�U�ў~�D�^><��v6Ĥ�K�̜�,�o�՞Ph�B1�H���Nŕ�;d�C�q�䄜�SeL��}�:�r̩Ww�k���j���L�$�w��Fo��E��p�Ik���ɩ�)D���60S����.�ᝊ8&�o>\�v�-q����d�j��o���J$�WN������y�t�%�K۬��Z��3��2�_,v׊�[\نF��9�Y�1��0�H�ې���S^�<i��/s��f����A�VY���&�4ح�H���
d�?��W3�����w7)����^���(xF��D25�ٶg�$ЦM ���$��b@��?�叞�Kʲ��2����J�T�^#��f�J�r0BS��{�u:�yM��B
sч�^��V�#�@6�B ?r�R����/ ��'�Ɲ�k����G��ߐ�"˖�W�g�����c��Rc0��GA}�	dC���fPR�>ր��Mergy��6,]|6��<�d�6��*�+��r����}2�Qe��׸�2��g�����<;����%2���9�Q5���FW8w�Ս��3�ջ޿�[L�	��8���X�j�X����Lf�w���}� ��t�?|�/{��칮nxR�����:�� a����=%!E=V\�D��n�V4КS@�"�?TP7��X�H�������X7�eGTȱ���6qމ��J)�M�i�c]�ʨ�
#@��q}l��y}����!�I��>�3ѵ��h�N�zB�"I�뤦��!SXP����'�M?�;|`���l�ns�VY8�i�U�l��W�GQm'�=ę��j���A�O�oT(��?�古�O��W���R&Y$�R�W��®�5��e�A	@��Xl����[J|$�o������:;ueY%�\��z�|E=5mPN��4���#o��(��f���ͫ˺��↠�E�
&�#@��;>J��m?	%'�@��	%NIR�,_>���|���.K�tJp��*�L�3�)8����W
Ʒ �i��I���L��f�YUR,_b�)���?�ʊ�2���4#9M�pǓj�)�U����p�5��$R�T�c0����l��(S0��Bt���^6U�󟐬t��,���D�~s�$���8�^����'?'�g���B����qE�Z�b����������UE �I��i���Ψ���^�j��pElrR6��wo�*�7� ���iohN�:�����GKA0�\�|Q �t�<�IFD�^>��Y���ܿٙ5�h/����U��F�}�7�z����')�an��3<���w���A���wC��,7�2M����q���8I��m���h�2� �4
!G�^ �g��麝-#s�hi}���q7���8,�b����GXٺ5���&F�]h|W��♾�x�is� 6��FN_}�|���%"���ک��/4�������D�z�܊ԝ����Z��j�a�C��m�U��*����`Y�E�#ܽ�d��� �nT%� �B��w��g�A��4����<�u�7$�څpZIf�O��nկE��i�j���x8�%�e���h[���CY�4�[�7�<��LM��L���`�F�|�KUNvJ�N�n���>�ô��zJ�/~4,D?���dM�2�	��	��'���P��C;#��ʒʡ���j
<�ZH� Lz3�d2�W��3{�W�o,� B�&�Y5x1Z�Q	ּ�sg2j�tX��0��6C������o;˶�c��úx��r=���ot�����������f����Ti߰����MM�6m�p>�O�j�����KҐ�|�E�N��6Q_^`�1'&�N;~1BWw��8|�׊���jW�W�EYƝ*�8���o��G���A:���	y�U��-��:�-K�$�$aJ�O���u0;cP�o�OY1�JN>?��(� �4���C���.��"��;-�H-�e�,ʡJ��u��7W����g�:���t����{Ҷ�����ye�Eok��I�u������G��Mː-�MF��0t�,�#�Q�LT\�������ouɺK�_�2����hY}J��4;YB�){�H�l�L8Y��YLe|Ij���W{K�@������lWd}6{QVq��h.+�?����c�Q��ZʂR��� �^W�m5�(�:��̷OP�_o��Eó�+    �2��˘i��Wfb�|�Y׬�n~t��quHjU��N
æ}�1�hG�/b�����tm�.�שUR��hR��I���Ja'L�7i�D�s�p�wG�fi�y*�]�e����?��
�X��U�Id8ȚM��X[Z�h'Y�+*U������#��[~���q;�p��$l�rH!(lQ����h���t���U*��?�ʳA���)/�|[����}R��c�Vk��$��<�\`���'L;v��@�F��;�[G��F8�H-E�P������nC���� ��"�*v��9����̰i�bf� ��ё��W��7(���� �<BB�M_�7'��A�ę��/i���p����f �E��٘���+�l�8G�Z�� �7�PQ���9�u��p��L�y/���Q7a�(:5t��ýX~��gmw˓[n:�i�Z��)�C⩀�Ċ}�T�=�� 3[��̒S4L�S���}X�h�wu�ߐJk�L���g�_?���e���=N�_A�W�(X��8_%N8�?�B�8\�+�ދ,�ȠW B�\_�����5�q4��Z3�(Y{����IJ0�D ��y��Ѩ��v�ی|ë��Jsl Ѿ���7�����ÈO�R����M���qL?��X:�!������h� �E]6��	?y� ���g^���x�,�9��-u�qf��c��v�v�ϬK�
3���?����o��&�cװ�ɮ{z׎Јg�^�
��$���vYR��_�q���X�V�'S"�!eԅ��{��jH���?�rE�B*,�7�Y;T��l9�n�'�a@!ug�f'�U��z��v�윫BےW�4�3'b.�PQ8J|�ͯaݴ�P��}����H��w���5�=�xy�0��Yx(?Ԭ=@�����!���I>�������3,ex��ԃ���\-�|�����?�u��y8�u����P3��AZd,E�b2A�ϭƁv>�2]��l@����!G��Ѽ��.����e�jG�T����wt�5d��W�Њ��B�ʴH�q�=ܙE�,s|d��t�`h|���Yi��"�>b�xz����r���P�S2c�L��,�2��6��R��*W����*.��Q]'y�`
�o3FInW�9���{���D�vfI����j�jn��v90�ׯD��l���Wq=����	�kRfSp���^�
�A��Y�'4X�	��f�c�Ӂ=���Y���G�8Br����TqW�s�2ج�j������,�To U�`B<�t���ԑg3w���{�`�&Ү���8$�m���������f/�Uڥ��Z$u��E�I���8�d5�ӆ�R3:�:�/���^VI�s!߈PY�E�P���<S����m�O�?���e~P�j#L�S>�ɹ�,lˢRd����ff��b��hN>km�*,�����h�)�_SF�Y�|�8��1�\�Ώg]�aZ���0�U� gHvLk�  *���-URU<?*IRe��\�ѧ���NXk� �l��>�4N�5�4�D���g.���~�!NE��6t)��,�H�n�O�E�,��-�Z��A[�؁L.����/�AV�Y_�7�̕uag�L�wt��煪I ��V�{r񈜵��b�xHF�yչ����CX��;��q���6)��B\�[<����*^����T���>N������0޶{�D��/m����7"��-�p�S�� B_���'w(`��$;�]���p�}����X��ω|ӎ��p����ە���NA�X{���^��w��c���'��%� �)7�(~w͹	��{���|߿�B�Hp�3�GL��V��j�mv���Ķ�g  ����~�G�(����� D��P����űš^�`�Jו��ʬ�D�G�|i-��Ix`�!"2d2��l�O|@{���'˾j����HҀ�-�0�ǧp#�ń����) ��X���G��2���m���M"������l3%�!��H�ú^�o��2+JÀ�e�U��k�|>���̝�D���:a@�!zT�����ԥ�T�U�/���N��'�
Ui�CC�o�@��"�����I$����s2��3#3�5��N�r��C�WC2���Lĭt�b}�H2�x��{��N,��?l���D3ƻAݨ/bb0P>�&d��w��k* e���r��hvp3�҇��ho�
[�=�Y�'� [�h� 25��S���rZ��P+��#���qej#�n��*[�v���<�M鿬����1�@�{�h���z�[�T�j4��\v��� p�\�Nnxm�܅�[� �{��[R������O�gl,���t�t~f��U�)�#;}���!�L0$���,�*���n�WEY�N�*�>%*�ȼ�
Q�;�'�>��� �R\��oJ�V���1�|�WQ���/�Q�i[�02�\���WY���NZ�:���rv-QŇ�Oq�`���Ku�`G';�*]�8/���l@����#x|�{�_��W��s�ğ���v�q���NOI�-�oT�U����<�ˠ7Z>)��$�W��E\�F�-wb����- H����n��\��.�GR�8kQ��+~�x��w,�!���zn!���kO����YK��S1�t1y[���H�������S�"����~4>�Z��0�������v9 T���|����sW�<��+};��~�� )�|hZ;����IO��f���.!t��Ѩ��C�8_�8� �"��u�zs�����ME��$�B�����Q"6������Zz�?V� ���W�E��7,�}v�K{2]}#oK��I�R�ᓱ�^�J�~Ak�����o��F13��!���(z�0���ߵe���"���%�[���n*Նy35�x�����o�I1�{(ҺN�iui�d�*��;`�N�Sy�t� Γ�Ʃ�1���CU����Ȣ��,-���������eg��s����6'�� W5A�^�n�@;0��(�{|	\��gĿ��X;R���-���G�@/�@�����3�����:��A�c�S	�;���Ta���T�\ ��{1{��$��p�έU��U?�Y/c��+�w@ �H*�+)�S�m�y�N=�჊5j18@
�+�_���p�Y�>����E��0Nn(aG
���4��1�U?
Rq�Q��q���\x��#���-�|f����|�ey��tF�PE>0�������K����6^�����&��[�ܨ\�Cz�A,�Pה,ۭ��Rj����g7�c��(D⿩���^>c���W��$�$z�,��7ՠ� ��Kw8ii�t���.U*}�H/�­�$-��C��Sk�k_�r��ϛ��d/j�\ը��|��9[�,^���Z{Â�J� ���HX"m#P�3M�>=[o�#e�av�CeBؓ���� �6j�9��a*���V��G
W�+n��U��a�T������3��������/�vTڴ#F��GmU�t7��Oj�W�r���٩LQA�B$���j�z�q�O��u�~H���I��0`���O j	��L���r�7B0��I�p��u��E�5ڳ��˯/\V�7�i\�M�h]Eoty�����4���FA�;��A�c<Y��"d˷�\'���ԥi0����:� �EV��o �`�s���� X� b3�����JCqLS�	�]/�R�r�P��$���d��#�e�i��������'��6�隕����)�������{|j8f��/�V9�V��7��UZii\��������x:	�.�e{z�8�ɟ�_H�k�ou����&����{c��e�7�����h&�/���86=��>�W�N�0#�(��݄��]k�q���a�����}�O�j�����j޶U�FP�SI��u��v��C��Bщ
G�j2i:�� p/�?��>����2�ί�,�tQCo&doCa�*���������;`F�V�`�l/d�+2�BT���    ���i��Y۶U��m�hQ˞��t��[�~�I��~�v/zbh�gO�;�<���3�8�Ll7��Q�>�~l�-@�
��9�&T���=��>yv��Je��A־�w^��Q}��}�>��P��И�e�����^�����Ee[�d;c|�O��8D��������Vl�!�ˠ��[��>m�������L��lxt��|�L�7��V�� ��h.��k�"��"������+��};�� h���q�.�������"R�򫒦,�\�#D*OSj<߾��K-l��~�ssi��	����_a�� E�<�RB(���\�aq;�(�Y�����r��0�Z�ΨU�/�7���s!���bh��p �ݏ��򥪫f]��g�*�����|�rV�i���Rz�&b��OxTThn�5���~��s/�du�Wt��\f��*�� 3���ˁ|1�������ڻ�_�����&�s|˧�7C����%q��`G����^�5ڸ`���t��GJ�����VQ���M=��E����O_�P����7�5��4�4�B��T�A�"LV&K�~�TqI�|���g���g )���U�]�w�jRGڻ��)�I�����''��!���S�UiI.}���q�AZ�����}&�H�=)Nc��}w �w�1X"��{����u��sqZ�cU\Yc�s���	�����"B/���
7�o �:-l\%e�;�j���%*�͚!�&an�tp��x�5G�'埁2����3�!-��!L�i�Z%�!��-�ga�����F&]n6[�1��mFV=�&����f�d�9�M���_ۦIF手�_�+�޻՟��i��U>�,����]�Z���N����o8kY����W�n'�:{}+��Q3�� yo�'�ݭ�?<�W��QEg����6�c��ń��u˟&�e�󛆴���^�4F.p#��l���=q�睸�>@��u����V�rb�O�\�8P�Oț�/<>���.͋$�_����;E��<Zd����xp���G���Z�(-�0�����ڦ�W�f�f~��r��T*�Η�t@�����A<�vc�v<Xc�^�u^s�m&�=!r��ክ+��RƸ����|i�&��?ŷ�
}��eFq�,Q�-����fwKt�	���<lN>� �2%Z`%�s2����;5�_�<����.Գl�;���⛜����n�=Z�Q<\��'c@���֙_AwP��'ك�n�J\�t2`D0>��Y��3��<p>�F�j�P�zx:q�]��c]�Rr���&k_�wÈD�G�6GhI�<�%�7�@W~MgZ����m�PP}���wH��G
�MZ�p�S��L4M�o�����S���5�j��c�nHAC�G!�A(��AJ��>�/�l��f��<���$+C��fїxf檦��kp8���^���.���M�SVT'���D����?��WH�?���Ù�E5UHy$nqW����kmB�}��6l誆e˿�]�.��UdV$uh��"z1 �o�)�9r��}�A6l��Dh��?����y�;������A?�S��c�/ �F�a��s`�d�6����ģ�����]l������ɡy���خ{r_��'��q�CA`,:&�!�q3�+�|�N-g����	��+\�S �m`Q�2��-�U_Q���?l]�&y�r)}lIhJ�_I>��a~�(�N�� $@��m�	jRg�K� z!�.08Z���IΗ��ꆮj�g�<�Nr}6�/E3��3���|�xi�tєӄ{��-z_�Y1z��q��(�;55������Ր�\�E�������Nr���'Q�7r�*܅��߼�nX��2��U�?���f,�:̕��'w�%)�7�j_��ߒ�
a�Y`�u�|��9�V0���jm(��0b�?�m�|5!=X�|���k�5�5������LD@�V�$|��_�j�E�-�L?鐚���������|���������������3"�ޭHYm��- ��ߊ@�� �;"N� ��IY��H��pY�����h�S/�5�����v7�V��I�nL�[�+7d �?Ri���#:/`)���ί��8��*��WVy��_j�M�WQ�s��GO���~�$���z�%���d��o��Y`Ԧ�����6F�{bO0�I��[@�G���Y��fȚ��?9/�NC��k�>���x/Z�Wx�l��}��T:45���"���7�]�|���:ߙ̏�K� �ɲHE������25�x���^��԰N��H�e]���GoԝO,�tX훢�Q�)ֵ��?v,[F���T���(��8�ð���A��U eE�_(]�r��Β���!��7m	ŇZ���>�0A������,-n	X^'F���_8U�Z|/f(/�>@��U�]D�b�IY )m�eR`���e����p~�9F>��oU�*o����*Ӟ��*�"#x�N���h�@��B��N0:E�>!y�"{�J;��_���}�-+/��b�\3�.]^�����Jo}��ѓ
L�v�l�W��o�'Ú������}+BV��;^�M6�Q(묬�SRG�E�,H�9=����-�ﴤ{�|q�V�%��[!��7�uq�$��W�J�,]�qD-�3�� ����"�Wf�"	ɛ����m{ܷm<���� �y}��Pk���0$Ѿ��5/o�+s�j�@0q�/��8���k�"�'��4����<*��c���6�_�p���7�����2�աI\�V�y�d�.��xô��.7/�*O�l�m+�����0��|��Y7ά���iՍ>뉐� �Uwc�p��n�s��MW�ǱVE���\u����b%û Ç(���׾~!��W6[�|�������%��!�eR��WD��n��y�g�ݟ`yCQH֮���g�=cL�'�r�W�������0��|r7��*/��#G�b���m�@%'����L�p�/ �Ue�ϯ�*�Ԧ�[�h��B_��-�,� �pNR���u?�L���Å���|��.���΋8�,��y}p��ΥB���Ԓ�A<�r��K�r�V7�ۈ�+�r�4���o\��Gs�2N��z��wX���]_�)�S+�z]�+��tD�-~{�!+��O��R���,��EtX�#&�[�����v*�&�4.j���4�ά�����y���T7����^~:�N��1\ס�/|c �}hCp㇆��q	>��χ]�v����U,��obSΏ#���AJd�w�O*_�C��������Z.m�>��v�q]��QU"=��R�=�#�yd��gӈo�/b�����81E �嗻i�����ή�����:�7���C�8��.��	th���(Ӌ��/��m3̯M�<���ê�w�Ȁ�z�ʩ�N���l��H�E������[_�`.�5ѫ6?T�_�M���?Β�(�o[�"���p�gJ�������C�s�!�ز^�様)h�` ��~ob^���?���2NoH��8�]����ڣH"��c�~��-��U�Zɽ:^�����|�ˊ�%�7�K\h��8�m/fe�)�*�ܡ������An'�.�� �h����e�q!8;�q"* ����M���1�wq�%�Nb����8X�b���P0nų���{�������>2i�r+]�4z��N��k|	DE�d@����C���;����>��V2��C@��)��z|(�o1�t��}�}�˲HC��и)wR� B�l8 �ö
P�F?B����n�.����`]�y�jӁ�0xy��7���Շ~8S�kā&�YE#�Lݜ1�*���ly�ֳ��>pu<M�"z	���y
��(�M�
���k�/��7�|���.Iꉯ_�b��*z;_��%S�0��O�� �@(��%@��:[A�W9���u�ʪ���� ��{�C��+x���-�텣9�����4
��D�    �jC����`'��'�cD��m����'kVq*� ����+_���%��Ӡ�+����8��r/�n���i�F5� �[����*�KM�-�Gp.p����Fͳ�q�_ (o�i��?�ln�LWr�AH5v���?�A"���M��N���x�������N��@=/A��)H��a�ӄ(X+b:��!ۮa@$2�ڠs��骖����旈IU�q(����v�"�z�PDY����,����_("�KC���pE�cw��s�A������i����(e�$�)��WUq�=�l�9�o,n�����g�U�wi��xPQ��+ڂ�c��U�|�s�8/��+�"q��|�ey�ժ42^�*��.�x��
v�[����2P+������]���-)O��2W�Eo�s,u{}�����D��U*��[��u��Pu��eRۖ;�jDT�hV ��\���pe�v�'ҥYi[�*�>�߹`�H~�n�u�^�2՗)�R"@!���38�l���ț�شN]��VJ,����|w���?���=���жu������q�d�!h��5�\�Z7�o岤([�*�hbd��Zo�(l;!�p�bs�QJ�5�E�^�����b�~�\��r���2�-tU����敛6�ʭ>�YX=^0�N�W��ς3�K�l���a<0���`����?p�|e\ږ�rћ��Je2 � �z�`z����N�j�{�*O���M��UZ�T�2�;7���2
<	[)y�U���{��O�Ȋ�^���� �t��ۅ�*�-�����H�__����_G_��Ⱦ"&��2��)ւI<A�ۃ�X�����$'�z��s���o��J;�.�>㕄��Q$jd����؉��@���uw�x/�Q���eE�l\�F����+���m�'�g���,#:�򫴪���r7�w.4`.��UN\`)�ӓ\��m��$9*]>V��yܴ�Uyn�ˣ8E�P�Z-Ş3�M��l�;�UYrä�H�"��"����]�&M��	��g\�U�0s�)�[⬈��7Ε��>tiZH�+�un�ƞI)���b�V�����{
�B���9���#�'D�X~��a�ﻧi��*���f�٤	To���glK�0E�ݭ^AbG�-j��U1�d-��u�\��Y~C�\����G��U�|l|{��:�B��(�%��iu��������Q'yj�G� ��%%�6�^�.<A���+R 
���^C���t5�'m'�������X�p��G�����:���~�E�M��3�����"���/]X׮m����J�:�^��G�{S��j�h��X��m�}Q��LU�����#�����}[��ՙo]��K�7Dp��sj�Jh�fSc�B4ߐ����t��NĐ�Bҿ�:�P���w�M\w���W�4�L֙�Ġ�1�6��
� �v�lv*T���o��l:�X��5Pa�j"�ƣ́q?���b�
��]�+��G���(�1�����d��2�2�צ�h=�m��7#,�
|�I����7,ε���+;������c
|�~B��R�#Y�1b��C#~J�'q=o����)���ε
y뷰�1E���^Q�����}9p+��#���L�}��8� �&��'ܥū��&���l[�y�y�O8O�d�Ͷ���6bM�X����u??�V�������GCd�[��Ӈ�|���k�LQ����x/}05��|�Nɮ��8�!fy�!fe4�fǱ�A8n���Pˢ��E�B;�>'G��c8�mL|�+���\�N{�.s����)��wP��%n	���z[�:�P��i\��d�-\���N)ҫ�����9�u�� ���^����/��3��Ov��j�9:�>��/Ȭ�|��z�`[8����^X#�;�%��HkM;$���%�t���kY\�:�*���������S�b ��G�&%\��d/^ޭ�!��?��J���E@�C����t^��ѳP$�l�0T1UD�Z��Z�Y|�n��iм�k_>b*9W�Ĝ��O�Q��&�+K/�Hc,b$8D����Ȇ����S�t�����W�V��h�$����<���V�+�z��Ǻ����{��0r����#�^���@Ivm`��a�C�o�+l���n�-��C���BQ|˟��۪I���F9qq}�������߈�?1z�b�� ��-�4����LD�Q�!e�P._b׵�:��c"\�b�D�8���
���0n%�� ��+�4*���J�""֟�cE�r��yf1d�X��Zo__N��B��ۃ���5r���T^�'�]�[L��I�|W��۸����g2���	�q�sb�`6q�g:�&·���N,�lj������o�n�7�B�7���'[y��`���YI�mo�Ú[� �����]�3(�hѱd+A�`7�s�.�Si��m��^k(������b�,G�4�. i���F�L�^TAȖoR���g��W���bʢ��,��� ӧ}�!w����j4�p�Ň{���v]��š��4+`1X�z<=�#y�*Sw��]��}�Tu�D�� �DYPتպ AO�(E`_�Fۮ[7��B�XE�xZمST 1:�e�mB�J�����d�z ="�$�ڮ���Ve�X��"�_L��"�@�~�*o��HVV*�]=h�;�O�cY~��qyקvEb�t����pW�9g@�O(�`W�#��%��p�Q%�>6G��B���L����Ǉ�|�L�f��6o%�
4�I�XA�GM�\�U!��O(���x��5�&G���B�.+����$s!�%I�F �Q#���'�橋���"��"����S��q���B]�F_D�B��`P��6����K(NE�,�-�x|��R�.Ґ1�L�X�*�������r�{�U�ybA7�m���*���$��O��z�'�S���ڿѶ�z��cw�?���&1s�s�	����C��M -���_�ܷ)ৈ��#���3f��zn�������b��\{2х��&kqB�h+��o�g�ޛ��V�9�Z�0d$y�`�㱮���C\�iiuu꠰�h���;��χ�sl���qY];�v~\*�r[�����pj���QC`���I����m�,A�+[~��'�z]ΎW�s�Mj�"�S��'���@�e��
s�ec����ߠ�8�]�&(vu
�� ɗ_��i��v`�1LҼA,����2�[[�|`���
�� b�>N�0@��h�ǅ(=�!� s^E~�[��)n8���'�EU�=@�T�a�0n�X��I�^s��M�"f;�X�˟,�y_T��rEؚ$.
����jD�a��<�7�^y|��ٟΪ�xQ��cZ-h՗IW�4��̧����?/��څ�*&�0B2 ��y
CV5O��!Ԫ�(Cr~�:�t�����7��_֐�8�	��r���\���Y�]L��+I��-z����9Ҥ!.v5S�@��6>�^d3���Z�כ���l�~��S���A�0b4��kn��|��h��h6I]�k�����	�<e	 :��؜[8!�|R�`���Fu��mc�"�G�]e��}	?����?þ�=�ju&=IK��+�9�Lz����o�	:�ԩ��\� �������|��7'��s��t�o�9�~fYL��E	�3�)��YR:졤�9`LFG:�.�0ɦ���^1@@���	j+���K�O#��s�&�������G���������I�T�h��]�{\!j|ߋ��:�\5�R������먺���*OZA:$Lp�6����f��x��RC/�Jh/[6����>���&��y `
�,��V�ΰ�Ҁ�!ἀ����-gӕ�	���m�N���$��em��5��i^�ؿ�f6��G���P!���W���h$d �Op�z��}�t� '�	�0�:��7~uC�u��K�W��4�����^tF��     rn�g\F��6B=i�V���_�Zd�{W��AҲLM\ϥH��/ת�b�a���h`�Yi�R��k8��j���RUuR����r��0�;s����=�����'PI8����x������P������i�X/�V5m'��#u�W,�`�7���n�0�}o�7V�OI(6���ǣ//�5l�Ϥ���"u׮�ߑd���B�s�@К���I�^!�O�+��(���J�i���Kg�C���,ML¥��@�6�
C��f��_�*�����ڄ���_ �W��b�u���c�DEZ̯J�<�C#��4Y�H0֔։
J�b��K��@V�L'�xa��?��c׶���̂��˒�+D���W�R�{�À�|1��C��2U��<�ox��AI����,�gP���9<�ǫM�P�-�V����W������?�ɰXa�җNb�u��E3���@���F��R��|Í!t�����$ԝG��`�Ǩ�[@@�
�S��\#���[GS������|ݲ�)���(C��ӡ����7���#b�|9���o�9���3A'��u��SV��?�jR|��?�
�~P���7yOp[�73W9ӈtEsv�~���?|k��4�'e1����?8L�͉�I�^�CR󗹹bB������+D̩Z��cx����
�N����J_�?ӆ���(��r�K�S�,[��K�j�2yRL�ଈ����B�Ŗ.�r�v#��U_b��t�Q�zI���bj����<�]mc����l�AO/�y�����x�1�Vl�B_�dMK�+�o<܊l[�Gs3@T��s��Zg�w�jr�Uћˑ��gO����,�r�Đ:i\Q���s��n����1e��g�li���"�0��V��=D%|�_@&�Ҷ��z�U�7�6U	�a�ƶ�EB��B�x%���zV�/*��&���8z;��cN#'�/u��K���#M�K� ��=	ɫ'E����8����"��&!O���7� +s�H���[Du{�h���N��{,��m���-��������Q�U� W�����Kǥ�?���ן�8��<>�8`�D��c�r��E�� ��5�������x��i��1	������ 0J��7���=+��rjD?��*&��]�z�7&��^5t� �m@��wQ�zD�(!.W�hp�x���:M\����L�p&!:�e�`��Y������y�ǃ�+H��E�A�V*-܋"�,��d�"XuZTErC,�Q��eѤ�`��=�҅����*�o�u"8��q���Ye�A�?s��{2\щ:m~�����whF�}ٴ?�P��M��dQz����\��$@�����.�B�u�1�#䨠t�]:�%��������@U�E�}�7]�EƠ��y:{)�ޠzإv�Nv��ʸ���� ���k���IS����P��X�.k��sY;�sn\D�������;����<e�����m�ҳ辰�E���iS��y)|��YߐC$��D�e�d��!����O���w����e��,Q�/i
�A�Q�ocU�k�%�Q�:/��ҟJZ��1�*���I%����%S��5wu�\.gyzP������3#*t���P.����*��;|x(UQ0YO�	͸�yw>������x.Xכ{�5�p�?*L��7H)M*g�(�@1��V�ל)�x�z��RZ��ߊʑ.5�3�7xz@0��y��ȹ�4��x*�ä�rTq�i.�z3%۠u�4}��Է��c�:�.���-c�������"+E����;�+���i���b@�ś
�	]�x���O�M0�Й����� �������t����^�Ə�8(��߱2�Y���� moI�`�2J�y5$��� ���jڵ�$Y�i��>������b�q��0��_��x��*�Q�"��M�:ydV�d�%CX�T�����Q��`n�> �[���L�"]ϟ�����C���o�>{�$N��Ӆd-M��]e>��y��E����?%К�b
�i(���%��,�_q���,�ԅ�b�B�@Ұ.�UkR�
(���+���8Lb�-�Vg��57�Ⱥ�s#q��y������ [u��^�6�HmT��Ta��_O�qі�+�ʟ����"�>5�s�g�
��A�t�ʊx��s�f>0��U8:i��E2v���9�Qm��zد�]Dt�壀�����*|ie��"��`7+o�X��C�v9t��N"��_����^��o���2C�y��q��D�__�N�	<����� ���8�7� h�݈��E�����9&%��1^ 9Χ}(H}�F�BnW9�e�<�
F������
t�Ng ��h�JЮ�D�^?MO�Y4��������Wp��R�9�+I���0Q����
l�Uxjz�t�M�ɭ��E�xN���a�W�*.��RЂ�gO(w�a�
�k_����NP��I�Y��Q�s�=�i�lf��-E�V8��5�e3�̫�
�KLdd������<ɥ�=n�'�Q���'��u��p�8uSU�3�Z�.̋|�~�&(J������i�����I�@�׾ؘw?0��r�����QA�, ��F�Ȫ��!6��h!8u�q�z���!��{��<X`���B��[~�]�q|��su:�8��1�4lx��@924U��J��CUPF������#k�-��`v�H֋�:��>/n8gu��=�e�/a��SS^�nQK�E�/�n��JN#�6(6j{[� ��3Z~�Sf�ϙ_��EY��+���`�JAp�s�D���E�H��1��?��(c�Ĝ[`u[x�������A�ͦ�n[��{�^�������9g�rw��0�͸��?
ܣ��oV�밞�M=S|�C>5��a��>p\�
��YL~��?lN����T���V�b�p5R��e�a4�ɗ����L#�ԁ�S}�6�)��S�EQ&7��*���̢��yX�~Av��i�f�*!|ehc�Π��5Ǐ�J�������n�]�$aHX��; �ek��oE�-�L��A��~�^ߞbdߘ��� ^R� p�d�l��2i��7��&c������us���!� �-�.�M4�?�&V��e�f��H@���]�x �*�_2�������`I_��0�|-)zMD�'��q��RH91����Qܓ},$�n���{�W�lCi]���a颷��x�4t���@��� ��6�K�P᱖)a_�������!|�oBm\������:ӨȬY� n�Ê�I��Ê�.��$�Ug��'  :U"(� 6I�b�ܢs@P�	���%��m�7e���b�����1I�:�������VDE)v����*sA������KX��Rb��'>��oE�a�gU}��bJf��l�M?!U�L5y$������^~�rYW�7�*΂v�E�S�����b�?�|�uL�e�@ɹ�]����Ե�t�GW�l�8�Ȇj�ʣ�UKER�.p��5����.����&_R�$C̋@f˿���37?�i%��>?{о?S��-���C1Ju"3Yx����~��h�ҖN�JQ�S3>����n�J�4���=�����ˉ����?��O1��>R��B�:C���;��7�����â�3�������(�kw9�I���AT��8w�A�<�"a-���^���XeM O�9-3M�gߠN��د�A�����p��d뿷�Y�xi�C�B�,��c	b���{�!��f�7�Б�L4p��o�X�CU�P���-7&y�$�GV'��A~�Q�<�Aٔ�E�(<A��ZY���+����!o�x~�_�u]e���v_��MhJk�����&s�0P����M�,�eu]����4K�0e��Hgh�e�(�<® ��[A�
ǎW"���W`��9>bs#BV+݈���;W�qpÀA
y��мKx4����ٱ�˭^G��8��{�����=n���|������{bDr�    �nԥ
L�~��tVFl���ќ��hz�V��Dx�Z���
 q b ^6eW��yA��j��
�Hr��5�����7[n#I����-��ܗKI%�jZ���-k��I�B� �X�������P�gw�2� ���iI�(GD�v��s?��K�D^:�(������$�_�X�������"��|�e^7M4}8�i��:�
�tޫN��G�;NL���lA=f�ߌ �~��ҬΦ7�qQ��P��;HK���6_�b��W&��Ꝅo�hVԠ����c�5�"Ф�}1D�뢺��Ze}t�	t!��;���>�T���H�DV�e�U��2��mv�^�z;��30 ���)��p�*�]8=�I�z6��q 65�\��Nj��	��O��QG660���
�)cC���EGB7��?�A�K�(�wR��c0u���L�t��(H��X��w�+�������W���s������FLM�1j_�4�
M����2��7F�e����R�U(����ҋd\Q�2^1b5�^EF��5+��.8�? ݺ����� 'q{S�2	��k���:j�QVJU<���B�}G���2WM\w�A�
/�T���qU��X�'�޸���NN���� ���H���8g��g�[��K�����p�Ln?���᫧7�Ie�0����4JfF��`r�ѡ<G��W���v�J!�j��H_Nez�
2u�'�	�,"�~Tb��=F�� j����F]��b�R� �������Ti�$�,�O,�j��>�z�,~�ѥC�[MÏ����ߩ�"n��YF�_Ֆe0.���1Z�߭.m�
��� ���5��.� �q��l�Zv���w
2%���պNik�`��I,~�k���L����fad�*~F>$�C�T��yPb?s#�!]�\hq?Sv���-��&���n�������.mᡊ�����[�q^�>�v���B�S�	�a�$f��	Y��/طN���mZfij�n���QϖH������.p��]�P$�U�ӯe��z��WI��t�6~��
�}S��PVż�O��#l�le�4���ݶ�0+�dGU1H=[��ƷO�Z�}xl3K����
*B;��K�H8����#0+�HS��ݠ�
e0��p遨%?����0�"jY�V�UY�U�L���s7���A�WZ\�J��mU:��T� (�&+�d��,��w�UH3)�L��3��QܢE��B*�K�#^��mM�����垄��"x/m8�+J�*G����NČ��K�4	 �d���Y��Ru�>"��ʲ˓�eH'�5�U)N��M&���~y�	�S�>��d����f��U��iE��D<�22��k�^�0+���w�몼���u�P1�>˫"�t�Q���茨)�4��\��ʰ'ZVM!�R��$Aff�M����#�(�fF�I7"�?�I[�ӵxR�d�W����Nxk���Qj�_L��u�M.���@�������v���n�޶M��w�EZ��_U���P��&�
 O��j�f�T�WH��=s�O�����w�騏��a�TCH�.��®�"�eU��4	�{	ų�geH��s�ZJc��Ȩ��������~�Q��S�0z�1���٥U�N��ܫ_��O����<�������& N"���7;5U�����W�]�z��e���<��˝�ݦm]<Dm~dP���>��TM3�)�/�
�@ 6�0$����-��tU	Fp~���s�'J�N�E�����D����ᣭ<fD��.l��\�ޣ�#"�0⺺�+"���We�źp���,����*��z�e�Kw"� �\�ˈ��ޮ��k��,+2�|S��s��7Zq�V]n�Q3�q#Fi6�SWuX��c>��י캴�b>T�E�zu�F����-���_�G��6!lh�@R%�*��J
n�1	��0��n����Uef����=N��a3�ZofU>�>�� �t|�k_�ӥ]d�$=�<�P9�B#��`���?�D���@z�z��mR	�w�Ue���+��M����� �}k�N�'�xA$l�^<�e}Ur�gD�Dwe�`%�MҔW���
����4C)Eo�ڌ*�!x��������5Z�p-s��'GOH��A)����$6.m�f���c��сV����-�a�'g����.3O�|=柅�+nb���'��pq¬����Fy�2]7
�����W�T�T( �~#���qq_�N"X�l��Fj݈��Y����<� ��S�\Kq$o�Ȼ�ۼ�b�P�yY�7�H״Dg�0*q����U���s�	�5�m13����o�=�������#��YE%MB5��*�Lã� r��g�:����k�Qq��CFYSN/��*��E�� �+��*'���%�U��.,td�!�hp������9��*�%�T�v���~�,Bㅋ�j��u��ķa�kF���Ё~��$9�U��ܺ'�4ˏg�l�)IS���R^�r-x������Pi�O�RD�����RH����˪�{W��\QZ��HO���߽��0�Y���&��ͨ���k�:��Q:�&�k������$��p"�9bD�;�U~��;Ghh���/�0i��E �U��O��(��FT���d����A����B����l�a�Փ��J��Uq�Ѕz��蕣�.��b���������C���ɂ$.Py��$N'�;����"j2�:]"8��ًV�,��҃�%>�t����P���͓8��C ]����fq|!����,�%a��g��ܾ�x�i����C��V1�2�	�Z��j�Ǿ��[�
�B�&%!I�D��-.�����"�_�NUe�7qд�+��;�����u�ۗ��H�_�ڐ-<%,�yg�:���OX�y��^ܛe�W���'Enzt�GL���n	��[Ӓ�fF�Ȃ�G�+�Ψ��ȳ"����ʨ̊򊐦In(�*.�O2�=t��m�.J*as���M�bR!O�����u��}<�Ԋ����ڸ
>�"��T_D�f��	�. NͥM�n>P|��rME�d6���321q�y����t��9���h4��R��dĎ ��` }X͝��}1�@������9��3���A�u����[�9i��rĀ�� �q��z�E�ӣ{� �s��a2��#<t��ݠ�����!�,�#��a#L33�o�R5��a;�%�pS��q� �wTQ�w���ۂ�����ݭ�y[�u�N�e"� �N��;�]x�ad��J91�u�G>W��#�]���x3�0�g@��#��8[g���5N��@�UyXQ@�#���Xr5�X�x������]p�O���&�@��<zG�#�y\@uTL�)�4�#+��8xc��cZmB�"�ШX�=U���"w�Ϳ @<����Q��{���@��=�~��Vu[]qbQ+���~<��8�u��a"~�(���&u��	��K����m9����U���P�fW"�Q�w<��.�7��WrfӏL����J2��A�|�$	�^�F��{�����P�~ɘ$U��"\q���J��^9�t���:U�B��+?U+D�\ƽ��c;6�4$ʨ~*�s�\�����r?h6��_��݇���x���'ҳ��������Z�ϘLRC+��j/����j%X�D������S�E6�����,QF{z��Y�n7��N��7Y��wO���K/�*��
q'F�`�����/\�$�p�u�L��,O
k`�Fp�2K,"\��f��(������� !���]�C��+��^M�h����;=������l�c�[��v�F�b����rX�8�H�B}w)l�|�"����ٵ�7��DߋU�t1,�h!C��NE�������,*߭la�ɖ��A�n�4�>��'u�/����'�ɺ���s-�����2eN[�� (��S�2���S
��a¶&Y��W�-	Zh��*�z�Aĸ�b����\    ��0�lY�T�#LA��7@w��JW�����I��I}E���(�[5��X���ȹ�U(���5&�>���!X�/D�:�2�+�K#�yY��<� ;nt��k,�i�����@�.������p���ht��������(�'OP��,t�H��^Rذ��h�������'����WJw�FJ}�eQT��ǳ_�Q���5��NE&�8diX����8��O��( PI�hzV�`P�Cs���0�o'R��s*�x���*��Vҗ=E�&_�*
��3Q��m'D��F��7W	����+:Ri� ��}��L2�o�9������/"q���Tf+.X��|,��p.f%P�X�?o0�8�Է3�]W������rO�%ϘP��1�v�l&�S���ݸͥ�bl���3����v���Uw3���(�&Ҍ�0�ߛg{�i\�W��Өw�i|�Ԯ�N+����s��5Z+G�۪&6���TzFآ l�:)��aKì�_��u�ﮓI�xP|v0�� ʝ2H�������:m�޻�e���L=؛��ǎ�/1.H/��HF���u�R��_�`G��%�p��4Ϧ��ݗE����6�+�X[b*!��2(���sd$�Aky��v3x���PʷE�������(��8<����`�9X*:ֽ4C���X�$�?a8���	+C|�������U�Q.�4M�vf#k[�GW5�aȮ̻k���,%)�:�Ҩ,td���?�^�����u�ti�&�@.{2��V/cz�Ev��E4���W��'/T�ji����B����$�����,Y��w�Y
�zOH�T{�#����Br�;HGS���X��и
�B�J
>���t�n�Z�I��$vu6�O��G��'���3i��<����h�o)|��x[S����԰AL=��n��	��m��kpu����/�u�s����5��&��B�B[���{8�]�g��qJ)��k����O�<H��~�ۋ��v�c�t�
kT��`F��G`4��n�L�<���	<Yw������O[���a\�7���z[̿1Dd���q"Eb���y��7�%��q�6�tSǗvT{s����=Y����iOV%�W�dW�>�W��e��#&�����R/�y�@��]�ۯ��$i��ud����Wea���q�ͷZ����y�'�2���?n0���l��	఻�du��<��+�)y�����z��'����F�] p���M��!�H�V@c�G��41I�'5��]R;Ժٸ����6�(�W��Dv�c�}Ƒ2N�l���u�q�Jy�[�ُ*~����I�[ �J�����a��7�n���d����^La88D?���z4 � ��ֹ���8=;:6/�����헂y���G()�Yܫ�.��*����խ�H�a�89�\�bӎcc��]K�B�>z-/���^1�.���b��Ɍ�h�F8����8Z���3j�q�r�5�f�m���GG�⛗������q^奩�UY�
�6��ʃ��%��������~x��P]�w��`S+��=��IE1���{��Tw���Wx�X����Ӹ5U�O�ă���m���~�~c�s���p2�!�
�ET�"ك�M[)Zes��k�r�Uz�*c�B���Ym@���^ˎ�*��4�~�b���������i��t����@�� ����ca�����N;�[��{����܂�Ǭ�]X7��kff�We���y;zvq��H���h�ʆ!8�|P�F>[q�l8*�HD3���q���􂹈��#B�<x�1վ#*�YLSԎ�r�2B��M�*� 9�,����ȓ�
 j��#�?+uߺ�Ҩ�TS��2���z���~.)����/A�&�h��~����.ʫ/���rX�>�y�͛�vldV���38Y0�>��k]X���3eX��a|F���4�(���@xU �QiiNx��z�3VA�A�n_��vߦH��ˤJ�l5�5�N�쓔�������$;z"ǹNA�����I�7W�(-���('���'r�NA"�$��I�%쩍��O����@*������yUzB8�@Qܪ�T�h<ZZ:����|2@�_��e~���uYV�N�ZQ%^-5O�����W���ԑF�I�~����D�����%n��橷���RU*R��,��@n|�]o��ӍY��*d:r�<��Q^[�P�$]�tAܧ"����S,��D�$n�Ew	M~���qWO��U��^�6��mm�`��Z6�k�gu�k�ɧ�_�I�M6v�a�mJ\����^h��"Q-�9�/?�X_�b�c�cd��x/:�~��g�WI��}���g��fU��6{?��q�E�R/�8,��ݦ�&*rJr��!V��(fe��4������|�P��I7�Ġ�5{]�]`�JV��~Pa
���
��p]&��*���j�<�(-h�2��DE��Dk|��Zߟ)A4���Q��e�(�}!�u��h:3
���2��6��")=�p܏�]CXsսtD�4\������t��3�1�+��������,R��X��6�Z��kի��B=�\����_��v�m�|�M��fT���2$+�Us����G�nN0.��L��jl=�4�V" :/�O+t{��ݻ��m�z�>w�|����-����ȵ�G!�h�zAߥԞ�4/8X�
�����hJ���� 13YЮe�@K>������(8���vh8u[����J���'��8��O_\�6���`$�t��~��J��Ճ4,��o�B�������N�����򱂩�wΩO/��H�s�&�k�^�L�0_�:�S�ki�m�w"��x�4U��1�0�5���#d�_Fr�����1&������b��\����5
��_�Y���b#�nd���n�B$��S��>�/� i"��;�Ծ�p.=����2�� 4�jݬ�n23$�25�P��|�4�)�V�bW����{��Ks���MA�[��t�L�Qh��"
~>��r�X��|�W���\K"NP�� y� @C`�]# ��₌�W1W�R�h��U0�m�gձD��p�L�l$�g��u��)$��1aK^��$��]�a�4�-+A���'*k>�[���Ż -��ƀI��=@��lF}@�B@!�4��f��(�[UNY����:����c"WN2~D��Ib��96O�r���Js����p�o?Q�a�O��������v�E�Z]���e�a�[��r��2��
\��Cy��_B��a�^t�����z����^�G^e�H���<շ���m����ǩ���f��o����A��Õ���,��p!�[A@��$市Vl����ɊJ�R� �w~0e��x����X�:��8��"�3+��H!�b=���e�گЬ >xw�
i;C�  w+.����,e5Xm�C��]p�2ۍvbsE��<�G4^��F����P���5j>,��ەC�&ޒ�;<����o��u�SIf��-
�������Îv�5T�~B|�I� w��0P|��w 8��F�yN�߾����tz�EI�!�E�:��wgu���y�� ��۹��0l�+NZR\���s�@�\6��z�j�Xc�~�z�A�	�DG�2�$�7���7%#A�6���=��u����j&J�QЩt�ݰ��:h����� �IS�8�Ñb��`ުbӞaD"�t���.�Z���u����de�]��(x�=�0�G������0|� t]���^	$�,	�uY�a�|R�IѳE��򕔏U �C�L�DY2�	6�����g��x��8Q9�Q���{a��tO<^yiҰm��i����_(���+�L�N��k�����&���	�����ۯL�E�]1w��"�T�2^�$��<FW�U�H�A*I�'�� B�~m�n���~�⸊��%b��M�hHw���7����?���$�W|��ź/�+*�8�O�/����$�ʢc處����Ћ!���D�@4Q�^��i��6O/��'������|�3ML3    !!����{��S呇���,�&��rzUq���e�ƀ��"o���3M��������'���>}T%��+�����%M^&����b_<ba5��4�OtC�9��8����D��K&R�ڣK�bX�����$�W,o�*B�ʹ���c�i�<��7*
�*##�k�C���"�k�{�ԙ�aWI��z)`��EzPL�dw�ju"Gp��ůA����h)�N���?��?�����8�A(��yF��~Z �2.&��:�,ѓ�BP3- ��&��� O6��T��>7��c��>2�)���>b��4���4�%<�%�r�';ۋ_�����q��r�)����BY��ȥ��슎-	]MjӪ�
����E0��Y��� 4zVO�I�;L���!UY�~Gִa�L?|I\�-Ynv!�l+�\�q�L��x�dK-ndҩ��f��T��m�|z��0�������֌d��LF��A��߾�|@,�iY!DV{'���Bn���i�~uنQ]q�Ӣ�����@�D���.;���������)��n�~#릣`���� ���.�P�k�W?��X���d�7��}��(V�5BTT�K�9�Q���WŹ�]}>m�
������
�4���egRdy����:�z���QK4��$ �}>6P9B�� G��bz���U�^%5���Д6����t�L���)�[�L�=����eJ��Z"�X�?���>�~m�4�|j)���f��r�)�����mԀ���>#+��F�^�\�RFhh��<�����A׉0�\Տⶦ����ÈzZ�k$���U�����F�\�M�Lj��B"[��m����Z˵ӰW�o h��Ϣq%�t��w�n��=����?=
8�_�f�ȳ�b���&K��D��,���i�rR�L�s�/�C��*]T���ٽ���U*,��VVmo5)�:����>��xGw��.D�t��E�
^���2��_�f�uL �`#��͚�3z�q��#��F��G�D��)�;���˽�ʾ܅c��uD�#�7?�Z�Y������j<EQ��l-3��S��̰dx��͚x��
hC�5��Kw����i�$�S�ӓ�h3�-���ݭ~�"����@��=���L�bj��EgDO��T�J|PЃr�~�sA�*AZz	�[!3O$ e�iTH��&��*TئMƁf���0]夙��Y��W����[zK�����u��u4��/`m�/y�w\�è�%<��s�y��Gގ��"���45̾��0��ŘAe���,��묙��$Jb��I��w��d���׻�/�ŦJ�����Q߷��!�o�����ǗU��P�A�~�R<e�t��=mzA�4)u�K���A&����Β_]F�ѿ�IQ�&�f�ԷYU����+��������O�#)o�#;H2Yw����u(��c��!����QZ�%y��cP�V��뭘iQ��0�p��huߵD���ֈ�l�a���3%]��\[3D��,%�L�n��ֻ�?��(�A3��"x߱$��M����&"f A��Q���V����+XN�L�t��o����¢��+�VU��+��=���Q���~:�7�+1U����(Q����RPtC�-�wD���N�&�%�QUW<tE'�/b<��+©P�6<>�e�DԪ�'��)�(Ȃ�\w
�;1<FeH1bCs��U��wA�XI�y;�A%�}zxK��V�_ޝ��x�aحD�P��<�n���ģh+���"5�A�����o�*�(�5�F�LӞ냀�?�v5'0�B��M��2�i�O���(��&P�Q��T�v�b�;�۸�%�E�^4+��0��(&HYu�G���&��R��� "0FC�6���Gp�Ck	@/�J�]@�j1�a\6�<�*]�2=�q���E�o�F
/��˚��T�l���wIG���/}I�y��VI��kFMe�F�݋Ҁ4�`ώ"j�� :/�yT���꟨�U_Z���ul�5"��;nq.!mZT��l�$3�Ɉ����������E����������K��^ �)�%
E�n7�
]|����Gg6|�����_ܪ q�����\
32Y���-ui�IH�wc���+g]�{/J���'1 ���.� 9��x8��]h��mΟ����}w+��{@۶̯8�YV6(� �vd��AV�w���;R i�}�N��vB;G��"�.�2�呷va���%OY$a�؀(��(�p�He�#5����%���J��5������C��Œw��,�8�����bt6o.�wc��Adb�@6�c�>�/pA9�/�Kf̾qZT����
�ZAT��nһ�,V]��xU.��q^F��v�2��v�L_LWQ�YwU�y�c�\�N�-�@��s�W�?�3F�HM0 ���b���j�Y�\qQ���)WG�>^q�B�A\�g�=�o����/�7�pA_��%a���W�^���(5�C�ϛ��)�N�;�u:$��Z_��>�8}#����e���U��u��W��4����;Q�z#h�"��2aC�w��'K��d�h�Y�lB���8�
0.�sq�1]
x�d�JCH��(%2O_D.�x�|��k��=����Z�a.��B�m������]1LH0ez4M���7Y��B�͒��_w� �J�B8N�:s]���,g.I]�^O]�����*s�F�ܗ{�+���:09����x�	8=P�T�g��rT#���8.M(�������2����ܶ8*�mx�֛�bF��]����<bsO-H�6!���3��q�1g|ꔓ2r���h[��f?���ؿ���Ds�6���m���D[M�/�[��x��S�Rzri�I�ič����a��a���w�i}��F��x�0�hޅQO�2-�:r(i5�5
R��������&/��j��ɬ���5�dd�h��:+����mՉ�Hm�������IۄY3=,y��*.�׸,2���0ņ��R���07�@�OtS�	��2�JF#v�ں��K���=�.O/q��(J����*xKG4�ϸ�U�Z�s�y��5�G�ݣ5D�&�QʙԚ0d��!�ċ-������,�l��ϧ2�"��0�����D|�:<e2#���"��w��-�����Ty2æ1���k��j���$�ǵ+��%Q�FG�Gd�"�yĂ����@���b;��gz�>��饐+�B�Q$�+���?y�A�/����q��;�:��������L�	DH��Y�a���,i6��d�=�V��A͒��(��%��Ď�qA�zi��I��"��hP\�EӳE��m����᫟����f�~��g�z��t8Z��Q�L��\�G�}Ui�tVK��}s? T�K�<��/Z�F=�����O�2I��{qp�ag�����
�9]���=S��	;����nU[M�	9�V�{�>�1x�B���Mہ�(4#��hd��Az�lJ!"a��ֶF�P@���`o���E����EYf��$<�b^ �SkZ8gȢ�'�d���lC�,[G��G,��L{�$�q��jw=�����{��FE�+`Ӛd���Ͳ"���C�ą�%E��{Rғx��"�0�ˮ���G�/V��VCdeQ\s�Ҩ,��*�x%��Ia���Da$=�l��5/��I�г4#Z;��*-�6�v���ϚА���Ru�d*���v7P��& ���݊��I���r��h�Yv�ٺ���R�G�I#�a�ہ;� PհVx]?����� i�S��,	q|����n��5]�^�"��%K�@��OV'X���H��d��Y�޹ /ƚ�����6����C��4~2�k�j�S�,����&Y�c��X��kX���ty��U��a��B��B-�ڬ�gɢy����e\Ea��!M���sr��L5Ni2�4��q�w @�^}Ģ�Bu .��Ɂ=t����nC�g/6�0�GyM�o���TSI�?�G�*�G���ִ䈶"_    ;�7y�^������ֽbf5�%��u��a�C�DyOj�f�f�;L"�މ%��-���]ɝf/���utd�(����
��^i	��Q����Xhg��M��Oǥ9#�9�ΘrT�C=Im~��ܦ�ߟt�� �nl���՛��i*'-���r�~��C���l^q\!e��p�<.�T�Q-�\}�j��Q4�)���,_l�Ti4K��v����L�4�CX�] Z��j��x:�0���A�:����P���n���L\`J�[,�3����U_s��2ץ�����ڣ�,�q�pɮC�Ċ؅i9�Y�d��0y���+A��m,���Qe�6a�7���9���59/���M�۟�M��w�IaL�,
��JE���gU�y�m��7�ۢDI��s�^�l1����4�>�L���R0�GR��d�#�kM�Ah�J��ރlW����Ep�䰤�Tа$���	R����>="YA� ���y�F������^GzZ��ɼq>Q��/���-uI�Wӧ�i����R��]�ԙ���q8�Uq)�(�i���|D0)��9�e���3���]\����^�i^N�Ѹ�$�,�������Żu>���
~�ަ�'CB~���Y�X|�<�ga�Yѯ��Įq0r��u��;	k����sl�
����J�\�R��<^�4��e�p6TQ�Ms�s��?�E��E���?�t�����H���P.��kJ�ؒ��=���	��t�m��З�|�A�{ٓy2n�T�A��Ĝ��2��p6=^�$r\��+4��'p�T{rT�U�G�!Pf�SMv�It�ŉSE�:�b��x�3Z�urErɳ��.Y�bX���Ñ�vc�?�I_#����1|�|�#���HF����}�mф�s��H+�9�C���=&��рe�[���ʠr�Y{��W��i;�t�L���+�ײZ,|�uhE�tW���Қ�<
~HT-�;Y͸6������j���\ė�l�K��ʨ��V���D���oT-��MS�\�=���(\##i�@a"p���Ц=������öF"ɣ���|/_�6�筪�]uN�Vw�/^�x�X�^\?��h�N���i�|^k��C)�e��Ƌ�g�k�q����E���;�?��Qt�Ԕ<�?���wIݡ��s�,	S�����	S���]�Ml���� R@�8Z��Ȍq���}�q�ˬ���{�,��޴"�Bu��� 8C�x�����~�7�s�ZL�k>ZcY����%Qn'���[��D�hgǺg��
0���6҂��L�K�3�9<+�p�^�/�nq����j�
n�Ŷ�ͫ��G�9��Q|&Y8��������\��oT�х����u[_��̊2�Ϋ�/�2h����@R�֠�"�/7-��R�m�M�H3��Z!QD�;���O]� L�[����o4|��%��� �#z^s��z)��|�me_��jr�r��S}ڊ8x{�s�"��r� !By���`$>[D���&^O��Ȍ7W$��Έ[4�~F�p:AD���s���A�m��t�)��&B��ǫ�-�+Q��wi j$zH�$FXFۄ""��$�MQ�3"����bD��qa�*�U�	�Ax����D�{`K4��`�(�D���U^Rh��6�E1�}i�Ⱥ��c�JT�()��^L'�r�H�~ �E�8��������q$'b4w��rKй(U�W��uq^%�)E�fl�Iإ|��`�W�H�q����ζI��&M�w������b�{�6~�7[�jJ�5�L滁��Rp�NStZv���Q@ڮ�g9Ku�����T���?^U N�T�a*�7�]z�J��R�6�G1������a���>w��b�/��z�<P�q{E�^�ia:/e�H�51s�m�W0A����_�V�l�7��	mB�D�xTHT����r"����i^��g�ER���[F��]���j�A9�r��-LՇ��ߡ���	�ԲSFz�O�ћa��8饳�!��2\��-��y��WD7K��\��{��%L1�������P�g���\�> S.�<�y�	�h�-t��e��z��5�y�؆�LC%��N��أ\�夝 �)(��D�f@�U�W�"+�Z�����f� �֥Xiq")�nEj�j��뾓ݳ��Îa���®�Qq��k��[����o����q!O~/&A���cW�XG�J�۸�J�s�*�۹��}�����KF���o���p�b!��?�����/���B�Z���k�;F(�!�x~j�:$)���A�aR	[�XW��:���ҝ�N�}�]�y9n�!�B�@UB����vt��&HC�v�d�Î���P_w{=�<�f����l��-E��޳!ީ�)��¡ץ ��Ղ��qs:�B`�b>������겊ss�+�@��h�.��}Qj���5Z�O.Ml�Z�~�Ɗ�E,[L���~���.J1=beVB��of$����$5����[ �X���W�78┒�b�y;NQ�VDNg_�1w.��bk�.�O"7�mx�<�b ZFQl
e�J��`����RY)v��"����q9��l��u؇W���8�L��i`��t�W�������N�����϶�Gj=�T���8B�W�M2��@�w���(��b�������>��a��Y�� �숚� Ėk���ئ�v�s&C9HZ�wߖ���U[Q� ,`@�͋w�'�A���%T�*QG��	*
��lϠ��c���ꜻs`�*HxKTn��v�o{w�).2�n���l�m�J �E��}����}4���;��U���g���8I���Z�6������T^���S/���~D�Ib�����4����|1����uRf��C�2)�D+�*
�У������;t1ٶ��y�c����c�"�`h]?ܹ�a1]��R�:m�+VGe�'&�U�����ǆ�t���_]����Ƽ6p��S�*Z�|UQ��<*�+�e����Y%��=˜Eh��]�j�cG��lID�r��.� 4eXn�>S�B]=���*�}I���l�h4�*�Lg�J��G�ەϣ�P�;]�HEC�2���ԫ��cRp���4�/����(\)��&�p_7�5�����f�o}?R� ,掛��ޥlN)��Yh"ź�_���)]�φ^wYV_��2XT��SY}�c�~:�Ͱ-�E,*[���>I�µc}�N�	��-y�Y��sU�_�N5���s(�S>|:��W���Ͱ�r^�sA9��t�}z��<�t�Y�0k�4�	�PK&��/�36��X����~Z���_U�'l՗��T3�K��f>Q��u�j�nR�*��j~� �Y��=�s��M�vW,/��29���W�8��o��%H{�鈐�w��e�KP�.l˱?f�=5EV'W�-/���-
>S�`׹��Z;M\�@�)7��`����U�SLL��'�Ccv�`��}�$����I� ZIp��{�^��i �D��}�DA�(U{����\��|A���m�A�c25|��%'݀KPj@���N?+��4�����[�^A�X�r����f ��A�9:�wKEpŻ
U�W�{!^QZ�u�B�(��|��pԢ��_�|)�W�@/�?�Ų�lt٦\�WLJ���fYa%��=���$P�����Yw2���cJ�_ ܻ#ݾvBS�m6�ͯ�(�<�I�7�Q��1��V��ϞxЎ	��XL��D���̓]��#�<�1��0q¡�S��K�7�\'��^A�P7$W���]��ۦ�k4U�)<":��l���@��T�@�#Z�T�ßT����a�R
�a��ռ����SB��c��ciY��t���_=|�B-T%M ����G���u�a�_��/���,U�Ϩɜn*�w��w6�R�
�knzUe�y҆) o�[)kR{���L�u�x���j f�%XN�i.�E�f�lj�P�E���@�ٸ�0x�+1�B0�󌙍I�t�lr���q⋝<�e8�K_V�'4Y���{�� |�M�P����59,QSA�!���^Wk(j��~�b��lb�M    �6�5�]l㤴��o 0����th��9[]� �q7�1��>���p�O�OV��C�e�yx2�\��&,�����.�*�5��J��Q�a+n��k!P�^�j�BMg�d
v�deT�/1�aT���G�9M�Vе�,`t�K<)Ɖ[޾a��it�y�"OÎ�0q�*=
���3@O��E������-ci�إ	��TeYR-&�=����>���d��>�Q@���%d�)�����C���V{�y�W�ݼH|���࣒�D�TX�l]���r���kҞ�+�z~����E-�]}8��?S�G熽Wa,� �!~O��Q�ة�q�:��̧� ����Ԁ����P��7��E�B�>��[�����S�5����E*q���3�{S3�N�H��������|BB�c�mxW�Fs��
�2��G`Њ���h+uTu�o#X���4�XҌ>Rގ��2'Zn�9۴�-�urř.��4A�(	>�lu���>�#w�i�U����Ed�A�^I7Hv�:���r�"hD`��ܾ[p[�MrEGRfUb=J��U��(~�����G�yc� �3<�v6�O�'��}kip�}� q�?�K�z��_��|�v^��bH5����-]�s4��A����z^�e�D_��N��/����hڰ'�h�W;5��S ����*�bz��MbsY2����@t0���T�=0��D��^C(���$�/,�����#�"�e ��?���A\_Vx�pp����u]�W��UZ�=����
�A��	����H?*��>&0���# ��:�^c��(��#[f�Ԧ�	�E�p�d������IDDQ������ו��d��w��S��t@�����.w"`˵�	k�m�W,J���[E�Oi=�����#kD5ؤ	��hE��"�}`��l��'�܀q.3��w?��{�˟�2x>�q� s%"L�u쪙�I�����V���Z#h
�ϵ��`~ũKb��E�Ѕ{G��m����cZ���;<f18�c�E�~�����ۯ<��zZ���Zlp�m4K��EM���^F��׊���'���!D�Wz%>�������pi��O�]�]�p�2L!|\L�6�C\����M��K�x2��5}T��7�8+���2�y �7.���NF.Es�$if,u��rĽ�4c����+�a�&��q�ŧ��G�z�?>s�cY�s���'�I/L)y�N�o�x��,�\��D��Q-��g��vyWWW�[�>q|�P�F�0��%�Bٹ�؟�����]Y����;*�(��;N��]�b���ZǮ}I۹�n�'�s��9�CV�}~�CVe���م �c$�`&�����p^uP���3@��|��K0�R�,���7�u]$�C�����0Ի�/�8Cc���!T \�o���ڼ������"���p穃
$�]�+��X��
����놀	 �VB�M��ɐ�V�]���>��E�\o1��sߪ��v�q���{ĂO�����&��u\�\	��}���g�m�0.��K�8ɒ��*�R��OP�6����\[u>B�#S�̿w=��;s�&��Q��@r�����o�%�>��nz!�U�#	�{m��`�c�·���S}�*�7�,U�F��ܾ�V_����J��b���=Ly�`x'j�u��j�'��P��JJr�z��/V�Φw FI:=pI���I(�ȊQ��%�ח�oE�G���,��&>M����"�ČC��3�D�p���W���
k�Db��GĀ|��'�3tǙ�[��[��K2
��jn���6��;�&k
�k	��Po�(��?h�v���lbo �$��	�����~F=w���H��n@04/����J�GY��n�+E�']~���&����8n�G��'t/n�;��㲔�$�[�7IA
��C�?�����Qw6�_ay$2tzM�C����*b6�S�~�k����}l���wW���:RR��庍դpA�k�~�]��/�y<�N���5c�ܼ�j�Q�M�G'iT�T�dm����~���TQc�𧎔�D�S�-�7aҔ���%��Є��$�@��QY� ��pX}pE��B�|��p4p;�-zr^� � �{� /&J3۝n¬��阱�ȳ��E�~�x�R3�P�GPu�e> ���DX�r��NG�T'��U���mu{����$�	󾩯k�ť��2� V�2>5��nslb���[���o<��Cy4+GҜ�����	�*	�H6UV�"�
�X���<�N��r�&��w�\��=�n�	� �eL��L�_��B\�堍3������~z���yj��Q�x��ŧ��FT7u���4b:*�ď\m��SL3>9�,��x�A޼�~�뾜���(SK�ih�v.`[��ٕ��Z�@I��Jް�K����!�WY���[,-ͅ(k�6/��S�4.RO>H��5�͂A����8�#}ݸ��ZD�D������r7a���X{�I�k���~�5�\���B�n�ܜ��:���	�ȽVWT�p�5QaW�g]z ڊ������u�Y�+t6p�����0rm�$�d��ܼW�a^�*�2�(�4�j��С�E����{�ĩ��A��
�ڏ4*2�j.�l��UOw�����]Lue��g�2zw&͋Я>S����ŀ|������gah ��QqPj��z���i�K=������b��EṢi��FZ��r��ٽ=*o��
���CϥB����\roM��y{E�jm_5�%\���m�����G� p�qh�Me`�<�+��J�m`!d��[�5QY�'����,��ʟ��uj51�}T����!���+`����j�D�m��Z�"�(E��Xl;5�ޠ��<l���(�<J5���q�H�ʳݥ;*�:D��b�P�Z�H;	�Qe]ff��(��r�зM{������n�3����}U��i�~2l�hO��#WK�Y�@���G�&��F�����i2�A��@�!9�W�E�,S%Tw?r�UYy5��(���bӡr��Ɯ�>*� ԍ���%��]�?�o>��d�O����A��o��S@��/�p����'�DM]τ�ai�c��@�"$����``���X��`�$3׆�����"gI��8f�ŁX���(Q@������H?1R�}�C�&��f)��f��fEY��y��Ӌ��u"~�%�"�YgN��C���1���֖+��Q��*�x�!�=��;n^Ԇn��Z,�̥t��a_]!��eY���'\%(x.+�I�%�]�v2~�z0����)W�uD[C�M�����:�6�y(@��.�^Ify�F�˲��O��2@ϼ�^\�� ��(�ݠ×,]�5�1Y�i�����5Pe�2u�]�U��s1�7Qt� ���pqכ�B%D�{����B���/�Όtm+��Y=k ���, ȑ�]=�#x����z�t�4�)m6����\�o�b��m�ϪZ��m|#����W�?0��_����A~��Lؖl�k�T){��h�-a��A*Fq6
8���$�Q�F&�����3D�Qt)2�_����n�Z���m���Uy!�� me<ҝ�YU���]�V�@���pe����3)Tj�K�oO�EM��QQľ&*1�?���=�Fm5�^B�4���A�9Y�X4�GT���~.@���C�
��l�Q�D��k�H�7ox��M�e�/[�$�'���2EW@eDF��h��~����&�I0*� ���� 
q۷��MP���G�Q�	U����ށ����.��V��5S׿��	ھ\P�u���v!aq�b6���⚸O�� V�_N�q��Ʀ=���$��;�$B����"D�bs��z�$,�jz�gE���y܋�|#��T�^��r�?����Nl���h�J��'h-AT���o��������ܝ4�����E�<�ָx4�H�����*L�CR�	`�B��k.��&����"T���6eʉ<u����������ʯx��$YCHY    �RQ����>�@
�4N��t1h�lUl����Lcs{��<�y���z�ڳ�ĥX��L���K`\���u3�B7ɚ<�"TQ�y�y1���P&j�q��*��ڳ.��l��;�k�P��b��\��M���d�ܕ��͘��T��qʏ�)��F8�a���k��6��-�k��\q�P�&)���~�
��K�P+��n\�
�I����(;���5��kz��o3��F'ڙ���[O�Pq
�EN�ע!���%�[�Bm��|�)�{V�*���6p�i'�ۋ�~����~�^�NG����]�Uv���9f t-0 �)�}G�	�/�ۼ�=5C7���"���&R�W�!��W�l�R�3�6��Y�|~!�O�tQ�<nv�9#nu��%|�$c�Y��H�l�ᤪ��Q�5G8����-����V�χ�z`���;�'ĭ�y��&����>9.�,�|�\�6�e>�Π���t����x{�R$�#���r-�gG�P,��IQ�IW�LOGE�����E|��G��ĖF�'/p��Q�6����n����:��/]�'�[�i����;R��{�|��j�l������'8���ơE�e����E���*hJ���>�lU��	g��m�f��7IW�WL���g�E��L�w���T]�tGzAx�ǥh3Q���W�<Z߉M�|��`��������79ľ\�����8��a��_YĐ+Z�7��{R�w�L�t�1��1YsV��Q���=�M̍bkݓnHO����g�6�}�����D�85&��^�7�_�<r����3��:�k��������P_Z��J+z�b=�}�'����� ˥�2�)�-��p���M8�Iü��(_�8��"^�)���]ײ��i�k��6]3�v��!� �m-��͇�L�*n�xB��߄<x=�I�Mm�La�w�;�kj�,EVR�:)qmJ$a�`E�8���>���"��b��l�{���~���(��Z�Zw\N3�t����=ҽ"-I6{o�ާ�W���\��m3ˈ-��0��WU��SXo�|ȦŬ�ׅF?�.4i�&���SFa�۴� �N��W�#85�2F�UQ�������VܳrĀ�cŕٻ큶�
)Ǭ�*o��k��wZ��uEx��O��0���Q�P^i5vjܾS��`��ww�-/����%Gդ��i�OjK�TJ{��(�t=���V������U�>�I�n���!֋�z�A�&�����I�׫���è(����"�P�J�EɎ5�߆-��(<�\wLs��m�݄RH7���q7�#��Gqc�Y�j��98EU_w�(�_5��_;,鬐��x'��Y�rХn8:�:?��E֙�8��&��/x���e�f��V(`�O唽h �ֹ/~�.%��\��侐����j�G=Q��tg � ��W?�l�jI>�?DM~ӫ}�8Pq�X�7[�A8��bz��M��.��P6,�8�K�2	>�`� ���SS.�/��TX� �~���N��X�'nk�A�DNK"��&.�煽�x��e��w���3q� ��$����5$����'�w^& H�y2 ,}wv�T8ٵ-l���P��]-�ね#Vf��5NL���j.	�&��
��+|��,��b��	�Z���E4�O�q��J֣P���z�� |˭�gfeQ�^1�.�4+��-�����g<=���wN�������ձ�BU�
�(�OfS�Ȓ$��}^�ia�2���W=tx����w�5�6�����Y��*'�6G��a8F^.�_0�*B����HV�RK4�<U#ވJh;�ʜ��_-�T燀!ʈn'[�7߭�i[��|Z�b�p	�bӕ�4<��v�09�UXF^�,�w)��Ue���h�ܺ�_}�{)�\P+�>|$ɥ�A����e�� ��>��__ee�\�����s���ZN
8�V�\ac�K��wn��^�%��<nvF��#d�@��3=+l1!�z�J����e�l�լ��b�(��]�l��*��Ԗ���6�g�Jݕˢ�c�k3Vƥ��W�K냘Ï=��tۥ:���_��r�^s5���hz��`�!���#�6N��H8f��E�v+L��zs2����otΕzC]1�Y���T�
F�Ķ����mѡ�����DZ���i�4V�so�?Cj�������N���G�K��'��	�gu[�[�DX��3m����m�FB��������d�/OcD�
sʲR��7�-�,��ms�����D��H����(O2��+���Ϛ���v�efma�8u������!�'۷���E��0;��� �����bV9�2������t��'7��d�K�W�YVz߭
�f�0	9��r�ԛ���S�L4� S.�K����5�Ϗp=]�c~aDcJ�(HT˱Pg�������[��<�M��J�W&� �J'��b~��{A	R�GE(�ʩ�n��t�Ԕ�Mq��TU$��������  [KL~��5��*-��K;:�����R�_}x��@�����6��m �8n�ظVe\x��*.�SꟹC3����}^����a�V~�Ē']qEZUib�RU�8d ��0��P D��%#F&��G�&��TD�0���9v}���P���Z��<v�W?��,��x��'�>	&����$~:���֤��Ksg��TQ�:\aV����������ݟ�/Gy�x�
��ۼa�"�O�z�Bq)��ݍG�x���j4���~s��7>\�Æ&�J| �cl��/��H��~���<�ד-�С�Ij#���c-���"��>�}�?�����@r�ϋD�%��3Є��l6:�=q_r�$S*���qX�޷q6Op�lG�Ea�3w@g�{���å���M+4���������Is��b�LN(NYY���~������-z���(�*���.����Y��y��u9=Rq�~�"�TY�%?��ю�$�.�WM�DE`Gc#��u��U��;|�)̆������L��(,�q0�?�!���{G޴�0�Eԏ��N��T�ؖψat�f_�슔�&a�c�@��՚N���d���;���{�#^O�;dI#`�b-I����MSV��eq��0������H�?�$�YX'���3��\�L� S��o|,���u9�l��E�%u=9�Q�iea͂������_փ�+oic'�5Z\�e7�޼YhSd�<�Wī�#��w�����X�<L�F՜]�&�O����gGjB���EWv�<���"�^�E���%�"�N�4��ѱPA?d��f ��H��!T�D^]�����,�1��M�I<���(1�~��,��m'v��@��P�a9wa
#]�_�Y�d��[ܗ)�����Џ ��b�ϳ���8��tz��$�3p��f����3Z^骱~�>�W�|6�.��U��
&�l�UC[��g�^���x~7���]��b�^&uNO���
�#*оxE1���B��dfu4W���u/#�h-g�؇3IO�.1��3s%Q�J#V:�Q�ͣԩFׄ@)!Z�������K!a�v��\*��|�e\;<�/]��*�s9�1���VjW�u���(�\���_�2�f��a��2Y&d��D8Mv�Pp��#�]���DW	�Em9l�G����Q #
�Do�Sa�0vx�|��b˽���2�+
�8NC��Q�9��"��)]��aĢ���W�(Z,3�V���8����8�3hv�3�'�\��������r��c���L��BňT����\�������Ô�U�4_!�cB���K��Ȱ:����6j�5���iZB᣸}��˺+�Vqa��8��:
�� ��5�R{��>�#��8x\�+����,��^}��F,��&���Va2�o�Ųt��&�Q|y|q�+"l��ǉ{}0�Q��]엣��e�VE]MD�UV�g��RV��.`�D��+|��$Tc�q=KG!�u�~��]����+TiS_��p�Y��TP?s ��
"b���*�9F��    hn.ګ��<�^�&�t�}0*�)��{x��Xo\�ʆt_�n�J��>�,94�0!���Ŵ�`G�57�t׊�P��z^b���%R����Up���7$v|��;uL
V���X:Z_�t��N�I�{X�����dh�W2g3H8�JD���1@�Y5�o;/����M�`տnN�7Q�# j]��%z"�����Dڤ��yW�M/�b��r�~. UU����ĥ?*���<�OC��XˮN���ّl����PՄs_?a'	{OǓW�2�5����ř����n���~�N��$yQe6�����`�T���#$��4HѓB�/h�jG�g޹�^��jX�5�A���o�PuI�O/��"��Ȃ�x�u�J���@~X�f�?��3J��������ĺ߄»$.�RF�}����g[zT}��W$�ҽ� '�`R�$��cxU�*�r=x1���a�;���l1Z�lBu���+��*/4���fo�L�^��H��~�=��KI6����wB;�-���b�����u\���)BfIfmH��W%O*�UF����pZ�}����S���'���r�27�v�x��-�zΨ�Q�a�NOMi���Ċc�㉴.��ZU�y�>Ӕ��2��K�7|O`eyM�GX�}�c�I(��ci��S��qP���ʈu��b��r���:��#��� w���Ma/1i�9���cW3��������V����Q.��~'������c���- ���!��kvbPM|�M�0L��������Iu�p%n�׮��ʯ��q��(�E�8T�&���^I�De�~d#��0aA��$�p���I��E^�W��HB�����@�T���e�Q�-��θ�聤�$�n�ҟ`����P^@��}(W]��z�L,M�9�'�
����_M���j32�Z�s��w�R���R�YY6KBW�PHq�����k��/��\�#��~f���&�{��}�U��S��>���7����ե��3��\<U;����X�7_�B�WF���8��f�e��Fp� ������{E�������%�0��'	�
K�oy�
���¯��Q]P��lf3��A(����u�'W샲(.{��4����"��˘߭^y������(���ɪ�h��{��=�c���Z(Y�yE-O��*���W���r4����u�����v�$Ef]R���g4�v���5��a�	\����Ms��S������r���	άK�	L/�4��I���<���~����)'�j�]������^D����)��E�%k�cį~=��u1C�	ޥ����^Bod#�;���P��*�t�;62WF�g�;0�<"D���|���(�I+��c��/�~��d��y�)�A#�����8-�V��p#6q=� ~Amxb��=���� 
5QܬI�A�Q�қL+[�|1���(j�*ˮ�:eY��Na������)E�:m�GM$��z�N�̌A�u�D�����^�]����iZ�[^�@	^�ӟ�"`�N�=��Q`o�d��);�=Aυ���AM��Wd�<
�ҎV�2�Z�Di_��~��i7���(��Z,�&y��B�n��m�O-�8.,ᦑ�%�-v�l��� HҦ�r�ι��M�5���(O���g�8x���nci|���{K�����`Rx��Vo�OZ��;�D��̘�����H�M�����{�"�Ks��<nW���
���{�i3�\��ۇPŷ��q�S�_��H<U1M����g��
�֣��:6�ED��& �k9QdT�e��0&�%��:��-���[�^�2N3h�5j�ŖR�G<jV}�풉!����]Zn�<���텀9�D֨�OQbSk6o������ƚ��G�X�������ք0v1A�=�3�Ro��U�~V�ZƗ~1I��ɜu��"{������+�]H��Z"/��b�?����i�M�˒#p~�Kc����} �Y�� $� 4)��wj)���.�_I���-�G�4���Z���`Whu����t�U�:�y�Ӂ��s��'�F�Q���'��3��"���'"���*��h0r���"�C?�L0R��&n�Rv��У�H�����6lZ�( V�bX��T+�8J��mD�aa[������R@r�Z���B�Ke����wi���:��B�[ȟ��/Ǭ�k`�&Us#����09iB<n$�)c�Av��aO�N؆�t�����!��㇈��/��fa�^�$KB�*�0�y��k]wBFqx�ɇн\���ɘ
�^�<�6�k󪿢�*Ҭ�=W�z��@/ f��Q��C,b�� {���{�Y(�'3��n�:/o?'�e\�W��Y�`��[Ѳb�SԲ/ว"�H	�B4�tӕQ��A��6;�m9<�|�}�w�aˋ��G-	^=ЬV�E��A�F��_d�SG6ũ�����b��l���uB���CQT����Y��R��dɀ*�am#z�(3�Z�����[�O�մ�Y,���֒�mT$W<�eY��k�e�=�3 C��'�8%|�	��j+K�G���v��
)��rq�2"˃_܉p����\�
c���|Si6I/���h0lr�c�-�\�Z��]�N'5�a^��+�mኝB�����;��~.w��ڳ��3�O�7���.6�B�$^-Ḧl~����us��7������IV��VǙ��Sț�_C��&�d2�[������<���M�qK)�+f��s�5��g	e'��ƪ���G�
ި��w �V�@T�U��/\]s�1f�<�2h!|K��]	�+��/���|C�Fר�-Qsf�!&ҝ�E�:�IY�������������[�U[��ÅD��#*T�u�ڒP������K�n�Mh��$�?� �����������3��$wX:��	�߇aǅ6V`[QH>�^D��`�u�X�p"%�P��$�Yw�* ���Q��n�bP�ٴ�;w���xʤȼn@o�2++i�;��ێݙ�J!��CnJAUӏy_Ӽ~Z_Vݾ�j�'�����e���ĥ��N�W��-p��)(��(=x��/���<oW�Uq�9�C��Z������'���䫕%Fu*B�G�bY����t}##	)��K�]b+3��z`=T����ij��.Q��%��u�G��zVܭ^�z��&�@�,�G���wބ\��b�Ϗ����o
�+�ɘN)-_Cs�5��j #�ǍH1�Y 且�[$���RL����� ��0<�T.����۬s=��Ʋ�R�'��ݟ'�w+)D@�I��Z�(E냧�S�F�j�=�(�D����JEےf�JVRMm�݋���+i\"J/��.��2�rW�Cl%�V_�ӵ?_�ͩ�Ec��We�K�Lh	������zٓfӑ[�B�ԑ��Q�Cb�D��(7�m#)�[��&�,i��R����F�F�ʼM������Z�<�"���Q�eKn\W��������G��$�E�f�Vt�^9T��0��_�Z{�Ft##3m�,Vm�s����|��v#�{9E�ِB�	�����ڥ<~x����~Z�����Uy�ܖ� !J�5Y>�X/���=y��z��b�Q�"!|�C�.��P��|nqE�2WYa�}�Y�l��+����U��aUy��uWW��A�ð��ߙ�����5�d#H�׿Qp:lb�0f����Ҿ��	a������"���G�i �N��I�;+�I����~�V�J�][Lat��Re��]G�'@�e�;��.��'�r�e��0�jL��+�i�	��wV�2L���w�4���I��,&,\ߙ��f^��μI)>�~B�&A��Cmȋz�E�/�x�V��M��]�/���6�C�Hĸ\�<��O]�w�ķJ��w�E����鱤���D��m�����il(@0h�(x��{}UZ�hW�r���l��>��fJ0�QⰈ ��j�\B��d��w���TV%�c�$�M.�H��"l��+�*+SK�E�i�|	x�2����B    %��\ I���ҷ3��v��(��e�u\O0-�
WZ�)�@�l��	k�5��s�)J���QGng�)����y��b9,�l��~��a����-F���!
�Ч������j���1sT�x�Q����ݫ�mj���.;��d V?z?�g�K�� +"�M����_ZW�_q�ȉ��q@*��^�����瞟;������偮�H���x�^���֋ǋ����O�Qδ�e��4ò��(��5� e4m`ۅE���s��k=1zsF�,��R7oV��f�m�77�wH�Nc.�@p���6	g�K��=1����0r�`!��r��L�mF�z�Y�r��(�\,NJGX�h�!�"�v�7`ȴ��٩o���z�*|�I�$�ۆ����&���9�>boǗ[SH�pp%k't#w��\4�^��3�Fu�.�{`\&}u�`�Kד[����vr/XCY��۴�8y���R����@�)(��'۴a֕�j� Z��il�RT��t�S�0:	=c7��,��n3�嶙�ݼ��n��A@�<��*��W�����y���,T�!��ܝ�����F�����$�x��a.ǯ6�¼��"O=r��k�r��A��^�oʧ�+�[�rp�N�xҙ��aT�}�Gq��Y�{�xB�Qf���8����zgߛ_��$�̧�ˁ�+h��ǽ�2CD�_P� n��6�l�&�	/��R=��L��D���Ɔ����Wd���#�B��U�Paw �%�m^�G�Wo!Cf�G�9�x1)��|�۰��	)����-��o禿Re�&�����`2��E�I��)��0��x�j�0&��q��٧M��ƨH=������x�ς)6��Ѹ�&%/bnȦ�rT��	��D|Cfu��=����0����y�/|�^���� g錴�Bߺ�Qϕ˩��5�w@���-BE��?{	����#��v�*�!r���v��8�Eh[^\�s����t��,v��7k��o�ۛ�(�W�2�����L��吽�}����H�,h�nvM�e8e!�����i	D]s�H��>�( �5u�*��=�c��J3׾�D��r�JA$W�\&��G7�`ϭ�`�!���TI�jw�j�ВPQ�"�jb�Pd���0-QA��qaEM��;�jǎSW,2�k�FY�d��S��c��z
�%���Sav��.�_ ���}!B��ܴQ�S޼�C�Ta�G���PJ�l
o�. (��p|r�ῤ�f�8��ny��G�X �r0l��XY����QE���I�\A�T�OM�>,?@�#��_�EX�*D{1�1��>��{���a���»���n�De���B��x+
a�'�7p�8���5{:O��f7��nPv���h1��\��6Z�I1!�U^���&�Ou(�E�Ķ�4�BЋ_��ʇ�XBNg�Q�,�~���ʄe�Ѣ���i�m�4ew��!]��.�J��(��A�E�}�R3T-���=U����ioϺ�+[c8���4�#��w�����N\Sɽ��ҍ�O!�"\�bmG�V�,#�8l����_��qdEJ�����$W���v�=� s�#z�$�ٚ�[����ʖå�d���q]GB�fa�CX�<�i�1���ÞܩGd_N\:���D�\/6對Ӥ�P�YVy����(ޟ �[�s;,�E�P�ψ�r3幺�8�d«��w����DkD�G���ѱ&=}T}�nD}>�/#'�oG+Ɩx�	��r��AQ�n�]-�"�m�eO��E�����_@yQ�z�����Y%�:������fE,�H¤d�B!7!G*�u��8��A�p�~�pu��������IK\fI�X�����[��,���A����g�0d|�	�>��tIӸ�'�yZ��&Q���(ލ�ls=��H �K�=���-6{�˴���6Mo��8��^��R�NG�~��G`/� 4�2����F{��"�X�6�sp�ɢ��$��AJQx��( `"�utؓ���O�!��q^L$(.����6N�:�n�$�+Z���L���+l���Pp�0j&���^������]����'Y���(>�T�ܜ�`�_p�>�l�_����ځr�D:}��(a)W��:��#-G��$޺3T�����3�j��¢	�˚P������B�r��d�:�p/�04�a����J���vM�v�Sו����*��/�{��a;52#F<�ؘ��x��X���J*�Zݑ��E!�uJ bcoz̜?�/(���
�C� �b���x% Q������Yzl�w�5����֔��e���JͤE�E��l\w9��?�"}~��F��rU��.�M0�')�us�X2)�ИPI�햲9/d��S��ߚ��Qf�xf�h/���J��^�Ʋ��YEwM�$g�+?�⾊��Q�&<���5�����N�,+=�yߝ�R��=�i���k�?^A^o;Z�$�s�*T�G<�C��o`iU!���wQGv���O��~RdDK&�{�Ȟ�@+��0N^y�L�6)��+'����6
��.{Y�~�xe��S��\&��p�?�yTLs'v9<�Lf@mRu]2�fVEh��$r���0ڒ[EHݱA�aE���@�ts%�=.��y@��t�q6��ZgՄ�@�I����gk�Sb��R���Zz�' %�ʈp�d�AEo|˙�ΤS�&M��no��(�b+C�$��L8�@�G���X6���q�8�
�4�ˡ�W �!���r���1���L���X�7_x;�˷Wyi���?�i�FSҕ��M�a�P�b'��g����_$��_%+x<7���#�x.��9��\��a:�j�&yfB�I��㦘���ӕ8���<ц-�81I�"�%G��} ����~@Y��ȂS�X&���3l�ӿ�?���yC7v���0��Pg�Wo�#����o�Yb�J��X�p,�Ʃ��n� �:�w��RR��b����*����JD�+ ���������B���T'���k�BF�P�3�l�/�m�����N�ú����LuUV��`�p��v�iT$����4ͪ̿���5���
�e��8�O�тE�fsb��bZ����ʄ!t���ݦqӴ�Gi�E���"��(��8�x���iض��6�b�P�W�M()>���l� wb�����gQ�Z��A����&�{�d�@1`�̞�W3@���t�;p�}�
�����U�m1#��)��Vl�Y[MI�E�6oU��Lt���0�����h��O����~v���G��᫑�����^}��/������Xtg������[��M���a�g��3��կ�W����O��p�*X`ĩZn�6s9�������%�k�-NQ�3Hi��7�l�����˛�o�2��Ne&Ŏ�~d���#c��bGn��2�~ (s��𡌃_l��a���\	غ�����1��.&�)�UGk�����,j����1�\%nK\.q?f�k�~mUd��ͭ���k�,)�����=��_O��X��{v%Y!�������Uhe#@Q��S�0 �V?j�e��f�\N�p�I�v.c��")�8,΂������O������ٛm����.
��$�e1 �\��m���uBN(�,��$΃��y�tw�3?��S�\��M$ +�u>�e��ď�"x�a�O�,�6��ac�� �4�`����?�E~�������T��-$���3�-(C��0&�͗:�i',��G=���h+3�'��m+���������CHp=��H �54V��Ϳ:��5M�:^�k�� �]xe^�n/2�ڀs����\51V�ԩǨ��<i2<�f��~{�\���@�)-������=n)7p��zP�t󂓋����?��0�����+��Ė�{���o#0���*�=�~�7��O�Eh���y�ٺ���sB�I�sB��r���"u �S"Sl9��!�]�ܚ˽��W���-�~���m�f}��$��$    ��$q���_D%J��vO 爢��Q�"a�Q�,��ԓ�Ǳ���\��m֥��P�d�� I"j�j��f �)�Dv1��lbY_��~��#�8�$�зA|](c��@�Nࡶ��	F�֘
"V9M��#p�b����<l�dB�(�s�$���V�>�ÇJ/�,�k�Q���.��;��A;v��ao�!�#��+s����� yDd�Ųg���YB�لAg���������r����Nៗ��+97T5�"��μ��z��{[]�^Tt�l��(=�	�6Y�[6�.O�.���Q>��,��[�S˂F�� J)(�َ�͔��j+�H7��^�c�����$pxDp9��ٸRyV7�ۛ��C�<���&�ڮu���t�v]�h�"���%g?P�Fׁ`��b��w�zc^EE�ox�&.9�a�7o�6�9ޫ���;UJW��M6��+N��K�  ��1�Yi#����F
��8�0;�ac���~�ܫ)ݲi^3s��fW��������}w���U:PT�ET�U��T�_aL�ƈNr�6�����>�����~�K�F��l��G���B-{gk>����teei]n?$9��Ј�3Ya�K��&D�yY��,o�{�����Y����h͆��ݿK'D.�rs�N�(�������;]֤�b3��@.�����"uW�:�T2��8�N��j!0���r��#���N�g�Bҟ��� ,���'D�� �� i��4��V�98���!�C��ws�ޯ�Ek�����c��v�P��}N���纝�j&�ny8��i:FU9ݢ�x|�t�TM�J�v���+�qY�^��(3��g��������9"�h���MX� Bzd�UgI�6�d��?=y ɉ��v�h�k$! C�8 {�n���(����/����=��iv�L�"+�)GY�柒�E�+e7��[ȣt'�������pp��Z1G3��g�F+���E�-��� �_T���	�>uGW�<���z�Ñ:�oD�A"U(T�w/�X��$��]���DQ���"����,E��"�渖QW>���$U�ɯ�����h����t��'����\��b]��Ke\��#���cw�'�1�(*��i(J����J��fe" ��:U��L(5r*x6�ʱ�}+�(�C��.��U����X`��o����м(�����ֻ�6a�x�\�JuT_�NY4<;а#b����)jJ�e.��9pses�RkX!��n��Z��s�5�U2���]�tU�!1y��߬�d��o��S�����V�/�P�u�L��iX���E�g�����wͽa�Z�Ӏ J�?۾�<�x ��<���3�;��������o�k�,�=t'���Κ����Y`��WCKs���Af9��-�2��˾�4�'��%�x¤,>��Z�|��k3��i��My�&*zq뭺�כ3p-v`��e�I�'|LˍP�F�q�N!��ڗ�Y<6���Ç����Nǧ��Uj����������� ��xѓ�t{�eN�S;o�l��^&M��N�(�(���,F�g���/��li��	��N��H���H��$_fq4�.����Y<B�St�^�?5J#��0LHp�Ÿ�ZMv��m��3�ׇ��.m- �dI��O�7���N��J���2���c�-ˢj'(!WaVx�DV����`W��ӓHHa���	M��s!�u}��r0�Y¡�H8�H�P�߫-9�Z0�.e%]�M��ӐX�v��N\#��G�f�}���6�W���#y�&wM� A�H�?B$!��t%�l�G��y��"v �Twp���'��U����/�5��[����	����Ǚv0A���HJ�#��joYq�zJe��2���$�m�U2y�
�Dj��:I��2��~�K��d�+[��T�2-�q��2�Z޿gUY�U{�����·�y|4�x�qY����']H�s�6R5�A(Ժ�f�Zz�3�n�	L�*q�=�y�
@���&R�n�r����hА��b�i��,S�Q�O8kiT��|���	 ��G?.��2�_/
���`�9p�|[�Fyƀui]�V�fe��I�s?=«o=6dΞ�/'w5�M�2�wg%w���p����j$�NG%J�� ���}��0���(K�˗��ӌ�/ڭ��G��^��8��%#,vig�TQ^��n^U���g@��S��������\I�p2�G1m�P����@ݳ�r��)&�Һ7.Nl���b�t�[<�>�
S�/�(��8�t�ǔރÈ	.��%�kU��f���gC˻D�W[�G��E�\ǎ�y]�O��ۚk5A.�軚��c��k��<W�Wem�Nx�*�ɷ~��{�^2L��Ts�F��S�n���q�F��M_���c�)��ղ�T������}T�?[�ܣq��&*��*m@�Ч;8���I��ݫ�����DaŚYw��v�BV�3�E�^��XoLt[�CMM�޿�dUvY�㨊}�R��/��ܣ���=���|lL���A��a��Ϊ��? ��E�OW\U^Ц��S���9{�0�'��Ӓ��H��8WEx���)��K#����}�����.�
�ˑ�����9(]�tJ�^˧H��9���^��L�A$�0E���L�i0;��5�gD��!��"�C����#����'���6������x ���N�Đ)����µ/��q��z��_,}����Q��#����ue���W�Ӣ�y���zđY�n�_@Y\ŉ���33�(^�ՙjG�
�x����TG*�U/�����"��z������?�?(��8�E�������g��_���F�pӇ��dd.4y�H��=�=`�D�ݥ��>��z�Y�uM���zN?[�q߭�m	t��~s����8���G�Aѕ?�[�~S:�^��W���P�R�$hw>�޹��tX��\����fK�uֶ��@�an�u��c��P����u�/n*�
�>��Vd��)�����N���ފ�&U4�%�;w[�6�A����AD�_ǵ.�6mnN�yN<��J�ɓ)��;�`��$S:�o�I[Z��w���n�+=�Ϣ묘q�AhT�������8�����O,�U �no蕭�ۻ�U^�����,��Ej�S=��+��[�����2��2$�6-{*���6�Bq�A�]n�.�h_����g uӮ�	�ܗ��VF������S$i��ՁN���B0f�/Wy������bzo�=�]��'<�y:u�8��ծ��Ƈԑ�+�\W�-���b��
�)�G�#`������N����8�u���ft*���j�x�؝�Z�zD�(�o�� ]����l��$,&�x�A�^�_�zD1�mO^����ߕ�~7,�>m��BjH�9o��ɫ؃	i�Ϊ�l4�$�tw�i��(K�z��<�Q���G�lA-&�7�>�:
���q_T���(��;�x��|�>�~?�m������w'J1cK�Ƕ�|��F����-��uYM��e�'6,-�@�	d�^��r~C1*��랃b�4"��7N�����P��?��.`��7�b��~�rqz�sm��9� ��Ɔ����Ɩ�	v`����_�?��F��z"�2U��g4Qg��ʗzA�d
���&鹆���/��wI�:�(�݂��zy��i]_���#�����Ҭ�]�܍��FIʓ�㝿�����r� }X�C._�e:aB�ab��,
~��<� xԼVO�cw��WS��
�������>5:CٴA���/a�ޣ�f�e�/~��g��e/����jY35��>���s��6�r_)����<{�^���yn�U�pѦ,��͞M�r]t}q{V��8� �����ݙ������/����z׊��Ľ;��,�a?|���;/{�����H�\ް��7�t���]�W喘�s<�V!�g��NB�,���%����k&<�i>"�J�    ����YrG���(;d����X6�,\ş�D��pOj��텈b�N/��8�5���� �k�ܫ���"��1ε�h
�QH��J��)�E� ",Zݳ����=?.�� �)1�C-B���l������ǘ�Ĝ+�'��cK�fw��G�߉+�d�����Jm��]��1
�º�M*���r���vx�6)��g�qV���U|A�$ʯ������C��:_A�Gp�(c\V��k��κ�|���3�(���73	� J�����&�!G,Fm�0߿�i����2�a^��ۭ���(��W:�G�~�@����m��V-'�?[���E8a�Wq�Օ�M�n���3��Tt����U�L|�"TM��P@	6@�t�RT�[�h'9�=��ׇ��%D�����M�U��P�$J���*�P��p�;��W�-�ފ�4`CKrN�m�t���|�(������9Z�6	�1_C�������l�����8�!B��?뱩�u=��%y��"x܈� �"���!��""���'��\�OVT~�V����ճ17L"�Eq����U���~�����0�V�%#�ˉWε�i�>IoO�Io�_�
w���"T�g�F�>b��5��f@I�# ��F�+��r[�=�mX������L=[%u�T�0&��U��I=c�\�"��W��.�mѓ��X(���c�x.�WL�e���QVLH�U�b;�����(5T�:�fj��V�����,A�p�73��c��·�g"d	��©����'�5�J�=��1	&І���i��y���]�|躆�kש��W��&z��'�����m���t5^�X����ro�2s~Ͷ� %5^����?�t�z�S�X)�hb�X �?������l�3�ܑ�WBC)_Z���]C�OFAd����},��5��NC�݉1P@�~+w�<�,��1��w�����s��Yj"i������`"��kI���?��� 9xX�u'ڻq��I��d�a2"ݿ{I����K��]�0��zk�z��
=��^�8=��6���-\�V�X�_Wm;�y,�4�=O�I�E+��M�mГѫ��N8���"�g"�h���K�l��J����4K��p78x$ʛ;P�����p�r}�P*�:؅"�^��=�>Ie�xuI�vgV�TG�^CB��3�P�Pupgx'Kᷤu�����{}9>V�Gyv �~���2�����j����ϝX������O����Up�h�-�K�o��쏮�����P�3��U������o�6%O\E/�i~UP�<�Կ8P-Ac=��������?Π����g�fQV�B4t�����7W��X9^v�p��y��G��I=�^�Q�u|2E�?~<�F}�_DPG�VdT�f��b ڪ�:b��?c��1I2���+�c��1����,_��k��w�����/{m����w�GM9�X���*���<Ƀ�]X��*tH����h(�=�x���W��²,o,�eV�(~����� 9�~U���#
���Zp�gޱ��mY�8����,��4��7l ���y"X!z�B�^�L�%h7�r�1_��9~�K���}���ė�Q��h���n�E�Q�D�k��T����y96�\<�.+���ۗ�Ql�3i�%}�*_���j��#��d�J(h��R�+�h��#�-��=�z5�σ�9�~N���c�;�MF�
Nl�v����B��)�L�h�^U�&�CKg@}0�%�;)�τMn_�kG`Ѵ�=C�n�;fF's����Y~ �0S��k�ԋM�M5�9�9������f���m�� ���s�
n������"K�*�F=J���nG1AR�x*GM
:r��vT��ʚS�3�y^N+j.�eW}5!R�QJ����K�T��� ��k����7��Z��"�%�uo��U}��� yk?��V(��������݇t{\�p�Gy�V��Q,�  ����A��Elv���������R���L�f������P��Qh8�4*�7����V^]�Z�'�Á�J�s�}]���B�.d���k�&�}�����Z�磮G~�$k9*��~�V��rE-�xn����Jݹ�]��є�U�?S���P&���.�޾ԯ'��H�uG��[����j�_�L�����YK�t���Ѫ��֑�����n_�PѮ^�"�t�a��Kղ��T*0�*�w0����kM`䠺�?��|�5��ژlM��r����}�Fф��r��e��d?0|5� JJd�gnq1l������E,6�|qx�[�>���H&I�C��\Np�=_v��k0H��{��I��Q�i��A��Ml��O��N�dQ���ݑ��a��)8��G�weE-�����Ю��6/��e���/ǹ��h��ӧU;aR���!��A��]����.ث��������|���2�TYY��9���kFf�`�Yu\\fV��Y`����� �u�z?�0w����z�@�n�����`�m9���2p_���'y�����=6�\���>�Ğ����B�*�x%L+Y��ߛ=�g����)ݿbw_�E{{+��x�࿩Bι�n��[R��߆M+t%|`��ڜIޡR����I-v����a�_cWgI2!v�+%����Ù0YjQ�r�F+!XĖ]� r�>޺��
2�n0k~���[N~6�d��y|{���U��U�ß^DP�|�K�G�7��J�|��QC��{�_@��"�X�gD����ۼ� f�UX(p9M\Wre��*���zr�b��?���|�zA�������(t�0�ʸ�Ԁ��/Y"�E�x/��bPa��nG�	�5��{1��6|vʃ{%�nt��RH�����5V�MV�Thع�L���Q4B����aC�g��ڌȣ��m��o)�:�����	�����l9�c��7wD��-�h��B����g��X`a�F�<�}�Ƿs�y<"/��w�Y5�es��B��Lq�ա~�����1��|��2�Q�A��VU�rG}1��\�.�~��M^�p��8�2\����/�5���T��N5��$��ŇKBa��=FEX�&��&l�T�Q7�k�2��a���W��S�W����twa���dET�~c���#LBW�*���I��b{�&��4�p��k�����1>U��GA��|-l|Hh�_ޮ;֣������Oк����9lc��H�Ő�mV��,Qt�1\$e��b#~'`�ق����E��3��0�w�j���->��zծ�˺������H�0���I�P��҉��z��ry�5�P���zd �TjO��wН�����(��;
���
� ��o�����:�wڣ@�t�"v¤���;Q��Ѱ�#�޸慚]g��� �˫�����i�����$��&(fȄ�{������!�B~b1�J�9$��)���FG�g	���W��i{�^�G"�����O�"z"&Q��Z�}RQ^����va��фg�5Ծ'KJj&w�J�0��&A]�x�w��nF��Q���Z��vk[l�C �����������3PL��5T9A�����,���k�2����9�YRT�`��4���9�x��9�1���$2�J�^²�y��P��U�I�&6s'l��8ٻE�>_F�G%Eb'���$:+��d�Z����Y���Uu�n&���eI�U�Ub�l�l��G���K�(O�h�-iT)��X9��{W��^!��Iw�PɈ��W}�$S����o�C���R��H�Wrt��A��
�S��}�Հ�����r{G����=�>yb�
Ac�a�76��j�|�)��M]���e�Ӷ6��������4~%F�&��ɱﴪ~X�,���j��h0/{���{�kϺ��'�\��>7����:C�A��X�5�0��1|u]@��Ь�5;�Ӏ�=�Y�:�Z��°�p��0�C�J�8���d) G���/�b];Z~�9(qZ��9[KEy���T���$ip���ʰzaV��Ө*    \Clq]l�8����l&�%r��-��t�s�@R�ľN��3���.4N����"��\�a'�g �~QJ�(���-��,�EI���/e���ꔦ��+�d�a��\w�����YF���uG.m���O��A�z��٘��#�!7��${`�e[8#�9��7�V`�v���qS�7;�%X������-I��/�Έ������:>궮Y�`���`S�˓U���{���GD�|��&���ݴ5yZ��Q@S�H 6���,Voi''Jô��k}48��{��A'z1�AWV�:��D�E�M�/yY���̃//�>�²8#�p��D`�P��
�� �lC ���bï>r��<o@S�J���FZ?���m��t�E䰁��{�0�$�ɕ��:�Q��,V
����'8����,���T#�gN�Jx��^�G��)��4
~�gU�fe�q�L�$!�(RM"����&��颾�&��*L�Ķ i�^�:�u���5����'����+�i��������W�	���(��.� pSq۹�����=�moW��5��bJ�p��2�C!V��Ӵ�ʒ]�vX��-��"�{j��w��&�O�)�|P�w�`p�z�(G�j��������7�$y�$B�E}K�Ȁ=a�/�[���!;���,�9���m�� �ۜʋy�p
ur�Ic\z��M�'q�Vy.�d�e4��Uő��v��"��K�'c��e�.>꭮������jEq+�2lDq�!"��,�{�U�I?au^%q���_8i=F�x�|�	#�r�8m�?��J�JHO���z�%�9��+��l�[��#]�n�rB�W	&l�d���󿱞���}���0�������a�{�u��V��~'
ϡ��"i�ӵ'�G�?�y����H�?�dY�'S8�Z���_A?v�v��M�; ��>�+�+}]Ta�#��gd����(�)�y��q��ok����L�2�7<	�	�Wg����r2�_"�/�+^�R������	_�&^�&K�g�7 �-�z�&)q�x���G}�uCN*6���JO,,�������*�" Y�id6!i��DC�0����Ӛ�BŤ�-�#;`_�P�K:~��U�u�9/Q���=0
�#�{^u�y�M8�EV�����g@�z��8'�nF�ڡ�:\C�"n��!~d8��-���k����T#�Pq5&�"��i�m�A�T1Z�r嚳s!vc��jp?�K�3¶�>��x�S��EǷ�-�s�DL�2��`k��`�j�a+�r�H��ؒ��o6<sa��Ԝ�Ӭ
~�j��E�V�2c%�TǕ�Jy�P�$��dJ�0�;��.;v;�	�Q|���N\���1�Fx��j��l��$+˛��0x�lp��W`�v�)�؛�ś���mԝ9�:\s�.�c(�S�������]֧�G,KGfJ�+��cF�Q�S�G��������@3i��HQ���6b�8�7��-��滦e��ۣ�'��͓��';����1XҾ��mTl�ͭ��%��脉�1q�̊��Mb����0�͆J�**&���OE���'���j6����(e�����w������u�w*�2a|y����;�\1��ګ:l�7���@*�=�b��ĒNzD0]Lwp��۬���=�U�y��<�D�*�>)T�3������%P׶�iy���p�$M;���R�o6E�.鲰���EPm�I�p�֫g|�-2�{K�x�[���2�VS�:��!rK��]���,S��qy{u�:��}�2�;t�U!I���2�me1�{̢~���Q����(��\G��ĉ��������G/�P���� 
�@����`w�=�2A��,\.V4ϖ.�4o�	�.M�زi��=[�6�B��j_�b4E2l��7>��`W�#���ϋ0���v� ���3Oh��\�l����L`�^Q��/��U�긷&�rߝ����N��S�Q3�#���,Jd_7����-�S�C�z�(�֗�	8Qo��Žd��~�}��Śb�jP�A0A/ܶ��������M���&\�,�<c�U|X���P�' n#�K�؊o�5}Z$mx{��q��d��c3�^�M^����;V_B����`���W���'6Ŏ�"^����<ǭl�	�WTĮ����0��n�=UTi��J4�󊆴������u�.no��2NK�)Y��!"��VǢ�0�����l�K�vp\#�@��NS�c��N�ˤP��J;ה�3�G�&6-Aq��m���-�Ʃl�־�F���b�c!%1!P���?��t&Z���~�A1/1+t�~="Fo[��94Z�]w�8ARp n��d�M�X�1�� ��c>����p-�����U7
a��ڤ5�k���=�a�U�\�i�'��b�l��]���j��X�.�:�"7'��R�H�P��W�����u��b�٬x���봙�*�&3E|�~��H�UcqA l��`qްG����� U<��\�5��c������8M������"Rad�tThN6����ʹ�E-\�N�b�[R��,�"˲���g��E�
~�MT���݂;J��'���%�mO�،-��b��4+�,��i��<�,��a�~{R��ToF�F��.�y�{�%7��@�<-�3��ML!+�ux{My�Jh�r� yO��[w2��Cl�^�p��,v��,xV�����y��+cqM��K���U�[�Z�a�pR�RD���ؤ����X�P��pi��UWϡ� !D���s�5Z����VY�ߋ�
sV�0[�7<��-�|a�[�MH7�
5�_/�櫫m��\a�X����!{ͳ�B&Zԡh�u	��\Q��M��=tt43��O��)���"��k�����Áxa����)\��e(�m��e�mɚ��8���UY���2	̹�H�kY&�1��]ǳ��ҭ�NUh�:�\�6,5sEHy{����9o���ۧ0�����a� 7�}��a���O %�� �t-�k�U�\(�����\{:l�,���= ���E�!�/l�d���B&�	ܮ~]#����e�G��x�8ʽ�i�_  �,������#w���^7P����(������Lw�Q ��ݫ�wy����&a��"e� X�I���Nw@�;e�I�?'6�����!�¡�e������G�ὀ�,��
�)�[�y��}�q����*x#n���w�zX�Ew"�{��WMȲ���lܯ��2J�*L�]����NI��?�dr?\m�v�cĪ����uNX�&`Sڥ�����R<P��E�`'������^�P�&�������*�&����T�;B����TW6���K����%�Ht�(߆�Ewo��W��~a`��*	��ض������es��v	��л
8j��b�خ��D��G�/���#�ˉo�Fm�]�_O��+Ǉ-~4�=QDT+?��:�D<���1��|����(�8�S+N+ؤC8c�cؠQ�u�3��՛�+v�8@\���r��P�P~a_/����w킖j��8����0�mCPDaU����I^x*U��� #��D%�A�_(>EiK�|���U7P	6ը�q�ؼ����:ۡ��*�3���Tu|{1��Y�����l�5*�g�v�N���2�B�B�#J�[f���t]'��Hi&�m�20��rM#�r�|��)�ADf1���Q���ф�Se�[U&�蠗�w�ܱ��:�m2|-�j9`�\��]�.��uY��f����eӊ�̪:S�� |���pr��C��j#(F#/J*R�lCLC�&�(\��l5�j��ŌbE����,J�$��F*���*��&8�1����-�ZM��F��(�b��q-V��6�.�4���gq��X�����<K��+
`��zw$fK@���LЉ�W����]�\�ƅ��p�^�y���Y�����=���M�*G��ըC�>����cK    |�=��!�8�'�.U��?q�
��:���������r��?Ŏ\���`�߈p�9��A��4�4�y8 ����*�4��	����X�Y��2���AmH�hZg�t��p�F-�L�sN�4��t��b<�٦ue����%^V��(p]_.^i��A�.� �/����|���Y�.e�u݄Q�I�R
p��|�-Q��q�DW�  b\4k�f�!-�fJk�UQZ�g�տl �5>�S}R�1�����e�r���V�����ʙ��7u*ɠsĭ�]�&m>�UY�}|;�$�,Ҧ+���{R�l@"H\��Љ9סL�a*~:w�o�#l*���h.��TL�aĴ��N�.��*�v�}��F���m�a�	�N}�rˬ��ײ�����,��K- q�~��B�����X	��]}4�)�O8�=����,�t��?A6n/�����|F}N�I[3%���{�8�8���]Μ�S����r����AV��s'�)5��(��\[EI4A�!O�¼�(���k-_�O&�
1ҳ���,�p]�L�!»ͩ�R�<�p���~E��G=��X�^������˂�6�؏.��<'�S�����(N��������4(���@�Sφt�ҴKo�|�H������F�T\�ڈ�[��5l5f�QZ�O�Pn�W�F���cx�]}�(��X�P�^n�>[�[e����H��"\�*z/�j=DF6{!��W�����F{����|���5�~?烵﮴�ɴkP)��`G	��/��L�p#d�]��u�s�8Vl�j��'�:����Q�:I���{yjK>��kX{�NM���LM`�j@��wA���֩�hL?�X�śLm��_�y��+��dvEvʤ^��8��f��UE�� ��ˢ�}�W�B�#���H�s���R�u{�-Q�[6`[�ͬ�������̔�9�<'E���;\i"��rzsa檲+�	W�*�̗�U`��Ww�%�{"GV�W�I���B���c6�����v�f����@?���&����u]'���Z�A7�.��m���H�~{%Ƒ��&�$�bQA�ӎ��� �,AK��c�V���������B�A�n���'՟��h���
\��M�=i��?��u�����So�B����ɶ<�R��:o��*j>�K�DX+��q19��$4*����E�����WXe砲�c�0z�C��3N��`X��>|���ůy����70��;��<��c�QJYT��e�?7���=LЕ���T�����ݩ�r�ډ��G��{9{�d�/ؠ�特�����#F�І�l��l���g��Zɨ.O�\x�.�@��U�g���ӅX��2A�拍��+��"� �X$I�$4���:tc�POa-��x���'�Ʈ�p��t�D�ѽ�ԑs�����=���"ML�/�H@���;Į`��# %&yp������}N��F�2h\���U�
>���I��Q�ŷ��E�ƅ��T}�M�\W�������0�(0~@�7=^ȳ��d��;:�N���}U�Y�he��F��Q@Z�`#G�>��S���^T~{�Wb/b�U_��yj6h/�x�?�pB}��yوx�:<��$�Qlh������>eb�6�zɁRK�a�����k�U_�<�n�\�@���]����B$����ۋ[(��VS����kK����I��=��/ߣ�\�i�wP�c�쿓=�'���ԋ����!f�pn�p6�<)�����Z1���Ax���_N,&�����b�ٺ�:�����hQ�U�P�S�+���������1��Ы,˫�����+C��
*��c�ߞl� ����P�y�L�Ѫ*�|US�-�<���j7{,4� ���;$�\�GU+��asM6X�xv���r�й�P밸ݟ3~p	<�| ��)�e�"K�OR�.x`Pwbs���X2rCɃ���m �K��"�n?re���ߔ%a�Wm@�e���(�]S7%�li+�~�������\ e��6�rRlJ'��.�ݝ����������19�$2����A�8Q�3\a��`Ӆ�)˖Fǽ�u��S�=��/�۝��/�ޔ�]y��+2m����j�}�<��Y���W �q`%zyh�E�mS�Yu'F��0v�n�B�e�:�*p�Y��8��:g0 �.�՚�`I���m�qs��o o+�d���@����K�6��]��Jpl��J)��'-k��8(G� _}����yx���wh9ٹX��_���U���{�8�h~��LuU�QE�t:�)��Cᳫ�4q���p�z�
�E^E�7f�Jj6
ͺ�����EE�IdI��$���0�Fa�z�� ��ɔ!�¡��;�OV�"n��k~��q��/S�qd��YB���ʲP�O�����ys�<u�5��v�I/�N����9�MN�k��8-�!˂O���S�����9-��!��پ�aUGe�d�����X�d@� ����[6���'��4*J�b$y�7�_�DAx��X}�F�Wn޲|��sc�Wu���9O'F'YC����,R'�<�t�wФ�iKx��L��_���$kdOOV�V,y88E���R�4�����X��\rn�_ 8fȓm��/�}uAM�?�7�a)���?=o�kp_Yb�&�bF{AZ���,Ǳo�Ԃ�3W�w)#O ~�d�#<�t,��l��6~ĺ/�bBJ�����u4�������R���$`]̑� ϑf^OɸCؖ���_܄�z��V�y�+����$=��	WJ�.�~^� $�3ն{�´��!.��k�5MGiu{T�E��xU�,"맳�d�M����|��/�Jg�X��tx��F�JT�耋����hZd7i=�*s�5�nlU��UX�|��o⸈�,#+��Y��?�j�5L}QvJ��}+͒I�{�t�0νV�e��>Ǵl\��_���G�n�(�ݽ�&�[6�B3��d�]t�u�����MRWф7�(bϖH���L��h(�_=��d�b�˘��r���FM��T�2����FP�&��7�p'�4Vd�q��n6�t�gaw�x����#/�80X�ק��r�?Ee�JtP�(Dj9��ٰ�Mїխ+OtLY�O|1��i���8�R�c�c�{��7Gz��b
-�N�j�����$��I� �΂޳I���^>��fXyey`<Yģr�d S����s�VȪ�j���T������+�.;�_�[a�'*N�E��%�����Q)�g1��<�w/=�->]^e7i=�L"��
�� �e�d��n��^����>4U�- ּ�j-��K!��2:17��hxܙs߄�:�n�EWÿ	?	fOϔ\�}PaT:a��r9���u֤��2Ɣ�d��x�#qZ��F#���	�h�9��H�]AsP�ŕ�K�����m���o�]R������ĕ�u�W��2'����	߰��쿹���i'C��1J5�*A,�u���V[[�f8𧓋�^���#'�j:A�ǆbx���?m��X�Eם(�tB���^U�jo�V��*�����=M���H�U�Sly�O���ӹq�]��m�ng�`��C�@N_e�oIj�p:�i��X��э��O�#�|�>�4�d�"-���Q��7�����
��6���Ӣ�r�+�IX��y�	��!��ݙ2rF�w+���6L�p�U���2P�0N��-��^��B�������z�+D����F]�u�G�=l$�L���mgH�	ƕ�&�O����~^-�Z����֫�"�8�������q�����[-�n�P��	(yL4��,�����dZ]#GW)�E&R�QF��x�>yQ]r����W�&���G##Q�~��
2l����wU^b��V|�0�Ǒ+�_��M���pY�x�o�0�e8+�u�N3����w�>Pz�鳨�����X�L8Ӌ�d�6'h�u���(�#ϕˢ�'�(��8q��1Є����(��%�t���w�o$Q�w ��#B    $7����-V�φ8l�i2%�IT���ƁQO`��
�*:��7�%״|۸�:媛&� ]��ZV���gK�,���������<�D�f��J���,�-ETK��_2�,V���Dva~��W澴W�i���ڳY �-� 8�^Zr�B�btU�ݣ�9���2�W�^��z��q�N�"̝�Km�\�c��Ո�Ԇ9�Y�%�|�EQO�Ye8nE�j�-���J���9��	�����Fr�]��^�[�:���aw�B-�4��5|ń���q͕g���86t?^�M�7,t�����
'�?@�Q:�䕑�vʲ��V�>�3ɟ��u�b4
����FtaF���Q�Zld��5)&��E2���.H ;}5p��I��\���_פ����p����fY��#�׈�:��wWWݦ�����a����f�f.��e��[l��4�TZ�]7!#�Y�;���ӆƤZ�ƵJջ�̓k8z���I�����.m�bB�V�qj#��
>�T�x����TW��3S�7M����j~D��	��d'��#����9a�R�>���$�#�:P�*ՙ0���	!`Q=���B�kx�m��^��Q�{�c�D]��x��ʔ�k�P����1�t��S��]�=S]�3�{���\j�sW��k�y��{���gx�rH��(�wL�l�q=u�P��� w�Rw'#øjn�_�dP;��H��b���`R�:��ۓs��#�3O���7Gn(H��i3Ld`��ċ���lc��i�	Aq�ؿri��j]�S����9j�ly<��~5������HT�z2�D^��Z�3��T��f�����h��)��̂�
 ���l(�!Rb�6b��,g�1[���e�Nx��4�#�<~����	���q�HCy�/l����`��\��^�0���8�tٛ���r������߇}UN8m� �g���D���� dl��<����E���Cu�*�s�10��EL�Ű��q9��o�	1-��l����Q��jt�Qm�\VoTT���
	Y�|w���!�}����aK���}=XW54�vLƛ�BrG :ؖ�Č��"m��`�����WE6�9L�p�Ua�^9�$����<�.�d�+�Ϧ�{"D��E��u��o/P�4̼@���	-P�.�4���G[wϰp��?"��4�l���q�C3!6^����(�5GMܺ��cګ��M���8G�҅ѡ��0J0�Bݿ�u�u=!�YV�!J"l��.�r{��E�`�鶊�W�v�2Y� ��X$�m��i�l�^�˕�]�s6���n�$�x�n�H1Z{��6��#9�rD�M��B�_mz+�a�EՄTPD��E����W�˩sY�������l���!�uy+p��7�W�_��Ad\	� �E�T�l���L����I�	����:�"ޏ{j�Mv��
��v�� �G���%F�z��jh�|�D��X�/�rb;s1�\�R����,�ȆSE�¡ɖ�3�qE�~w.H�68�w�E&[ah�E���ޣ���� H���w��yº3�B9��7�G��+�@�
�;8Z!�
�b�d����>�L�;����`���]���J�
"�b�b.�>,�p�%��,����G�	�v��e� yk�N]�:7�b�YS�@ �����\���L��>��n 3M��_�2
~�&LH�q�t]�1\T����%��"���'{>�.�흉U���٠�ޢ��E?a͝�e�[�\��Y�����
�J�vW��x� 
�Z��d.+�>l�r����W\*�����_�IquV:�r�V��C��땰�q'�'DL�1�̙*�/���Iۻ�\��vi{U�2���Iܐ��	�1y�,Ţ��YmO�G��p��I�;��2*�~�̂��X��NV�4#c�AuA�3���P�e����QB]�� ��$�ײ�E�����\��>r�����.���[ɔy�##Up^�ō)�vx��`����t���amI-@aɥm�ٙH� ��AlLXՔ�{���{A�"��%9�/ɒ5��𧰴�� ��~�J��M7��w*�e��Faq��(�]i	4tqaX��`P0߃���AF�:�9G�H#F�ڑ��D���������r٦���W]����:4�y����%�?�#��t��Aw���a^Ne.�>J���}���y�)�%�kp}�L�y#§֠�{����2_l�:_<�Oo�s����$yY���6��MA7ř���
'U��*�^ի��&�n�K���
�g��7t���WPm���G*Ciﾨ�� �y��{Ee�J"�L"Rl�l�Q.�2��%��$�p'�ʷ-U�\ӆ��Pc��lt�~T�zX}d�؍Ԙ;��b��Gu�O@�di�U ��`^��0�EiFʾ���>��>?{���z9ؙ��8���庑*�W���4��F�GY��]��8d8� ��	�I.�F?Bj|-*b<3�~�r�����IqZ$���]E��̬�@��]s7&��.)cџFz���U7E�l�^�OG�z��:�:��%�\��Pc�C���	�HQF:����2�X�牐v��u�k�Q] f�_gOQ��-f��ALx��f z	���`��4CA�*\�U7�z�~G���UW6O��Uy��n�Lq���G*�bF��\/0S�:ђ>��WpR����_G�w*y��M!*.�D��%��V����"��,��tu�$�����w�瀤�C�Ҡ�#��JR+�^�� � �J����:Zi�Ytd1��_��ʢ��<y��ޠ��~����ܮA��%_���p;SV���?Jn]t*���WE!K�*�{�FWe�N�wi�{DY��#$-������\��xP�h��?�$�:��"����Po^ �fz�H|X����y�6F����8Q���RL�3���+���KH' ��p�Ű�
������xdԊ�,Pݩ�#�S,��$�'Q�7�7�yU��*W����J$�_��&�_T��$J��6�_�l���.�f�t¤����aY:��? B��9!�Ki:fB�CF�?]��������*�B�X�_�w�5�B�����Zo<L���_z{�-�03�#טa�{Q�
��"��_���F��k!����z.��Ȳ� ����ݳ�$o���M����@ư��8�@S���D��)	�h�������پ���	�)�`s]�W�a{Bx�av}8��/Ӣ���,�(Nso|�ʕ�3�n�'}:<GPSМo��TU>)(U�˛��L���O�&(�m*j�6_�B�Ӭ���k]���f���҄��:�&y��ˣ砠�1׶T����z/jeWY�<�k>j���y�IS���5]Q�I�X|"�N��9�qO��G��w�!0�O}�.��	i����?G�+v��[, U'�bv�>��V~�WO�؊>��Q ��y�o9Q��◺��N���(�>~e���_6���N�<������4�n�Z�r)���e���l��4�����Y�qQ��Y�}��N���(�#�m�/y��p9��\,�>�]u|�����(�^+���H�2?&�������0��I��<Bn�/.�"h��/�4N'��QY�-
ދ��p�F��F!!J|>D����K'����? \Y�N�ԕq-,����.ɢ�K�cR��7R���hW$�)���#�͔Q�i���m�q?	��ǀ��8�`�C�qc�Q�GRA�֭A�պ�<P�{	|q5lq_��N�	U��Xo����"d5�Z@�\��u���`Z���Z�o]b��&|�;�����Ě��I�����!�co����Va�ȝg��b�#G\\���f��1��Ӫ{%��K�3$f$�)��-z*�L��3�{8��r(�.O�y:�q5a�_�iUX^�����"7/J������ȬS�|P�^�a�0�S��}^tfi�����]]���,��Ɋ	b�e�!М��UJ�d��f9��X�5_#��E>����b��(�s�
�}9    �������l��w����#��p�Sq�g��c�2�R��
n`�F��F�<�T�k�{7���.�-�H�4�/���,�+���F�7�zՀ�u�z��C�Q�X�7�p�ʽ����l��v���qؙB3���0YXUm'��=[��4Z��H:�.�R�d{� ��4��z;�J��(䛾G9��F���ozr8pv���dq�NXlT�+��E��R�����B�-'a4�d@��a;Af���4��u�5qm����Kl��U�c�bY;��d҂J�+qz�����|�����������wU�F&�Ge�(�(�IxgJ��
pM�)��h��-a����ۅ���4�*�RKA�1�X��@�P�X!���,.*���%y�gU[���<�����a0*�ٞL�6=4`��I�����`�ܫj�#u�iQ��"�K0��W#���"�`{�f[�d뮛 ݬ�,�� �Q�� %��p�b�r^���Ȏ�A�VF�m8�zx��Z̸k�]L֮���UW�J��^������е+�w@�`�]�F� 8�Ho��a�pE�pf��e}U���:+X����o	�k��{ܠLR��x�˙�=�|�;�1���ѿ��	�K�s	��z&,�[��4������环�H)���-��
��?/�MG������sV���$�4ӓE����\�8�n,���fר,= ���F���Ž��`���2Vm��A��>�r��A��p�� ��{�Ϣ��ܽ��R��B��� �Ө����:�oq\ơ��<��- �8գ!��"���I�d��Y�L����hoD/[�r;�L%Ϫ��o�^�.�J�@�Dė��~⇆�K'�R@�$�WRԻ���Q�E�x㳹��#/���&��F1�����2��@-BQu߉�3���Ϯ������a�7C�����f���U,�(�YU����e�n'���(�j�
���k���� ��-�lr��9�S�>$���k����޺�Ä\�nD��{m�>���#�W^f*O��cG[x%sǗ�f�\D~��c6�l�n�7/s]\�+O��9]�$O�{d.���&a��EW "s��w*�i���9�ଞ0�K���{ۮ�zBT��k!�I|10G=3�4�닏�K�K��>�*}�9�.���r峑r���̣M�0W�I��0(B85GphW��h��l)p��Ҽz+#�>��&�{-�S�n��Bmlܿ�������%�/º/n��" |���Hq��bc�զ�g�*3->�g�-�|��.4Q{�X�Ož�K(_.�"�u�|M��r���3�-��P������$@fS	(�6m&�$.r�<����������j)Ɲ�+f�
շ��{s�!Q��ל|y�.�P�8I1�12�����4����]�bTe��4;�/սQ�g�\�`,4��`#�9���eV�*$~�1�7���R�a;-r�#"�1=x`�/�F˦�z*I��җ�ީ�d& �����o�ev��Z�������<�sj�H8}��4.���-��+{'d�4���yRj�,Lᣟn�&0��+�wX����d9�T��<a*������$�|&(��ș�����/���2�ZW+�E�Ef�qO�`���(\6��\7�1�I�$c�+
�q)$����U�D�H��U	q+ԷYϓO�H&��"�s�\�a��n={����V4-M5j����ݛ��ź[O��eꎀ�(
~D��_A�ޫ��RK����!%Gǝ��QE��'��7`��9��68.ڤNoﵢ*�J�8xG,���}ݴ#o�"
�(�@��w�L��Dd�N�+�N�\�Zõ����b޽�	�]Յ��9ܿ�4q�;���4�8�X}�W�l+����n�(f��VN�d)V�Ff��Z�P�i��2 (òin�D�(�b������ns=�r���A�CU��x�6���B�f� ��H�����34�1��Z����W��+�o��� ^��`��g�j�V��t��< �˻���U}�*V�F�N1K�6�ۦ~�*�	B��4�vZ�$��@آ?g x�[Y� Ã�BF��.������K����\�`O���I�[����9��%�̀�y pO����6Yl[<���0o?�qQU�)��S��#҆=�~r��r��ݡ!���t�LROI� QU�ϲ����_�eݞ��4*��!OsW�P�gӛ��26��]N�����v�)��)���gq�<�2o���(vEؘ�/5��|�qг�c ��˳���n0�6����粣��ʝ�ۧ- u�̅�Z���M����U �!d*�n���*�g"�m0B`��s�����b�� t�I_Y��t{G�Q��(V�ߩ3M�%X�6J��ƫ���
�~�j��K�	��t��--�0�B���(�=���{P�H"-�iY���� �E�i�{�LY�+96�q ��rh��0e��f�qUf�=nY�]&���k��%����k�!��J�G~�Z��!�#Ս�@�YO.q.f�<�S�Gyx{���R��'Y��m�]�(%q��3���d�~�����"%����+���Y���,�����.��8Irݓ�3�I`��g�(�A�ea�����0�*��	�7I���J�ߙa��Њ<_NkT��G�F����	?#θ�Ŗݳ�����ַO��4I��6ϲ����u�mzj$�������t��ˮ� ��qs�T�{Y�7��Xzsa����	70�s�*���6_�ˉ!c�[�?��l9���}ο�/@d�<R�hr[��ZG�%[�̪J��8_�sΕE��Ry2#�Ƕ�H������Fs6�����c?��'ž�^Y�wiu{���#+��l�$�ň���T��,�]^w^�q��8.yUx�|VB婻����ɉ8����7���$;s�$3c�b	^��̐�O��o+8�q).�z"��eê͋��ФK��Ȫ������[2BV?�e����GW�V&�mb�LBHW� -�=��4f�ײ�Ӛ� w�z�E�=R��� ��;�H
l�]!0NV�փ.��ڢ�g<qU���O)�7Y�X\����~����w���z���57��r��՚��0���W��k�4�<�=�	ʶ�ڸ�9�A��9� {�a�?����S����4Q���������b�rp�'��D�RU��-ez�mM�xz �$x{y�Tnq��7󀄦�B�ۃ%��Q�����z�RK����ۧ���̘1���T���SOz|�؟� K�5Q����1��as�����Ϩ��f��M^� �N�zF�p)�l��<H(�8ʹ?��5Vv5�f �1ng���y.��g��|=��Ŗ�u�GɌ�%ihȧ<ޚ�ǚ�Қ���/bq�t-uUN=;Z��U<bs?TB{E#O
rk���}1�Z���i:��i~��=L܂�����D�*�d,i���#��)��7�i�҄���rBɞѣ�j���0/�f|!> 4�Z�b5��b;�������L�Ŀ`�֢e2�	W��#��֍�@�{qꠛ � '�b2�`��{�u-R��M��^i��~�V��G���e*|�DO��C�@��3ƒ��z�N��Y�]<��ٲ�(�P���{�
?
����%�n���M�#�ɒ�,Z���!ث�Sk���q�\BL|F,��=k~�\�c`Y��# ���)E��JDܔ����ܸ |���|Mv��}U��oP�ĝ7�.nN�5Չ���_��{6� Q�ܰn�M��R���N�JA<�����6�+�o�i3WG>��@�E�Y]n��Z�q�U��aTR)���X �.��ȵ'׶*n� ;�*O�7:>6;��U�I;�K2�T�cXآ�S=���EW.���H2��ǭ{oX@��0�a�W ekZ�K�@} �PPW�Ƅ� E�F�_��*=��w"�Q	m'�_0���W�/�)� $�����3]����z8�� MV73�,Ob_���R�m1�=
 ���-#���ŋ�q���� kL#��sQxC�����"���7�i�.g\�*Φ�����I (6�Nl��    k�;�2)4�_U$��-���������<N�rWNR
�D���y���f@��0�̊6/
W��o����mFX�^�0}w����ȧ�|E���c/F��l>0�����ˍ<
�ȦUE|��1+��/;���8Qqw�5�e?��߁ǭ������|��\M���!_�~�Q8c2�GWr�Dv;I�A�;y���f怘 ,�um�|�ֺ�Gy���u$e\#�a�.�;nw$]�%2X��+��h��i�̀_?
��V��ce�aYķcL�$M�uO�+ޚt�ぬ4��O���.�	�a^���3�;|$�q�ڞ�.�f���r����8�2�����b5Ʉ�H:m�6՜@T�Ue|�Jӕ���˴�{y��a:�6��?����Hv���2�(-���*8wi1��(���q�y��gf8ʹP~���7�9o��99t����S�y2b�)�L^}��.3RA�$9\f���L��u�]����.M�Y����C�g��C�r��X�bd���C`��$�;�e6����y�׌eмH_6g����4ɺ��9��ll!)��{+���r��g�_�D�y>�H�U�f6�/W�p��0熲�d���M���~U��$�A��u�7�A�qz3b��~Y���C�"��)�>KE�B�`W�q�,�'��SrȎ	����L�������	�,�oO�ET��WV2���qU���;�Suih�}u	H7B��\O�m1xc�W��6XV��D�0�M����(C6������~1��鑻#�V%##35��ո&˭f��=�3�k[[xTQ�>��6���&N%�t����{�~s�.���LZdY��*v�y ?�x�4N[w�j}�X�]���ҟ����p��G�-��2Q�"}�h��R��߀��I3�?p�������#o#��eZy⨟f�n��ܧKW1���7nP�����2���']��gG��Z:�m��ķ>�M���J3�� �!���
1���S�C��6��톊Z��E����΢LB����Q@�s4�������z�^���7#�e��7D������x�m��XW�Yq���p%����Rs�T-���ع'����>�@d	�U*;$1��-w��Ir���9���e;��n�hK���G.R��[E�+Q�0�!?��A���O���Ef����#r���Y�gU�Z�yg)ݧ�)��������[hUy��GR��i�L�4�Ht�p:#-@�ֳ�\
"еC�ޞR�8̭�������7��Oj�R5����L��|=ª�1���}����(�2M�W�p�ő�տ���%��z�J����G�v�p��p3�a󀽖��N��W������/�F�*,fȤ�3k��*���iH'R2b��J��H��88�Y��a�3N]
�	I���'1��
Mfn�_ \���I7Cr��2�y��)�C�-j����~��1��	�*��ϏG���pt���˅v5t�b��>q�pFQ�'^ʪc�{Eb�B�̂M���0��p���I��Y��4^���w�z��u}ڦ��W�i^Z�\K��z)�Z�kR_}=��"X�Ǒ��}�Z��L!��JUJ�\�AȆ�s&:.���U�(@�'���������L��_�T��H�&�����.a��ﰶ�"e��P��X��:y���}<3��j%���2i��%U�@f�{�}�����Ŝv5"�/�~8#4���,�K�kwyooK]��%Mp>�z�^]�+5�2�N8Y�������g[��.Ǽ�l��i�^�1q��m~{�VEYjH�",�w|)Hh����PW�W��#z�K��I��.2�'d������������fXwTqRMɥ���������ғxm�
P�WAs��ڌ�7?�t�!���z�D쾏��a����d����Y�̂���t9��G����]��U�~��p�)K�2�6����/��`�'��J�:O	��'��I�dB�#��И@̪�&#y��*f������e������&
ُ��$d�y�{sbT�	�*r��"���G�)�� ��}� ��������3�(�^��>D�v�{/$�̓�����4��z��%��8z_�&������f�m�ɴ,=�@\"��aBqU�{�&l��=����z��,��b({�>ne��e���r+�v�����]m��X�;Ĺ+�o?ry�A�E��I���G�0Q��t���>���'py���@����3KԺ��8�]O*m����4]6���Nn�M��#!�d(6�Ҿ�
z��K�/�:�G����C:TՌ�E��(�� �Fǒ��uD�����'Q1#e�����Y���>6�~C�G%lw�����!��������{�0!���9�� k������6͏5�9�r�բ�_�<Q�PR�TE������B�S�7b;�������L�����������9���v�ߎ�6�hǽ��/".��1w¬^�{��А���V�0t�Q5�A܄�{����$n�L�G��I�@�g�`����=�B�A��[� ��QP����]*3�"���ܦ��CYU7��ЇFU꫿\5�z*���w�~;h���ct=E|VCM�u�T���y��~�(�L¯���3�'z"|���3��q�<"8M�M/�^Â
�y�����ԭ�f!X\�ʀdT� �U��u�{��=�ȭ;���ww�+~"D�4���������LD�Dh�\S^�}n��Υ>T�D�-��������?bݵ���v�[:�wO�5`P��l�8�߮}h���3�SYd��(�H�x��'���'m9E�6ν�0lr�q=i��莪"��I��Nn�}�!Y�=��Yzȶ�'d*��@m�I�+\a]�;jXDRE�,�Ǫ73u>8�/�׭6�<��}���W;���Л�W�H�Ѩ�d�*�t������l)z�Y(��V��8�C�����ӳ�H�J�����e�BO����$�-�yݩ�/h��6���"�ƥiqhV_DM����o�8I�|7�m�Rc�⠆��v�|cY_�t�7�*��S.�(����� ���'-�Dϰ]�!��H�;���a2Z����CL���@dd�u"O�����;�!&u��0o�]O�2���U�S��P'�K�ؔ�n��A�@�jY��t5�;����������#P��GD֠�q0&(ґ�)bO�y�X�'C��,��="�5�l)�p�ú���B�w�J�e��Z�fVX�1u	1�:ѩӽ�p9�b�}��§pa�����g�j/�kI�c`i�P�l��q�KU�~�<��e��C�k�j&:Q��m�8yB��.�8%����/C7��0mV�bv�_�-BF����e���P��J���T/����N*X����
gW&�n����Z9qK�/|e�ٱ'ݞ��j�6NO8�����rQī�ښ��!]��&i��8���l '���ݶ��Lm��{+�G"6+*�,�z��QvÌؔ��q�ty����=�'�[W��.ҷ�'�YvS]�`�i�.��uiۺ�hcY:�)�[f�5�q�9l�ګӞ�|Q`�ܢ��������{�R16r�
i�+}_&G����	,|�m��ZB=�}_U����HFIn �"αv�7�5����}}д�N�|��p�����r�i��V^�뾯&�D��X�Y��ʮ��2d����T�7��88b��1t��/�{�	�B�����|o�;U�����b��kh8���� ���� �Fh_;d�}_}����qI�8�T���S#�4����N����*�	�o��=���t8�B@����K�LWL�L����W$a@.�4�k`w#�1��t���dV�0U��������9n��a�P ��ݽ�R{{6�RåRˇ��&*G�-}��R�B�T�4��w�L+c�I��
��K�������QE�Q] ��t��;W��%�j-iwq�H��p�g�*-Ͳ�H���#D�1�'Z�l���M��[��    gyh�����W;dUԆ���-��$B>$�AF!����?��\ۋAҴ�>���j���&D��Ւ�k�E�������5���#8�,p�=����?��&̝>c�!��2���&�5]^��m���u����+z��3IW��b=T��Ir�3'q�3B�e+w�L�0%�i����ֵ�K�%�Vˡ�\���in/5�4�
!�+O]�W�ȅ:��!���&#:����o��'�8Ԗf󩆜���gnU�Yx��Q7��x�u?<miYE��n��h��5l�^9�b��Y��6F��Q�I�L�����xc�8�O)�v/2�߄P�+K����n��*Y�a��Q��7��x���f?ɪ�!�~Q�<Z��h���۩�P�QZϫ�ʿW�*N�z�4˥�!���W�j��z 19b ��A���� (?�^���/��2���/�F)��� ���ú�fd�<�C��%U�w��
�I�Y����Mn'�t)pa_�\t⨞�I�4��~ĭ*��� ������0����5�ԍ�A)��'%]w�FL�����Ĺ\L�:�g��2-B�5��A� WR�ʻ�l�@���js��v��E�f�V��:*q���tk�
�&r\�"4�k�nw���z�d)	�"�0	�����EE(\��m~	�/ͮ�0�&�c�CQݿG!�+͒C9���/�����j�_d+�*�~� �n��x�E��:���� ݺ>cf��7��aI�hUy��Q@����\���YU����؅ӟ�,�>^��'J+<&.������	�,�,����6DYHK�E����5C����O)ȕ�DY�a��c�+1)�򍇍���&��h��	K2�?e���9^���/[C�mUf�'�$�� F��T�^�o��J3y:�������|��r��l���=�N�@�]�Ӛ�&ӽ��E�����-�Y4g�2�+�3L�9�ȋ��Iںn3��x�D�����,������J��b!H����+Ɗ[�Mw���ϵ*�}��:)K���\j!?�0L"��gȉˊ��x��&09��V�W���$s��f�	�� ���U�'S��j')ڼ����Q�K�E�#��Z�)ėo[w�\B�+;�y<=��O�C���Y�Es�g���Y�S�qwh��Q�I��(�d��_�FZOC��jR7�{��ef;�,	>����Rx��j��WT��!�n�O��8or4�hT�b�F�.��
0A��׏�I���f��4N=�>KbG�i#O�l{�F
=�����T����%�G�K���4�*�EdYpOl�^,ю����gR�D�e#�C�Yj�m�B���Β�˰4U��3( X<�[Ӆ��N�4����K��e�2,��'C7�9Py{WV�a��e�����1>�Z��O=��~Zк���-����9&B��F�Y'�FY��8r�J�m\���lZ�>��]�w1dϣ��P������H�x1jU�Dm�+2褾*�X�^Wb���cħ�쯇�
�r�ʑ��N�i��D�#&����"� �s���Os�<W�?�(3;��d�!$�Ex9i�B�L�i�W����F�-��Bd�[����?�$j�m~�U� +j�+�έ��8�^��8���Zy���p{��j�J�q����
NL|CN�=]њ-5�ID�:6bY.�"?�#%+W�/֨�iT3J�j�w�a 5�+�=�ϋ��u!^(^�!����r�^� )��f�&�R�Qͣ�^�c�]q��Ε�G�=S�>e��"p�'	�^�*Y��0����8�á<�y����Ĳ�y��K�4���0^��G�/�ԓ-�
�뉬,$^��:���D�%a�k�<	\ ����# P�b>�����<����/����<�j,Ky��i�ݾ����y��� ������A��z�ة�q�~e9�x*�Q�| �\��eẌYQ%�g�[!�A͇�� ҩC�D)TiP�&]�q�T��EmR�x��<��n�,�`���L	S&\_�(�H�<J��zz����$�ftY��^�2/t��^�_��ѷ�W��F.L(ϼ��|�5�B�.@i�E�(�*��z���r޺~d��uW�q�G�	,>;wZؐ#���|=���|t]����1�ͣ(��^TgSQ=Wџ{e�h�� X�'�<�[�V�.�R�럕ey��pUabOT��
|�C�ue����B�7���'_���7���1m�+q� Շw���W�y��D�b.�h�!���f�Eh�M�;E�]l���{�]�{R��$���f���B��.DU^�3�`�g�5�E�"�	}ޞ��FY]e O�c�4M#�m���q�)	��{f!AY�&�ۛ�<�r�	)����`"G�X�����~��يxtp��=��FF�	����Q�t�w��򟾽�՞��"<�p�<����H��kn�[���y�n�PPz�������C ǉ<�� yWͤޝ���t��CK1���\�h��<�ߙ�IOB�O�ñ�Y��dS��*>�^\|aO=�ST�P<v͟��g�]iU��+��jȏ�|��qm�z(:���¡H]���D>�O%){1G�͠��_��2�&��J^?�0�0��,�XE>TY �Q�G�۬9?�jT%�ҿ�!�`���D�J�+}�jo.^C8D�O��"�
���<x�����z$T�!#* ����r)�ǳ��Kw���lh���nG���T8�⻞��b`�<L�x��-�ث>��P�rzo���V,�6��f	B}(��^1p,&��2�;,U5׌/��#�1�����V�c�8_1(P��R��Ǿ�6q�'�د���B�2�zjT��iKe�E����OugpGC9K�.Z�X� �৩�B�z��B�&���= �`t®ߏ-p���?�������@7\�X~��|70(*���]����A�R��<*�vF�WV��	.���]OO����)���ڕ8��������t5`��tʼJL S��65�\5�H�AM=c�^�q�;^�vE�or�eW	*�lA	��TJ �ß�#��&���8����z�-���;^=|�����?y�%3^�"�r�n�a�V�|��A��Zmz�1O��SI��&2��]�jM�bĦ<o�tƱ���W�e�w&�o�Xsj�B'��1=u��A���8�)�{� �qL�r���P���'����]|�r�*����ڗ1�E*��~���\\�:�sQ�������E�AT�܂����J�lI�j̑T�o���&����ח���|�Q�p�K���)ھ�>�-ϰ%{��.��dĄ�h^L-��BP��Im�5���w������)��?����&��I���Xƃ��_��%2��+�����$QEÄ	D^�Y�(~>'0�6��dKxbܔ�܌����)^o��/��b��J�i�[P&�V�������$��ԇ6ˎ�OJ��4h�)��6���P�N�=y���.����gD2+�Ц�e�Ī^����	�u"�]! ���)#��1Ԗ��]6G��=�W9<~� *tS��T>��nȶS6�T�>� ;�B�t%(Xj��V��As/�c�}K��2]Mm`�1f>D�^�=�EY�����? C �tc]�Ql<<�ʂ��&��B�dx���|(M���g�=?B��=��m0� ��:~�����^�7$B�d�����C��	��lj��?��Db�y�+��l`��Sn�c�=�	�CZ�tE{H,\�1m�6ҏ�`̮�� �Q���K�̋v,�}:�8�� v�_�8I
�&�KJ�
�Ѧ�{?�m
��ݪ�>]L�ڟ���:�y=�,O�E2Q�C|;)��܋��Ep���e�g�a5(	"4[�Cactqs۫3J��!RXd�i�R�p��޾/+���l�]���d�0~��w���*GL��vB����)>�l>������^E����y���K�U�V�>M1Z�}ݛ��ut�	�D�TJ�n���>A�8�$��%    ��Qي��3�CA�.W��/ֻiSV�_�2�r/�^�ºA[	����6�?@a�����[�7�(3��ܲ��{���b�u��.�V�_]��/��n��e�žǯ��#��1=���n�'4����u�[F{1)������>�����D؊��f,��$����8���͏ʧe�4N�M��d(�xXUs~���V�r,��(���!�Z�y��5�&��D\�����1�o����^}���v��-��,��+���z�*~�ϵH3yR�dA�����jo�0rx����˃��Q���>�7w�q!�7�ͻBx�{����iV�sU B�g�{�U٩��PJ���l`\q�����q{����v��)�}��3�Y䩗7����'�yܺ4tz�*�{bv1&��P[�̄���ZI�V����}���~5]�"�p��ۖ+s/ŸpbN�a6��͈6Sz9���b������ ��9BDe����b��s�,f��`{�����-{��^	yd��r�{
I�*;GA�T�gR1�p�9"�ކq1��2.���Xf��TU��ps���RD�S�u����M<^N؞z�	 [v���Û��0�A�#ª���S�t�"�>T���G,|=|ч����XSД`��[���F��\q���iH5� �
1�
���	&-
;����j�bUp-7������t��J���3����-l�fl��\�\lJ�R}��~ɫ(�̕������	���E>v,0w��H��'����N)ze5�1��+��G4�"�k���5��`�o��A)�B������,5�k�;�j���Vt�:<��I���I$b��kq)��L��zGs��}t��ʀ��eI�����!#?�F#e)`��}U����d������u�k������S�u��E�x�0
��3��Ai�{]�i�EW����n�Ń�ܫ7w8ү�/�,�b��S�䥭��0Tk��LO\���?�E���V�;⽞{�R�G9Ti:�u��(�!J�O��Q2ѥQ� m 9�ab��J�]�P2�W��ß4%���Z���r~�A�ȋ�٩��4��,�#Y8���F�(i��e�{�_���%�{����k)}ҕT����M*��{��?Q#]�*�o��y�P��?�9�����:������0�7Tňd�L���	���Kj
��s� JD�4�l��0�C%	ℿ�UsUu~�1E�fYj�4>m�C *�Oj	���Yf��\�|VO{K�F`P��@x�����̪⦼�/vы��t�\��wP�8���h�ģ��cwI �͎�d���C�5�)��z��ٕ�$�����w+U�7R]|�0�||�`��� �\�J"�(�G���U�SP�������)�7m '�S<��j�CSu�28K�nN�]�����&d2�����Ff
ԁd�OJV:�j�
ِ2�*i�ȷ�z�KMn��In�:w?WR&��h��� \�tL,}/q���FT��6o�U@U���@ei�%�J��Ylx��(�b�q��~�:��02 [X2�P���iw��( j��VL����f���e@��8�~�.M�6�L�c�
�>y�)��]���r����W��l˼�����1�!�H�oN/'X�=(3��H�u�ᅥ u��`2�x˴b[��Q��X� K�C�N�;���
\�#@�Wx��ò��%A#��_�'�ܡ�˺�o?�yݡ���3&S*�P*'/1��"$�jI8����f��!)�Ԁ6e_�\�0���c�NmݩJۣKx��Wj�^�I
��ozpչK�|ߞ����2��T]&3�2*m�^Fq�Q���� �TB��o�����]�u_����|qi�08<�!Ԍ�a�57�h=��b�s��(�=�U���t%�������|� ��
h��m
��V`K�#YM�v�������E�+)��K�{?&={�m� �W�9a�̽@!yE�:�<  m�}��?����~}��>��o�R�q4��YGQ\��?cW�D����<��sI�A֐��uX!4��	1�zp�4�'/H:�z��5�u2���I'�������}��o���<r�ϡ��x��C�۱�;*t��iԑ�q��}qb��v8������n���$�K:��va���~菹��� P�*�%�^ɷ�PV�,&)֕Y���4/3�/���}�1^�{r�H�E�h��#J��+�ֵ_�����4/�l骺�n�"/��,��7�F��Ǌﾇi,��0"~��^lR���.���h��-���.�ۯk��d������U�'�J��*�`>��{��u���!�*�qis��Lb��@����o��_�l �ѝ��Ҟ�lh�����`�i�ɡC��u��2!GI&�=���Ht�;-oGl,ƣ*��ny����:^ #}ϞD�U.�d�/b�B��mJ��p�����ˌ4�����1���V�ך9��I����v��`==��`����~�l]�Q8���|]�2�
~�^Df�Go~2�'���K�L �������UYv�w+Q��}��Ч����鲓�M0��vO��\5Di5���N�&,���(Q�[�G�6�J-���3U�N�������-xm�s��NT#�5�*r��0{�cp�ݢ(��P~d]ԲCߝFW���=�O�6�P�x��a���J����܋~)y˽\���AY�N����7��),�p�E)���)~K�ݝ��6M_&�䒊�=Q����饟�'L����*�e=44���>A�Ў�;��ղv�f˨��mQW3�j� U�q '��}D#Qj�0������P�>��9��x�06 �$W�n?������w�@!W�τt?���z:��Ÿ�jFn�"��R�I`$|���l^i�ѱ��x�G� 9�>�(<oB�����*�;��7��8LR?���Ӕ_v�m�h+��L�:C"�}��s8��S�"о�;n��j���_�-�D�������(�����_�c�|x7�Z�dN4|�G���s�j�t���EW��2�k9ɼ���稺X�o�6,n�V�q��d�c~րa����L������%��NU����e��^ȝ�&!avv�x���+�x,�p����ыQ��̲�+�8I̠������<8�W�+���t�}*�.�'�(X����VK���+��9/e��X��mUHU�x��ʢ���u�r�����-^��K�1�GZ
$��m=cُab���
~�B|�����{���rz��~g+mnVe1Oˮg�����7���3\��~%���-�w�8p����UA< >���.��H��W q�e��D����/�e�i֨���$<	�C3�<Z�,C�_��������Q���k���{�|ͷ���Y�M 8���{� EQSp4���?r�oy��h=����M3���ͽ֞2���Cdie��"��[�9]5������op�d�m��������D�{x	�J�,YJ��}�Er��%����<�p�%�}�Y�AF)���$���Ҹ窺=2I��E&8�ֿ�p�aH_�cֆQ_�	C��t������˝�))��Q"k��رp0�zfRN�X+䅉% ���}ѽ��ݒl=��R�m⪶�[�$���[�j*��ݬ!Pj(Y��=i�����
,V̶i]�錸Ta��]|�9��*G+ǈV8xj��M2^� 	��*V�2Ӕk�In/b�ԕ�6�O���۴Kh�۳�5�I9Vyw��ڈ����S��y!R �oS�$Ͳ-~QA@�3�\��o]%6�^�&Y���e������آ��<m�UG��-��Bj��]Z��z�pm�f�탺�5R���Q�y<()�ҵ��ईB���/�� f��3e�pJE��6���Ƭ=]M�h9{��.�9�(*?kO�@��u�؏{��?1�riW�ߘ1<���wG��+�]�@ݧ�Z�64�B���9�J���W�I�fǷK@��~@��g[��+p���Q���.    !�N�0pLغ�4^m��|���:��*SW�lgѐ�!��P�u=�R��IΈ�z66�5�m_���6�i��f�[��Ԅ�'� ��8⦎����p2��B��p��m����7���Dp�48��^;�Ȧ��T��5�*JS{�5=�W��$�������E6b]TT�h_�d�u�)�	Hz~6J��W��ҤqɀJ�6wrE�i��"������4\E��I�¡�����DvI��3�I���+]�Y}߇y��	��بi"��t
�@$�'�3��3�3i��"���e�0c|���{,�U��������}��*�s/�R55�&9\�6�J�A���t�~�ɼ]�D3$�<�J;�Y|��*�4�u)`������)��K�lb�8�ӓ�>&*%R�ނ��>���ֱ,V�tM��X|����9K��U����=�&`P�� �4���
ҋ�W;4(��6,�tA�P$���^O�b1�F���0����c��4�XP&\�%i���rP%�7d��.S�:���15���7��/DDp��O��8�o�ea��4˼��)Z<��OL�#����B���( ⓮�A���ꮸ��΢<��,��=�� ���	��EQ�n�wd_��*���?�\���,{�~H���f�S���La�̊ࣈ��ؚ��7H��U��V�{�+�c)�MA�R$����b��_�����l�v��2q嘦�D�;��˼�9��<l]5�u}�K�Ȁ���cA�	86�O�A��V�!iP��.�3X�����R �R�?rV�֗�~4�SC��t/�.b�m�=������'�Wz3���婤��(��J@W����5�8��jY�/TG���H&a9��ɒ2��H�9\�S��J��� ���'Q�"��:N����O ���� L�9q	V�,�Q��2Mf\��,k3h�0������B��ѬZ7}��j��Թ�|ȇ	6Oc?����͙|�I2J<��T�Q\�� ��g(+%��j�܁��UÒ�'��	+�p���z�5,y�J���0ojz�):���a܍ �~Px�JI��w���4q\��P���Zg���F�뢚ѳdeQz�_?o�ԁ��v'��m�MsO��E��jk�Ÿ�}�ϡueUUy٘<��ˈm��������|�� 9�D�W;=�d�>��OO��'U�i@�d��o�Tu����������u��#��P��	���E����j����F�(,g���*Sۇ�Y�4P�n;W��w�$+Q�����U�(g)c!L�a/e.8�i��a�G�B����'Q�韄�V�1��:�Ko���D}��e�Y��Ыr:
Au����y��w�CRw��-q����~d�f���c��B!��]��/oZ���H�ނ��7�,�����  ]�LW�OE������r��-��{C��z��u1��~�A={9JݼU��H�d=h�_tˌM�S������/��K�?>��X^���ܙ���Sw���?�U�=�J� (HZ��h���NSGw��5Z���
�������'�]��^�"�B��_�7�_ꝡ��/�ƙ,�in���2oy/W� ���]>*�Se����c�rȚ!.���eQ�O@��h�R���z�p�2Lm3�4+!i�2ֳB`�9�~+ơN�aF��0�����_��@�v6E������6&2�[p�Jr�>�����M�	#��7:$�� ��G/��K��}�^�ٲBÈO�4�8�e�Y'<?���=])~R>m���>W��������,��Y^�+�e�1�?TK �����e]��K���g蠈��5&'���}���w!�����?j:S�{{Xs@��Cמ2\���q�Ї,�4�����`=
s�Ԯ���+�Mt{]�:��?�I�F�,�k�!�����u��Ь�S_�BwM���Q�E)��O�^=z�K$���v	���EaO�Tw�L��n r��X�C�_l����HV+��P��)g�6�����E��O#\n�I�9��tJ!݄�\�RT9�٫�>���R%�Ki1Z��ܷ�E��ՁOG�"<�N�u1�D�MhE��as9]�T�v`�kI�	>�WϠ�¨���'�ERM��E�V���[?��H�^*y��[5��ֿL\�'���z��"��V�~όK����G��	,�I0��TҊ	7�Y
�㪠߻�xcA,�>��%s�y4�ؠ��I{��\B����x�zq�IC!&��G�bMGaV&3�[E�T��Y�{(��[/��A(o�z �(��r�0�M:�[ZQ鹥e��`�ɡܕ���`k����ޓ�TJ̸��C(W��R�(,��m�]����#�)�0V��,�N�Bo���m�tͩy�v�$7��g�������ѵ�'~i3�)�W��A=N�UEejOT�^�]�4�T��O���Z�{��]���!��_=�*
��o�̕�f�C�2�-p-E's9���ՋaDa�3@�eX��Y��z�VC\Ko>a����I�}�X%ŜM���!����/��)�"����{'V�G��6t�8���H\є�k�`KIڼ���f\���]SԷWeT��g]�y����9� ��+�~��Ɲ�q�� ��w?�__��)v�O��W����S�_ƥ/M�o<^����4�R�oe>p���뇞Ȭ��3s�5#�c�������\{x��j���>T�(��� Oց����C�" �B3�@^�djc�5:��W��f�.dݶC�֤�w�7������gT�U��k�Sl�p��WϘ���hf�	wb=��,��"�����`!���L��M��w�e.�\��UyQ.R�u�u�=5Y�|�y�RT�(rMՌ��L�����2xK�3�b��	�j2F�����Q��|
�5�I��jr6K��(n����,�R:����АP��]�#	�)W�TX�ǈҪ���*��{Ta������<�=�Y���;k���hr|\{me�H�u�Y��H�ۊ�� 6N���Ȃ�V�,,5>��<Ofp��"���*
~�f�ð�3�t�i�W@S_6]���+�������g�;|`�)���e�$��o�[^y��*D�Ŏ>n=)˝F�|�߷��CM�n��w�%P�pS>{�Ai�3@��H2L���YH�)���Io�]�Cy��*	ވ@Ć�8��s7C(.d6�P�����u]�m��$e!���u%y8,R�Du������kz� �J���=E�ŸHQR�!\v(��jBK�{�(d����j��#1����_�q���oW�����T�w/����2O�����7?_I�*���>�$L���T��j�̋��Q��uy{E�J����<x�e�յ<m�c֍M�H�8ɻR"�����+(��ަg��we��m���^=f/��oO0UQ^��*�?���nj�V\)L>^����bU_H��zJtq`\�\�'��Q�y~PUo�*0��8�5���H��߀���	�[��g6�F�:���b��AQQ�j�2�=����lxSU�G�⴦�NLL�ޚ��yTi6(!8嫗.��!�o���$y�i�W��~�َ��O5$������jٞ/:���r=���؈��V�z)�(	��f(�[��V�Ua�bx9��u��.�ڀ���+�3i�����H�Ğrߘ��[�w�3$�N3*�r�Oj��x��u����9fUa�WQ���龧���ҹ<	b2I����N93�6�4����`��ѭ�Ş=�n޼bsqD�Y��2t+AZ`{A�?�	��'�4l�^���cx��H�Uq����5�����}�^،�dy�Ow�zd%��zV��A.���3��&���	�r�M-DY ����0-�e$E������՛�DIմ��	 
��^�0~ޞڋ��|�����}�(���4���@�E°��h`"�R�v8���T5t�_o�T)�4Mߤ��4�*�VaL���������o�6��Q:3�DtVk�[�$]��?�.����e��$���|폨sL�ד��    ����Ūd}�2���Fw�!Qժ��Ԍ"���oꓡ���.�K������'<:�
���q���:�z�lգ�&��!�-�����c[�=�:^��ѐ����(ss&�"���Ӹp�}:��t,��%j(M;|P�:^R{*�j��R�r`5ٌ#X�y\Z좀Cs�A�%�B������vnH�ga�l���m��Cg>_ڞ��B5��YO�p!�(͆���F�0H�@����>^	���s�b��#Di\�F���G�ml[@��LZ�����iU���7��Ro�^�=,�GE���:M�����/X��������w񔭆��&�y��r.XQ�:%J����*\.�.z*bK� ���X�qx�>�� ڧ}�.���!�����V�][��m{;�߅8��¿�x�B�����>}WԼ=�� |�j�͋	�Di�s�fIlM~�o�$�y����	6�Bhw��&Lچ�  �s�ӌ�]�_��K��av�2х�p��W.��5������@v��'��P�����F���gYW3�9W*�7*!jr�q���#)��G �d��>�a���1����j��
"��^�=�Z���4+�jF� �@�UT�2�2HϒU������ru6�VGXփ@�i�.��gU[��OR�S_�\�3z�v>垯�V��o>(��L�&�pD�z�cˬ)�r�a���|��8
~�Y�؏�������	Ixa����~������L��y�;�۫�$)#�$�8��8곀묷�w�geؕ�jI���#����I�Үq_�V#a.FY���g\�ԓƪ8	�������x��>�l.�+>ţ	�K)AO�Zo�P�Y�H�����:���K�ԅ���� {Zظ�n�'���Ȁ�aM�׹>}�TJƅK����tMn��T�+u���<.?��QB�ՠ�F $.l�@��i�H��^�d���H�D	;D�4I0Zxp=�.3�n����F��t�M�R��,���g�H�
�1,@�h=b0}<N"n��Ji�??��O�w�f*��z �G9}Ϗ/���ͤ��Eᱧj��R�Gz-�Ղө<���#)��0�U������[M�4�O�Ь��/p�kt@s��j��Z�Q�ͱz�vM�nr{�ʀ�Zό ��sP3T5�R믇_E=E�����ƒ��0W�;���R�B��~��
�� I�W����&���ġw߯ �H�v7S�����r��ա#~YM�.[�®p��?⺊j��$���-]y�FY��qK򦙑k�*�|a�:ZŬ+��}|`\�Ηa���b�痝WD�փ�-�G�i��3J���V�U\L� �ƥ0mj�4#6?gWoލ�yBّ�=�z\ttŏ�m�U."������dV{�;�y��3����ן�2x����+o�70�S�x�%����ܵg��5MVi�@�|Dy ��HZE�+/�;���
�V�K� �7�dʂ'�ZKv���j��bӹ�jn7Kw��ê���@�7h�㤧�(EʾA��ˉ��tK?���09̻�a��eU.�y�עގ6I��}�"q�#���W���Rw��sm������	�����i�����I(/�
��@O:"��m����7�f1����	��q��r��̊��qL�7'�H���io{C�/�BXF*u���h����_	��_�	}TDQ�����
6N���,����rE*k/�h���n7j���B�΀y4�]���~�kw
ú-�eU�f�b�L���Zx�q�Z��^��貂TѠ�;����j��$E:D����2K�*Ƀ�fM��NS+6�"*�zr�K5����,,��F�I�+�ńm��m����H����{C�c��P�u��D��/��މ��=�fQ��J�৾��3s��(@$s�J���uF�{)�M:�j@��XKE���3K��/�*@۾\yp����:�t�/��H���Ni���L=N�ޤW�NTT�L:�}p���3M��5b#GٞU0ݑ�|"���p����M��	O�����So�u>w�@&�>	(�O^�Jms�͝(x得GWta7!T8��q-�wܻ��-�Q��*�]8��t�r��̊���ٻoC��讈�"����i��蒨lg��7�i�M�k������t�Hܼw��- ��H��a������x�v���g ?QeoNOL��\>�{3�A��W����LN�2�öW�,i)��ܠ�F'�$�m~?>ԇ������X��y�2��Q��T�c��V���q~�ɒ����;b����pO��g�������GW��1�\pSE��{B�k�h1/�e>�������\O�~���o�j�˙����J��o���E�����?��cv>�"�t��3���1	���1���b�̧�</"�qp��/T@� ��ݷ�=�| \D"�9�X�o��W�H~ه�y$����7�A�	�����G�
h1`w�y;#���^V�I��,�����V��0�A&�q�@�/=ӄ�t��1QN�ӮXlX�ER��7e\Z������1PZ���w~�2�ᠿV�����wy�IR�۞��@�~�N�����b����F�=�ZB�ع7�����-��ڋ��Xc=z%S�%zj�b7���J+iƫ�`랯]O���$�E�C��նPD�\Z�����v����;q����ߙ���4�o�k�/�w/�˹��?���f�:��ZV�M��W�����������7��ʤ���O�z{I��KAx.��╦P�����8`���`p7���u��@#��I�,j+Ӷg��U��X�{�/6���΢�n�p���B����j���le��3h�y�E����=�Ϟ!�
\�+X�Nz������jT{��B�A�W�.8�*���oߊ�Q\�>���x�*��3��Zp6x��CE��i�z�^D`�*V+X�;*�(��e��������bMn.�$�C��z�2��D�B��^*׏��HLwՉO3)�l~�ņ�»���bԌ�ɒ˧<�2_mgapO�"�˞zN�?X���%���+��B��s[�L��6m����=�}�޲C��7�^�����*�੣7/��l�P��ߎ��?ѻ�UT���>jh9�ЮA|^�K71=O^ˉ�;���D�maZuO8����]wT8�(܏CR��ؔq�3�h�WS �VI "@UX����;�oY)�Rd�{-ƛWu˻=�Em�U}�]�՞�Ř�e[�y=�W�gQ�'2j�傍�!9�ܾ̯L��d�� �l�I��;��w�&��C�\��ΠO�Yz�C#=�!!�:��R�[J\�ς\$pH�:�o�s�5v�Z�vեxK�.��o9�5[�+a�|���v�W��q��ϒ��٨�- H�jҍWFd�P6�o���9������<�n�u54�9��>��=v�M�G,��g5�<;En-�����I@,3��WF�t�m���&eqeR_��0W���؀�� p�&O?B��OlY�g %�WI �Kpڸ�4l����x39!�
�0q�R�Qi :�6���L��^�<[��/��U,�R�Y�`��M�7^m�9��2`�*t�i��-��ӱ�40W����(lLԱT脝64�D�	��'�.&�"@�n�ѣMMȼ�.�Z�]�U�⤟�2/
�,��o)�p�ca�V2C�ߊާ{0ƫI�A]�d��p�6�&CDg�ZGX���.V�"5΀�UY&���.ͨ�29Qe1`��׺�]e��'��y1�A�uIu{U���U�"��Tb��5��6{��ۻ�U����f��q��;�U♯4
Y����x���(�*/m/�x,�uҩ�{O�է�l��0��!��R�	�:C���lB/cTZ�x�(��T�_UQ[�^�I�F�"W�G�k~X���p�=<&��:��)U��D��C,/�-��Ho�
�ݛ�t���'v�PxW���͛����s��=5��tLv.�T�    v�Pm��2Y��3�X�~븪-���E��� �Ȑ��_�����^���dN",����\��6�q/�<I����=WS���su�爥��{�.�+G���n��?z�
�l�� �G�D��s1?=n��To鄃�����r���C�t����ysy��%T��&��/��wLK���^U�/q!�� *�y���Y1D�"5v���ߢJ��=O]Q6�3dAw}�M�Qq�K&��(ER_$i�i���:ʓ�������� q����:���y4���Hƨ��Q�wѧ]�
 8�5�m(�-����]k�߿|R7:���M�iG���I��T�
��i)V3�K�f"l�z�K��uY���i�����"x�Ů�R�u��_��;�����z<A3�(�ˇOb5ɲ�Zں�� �2��ȟ�2���>n;�2��8m�:GdV�*/�'ۼ���*�2���y|Fb �+e�ۏ�cB;��$ⴞO�bC躏��A�W���-B�bA0�i�MY�	��u��022eDC��?h�_sמG�X��X�:�u-r�0)�ױ��̖&E���T��S�Mbc�Y8r�/CeASEb��9lޞ&��>��֥f�M��M=#�U�El�+b�9))�%�a<���M�D�^�^W��r�8��R�m�E���m��F ���Z����g�7x�+h8 @�W��b��M�!rWa[�(���u��SV'$�LJ�Xޫ��������P�&wH`�<���Q^�h�TX���7�o�6+n��UT��B)�k������ �j�`b��t�~�yF�X��#�Ræ����k]��	��O���'ԇO��`y��]�!O���K{Cgkt��v��5e�XZT���3-�@u*�O�O�s�@�
x&p�4����Ӆ%��M��zB�q/�gk��oo諴L���(�_^DPCr���m�ٟ� 	�謆9\�P�4՜�
N��e�tLTo���sN�]��m4���ABM�3�4�@z����`~="<�S�<,e/	�����=����������f�u�#]�W���^h�(�!#���M��������隋jNF�.zPmƋ���8�>���k�.�a�RUq�h����n��AI1%t��������{�۸)�[_,<5P��$�l`���+~�Ww���M�Xo���V8����M(�w!
��W+��\۴̋����o��4��l��!�a=����O��=/ L�b�1A1�ԕ�"�m���,t�����ʖ���jsԡ$4�Mm��Lp�l�����a�ڍ�[Zf����W�o���s��2ʭ�/����?Bq6D��p���*Q��ǑY��Va���#��ԇ�~'	M�OԼ�x��̚I�Q�f34��+D����*�m��:.o����eWk��~�B銬�� m��\οxWӈ�������6�P�x��(�ଲ
>�.��#Fd;�L��k�6q�"Fk��b?��<?B�C��"-��?F��'@Qq�+�(6�e\H'�k��hR9�ϧ��	��g��ra�1�^����[ϵ�3&S&0M&pz�a�Wp·��97,��]��l?N@!��d'˘v/O�x�I���.�����#��ם<#fq�Mj�h[4��=��^�v�r��s�!P����Μ8���P��[ ��Z���xL�э���?0�԰7[ϲBܪ�/��v]͸�EQz�*r�����#�X#�9<������@���1���?�L9���Tdߪ�.>����d�!���H�G�?��wC�j�@}C
1 Z��=��{�X|2��V�B��f�*�x��*	�1�0�?_|�ᑏ2%���:�Ōպ8m��+���XkI�4�M�#'IA��"�&C}�=���wW����oBȒׯd�%y�Ƿ�,J2/�[eZ���ЋnN����')�I_�Nz��u���8.C������O q\�:
1�t*�U/�ʝ�{�;<A_��V�!,����QY���GIX�m*��q�=��
1��ݾ���?��4i��)s�2�Mr��Q��N_���V��Q��1��2|��|�,��pT��j`$uE�H4�����OF�D�}�ftⶣ��3�M�96���`�yvջ�޻�/��.��̊�*K���AsT-"�æ����a(�;�YIOf�����tK4&������(4������Bk,�q����K�;W%�3�b�{����	���BWF���[G�k��]�,6# �4��T+�o5Ŋ�Ӯ*ʛA\��$4�F��,LX� �V��jzDf�6h1XKW�I?�wU{�V�a���@���H��kwV��BR�U��4�k�$�q�\Gm8����႟(s��?l�B���B>f�����l�f�(�h:4����s��:c��q�:>�dgs����Q 6��������׺��ݪ���sY�k/�v�^׷M5��(ˤ�||��=�jl�.䳉� ����ּC��5�!se��g��jt��&������-uTQ���e�I{
T��O8ECi��1(���k��(�fL�0M��=˃O�*��kM5����mH"R�O���0�?�v���z+giEj{g˄-��xFآ�0@��A�ྯ�W	t|��׆V۬���NpԞ$�3m��X�a@]>�ts/���=E�|��.6��6�n��q���G�&$�_؛�@կ=%<!	-�Wh��;�K궤`��G���p1U��Y=#j	<W|Ԫ�wR��$}?R�ۤ�r�K��V5Xjyl�k'o�����L�7ER�قb�s��HKq�⇫��v�őkh�&��}�1ǻ���L��#R�Y����m�)���/$�յ�}����Ijw�����T���X����3j�����؉��s�_8R��UnaAu���n��qEB�R]��MMt�t-N��V(Q���:`J!��"x&w�-��s"+��8ϫ���
�*i�ۇ�q��ޅ��Y�ZW�w���yR��_z��(\�K_���e_�ޥ�y��u��@�	!�x�4�	�ڢ���(g�_�x�J ��_K�4��R]'QGu��wBE��-��A����@L}ܛX����Cb@~w��D5���+yq|�ODQ���P�����9�~�"<�&�T�&���N5���~��{'�3���4���y���������%V4�H?���7���͟��꓂h0�3�ڻ�հȒ�oӼ�Qy���,J�{���A�ɔʞA���OLA���$]5�g�ū]����iz��=.�4�^A���`$�,L�.�1���T�v������e�ﴒ�;Zֶ�4���~K?�j�t[0�23�l��f�ֳ$+�1��%Xwx�]K�Y�ƺ�dR vJqcX5
S,����ҝ�wx~����W0Ԏޯ��9K��k�*��ެ��
AK���VL��q�L�`�N��3Vz�`̀F԰D�$�Z*��x�Q<rq���Q،C�s�ӰV�G�.�ip>6���剂��^�
�kl��U����*�q"	����0�J��1^Q	�ϗ�Y���$��p*"����3�#��\5���F���������E�͘	&)�>L�>�����=�͞�?�őS����oL��p�ڍ�)>���j3�E7c�dy6M�2�Ёn®���;�cr���%e=��Ų�P5�0�H�i~U�T08�Y���(�R4��\��#�^/T�P�Q�B�=�1^MWk1����Yv{��z�hz��0���m{�'�	K��$wՖF�`$�oI�z0_���#Xϑa�W������³�c��Z�R2� E��N��Q-(l���{�(�8H�z9_}��a���a5�Wb������hمG�.i8����ݏ��3HiV����	,�t�i�a�'[26g0W��/��ä���&�����I�/��^e��(۝;�V�,6��r�p5��ܛ.e�{'=�Sk�ʀ<�5V��"�-NR�u�݋U�g�����(�s��}I�;�ُ(T�    ��ty-v�p�LM�N�.B�`v��ZT�C��7�D�Uv	�'��`2��.~��°��I��N�L���/	��F�KlS�u�72#P�{?QǴhJ8O_��{�:53w�no��4���e��TG�iO1]I�>�.Z5pm��cq�~l��ZqV���	x�2��j��� �����<��"/��%�i�Uޭ,H����b��o�o^��%�?3r�j���6�qXTQ8�E̲��S\���Jb�t
6��Q��3}�(B��\B�b��v���]�L�bƉs5����A�c�b��2Un�����x�\[�Q}{_��uz�*o�gF�W
�4ۤXqN�L�Z��;��mf�h����k��t<TzX;n	����i����pN��+�{AG��J� ͘��D\
��]y����i�V���(��p�D�?8!m������*��?��.c���sx�!�1���dʏ	4��=9L�Y�L�ގjҔ`���f,�,X��^ǎ!Y�]j1-������EI�w>I�w@�`5����+"�2,�.f�q�	D���%�Y�5�X��������Q����ѵ�y�+�$�4�.ޙJ�6�8���p�4?Y���l,��N���\o�E�6v"̤�L]H�7Q����IO'�?����$]��>.�h��%������4"�$�q�4F%�+lT��`���>���0H�M��D��3�;��'_O��|�z�q�� ^D�iZkz��#�Y�Pp�;= �$1�͹o�e(Zl>^N�^��=-�\�����\�EГL�@��vO0���K�g�4{ښ�dkC���� ��k���Y�^w����7�4�a���]����2�t�w}�䑋�YT���92+��1��d�o�򨮧���U�W.�~TӴ��I����
�*"�V�����;͝1�����$��ꢙ��կ`\:(����!˒���C��X�9�i)�*�*hn�1,���%�ג� V��L�\}�1�w8�)��-)^�lo�i��xPswN���
��Aw�#� 9r��Q��5�L����|�˫g���8�r��?�� ��q��N�aF�S�����4~�΋S΃����C�ue?�l �d<�t.;�x����i����Z��^�CGm�f3�}S��Fp~Z���3��'+��&cT�YX@���(�Sk�%�/�_[����M���Lg��¥d�㨫�[���D�3���e��%�u����C��'�R��8��p(׹���VOL-ko��c�Q��zδ�%�a���;�<���CB� �gW�����l%;�v��v���I�|��5�pX�z�DNĀ#m�� �l��"�����*�;�"B	zy�h�
_�%�[ =�'l���z�y��.O�l����p���0�b�,L����kR&6;�e��Ȋ.R}�?��i��W�B�Z�~��\�'m���T��=R@s7�a����ju��G���B� o�e\�p���i����k��`��@�{Q<7�t �yut%��rr�pL���N�C��{=���ݩq7V�C�q��q�WS������lU�n^����-T;_�˄Q��y9�[�-6����,n�i�I^LY�82�����G��~�FP�̄B&�"�kM�
Fn=���qZ�Ō�$MS�1�e�M�����;��i�,SwƁ#n*�#�^�"���Mg��,�'PZo\,[��M1�5}��D��6��Ik��K��);�Q�!ve;�7P��zξ���q�팒'O\Seq���3$��Ӎީ����J7b���!8�w��&�.����X;)���\Ҹ[-��!�g��"�"?�ɢ��aX8�+�^5X���l�f�'ٿ���fHG;�f�(��?�դ����u�D3�Z�I���,@���`�����G%Y��sg���-�S�����U v*d��#(���Q{��a`�����bC����zF�ʪ�ށ$��4���>���R�Kr۶c�E}A�҈"�%^5%ƍ���NW��a��׿\k���F�Dԙ#�$72s�e��]��L�{��r"�|R�|�x#�����I��
����r%�G���N乍%�����~c�i V�}9o�P�����#��~zc����H�>I����7(��E�pa��D	�r�Hmy�B?ۏ:��!HL�j�6�wҿʰWf����C�~�VY$�=�(�o^h/��8�Ay)�ែ4xr��m�$�"\����� ��v�#�SO�����;�,�B:ϒ��|��!if(�Qnؓe���' �T��7͸�.�<����SE��&u*}�o�sg�5���8I�����zaj���#+��6YYug/�k}��n�H-���>���6����T]�DU<C�H��c��"p^�㳬NNO�!6��M�C��6��@��^�22'3 h1�k�����I���˫"�b�����)�=YW�U &d���,0�}��Uܼ\m������*)�L"����Y�XO�s��C�"���%	���l�x���X��?�I�zh�����(B�<�aLxt"����ZQB���	�jC�uoŨ��Ő��i��!ˋd�(�Y\c�sv��mު�-��z��6�u>��?��嫙,f�'eY̩<�<�Õ��������� �"ҧ^�~�j{���sA{= ����
2Clv��<Z�z[�KK긚�r+L�7˓�����v�����Ա�Ef��_�&;���j`Ų���S&�����GEU��Z���:Ꟶ[1l�(P�7C�%Y����|X�4�_��~QTF&���,���q[S�,g��ι�HW+�Db��N�!KoC����\_T�q�T>d9Vx�KJn8�O��T�k�*��j���ͥ� ����gLi\�3�M�4*}E��o@�?\p�0�1WqJ��/�Nv�#=,j�����`n^�~�d�5�	J8	�l��#A���}��k�rۤ4-���e��^�6/�_/4>!�KI]�?��g;��E����U�T��y�1u�0��~FG_�U��y�y��0r�f�l�e�cPe=��b޴���ve�^���_�����9���V^;�n�ر���y�.��D�?BM0"/��t���j�"�mi�匛Y�e��!E|@��Z���zSwntLr�:��m>>	�U�?�jD��4������V�}�B
��������Ԙƾ�8����F�sj�Z�xy2X�j�Zl��q3�X�Y���N���уmR��ʸ�����.����8ݾOs�Ee2�W�a:�O�oH�¦&�z��#M��\����������X��(w)�is@�8�>AT�I�.���)ZԷ$���x�;HQR���D��Zoa�خ%3q��,T�)��̃_ 6kZr�k
����~�n��?#�:��3�Lp�f�W[�/e�gE9���*��M,<����Z�5j������2�)���p�F�㿋j�ֶÅC�˱}�?�jZw��Y�W3֦UG�X��A��K�j"~�Ď��_:4�2y�C�J��qZ�xR!�s}��Q��_l�5M\]��P-
�8UT�oS�x�/P�dj��3�= �1q쁸▕�������������}��!���d[;L�C��?b+Tӕ�,[��U��ju5Y�a�һ��(�)j��~�_�T��@����ƣ��x~�M��r�(�/Ů���T�/^�O�Ħ� �ZO�~��f�xYG��E�Zm�\��?zQ5��-����w{�pEJ��HC0�|o(@��!��MʪX��,J���ݾ�s�Yq����s%a�{�2
>Y9��oPUɚP�]��s{�H�>�=��ͯ�)U������������|'���V{�~��ڈפC��U'�-lW��xU���<�>��i-�YK��;�<X'e����h�A\��R�%cQc �^��Z�[�\�Ӭ�g$�<I����K�H�>��,�C>�
Gԟ�p���������Q}�j������a�󬌮62�,    ²�̦tE��O͕A.�ks�ik��ʊxm�5�B���ڶ���x�h���0�),�ү��<��5=Jc+R	�=@6G�^9b����Φ��hC�/��3�eU�Ho��QY�ׇ�,�؇�>˳���д'ה��T{����>��{.�/*������[d�d��z����<Ժ,��t�T��}g�q��H�+�h��jն�1�U"Ev�^��?���i��qq�Nrq^�ь� �g�U����	�4�^*#Q�Y��1
�Q2)񒝟��c�1p�����mX��Q�f^��
�x!��*�$� ��Z�Xs���(b�ޤX��)v ����'Y�@3�̯w���`c�w�g�I�ʮ�=Ju[:s��0��Zj-dYT���4�;[�6�&�G$��s���^�B����q��!�j�*�S�E$�<+�h&�j����GsV�-��qn��M=#�D��{xb�@'~��rxw��iN�N4��>r.�ItA0s����ڑ��h���<�Ka�s���ø^���J���	� ����$�e�F6�6?zM�y�j�4��5�<���a�8/|[X���@�{�U/В��T��4H�pU�ލ�5�
�BE�L����/�=�7��S����x'd��^�T)�ۓ��$ZضYB�,<��ii,V�QX'3`��\�vCm
�W�PF������Vn�=\d�NT[Yb���J��0E����]G�����2� �ɶJ);�5�d�R��aJWC�'�/�mI]�3A��^l�ʃw�$ �mFW��\��Qd�~��}'�.�]i#P��7c�x�w��zZ.�i���,L��vAU1az>��V;��x_9�M��b�B�	��1f���gY�$sbV���We \�N�Y4�'�j�dC1?�j�����J-q
�R�9/8�(3���㎋¼t���2+3�*p�.�����$Dj[-5/�C�tE����Ol\��q�*� ���J�2��j�]��T�y��8�UZ:�bd��*<�5m���~Z]���ٟ } igl�90UEX�7�z}�}�J�yw�����PU�֊,F�)�jH��w�xEb�(�8���gZ��S��D&�d5v�b<������zU�?yq�Mi�/������
btnMi���`'�o�-Z��Yj�[�iW\��<R.nI���q���a���e�L�h������哓a����][�׷q�i����Wq�4O�a4Y��,�?Ϧϥ�|�t=D��B�ܷ�����E��ɌK���Ea|FK�@��T�F�d!nj�a��5���m4��&U������6���t4-SLM�gm'��q�;��,:OH5�Z@����`�n�yW��P�����JͥБ��A�ڔa���������,��>���f;
���@͔���_js��#�x��J��F��q�Hw���9>��%Mo_[��&�q��X�y��X����=ǯ8��_x�O��5��|xVWC_�E��KVFI<\_��'�N��`��z�M�N�j�pΫ�@ǌ��&�sh ��w���xs5E��p�eܶ񌴐'Q��BPT��'�^ha�C������A53sS�*7T�(8?�����eZi�}]芉 ���q�e��V�l~!�@'Tv��)d�z-�b[�W��T\��3]2���5�GX0��M��ݝ���m>��k�s���J'�1��0��}ᄲl���j7��u	QP>P��&�?8�W���:;������aE`�z��i��_{w�ɴ���a߷��?�ja]l~\�Q:��&�^rQ����v�;��&-ՠ�Sc:Pk�50/#7��?��E�]��,v�������Q|�wq�ur�yg:��9x��W�����e#������l�xF��@��E*>c�zW����t����ٕ:�Uӊu�`G�.@c��K�
�.�gl.�$�}Ye��6�
�Y�Z�Z���F�v��t>��-_�Um�S��{Fq1�O��j���@(�W�B7�.���*��u�@�ؖ�=װ����I�=�ҁ���/�z$	��S�2Dۨ����ɭɉ@<�ߤ���)��e.��[�ʲ��`w��2'�a�T��jhM¬���b���,�5��Ye�w���+1u��,Ey�EB��j�*�V�+LDKҜ�ۗ��@Ź~��d��DQ���3Ȝ�r�t�Hc��{�#�w�#M�ஶ�Z.PQq��6e�S_��orn��0$�&������%D���=q��r�6O�9����5�bԣ���[���*n�l��̋���
���00�~���#�Ȭg*�\dҨ���K
X
���a���4Y(̀�G0�Y��g`�[?-F;����g�e�=�L���/<=�'&Nx����F#���-Y�4�Z���Ty���7�IeN�)�EE����0���'~�&P��_G��z��&�}�5�9�cܾ�cU�a|��25?���qL��,�8"����])�M�R"���MZ�:̲�ee��L_$�Ud~_$�I�S#K5�5��+z��5^�a_�[5i;��JcSw�6(΂��"m-ߙ[��9�W;�v�?���N�lNV{/��r�����N��<���z�t�e������e�DI�7S��h��ŔF�����3������W��%�6J:c�۷���z��a����b��5���.|<�l�p��x�+��`�Y��-S ����Wh&���?(:	拭v��#��.���a��'�qɣ٫-_E��r�x �.T���q0�;��iF��Z��Ӻ��>�d����R�W5H*3rL���d�4�NqD��~����o�K�HxZ�4�.l��.
_?��� ��j�m_�"C�:����4�J�}%a�N�j��S���z�o�gb�L~�#�G�J�.�0���N{ZΜ�e>�Z���8[�%�㴛13H�*v�(����fѤO(ׇ�;����(�D�0�ͅެRm"�j�hp�~�"[�q�9׃�.�$y5����v��$�\�1��{��ޚ��럛=,?U;������f�#^(���*�b`��G��i73*�2)}��$�gz�7Y�Rϣ9z��y��o�����H�����!l>�jk��ʚE��:��P��
�̟�4�F���_�;fjo����4VL����ق��z�K!��/�G�2M��&Y��D_>�
7f9O[s�dP��:Oy�#�o4����z]��z�m�*���x=��b���L�Ê,,3�0H ҍ�"�g�9�W:p��@j�@���,O����|o��[��7�xke�d�՞˽�U�͸�YTf�p$�L��0��g��/�j*��v͐�@�eI�O�Q�0��^N��7#"�����z��)��]�P���0�|E]ok�b�w��ʾ�ճ�����Q���pz����⏌\y���u��4���i�J�4����D��n|��Ev���>�p1��rl�fmȊ��ęei�3i|"t�@: YJ������*��'��q�`��nO��NB�H�1~�ۇ06a����$O\�����sA���B��'���� �U,����|e?Φn�5��VâCㄺe��/!p���4��H��|�w���R
����]?�Ȓ�E��@z��&G~�Ū)�u�",�Z���H���J��p��	��Ex�2��Y 烶>प#��3�6�:�-�dƟq���t���@D �DSZLdd�� I��\���RY{%��h5�b�H�ь)mV�W�7�$������Z 1.������'8X:��ֺ��1,�e8[��Gٔ&��>ض�:�1_�*��܃=A��x��S(X	�.@Nۿ�������e݈�d�q ���t1̉�U
�,�.��*�W�r��d���G�)�����36� ��sVWc�B�)�T y����;���À��ej��tƫ���d�$I�z�鬪ܧ�4���&�h�q��v�|Ϥ�s'-0�\TC'b�b�<�o���i�^_=����ʺ��� �!_tgQRy'�"F�6ޕ�����/��.�&M��Yi��2�a<Y/=��    �)O���PU8���n�?���J¼B=�7bV��H�5T4��T�k��߱g�|V�����T5��%J���ՐJm���[U<�O~lm��������X��kpg���Ui�f����7]�"�VV#�ĘQ֠b� �ﳻ�b����V%�g���$v箅i����LW,&�du8gP��Q��G�3�<���|���;�H�scr��K���^VM�Tyj1v��}g��Ws��뻻<�'��T(��w�p��6p[�P�9��яD�|\3��<���q�^���*�Ř���[�,���>[�QVxx�9�y$t��Z��{J�d^B�S��<*ڋXI�����U�������<J�E�XM�4����<Γ���Jn�]�jJ�)K���D���Dc@��) ��	�@�U���w
=�my�|����ɼ>�I�y8N�>�=�"�!{��{mT�w��1��D
����a}��Iv=,3OKo�eQ���ô5t�b�ew���R %� g.-� Ya�2�@�7��Q��h�Დ:Qb�����o���yͳ2�}lA
n�xiZ��z'S/�����flMQ��J$����)�̱WKw��[��1��Y*��潉f��<���,K�!ڑ�jk:�L�0�I�I�������WSZL7���p�鉛�di�b��
^)�\���+G{Bm��d����S�{TOp��	���+7��;ˤ�AQBM&2"Mz��)%�i�5!�w�_Y��;I��Ʊ4td�n�__�D��k�ea�'N��%]k�tW��jЗ����E F}@�>pp ��_�_��{'��/��;�49���p�w��	4�o�εU��)���4�Ǟ�*���C����bԒ��ɹ�̳�e|���ى�L(�h^1ҡ�^�O\2������E����>��,����v2x�6���$��~��)��,��QJ~A?u�h^��w}`�3��4�n�m~����h�$��Ŧ�?�|��K���]�?��?M����>9���IϏ���Ozl�����A�4���k�7Q�6�݉e$�_�;{4��#N܉�(�@ Δ�I���
�*B����No_r�M�l}=���ĳ<��H3m�SYDqг�3�P���v-��H*��*r]{�w"d�|ޖ���!um�V3�	E�E�k��"��rtm�st8�}��9d�}3���c��$�hus���?�n�6�g�ϔ|��5e�`���\�>Ӧ�O���J�Z��*G[e���"μ�b�U��y�a=�m$
��R�e�:���b���B�asz5goo�-H�G E�����%!~�ۇ�u�T׷9E��ΐ����G8��A9��>��w�^�f��R?�<���]���d����ʪ����T��u@�}7�̦y��y��QV���A� ?Hc��/&��1��Ɋ�E5,�L�}bڙ�Ò��
���K���(K�<�8ax��K@�?�!�Э��v/�v����C�̓��O�w�B[�0ƫa�{�������X�ߤ䩨"R��E�z�2Qv(��M��$��",�4;S�[�Q6a�Y�ӽ�q�yh�T4��b����ə4�
�c�H�vݮW��u�ʒvA�_do~������ú�<�3�a補���g��G~d=Q���.`NjQ��D�.{�.�H���8 �\��\;�nW�չI�ׇ7��9s�N�$3���b�&��i&��ͮu�|!%�<�u�òJ��9�zfY¡��&�����;�M;�XA�i^D������hH�-+a[����#e:5��g���Z��*��+���uiJ��ծ�|@1aqم�'�,"�愞z'ذ!���n0�E������uq]�R�dXײ�^����M]\_Ɣ��ݘ��:����T���Gҙ����h�wr�^��#������W����3�a\�׏�J�2��Q :�R+sx�E{<��,-�=ϯϽ"��-V� ,���GE<C��,���G�8�p��c&+/`��
Z�F�j��
z���%1U���8�&�޼�����"`��h=��R۩>�����TY�U�Rt��aKyԾw�8bҠ�kZ���>�8��ۗ�,>�m~����?�,V��.7��8����Už�+��_�N�eꚃ���T��[7o����kKj �%z��՝<�z�g);�>��d,^�n�Pd�Wn��@��g;�&eZ�F�ԟ�|�ըȋɿ�M�W�g���.�ȵ(L��M�ԇ��Mq�@Gs9��dl�?�!�������d4֭�'�����Û������]��3�bV�4K+4-Ҕ��<<B�7�gQs�:���7�4�s]%:nwj������o��l�b4��O���9P�O�Ģ����?���sB������&^�~��,%�Fi����܁�p��hUdy��2�D)$[�m]A���U:w����6H\k���/��[���� )��2ήp75R�e
���a�̡d C�h��4�6��A܊��@�TNZ�
����}�y�пHYt��ږ~1P���0TUE�w^*���](��Ӏ��d�iT��1v=�#�(H�\�~`��GsN�κw�!�x�.D�&�7>R�	�"�������T�D�X��jqj���D��>��X�/��ڝFт��p$m:�C䃊�?�NF_r	�)���j �*5���ן�d��D+�̴i��v�`Ĳʗ�h���C�Zs?Dl��Q��ޚf1`ԐUe2"�9�p��$�8�(��C���5Q3o�����4ڏ�L14!׏�Z�pTOtZS9�	���3��,o����Fi��ʔZ��ˢ��o���2����ˑ{�EO�PfߍZ�;����H��Ać"����0��DR�̂���u��7����j���\s��ʯ��C�����̃���	߿}��	N4M���i�4xm��$:VO^Q�,���p��,���D�,�O&^i�J�	D�7���H:�\�?6eMK�qĪ�	��-�y����M��%W��6&�r��$�s3�8qn�QY_1�a����x-#@?�k�L����u��YP��C
 j_�$�^m�� 3��zH�4n���}�I�E6���j�mW5���Qi�R:�H��wp�s��E������ͳ7�0���>�e�{�*�<�:�CԆ��Xz[)��vԖ��%&WUu}}d�$�V�Ud�sL������,Xո���s�+�%�P(���A�w��j�R�$����U�	Y�q��ng�f�h$��F\�����E�)�9��
�.T	4I9�"k��7[�G�`"��֍�LhN:Q<	j��<�O���ټ��O1=<�x5��̮�Z���3���tc�*Et�Ӿԝ0��f�	�Jn�K2	�����*��c���ܒK�"%L*Ecm�6_.�G���˳{� B����x�Vv}���&1ƙA����趇�-���B����yڜf`� w 3f`�b�������H��ۘ:K�q?l�F�mZ4/�}ؼ�'%i�ߛ�q9���A@�~�)J?�� pwzޞ�翡"��b�?	�a*o(E1xK��iA�,�@�;�{��P�L���]�c[�ʖy�\_iDIYx��
r���E�L\c�2&fL�հ�KA���j��t]L�"/�3V_��͑������!_������j=���Rh����U��Q��S�VhfjN�ІB�������%���YI��U5�&��d�Vї�2 �ˁ���4��GF�| �@���8V+:S/�:M�>
��DQ��Hi�b�__�Z��X�n|�W�C���܄�i{kb�:e�V��O�A������:~�Yї�	&dJ�?�Ǘ�֦;I�� ��#RKf2�WS7X��ﱁ`�Xt�������jhF��3�'�v�>PU4��0=S!��~g��a����y�>m�YT��fc�1��?=*ü>�~HD�8?
Wy�4���A��Ϭ�Fv�N�C�3�_z��H>�_]��<��N�@��hIK�����d��    6}{V�����vb�1/555������E��y�k�d��j�K}�FdsYV�R�(��*Q�Ì.������'��*�s`��&+S�z�b���Q	���BC�+^��|�Ղ�eU����_�ԉ�"����[���*�,�Aa�L6����_>��!���VC-�4I��K�8�J7��4x�ފb�L	~���D`P���Kr��GI��5�����vq�*~� ��n�Fo�44������"�}i]��ؽ��2�{������%�;aL�V�T-%��DEX���I��>�y�Y��<�r��b�S�*�3Sw?r�ƥ��jWt)߻$*�qE��v��>dbJ9S}���V\���o^�x<Ҝl<�4 i��Z5�]~�Ή)��ky��]ű?oe�� w�Dt��Ԏ52G'�*��c}�S�+c����3�>�
q`%g��`Z�r<�����o��<��8
���N���=T�ƁN8�:��:���+�X���V���-���D]z���VdI�*�(
��V_Ʉ�0������2��uS~�*<g�z욶���E}Q�3�Ei��8�,���kUr,�M�;^"�RYM��^������:q���/����Z�����[� Ig�� ��ڪY7�lDF��Δ,�,��TɄ�Cb��B�Q�W��.v{�o�G����95/�a��Ǯ^��NO�C�)�>^V�bN��a��[-E�J�8�f�.1-�S,1톹ů���[j�Pd��-�)�)�s-:r�9Ͻj�����~`\���n�IR��O����q�?�l���Q7]<d�+�k�$bre�!��kQ^^,c�ݼ#w�y�͈]���]a�·��TѮ�e���5�[L?'���*g\�$,����E�P+����){�0b�b���C��`
�ĵVŧ�&5_F}=���XI\�Cs}ǖ�a���
HC;��R�!�Z�A���3%��|��
o �\s7_�
 �W���V����W�7/6���LgWF�(�x&a��]�r��
^�b'��'T��.��=�2�~� {�Dz��b�ͥ���)�����8��ʷ!qX�N��V3��(#�zZܴ����v� ����)�DϏs������.ɳĹ	�q�*�J�5�~���;�]�M^7?���Bte�fܘ	�|�Ո�C�89��2Lf$�"�BW�ĉ<�4�3oX�����rPCR ���u)�vwC^��0U`^�B9N�O{��yc=�J���-�ؖm�"Ft4řl,����3�������� %N�.F��G��u�$���̱��l]~:C��Y;�B!3H��:{>y_����#y��SCC �s����U��צ�P+���+�_'"�7��z�h�`G�#�6�1^��Ow��X��V��1���'�w��P���3�7Ċ�"�k.� � 1yޏ�L�2k�O�N�?+��`�Z{�)N<�q1�W�dc�r�M4��z���n!,�W5P,��,Ѳ�O|/)zI7Qޙ�RM5��"%�i����(��2r�Z&��� bn�wXP�HwZ�=!e[Q�#z��W�ZЮ�����:v�Xm��eg7�9�$QUW�� �Y��y|���C:�0jݨ�Ώ�q�7GR�@�E�I��뿭���jS�7n�_��z�m�a�InQu}��Fy�G�q|##�ŉ�K���v����@��m(@D�BƜ�ы�JљS�I��-�<�ʛ�{��a`CK���X�6_B��Ŏ��GN�08�y�4(�7�mw
$�mѓ}D��?PĶ+��q�ߞu�*� ��.���]��et����䁎��l�_�i/��	�B��� �����{k�O���Z�u"Uj�k�i|���b�xmn^|9I�a(�_|�q'>�U�g�V�I_r����a�)L�ib� 1���vǊ�F]�wz���� �j7��h���b��s"�wa6*�Oԛ��wk���sJ��N��PXq� L8���d�E���ŖI������O��d,�)���
�a�M!�j�ST^8��/A�C�9�\�*����Pڣj��X�'���42Ɋ���v���\/���7\Co^)l�Z�9z P�2J�88����j}��*�E1�'��UUi�u⾍X��cG_��^���/����'���k>���H�?�*���噤��ߏ-�hUA���yY]Q�^��!�"Ş^)�j�Q��y�	�r��/�u�5р��)��Q�p�i>���m�z��ˉP��]Ox����]�$�v�1M�
,��_Ъ��`��n�O���>@O��92J���I�3f�)&.[$q@K��
h	ϳ�!9����<�י#���B�Y��,%����-��L�ǅ�Xī=���_�i��"��s�yZ��?����������/�����W:~a�������l%M3�3��"-3n��w��k� Q�I�.���X��2(�!�B�7*��8߳��{����P�/��j��S�+�*��1��j'r��v�Er�r4-��V�z7P̥�zڅ�E*g��?M�L���z��b����yZ�����"xT��༰���þ%�7�כ�/�cjz���g<�x.�>)M(N����@y�M�|�Y�\�)ǁ�)V�u��yS�����,����B�{��F[�O~�A{��g���&��L�QڼJ��;��<_-	,E7,��,�k�[a��*��S���G�#=��0����A]
M.�pT�����^�0o!A�$�vF7�br+����Ɏ��;k⡩�*��A΍��O�K���x�ȓ?��C��ɓ���m�����-��ô��U�i����DW�A_u��b�;��6�oP�Wͦ��sm��kn~W��JJ�����[-t�'�~��RX?��Wo�׈	l>��l.&Cb,F���^s��1���w���шt��<���ԇ	w��|�8>8���wn;�Fn߭=Ic�E]_gQ�����+�{QAo��k����������}PF9��7�%ȚѫV{���Ĕ*����9�;�F�����C�����&N�Z��ۧx�i�X�eId���-�e>c��K��q�/�UP�Ѡ�{Q������������Ve������IiV������_�$�ڛgJ�DzH��� �"�"�_�o̋��1����=�mZ+n�0�����@!l�ǫ���BҼm���t���p�2��)]��Cv�8����s���Ի�g�XyZ]2���N��ͫ
E�ɒӢ&�d��r1��i_���:=���i��if�Kì�=:A��旖<&_��T�8�{�u�s\J�*o��g�N:�4>������;yEr�G�I�(�}HWZwy9�Pi��i|��Ch��-�G�D��d%��_Y2C!
���Ze��Ir�R�$a�`�t;B��J��k2����)ˍ�!Sc�.��q�:OW��G��؂�VRpB[�U���Uׂ�.��u���o��hYO@Ahb�N�O[_�C�Z��6��0�_�O��e�0�����S�i6T1�q�g�����7!2h�Q'��Pbd5N��Yݿ�&"m���q�t�����%ʾ�W-�?a�KC�����9��D$[vµ;�Nap����| ���\�4l����H��N�$�\py����U�����G����Um!�����[`�y׶���0Wg��K�U!侭�7T�'r�l�:5�p+@�?�����(��$Z�][�:Q��������i��]St��B�*�=8��?��E��.�ˑj��B�
z���?�=ć{~~65͋�>�"�bz��fl˛w�LҾOg(��a��=�g>����� 2"�sG���c��\����q>�,��2��,
�E�K�v'`/o~���v�'KttD'��>(��<pX%��D�y
Q
�y�B����:��o*s��uݐBid��Z[�S�
��yl��߁q�2�.d�s����@a����5���X�
}CE�VN�Q����p>�VD~�6�1��ڼ�pW��6���dck�=Ն��(�o��A}/Ϝ�Ș�!���#�<    �`A�f�X#�ƙ�$ A�]� �;��w�H���fL��H3���8��B�7�=g����B	�U:�"afj?��,@�ɴ�us���	~/�#<�����փ��.��������'7�_�Z�bPV?�f�-o e�.�g1�mn2Y�h��'�z�V��� 	Y�f錧5����-�9#��r'r=���m��28���J������Ӱ*}p���[h��Pщ̓9f��Q�I�!8L!v�PQ>�'6?�ཪ���n������"=�����rs�!.���೒Zq_i�.��(1��5r����l���b#���tFt�*���"��a|���v�<��v�� �.���U���ÎJ�"�'�*���:�|=�ǥ�Y��l��Y�9"�tde��p�t���鉳~����RWA����~��}�9�<J[�3���(���[���_9�5���H�eT�C̪�]�!о�d�
��Po~@�������)^#��[��c;k�*�q�M{�l��<޾�:��:�hH�9=�\�=�V�j5����m�����"Ls�(P�(y���DIX&8
K��9er�b-(�E�3��QH���� �����I=Co��Y"?l����^:c���ku<0���vl�?ᅡ������һNg�䚌,�6Z;g1��<��tFl�Ĵ1.���7Ia
>Q�d�3c��e}���=I�2�a*�t��6��f�����^��q1�$O�d�_aZ���4PE�e��7'��5d��x�������U��bm����5�~s�	�Y��B�N@�K'3)���ިS�F�N�x�mb��f�r�m(��W'k�A�P|��4
�h|������;��y�M_P��=�f�'�w.��6��rE� �6�h�ݑ��j��ħEG`-�W�N���l�&&ܗ�)\9�E��Y.�4���<~�9�T�@���[u�*P��'|yQa��������@�e���?z�9�nqP����RƐ��VkU����:��J�,����TYL">�g��c@+����W�c�R�,@x'�������b=�R��y�4�����l����F&3�}x�r��n1Ѭ|(���YFY�0��T{A������K��F��)�ET�3f�e\� YD� �xEE:��Q���ߑE@���K�D4��'�'���,�:��]��7���ش�K0�(Aj�n��"�/R��u�B��Q�Qج��Bk
�����rף�C�`�,����r��m]�df}6C�N����I��l��l+�Z���0�ߩ!x�[)dAhX)ڻ����]\��O�~�Ut&3]Ob�¤��[����G	�5!2;ƒR���}Z�t�%T����*��:n�4�/Z^I9\�1����4E��FR�O(�ڎr�v���Rgz��_{� �| c����bC�2J��>����">�'�6{g7�����=�WTbJ�����ՠ����e�e��p�i\�D\4Vy�z�'7�S���^2��Y�Ƚ��n��c�����
&����*�L�b�$�r��c����r�Ҥ�v�U�F�詨Z�9�kAsVfώpZ�\Һ0P�j���u˲����tҡ<�!���Z�{�H���+fe���?K/nL�8Bx�+��{�Ebv��?�;2����ŕu^� �UUX��L����@�E�Kq[d:Ju��N;'��K�f�W>]�c�kU�6[ �?o�3jડec�8�gZDS�F��Mll��3�拢��A8q�C�_�`/�����Vi��$�g�����%0b�L��{��T�V�ɤ0���"��\���I�zz�UI(�L��8�����R;�hO�mZ�;'g�r{�f�^�}t�F�;ސ���b����յ}:�(�"�e�j����r�o
��W+�e��N��0�l���{�p;��)���®K�����s�	��4f[jSA O���E�e�S��I�2�T����X��W��k�h��}�������*��K�wj;e�y��*���y����x��@�X�di�v������T�8�}p��e6�l�i����MU����]�e�H�xt3F*Tb���Bw���T�Ehpb�T�����ܥ
�0�qJ�$*\#R��0rHa�[�Ó.2hrr�S����]�2�p�蟔���q�J�n�@�OM�m^)�����]���3���y(���p��;l��.����Y���Q���Lj͖Z�=�[n��-ְe��;��eׅ/L�{^$�|T�U.$L���`ł��:�e��:�-U��ҿ�ʨ_�:/�����V��c�Tq�_x1�3+�+��c�{��l��B8P�9�?�I�bv^�B���Q�R .t���2$�����Xl�]���nVE^`�,gF�����J��$8O!/f�*򍖛�����<��pnl���o����bÜ*��!�>�y1I�U��
{ZJ�G��d8��0YL��*ڮ��R�*�jaU|�Y�L�:|%��W�7�&H
&��)�i�e\_��2u���Ճ��.�¸ro[_�9să^M! �7�~��ź�,O�|�{<*��
W�.6�z`�g���*~�F�8rlpԽQ�=d�p����Mp3��`��H[p�_q�\���uX��q"U\_sϝ;��'���V�}K@�v��u�wW��{��a��חQb�(.3Vi��)�Ⱦ�2�.�wL8�ƟNĬh�@���	ů�&R�j=-�Ś�:*���aL��nصU�I.�7
���g)MS���i�;��_�t���r�EWCRΈZ�z�g����{Y���ԯ�J�$�c�erj�:�}��:��j]�u<#��e��U�Q�UPx��&���n����1��ۼsh�8�7�lb�^�;���%��M����ء4?�fh���-6Q5���BEw��y�AU?��F�����z<�6��N�yEƧNP�A�3�ڍ������n5�r�l�v��^��^y���h��ى�)a&��: �|e�ux�N��j���0-MT]�e���s�M��E��T+�~����v�����<��35���#��<�^,����'M�ь f��H.�d�N�$xㄞf'eԉ���b��7X��X��dQ^_��E�V��S�<g�ӷ�x�>,�M?�gT�t:� ����e���E��傗�Cq}��&|>xIp��K�[��Ss���q'�&ޫu��Q5e�D׷c��*���&~'D�e2�>����q���Y���.
R�Hm5�r:!M�W���Ffy僖_�ᝪ5���=�k��$������Z2�p�,(F`���	���$�$~��S����<3.�������Z&�=jұ2�
��?�z;ba� U7Ӊ��CY�� ���R�
v ��5��$<.	�P���?����j��,�8��i;&Ӹ��אe?���룸� ��[ȑ��~`[���=_ġk�	Ur�O;.��LW+�3Qh�l��b��(����-M)E�^8n��=s��0�K5`�i�b�ۦ���p�Q⋼"����E�"�e��R�Ů��TX�Q��o*��3�vVq�8���:����� �A9���K��yv}�$Y�v�IXo��%���Hs3�Gͅ��8����`I�B�}�V���]J��&���I�","�*�f}O"F��\�TjI�/�y�JT9�/�n����=�^{��Z޾8F�i?��gY���t�j��L9�בlv"hI7�~�������m֓_Z�}k��z��V�f���Qd*k�'_�gQ+��������A�K"�/��}1�O��ѽ��4�8�%.��=6t�8��PT�}�QQ��ße1��s�����O���Ф0��^7lu�K�1�=��{w%�0BwP�V[�f��;az�"�;u 1h:a��H=! b��k"`�h4k�����Y�MNĿ4�͛�5���H�	���,��W}�:��q�Lץh�Ͱ	�H�����^,÷YU%3ʞ�
�� ���?2D�;j=LT�P���_|�?�gr��:�w����mѵ݌��<љ��q��!�$L�,�E�ί"��)b    �冃�����waR���Ӵ��@�` �w���N�d&H�)�bO 	��V�m����˴���C~�Q��.�|ȇ�SNZ�UX�0f�(a�Q6u؄���H�/=���.����/ۓy��83hbT����<�0����ue3͖�i���恸UPI1N�"g�ͬiE�t��8��h(jW�es=-�&�����v"�O�
�l�M�L���������!�_��z�q1�Ү)�hơ���wwQ�Z�c��F���6��Q��q���(�LX-�#�[�v#�4n]�&e�׏g3S�D��U������ϫ(e��AZP�zg걈4"�H�\m��؅��<���� #���q�|�����'���G`���6^J��O�,�q��<�Xl�5���nBѠ�����gu�����r����)ť�m*4��u����濱	����a��[�jL� �?�m~���?���[l.g�|A���4W����,m�(uC^6��N�t��1��YܓrAI/�5!�m�c����U�M#~Q��i�!���gC�,}�\��e�['�b�7(l��ͽ��ˏ��Y̵�u�뇳�I��8�2����t��;.]���3_�6
g�߲�K�GbiԐt9q]f�o�э APiN����M��3�Rނ5����bT�	��K�
��`�'����>�����V�P��ꇑ�۱��Ù�߾<U_f}x}���y��g2$*n��rK?i�?�]XY��;v����9��[�=[�`��h��4c�,xc�B�?@��6���>� '`8gN�N0X�]�1��2��j)�4a�?_>s�|w�����Ž���>�� �.�9 G���av�2��E҂�}	�%?M���nW2Dq7cL��SY��Nu�Z0����X(w�.�+��?\^(���n�}�o4�z���q1��Ud�[?$�0#�E��>7��7P'O�k���t��2�S�,�IÙ�=Ήݎ��勋�^����,����弊L��bY�;���������tw@��iG�����:��F`.�ʂIZ3����ޚ
X�Z7 �������X�%ً>�D��jol�(�����сu-�z� Ԋ]�{+׎��&�6KK2e�T�!��.��J-� ��6�R�.�:�>��GV�0�l��0�<eڠ�(J���O������Pd�k�EwE���"�$a@��<o�Ǯ�0��̜���l����q�n�^8TE?c�TDe��
(����O^�S����}����h��Ȝ���@�ͣ\�ש�}�Oq���C�u�X�Ӽ�Ģh�$�+��ۆ\�
v�g�W���=��n�:�>քA��ZU. ��l�����
��Q���ڰ����FM:#ʰiq'I${7[���oe��b�����������%��e'|9��f�$����v�殾L���(F�3����@r��c}�*���;�d����%�OO��-��'YV8�$ɂ_Lz=��j�V �S��^ǐ4Կ�n��x��(�J0i�iy}�]�i��K�S"�)�v��퉞������*
�G������P���t'r&�~�l�=A�f�L�0�muQ�E�@�I�o�n�;ġF�o,�S��g���^ڼ!b�ą4��$��+γ�?�[��hm~�L�4L�&��2Q9I������������n�s'j�A���2~w�¹��V��ZJ<*�.�g��*.K�T����te�k9�c��r~���B�$���F��ފ��������͖���i�Ō�S�y�7
i|A{�U9܄�p�؊ߗ�x~`�~����q�~R�<5 ˢ���8e���ȥQ ����ٴ�<@-;~(��8<�AD�x�1�� ��_�W^��!�*�Q�qy�Pj�����{R��X�Y�`פ����#ӅF�S��$�n�j&�"�A�(sq\.N(	�t���(5~R�:���_ Ϛ7�럠�l���	��:z�=��M\k�����Y���'��K!`E*��W��Gs�'�F�����X�B�O����#�U'�;N[��ۙ_�x}�����[�Ҡ�%a��Ѽ���Ѥvw����(&��M�LuVqm���l҅
����L��Ԩ���*[�Z:J$�t�N����Z�<�	$_����)�q��1^���t�P�Y� ��鷧���~,E?i���0��ä��A���܊��\�ا�u�2�_��Y��̊���[-�	o9֩� ���_���F[jPcNg\�hTʼ(B_��4x����������i�7�߿���⼥}�3v�̿��������C�+�/�vk�,ts�ݠ����Z��o�w�a�n��1V�0<�#��� �0��ĩr� �đ�<�{��qև�>/��U��@����2/�J(������,JT��B0����R����I\BcTDl�c�w�����氮F�_�VF�TU3neQ����"���+v����o�<�{
+�c��$f����I8�����^9-�?L� iN=�����[����K& M=�M�
I30ۏ���/�?�躞g�����	{G�@^o�Ի^6r����r�LL�ؙK�9��*'k����<������$�Sp�f�꼏,]�~���,���t�JRh�e��ݽz�N��PcoO�������5�:Lǁhŷ4X�GEp"�,�U�q.VC�-�GY��@ؕUU9��$�������s5�WV��D�ދ�_s�u` ����	u�Tx�����,o�W85o�_��4�����Gܸ��x�]��w����V�_�ٝFe��UWQU�̢�ze��d��0aǃ��X�z�#�{:H�� ��Q���H�M�~?U�)��d\:��$�������x�Xl��zk���&[&�i�M	#�CUR�*%��y�1Zm9�܁��l��@����`��]�DRz;��
^?����v��,�6lZ"3����^�V:BV�8�i���0����� �hxU{�@ɏV7�����lKr)�k2r�B�	�`�k��E;]�'��W��t��yS=��[�P�i���߁�V*
�*zd�[DM���_�W�Z��N���0��s�]�f�/!l~���)�+���b.m�j��OV@��\!s�C�rb��?���a��@0 MBu�ȫ�KBK�W�/�j��ɻe^��,��,ͽ�K���$�/rz�>+�]���m(�KQr��c��ko0�ѲV���em���g�CMh��7���b�i�6�fd}�,zU�,~ÍS�аÄ@"r��
h�/�Z�����@�(������S�bƲ�*����iaN�	�`�䎟Iqq6�p�:B�b�D�O���L��=V��I�D2*����AUF���g��4�L���4R�Lii���2����+n����qה3Bh��U�7�'����EGчWh���1�I��QP�h�1V�z��K���4�f_���=�&Q���
��V;Toq�;t@VW!���x����(�<�aV�6�Zݼ�SgM�\{iQ&����Q�I8>*��l̔�nO⊥\�.G�#tLIƧ�+��o�W/�F��ՙgQ�=z�o�Z*^�E,�6��n��������Ƒ�����TҺT�$��rYV��H��Q���ș���jkL`ej9�g������y��Bu%��R��)�f�itt�\Ռ؍����p��Kw��Op�kK�y��q'�;1],�s��
������$'�0�09�4?�G	#�d�F�=Lx7)�G<�Vb�?��p?ԕ]��p��\\��˳��,7~�˴����j�M��$��T��3�@O�3�I�Y��|-^�r$�����R��ϕĕ/�$6�NVQ5�[Uc�ůL�C�mcs�M@_4���yz,��������g�Y���
Hms����� x�X'%,C0��꿘�@ �7/ml�r�V3���]z�W���Vp�n��"�A1�tv���E�d0#�Z����aj��4��^��W�E�Y�I2�r���ԉ&Xg���"D�Xa"#��R�![��    o9h\<D};��M��1���D��{?E�Y��A��(���@N�va3Eœ����S��'d�'Ν�hq�tVu>�ʖ�+s� ���U�d�Z�����N�Ź������-�D}c
�Öj&$��s*<2���-QF��y��4�����A����6�E�a�!����#^��݁Sƥ�yɑ4I����K����Q�V�!zR*=���"��MY�տ҂!�|�Ю��UC/�"�ܜ���#�S��k���Q�������o�gG� �Z���qv`.�ñ�a���F���-��I�x���jn�߅I�FP	_���F��)�>^�0��_���U����ǐ�'i���u��]�^��Ei�y`G���.�p�wt0�d�&�l��w~���v�Xo7��}m��ꯏUVT~�Wd��x����֘�Z?g��O�|aRS�@U]�'���/A��E�X6(Y^�x�B!�t5,aw�2g���x��-0�s�̓����+���D���������ϡ�L���u��u�E��&}����o��0���K�Lb/y[�
��'�jҝP�����lLG��sK+��"�ĵ��|0��z\�Tn�4�9��K�ˀ�u��&8e$_����U�.u�Bap�ݎG���(��zN�K	4������C)��B/�V@��ޓ�p����x9aTZ?a����ƒ�^���/cX�����8�R(�gK�X�NӺn��(�WT��٠ز2��PЩ�P����i^�(_�8����)��v<D	�m��jM��N���ߟu"P��%��$Ӵ�����T���`�qp/�ޣ8n������L�R�G� |C�a�J^�U�Ev"�z�(�����6g�Γ��V�U*7�$<+�4�ن��V,�p�<Tg�:7�|~u��]�{*�tb=�����ݼ�S�6M:�x�b�(��Wlt�օ$���zG:j�(��$���V{އ�;8�x&I 2�fha��6�YJ�&M��쮟�!�3��,����N��:Vt�(���'G\蝮7h�g���$��8	���z���z�� ���i?#�U��2���$kS�g���k��3"k�2�0$�d��y�*��:�1���l�k���-�/�fa�3�X����_��!�Pf���I���9��ݳ`�'�{5�(Ws1_��$�L�^��%a��ai����Le3�&Ȳ9�O�A��^:�-?Z�P��x�?Y��oJ���j���Y�gI?#�EV8@Y�3�n͢`���[8E�^i5�v�Hx��	?�j7�(�r����Uq}�I�,�ܦ*4aCvx}�$��q�4�JuulX�hF
�EC�ă>1��~���=\�W��<βfH�/��8	��VA# �Y�a�fZ��R2�b�'��B=K�*�yo�4��b20I�ܷ1U���Ꞿ��Lv�J
�������a�jg�s��>k��XF7o�f�����,M�b��Hy J�	�ΊB�.���w��Dw�|hy��d�V�u\���UYR\?�J�<w��J�JwUEv�M)����T�ۓ(�LE�iA1����]�5���\�1�Q���Y�^�l�(���+L��#?������'���׎�XO/��.�2�f�^4�Efm�t3�D^�~Q�>�P4����[C�B�5�Q�G�Y�麤��"O�BU�r��bGv�U�J����c_�6���x�T�j5�b��l��9�EYƉ�%�J�ӻ���Y#��oӰj�KgI�|{���d��0UK����Fٌ�U����Wpצ2�� ����VȔ��P�pp���R����w�y\W��MU�qn�����g��1{��"i��m��j�{��Z,Oê�~n�Fy��.�"��D+1�a��IT� ����q��X.���g��T��g�O~��'�S?
6�Z�QG��X0�_q)�q�
E�<%����7ab�]_��Il^
�$x�І�>�u�l�|Q���<�jV��o� 85W(����#}��^��dY,E�"��q~!�hd#�� �������р�ď�Z\����j��OH�0�.$j����{gvdm��q#V�P�<��"��)@_��id�ӈt��d���s��s|����j����P��O�-��ND��y��������8��@��an��6-��*�/�2��e��(�{�z����� �ֲ���?�WwG9�FL|�cńÜ\0QÝ9�0_���R� ����a�����2x�]��m=A�D'b��g����~�OJ"x���������+�$�o��<N&q��/N���Μ�2J���vLz�jA���fk�(�?v��c��,V�M�f3�X��e���O�Ī����C���a���꡴�ڣ���k��@�Us��,�$�˺Q|�g9�� k\D*�r���j���}�Lo�'��>�"�^��u f�;��(}�/�^ZY*�I7׿�yE�����mݼR!X��ta���BQa�p�N�|��h��]�2�Ҵ���rfi��^8��9Lk7T6�T~̘�u{���|�	[�ơyi�)>8D섣�02����'Ks`��۶<)&�K�T�Ժ��9Q�k���m�&��uΣ� J���)�R��p�I�3O��~��J��^,�a���AMQ~7
V;�_�򬆃W���$ B�#1ELO��΄}�?7ٛ���0���� OXM������Rv�[����Jâ�I{��<�O�������r�eA!z��?����p&���-�.�f�4�'�`ܷD��X��9�l�^�CQ,����zz�>O���Z�۩���=X�����<��L(^(��D�T')�N|T�����I���� L%��V�)�1�/�E�����zJ�\dk���������p1�%�/�h0+[Z�O�P��Ǯ���)�]�V9����:��{�[����# N�9�Ϣu2���O�<��z���ʞ����21ϒ(��'��P���n'�\��yKv�#��Q�.`��6�Z����a�*f�������~�.r���sam�ә+�'�7�	����2H�,Ƒ/�f���ɋ0u�|���ڿ5;�UbB��E�M����Ѧ#i��Kܛ��V.�+�$+g��eN��i��j��%��_�`5Q��,�ʮ�f��e��n;��*���R�
:g��!����A�t&n�O�(�.��b˫"r�#��?!]�:L�]���e{>��Z��XIu/J\b"o*TRT���^ՙ'�$��*[^���7Y-5.��X�0�`W�Y\��+��oL��O��������� >�W3	SS�i��u1�X�y�����G)	~�r�*�����&Z۾п
H�t��\	�Pn&���fK������UD�V�u�q|���˼�",�g'DԾ��x�(a�M<�2���Sp7�"3ദ��(��Nn?]�_�F�$�b�R���B�g��I��2�6�2͓�s�	�-�&=��ԩ5��g�&lg�E��>������t���jO�7���#�@ j+]�*F��p�y�8�o��*�"5擭V�,րU�m[�Ҵnnbd�B[��~=�:XL��Nb6��O��sB�9ޟQ=�w5�Z�L(zte�z�4̧� �L!S	��zK��S/�ߢ��P~�Duh�S:�먿[�l�1䯃�5w2�`����m�Q���t�z��y��P�1s������4%�����aさ��zIS����&e������(F^���y�BqT&��@w�a�GnS�ިC���0ҽ�3r��dV�v{�>�&s�.X�=s�W�	,���a�׿�%���-�T�L�i��bQd�� Ng��uٓ��N��P5�	�RP�B� 1��)�/���Q%���e<��%`@�f��tS�ojP��5�-��}q��)7�E�4��:R��Z�'[ζ���۴gD����I�|�j������?��q��#_�0�Ψ~��/�봨����Ҝ��]�F�樼3ח^0�S�ǹ����y1�U!l���x#��d��p1�X�WI7�f�TI�$�!�z�paW.��    �~ ��t1�.�&v���UKU��Y��-��K�\��+���K�{J�{�LO��V��yl)�5�@ky�`%���(��9jU��Oi�"q�Ri���p&��Yʂ�@|}߃Ӵy�7'������T��6?A�ل%&�S:XTڣ�6����[R�M=� [�� ��恸�YP�K�I���uy=��L)�a�}7�=��Qct8�%�Ĝ�#N���ZM�m��b��{�*�� :)����In�U|�f����MŹi�����N���tp2{��s��4�j��x�����|R�T�vڸ�\��tb�D��xV�[��ة�.��Rî�t����({�;C�n���x:�Z���vr����"��[!;���DU�HЂ���}P�Ǧ=4�>ƨ��ǜˇ�ˈ�Kpw��+z��*�KMo�I9$1�̟F�f�7��jf��F9��]�	�����*Ż* ����|C�i+RM������u�07e5�b2hMF3Ի�$-�nf����P�l�j^���ةA��tۇ�6e�p��]�'�o�I۸��)�*��N�v4V:A�4���;(�l�q���6��Z��a_mʲ�D�ɋ"�����"�e__��J�'�v���?;�t�Gā?B�jr4�ó��u��p�&���3�r��L�rpU^�f�L�LRD~���CǑ�L�B�����Ԩ�|%vC6S�u����`����׳s_
��Tm3c'Z��qM�'�)iR7�,c@��eU���O��.�i�n�~|U���%�Y��/R;�g������k�{ 6nv�,�{���o��4pȽ��׼�V���}�����9�M[���Ӄ�*�܁���ԋ*�Z�a3ћ��5��E�����%�n�����I"W
��H3�"���y�E=�����:�|ydA�e �.z\�\��Y�8�΢��{_D)	 m6elR����4Y����ﬂ���X ��)�����M~�w��8ޔgG��X<60�6?���$�����r;;]��H��q��t���4��%�jmh/z�����H=���Ans�s��q1�P3��Z_��<�}�["��g��55�k�=�;SvA"����h�6�H�y��s���Y�a�3�����U�[��y{�w2���d�m����HlGC����٢�U5�|�ۧNbZ�ׇ0�b?���@���TK=�{MC���u>��\�a�+4��3Z�j���F|m�WWk�!ZeZ�Mw��Js1�p{6O�*Ჲ�
�i_�{�a������}Ő6��+&hi^$.mfq�Su�p(�ѻ��܆����-XPy�8�'�-+(��`5U��F�m�a~}ܲ��|ܒ��jy��[8��_�lɍ#��9�_P���X�$M���-ژ�%�K� ��%���8�="�3Oți�ب���*GD�v�A�4#��M����ml A5���F���n5�߬�GA�X�6&t��C$Y�����o{q��P�<�ė�4���������z�]<X��G��:�^P=�&�a�PFu�;��2|���b��]�pyN�R�*��Fp��'�9�i�ќR☼%�h�H�����<�
x��\��x�Q�l��M�No�E͹˓t�R�������*�*R���ǧ��R�b��̗Y�X�4Ǣ)ڨ/o��ɥ�g-s���tܾzu\�SP�c��.R6/�G+ߦ^g�^B�X�9_sߔ}�OH�E�$������- -�y$y�언�04��O�MG��'<�eV���� l:�tSt ��Xq6���_�j»X}��y���:�	%l��V<rYSۉ��y�M��^�4M
���<�OW��
��-��-��D�7�	���{��N~+�H|����/hE�H+d!�D�5�ަB�V(��uQ�Gf�5����?��?5�ځ�'�A��	9�t�X������l�����#[:h�M��܎+L��28�]n6P��~����[�3[���)~�4�G��F�d��(�E=�`{�������Ǧ�����Y�t��b����H �A�G�6N�W�P�H�m/#U.V���Vda߷����&�kŪ8��	&S�趫�B��hh��$� ��������^��Pr@�h�e�l@�R�G.2?�)���w3|'Vg�5�)����H�`�P�`��
Ag�;Y:�b��r=9���A�(��:�q!��
*p�� Kņ@��4k�H�4_�bJ��x���P�0���[eB�i8X��h�~�Y].�����H_��U1�Zٍ����l��!?_N��bW�ꢇ����iW��׷Z-5��qk
����@���(x+�$�贃���H=���Pe�TDӓ9��݈��[�z�)(&i�M*%�����m�&�n��$}u����aP���r�yW	�b<J��3m��ª�/���ҍ.˾o�͋L�J��.�47[u�&aN8�iR��AΓ@�=/%3�Z�g�b�����"�{�������wȍ�^��Ɯ�9��RE~8��y���6ͦ��Q�����#)?���������T`_��6|�ڰ��u=�J�Y�uG�OJ�7A�)�������9�vt�.��|1����
m���b�<�1��\���+z��M�7X,���S�H��G[�8��N���RF�d�̶�0����W����n�E��zl%���;�?]a��\����>��?���noӨ�n�Eu��>���0����>�Ǵ��1���5d�0ڷsw8k���v�����ie��y�78pqWN�4�+؟�*x{9�6�'H���T�)�rB@��Ϩ�h� Z���c'>�8���ͥ�l�wTL^g��+ u�**$���L�p�)�5-c�j
��Q�-(�7�E�1	�"���@�����,��v�O\f#_O��;ٱ��k�cjŁW�K���{s������z�t��FWg݄�-������EX� ne�)Fy-$m�Ζ£V�h�q�l8�n�V�������#�$�p4W�����鴎*�/�pln�����D���~�>M�ۏQW�/o�4�]SէU��<��T�|�g����YZJ�D�.�L��? �5�ZZEYv{=��@���f�amkigba~8ҷr4�▍S<(,q�'nV� r֌\�ػ6��\�Es��21�u�as�<cM�D���H���'γ����v)�0[��e��/M�y{i��4�טl!$ld@���s$��A��Z}M��_(���&�p��2�|X���J5�P�R�{G���3���x�+q����������:E��̟�x��:�|���?C	CW�&3��/L�1���@���+P�ֹ���Wp@�*�����V�XAӈ7�J��yX�B= 4up��V:��>��y��_���a��+��?1[��\�9���5,�N}mB}5?����#����f$�}:t{Uʅ��(��	�b4�$�e�\��Y_�U��.`
�8�}{��YU9�OQ��>���|6�X��ZU��`J���ab�zVX�V�?�o����_K!~�ʛ2ޘ�@�#EPYM$݄���5a\ ��o.n)��;;�,��7h�����ۋ�4N2/�^F�[�%�[*�5,��]�eŁҸ�J�q,��Ù���o׷��i�Y[��;+�	r5��,�_Ȩ3.˹lϕ��0l��)�F���L�w�	�1$�y��0?�a������P�*�yQЫ"h]>֢)�Ӣ銪of	k�e�i�f��i�+a�ǉ�D������V�0��D�-o�¿w)`����C��a�N8�y���̂�5()�\��K ��k�p���c9I��ffy��=��()���;�:ӫ-���e��->`�D���-��	� UV,�X����p���D�"��Y"Z�ՔTPf#ݕ���w�΋k����&S`ʂ罝屓�>��Y;SO�ݲV7��"�_�����I56q�a#B�֨@�a>���X�3�$���v�q9R�����@=)*s+��"�fʹ`�Z	g`��:�@�(�G��]տ�/D����    ��?� FDaw�ή�>��u�/���X��C���YU���`I�ea�7����r1}�����,�	hh�,�~�V��?	nՒTW]}G�s5:�����_�D��}L��|�_q��#YhHv{�Ea楹�
�B�鄦�ܫO��aN>����S���+ԗ���y2O�L�&�L�8)C�-�25�FB@�E�� 5�I�W��e� [�q.�,��*�pĒ,�ޑU$җ��������	�����\`O���L�_'cg��+���J��O���
K�s�͐z����m�n��Uڟ܏����7V��7J4�_��Q7:�=@�&}���yXY�?��&��t�6��7����'c���9�o�4z.X�A��3��:��)���q<�?��˟v�G��S��PY��h_.}��o�� �3�Q~�n�hR8��SI�Ms@�(#����;̯��K��Rq{v$�m���@Q�&GM�����c�?m��0\��]�M8�r8��,\��o9�����Cz�m@��HN)�m�����5�s��~�s�	Og���z�ʂ'��R���fl��(�KS3�J�hd��'�y�Cy���b��F���[�aq�c���r�mփ�Ir;b7+��"��*	�Bs쎊G�Pp�7�յ��߽=�򨝠����-� k�E��ei3�)1���eQ��I˪4��(�6
��>�$��=�{V�<�m��|t^/ɴr
\`�Ő�q�D����*��g�yXd_U�'�'�X_�?�V�HHH|#9�glʻw���p]�o?Y�)���[f���T6����
@���uxX}P�ƺi�����-C#����l�+��z>(��"q�w�=d(vWgw�a⫵̠4�`Pj_L��aqf�pa �E!���&��[�k��>����³��4�&�#���i���s<
�n�V��`�����3�}���1��P�)��ݒ�p��ZTH���8ˊv�	.�P��&��hYآY���4r�6�ro��Q���\�����iX/�\�k)��l�{Y�W]s{�C�:r�K�� UY�ը�hFı�t�!�TXf���6��7��Y�~���|i�,��&�9^��q$J�%�3(�%Ab�i �ڌXz�s��*����KZ���y��m�W��Щ쀂��i�%'34��V�e9���"�o_Lq�n_1vե��M��A���Ί]�Y�mQ���@�dn����Dyr������T�^R@=R�pN"���d ��'6fqW��w{ S6_�U�[�D�V����h�-3P�G��j�G�}����ȕwo��%aQN��Y^��8
�?.۱k�QR�)��^J/�O�Xq.r^��i�O8Yy��nFQ�Ѵ���x��1��[՝e4$���{\]�$]2�(�g4�]����WL9��$Y)����������aEYF�0�EI�	)����� 3ЮE��`�	\XYB��]��t���ƹΒ|]��#ڋ��J7ۈLy�e�A��V����0�<_�\Ѥ��a�+rFT3Ħ���{F*y*���:,ݫ��\����{�����x�Wp�LD!z$a�{��N��֕���/�8œ��bG��ͷ�)Ω�M�	T9��\ �&��A-s�b����r�ka9�~��Y%T����
NW�22�����.:M��D&�m�I��rG���=¢�u��o~lZ�Uhϳ��'ˁ#fқȒ����DI�Uwr���bE��������n:��1u|!H�+L�2�a����.���YRUل�ZFy��� ʃ7�]W����u�PaZ8[zz6��	�삏j	Ņ��Itg��R"�1��U��M�Q��>�(�<Ŵ0'�:f��ʑ��\�����(�'BX�'�5ͬ��bs	�gI���ۇe�x�h��b��Üh���*x�\��wH�P���V(+s8���<FB(�J��b>���dI[T�(e�O��y�r!͸�Qc�Km4�(����ۭ���L�7F�\���������p�U�\��0x����ZP��>��ˠr��R��g�đ�y>A�����I�dq����8�������L.	bT�}g��4ZٔUi�O<J�jV^NF|k�L]+�#���L5H\������z�����B�[��:���
iO�䕦Ջ]��NO�8HW8]Aknn\�ը�E������)�A-7L�+��i�N�.����eq|V���R��j�m[-]`	[���'�6�%�B��d��n6hl������yYe����Y��֢a��r���^a�<��h�q�t�]}���:ߪ'��*�J1W�$�\Χl.!�&�@�7g��.I�lhӿ��M�9����'X��kQ}�v2�:�~��x7ŁU|�-�[z�_���f�d��nn}UQ�����񄟿9n����e��Zzu���/���C�E,ݛ.B_:��l�O�o��AZ;ǋ�櫝Ss'�*��(�2x9��`Փ`!�!{�����l�SB�8�8��Ӏ@�'1F1��wF�Xl.;�,?]�ew{�Q%Q�7��
>p>3b�n�tB����6�������m��nN��r�lx���)�9M#_e'a��h~pZ�=ڥ�uniR�f'��*��>��
JĖ��s�n�]�A��R٫tIio����Ui��������U�I4*1Gm <}X��/�i���7�����w����W��zG{�N�k/�GK�/�oÙ��5��n�'uA��/��.6����j��ݶ�%ZN[i.8if���v�Ae*g�%I�_���y�w��֙�l�g���w!�Z���]q�����m=� `M�lM�њr��CY,笫������6�YE�t��3I�b_f��/V:�ә?��Y9���E\�s�n�q'gCp����F�fJ����&w/�e�f}3�7�%K��ъ�5NW1���Y}a�8���5�p!�!I�#��Iqs�8Ue���,°�|_�h�C��ƉkO�&��i�o���|��މ�+� ^t� �Oa1��l��k�vB�
]�����pJR��o{q2^}}�(9��iM)��P>�!�a��I�K�3˳��Y�#}��4�e�y�un�Hog���ƭ\�s<���xwﮛ�y����ˉOU����U�」�>�jU#����a;\;��u�'P\۴$�A�fkZ�n�����a�4.�P��_��>6d"���8 �_ l]W�d�|��B�[�D~.�c^%YWN�[�T>nQ�[�����m<��_�����6��ڬ��yXŪ�� ����#�3Z�Ûm��E�oj������8p��4�%6�7Ӥ�L����ŽB�aT��Q���-Gu��5�M	w���(N�t8��'�tm1l����!�A]C�^Qy��<��a��g�[y��T�4u6!kdQ����N$�>Y}>���+���r���t����/#*�Nr��`�Y���I�Ͷ���>*'$��JWB�Y�/��E�t�P����9VO�~GKQҶ'�I�`[�bZ������]g�����I&�üH*���I���<?"h~�����8&�9��K���5�G�o���rP��1	n�
����.���QV��a��2|��~;�V[�yP�ap^'�i�w��T�H�u.t%#y��z�a+A>
����bC�������L�����Z��
�Y<�uצ�N�	��`�"��_�:�r��2�ܗ����~���,�����Yc���V�N��|{����W%�*��Fp�SXf��I�[�� ��I8�ë�(^TT��a�貙��`(��=��pY��{|g�q�W���ȝ�V����9ѡ�Sz����Y}9^:5�<E��_��,
R�g�[�뭔U���沟ϊ���	eUU��/���p��V��T�*�v�ݽ�_"2Op�t�J����x0����]��VY�|\�����iY^��w�L#��fa�۞��[2﵍��yH�*;��m`Ш�b3 ,H�>�F^Ld�S{�����j���&��ڊ�2r�^YfZ�͑aNC    �W�:�(RjAv�|���_�3�LV<�ض��j9��\���l���'q�T�,�wIMg�,$����Mu�d��qg~��%&c��iy?��;�x!ß?㈛z�M|��E���@���wK@x�%̊ZyC�Wl�Ps9��V�]H�U~(�z��r���&;EۆF�q����~f�4�2�B"tS�Qc��*2�fM��I�W��2r���������r9�1pz�Y�C��r�͆sD�sa	Pˎ�����#+òI'�������"��I�3-�.Hf�п�ڞ�@�i���-�q� se���@�z'Z���rl�������uqe�3���:��4���\�<o�[@8L��/�$5��y0���6�t��t�l��2����	bF~��U�'��/2�s��6Pz|��}��ٳ�opW�.)�	A��4@2����ޘ�Wԁ�dv�"v�`j���Jص�nH�.�����2+󨞀�I�2�}��StЁ>_{1��,'���I�0P�)��o$tO�^�q�Fu���s�B�NGL�/]�>�\�`�ņ㙽���6����"#�z��AB�mYN�1rzX}�i���yZa�S\�E��,?S�?Ԛ�r�e~o#N�AV�1 T�C�+��*��	���oM���2�6!�<�ߎ�nd��i�O,)�Lw�6�cr#Xw�S�����j��e�U�Zx��?_O�6G�� r~aq���Q�f�ڔEU��'�$.�����h�N�#���86?�S�vxX���ݨt5^I�g�޳������vk1���D�N�RS�e ��'CU�<�hi��������v�>P�A$=�Uƿ��'#�o���S��!
�Apޯ�J'r��я�GQ�AD�@��3Y0:qj��������Z!�ӵT_;#�,�hJ^N��K��I`=��)(�D^@��1�
G�ə�*�'�oPV]5�L�8/�&���Q=�y��J>c9�q�N[���8����bP��X�u\淏��]�K�g��4��[��ņ��i�ȄkЎ���"#��6�ESS=玉�f=����u�!q��Ns�
�i�~Bds��]d=�R�yhϘ;�|�: 
2[z�v\u����/J2BS��b�m>��g��]�q����-�]����b��u��º�%3����2E�IZi�QcK�֙"�r����?�� �e���Y�>�P4)��V)���ū���RcW�U��?��X#�:��Q�]XN�K�2�T�
�ZH9�*���!@ 4y�HtB���|{#���%��R�n�y�v�1]L�|�<\�a2%�T�&ژa���c��/r9{��Kf1S�{��3�d��T.f��VI��OJ�0�����L�Q���>���I���j���g�*�����F�=a�Z:��z��LÜ3�Z ���(et�8�bH@!�[<~Ċ���G}�w�X~9��N�U�p��3W܋HI��1�(�!t�\,�WiGJ�a�Oc�.l6&HU��	%]����$ʊ4��#�TzA���x�����Ё���+L?=1l�b�O�̫:,�ۛ�45I����,xlw�<9�̉���L*�lA��}��V��r��IdWM�t�s�ܴ��+��Q�;V���#B�6�5�ׁl���wĂ���W]Q�^��LGq*�t�{�W��^�(ۖn���1�2�n��렂��y1�E�r�Zp=᪳�P7��X�v��%n.rW��S�jݴ;X�R�FLh� ��/�|�wrN]�-�l��$��L��@ŷ�~��8�3��0�#rh�n~0?�Z{L"i3�ʑ�ӊ������o��ߐ�m__��,�^yC������<#H�<��r[�����Ф�ۻ���2�e��m�!I���C8op��'r=mN���V��\��D2cV,'G6�~�������ea>��+��ֱ����^��SW6Gn�,���SgUA��(���rB��NuZ%���{y�ʱ2�9:�?jP:H*�0e�z�<wN��Z��6��Ӽ��x��rĚ,��Q�v��G�wW�3�sm�Xz]��o=��2��j�?G�.㴟3�Jyk�2>���yP�uP�dƧ�}ӽ���Y���,�-������&Ono�l$)T&��*��yP�(cu:�m����AG窣��bjh��-���@.h�5�,�A�����%M��e�Ce||ݳT"��}����/�x���>���`��i��%��vg���2�no�"�#��;R��#;���f��������;^�8a�*�3�5�Γ�[�a�s_4��/�7����U�Fqe��e�S�C-s5��P)�E��A�L.���sm��Z72���(g���hPDt{o�T��fx��f���>�'T�YYD�/p��Q�98�2σX0)v�G'?�Fv�9l���`��A�a�N�z*�����/жR��[O-2z�.�OQN47�fo H�t~
�M[f�YG������a��>V�B�5�����W�i$�T Z�apk6滋�$*�۟�<����0�!��N���Mj8 f�\Ay�%�y�6�2ɠ�s��*@kW�fψV�o�N!>y{D�0E4
>Y���Y��_s�w\8pP��Y\m������]y�n/�e'f+�rjy;�a�Ui�L�c��Vq�%5}~�hw�vԦ�L���
���t�̋lD��4�������q��")�	QM�8v�_���a�JO�c�U��r­W�@��8���ǥ���C/^85�Rc]MO^9�;����;DY/��u����w�I�����Ҟ���3�E��1b;��l*`B����k�"Y�˼׎��kD~'�X�E��L�u���g��'����~�b:��R$ȗ�-,N��I�+Sp����F�ٌX������vaF��#c�y4���_���U�qB3H�3�K!Ӕ�o��V%(�����ɶ�|��U�����d�*�HU�N�j�YQxݢ*I��u��-4�l�.�,�DZ�A���}�لk_De���*�b���k!T۱���0�ݳb��#��R[�������C�ĭ
��	J�e���B��K�I[c���NpUǎHr3Rꁑ[L+q>�+�xJ�
/�Y��g�Z��@�=Mh��C\k�ʛ�H�i����E&ccnQU�?�`ݯ�	x���"�&TU�g�`3/�௶��_1��;��L]��쎩��[�@���O��l®_߾`7�_R�Yb��3�`���@��Q��<ПEU>�}7��&W�^6�HByؘ�-l�^�M&�U���'d�ᱳ����u�`]�Cx�|TR�(8ݤ��LD��|����a~�m��AI���x�nG�_�#�g���iRy�� ����p~1�U�FU�d����)6a��컵�
M�A�n�����V�	�z|Uw�h�g|R� ��P�N�G,q4:���k)G�_���PW�����q<�[DQ���0
>�a�E�2
������v'�e��x/C�ͶLh P�M�U��&;M���)��g� ����?ĦGM�mp��q�Zo��xn���2p6XH�Ev{�\�y\��%�+�Tw�
Vr�G+��S����d�EO5�с���!B�hx5�{S�Og�ɜ� ?���5YՖr�9ѡ�p|���u��)b���l^-��LS�&C��5��P'�1��a��ζ�n���r��,tny��9��(�d�Ó�Jՙ�4vmˌs,�S&�'��s����*˦EYY8�<̃�`���2�Ps
O"Y��!:�]�+[��<��Y��Ba���g�BM�0��i��htU7��y�R��s,��"��5�`a���#�i���r���M���'l��ҕΫ���\�&�ֳ��e��;�]��5���M�M�9T�*`�!/ �R���
i�~�?����*)c����J��&`hߟ�{�|xl��;�� �dV�D4{��~M��<^������b�5�s�	co��)�ɾ��\�n%�{D� �j�`;�S�Ila%�m��ވ��K{�0����c ���������y�s!ݫPC}��r    
�Q���A}����*���MV�?�aP��	*��i���	hzݽ@@J�kD�J��(vn�/uey�x�6����IPi��K>Q�����5O�[Z�h?�F���rk���qml���Y�� ��%
��v��
0u�Jl��K	E<�wBpx$/5�J�l�r+�ܡk�c���C����I�M�(��9'��� ��t�%�a�7����oˋZ��n�Q�)^�Zy�������q���1��X�;�i�O���I8:�I��A�������I� vTG�Y2�_�Y8�B�ͪ.n&D��HdZ8b����V�jל^�X:lg읆�h\h�XT�������6	m�H�->m)'E!��O,�Jg����l�M?i��B`�
�r�m(�ݼ��L-�W葵��qE�B�3��t��������|�A�!�㯣����B�P� R �f���$��,����0�_ʝ�gu�L9u���UI���ᩕ0?�^4�6V/�~]}ߴ�J�S�-c�-i������b��|P�Ü�r~8�JU�z�"��1���gY�؜�C�XN�MN�%�1��1 ��k�:�'<Y���eȃG��	e����1�y����[�6����e�5��=�u<e�Z�e�d}���� tB����/�<�1D����h )���X�7���u�O8o����� ��l��|`�-,r*f��ڔ�k��?2���՚���OY���IT�$<�}�@��������/�~��a��Ƅ�U{}�O�8WP�v�0�O�?��R�c�`��AaGV�V�I���l�u%�o�/D9}��!�_8љ^�x�g�69��Z.lu��1]X�t��ȜC�����Vv���qU�Z����n��!�z�rm�O�A������f��+W�?���w�dC�$y��q������ֆ�x(�2t�ɲ��7&�n�b7�,�-Z~q[���v��9(u�:��	G�LW��q���&�Q����X2ágE��f0���Us98}�Fp�:�\�[h�X���<����PvI�LPW��<K�#�o����(��N��$a`HD�W���e�j�W=����K㻿�Y�f}1!�I��^˔�4PȺ_�i'�R���f�*��*��8�``�f�?$E�x<�S��a~X������]V��Ԟ���9�������H$x�g�M�U5k�}?̼hSu�~�R7/&�K���~�������U��y���#[����T\������U�P���/K�'U���-hJ~�I,�?�;Z2A����G����l/hѕ쓪��rW����;z�a�f�	z� �+	��Q�s ��&���0p�^cmC �Q骛��/�9מ���h��ZEL�r��=�P��G�˯�u�Fn��2���Z �����'�S��ӑ˛�X�7[5�N�	�U��k��*�g���3;�`��3 LF��"o״��u_UE#Y�cI.�D�<N'�Y6
��X���4�nG��\m�c;���֋?	�"����w1,�|�}]���[�H��N�)O��Q5��O0�L�V?_�Z��Ϥ*;��];qqr���W��/۾���H�������[:�n���U]~����b�O�챭_���I�,��^_6�V|$�'�X*��D�a�6�큍ʸp�:I���>C��4Gp~N;b��7)���p���U�i��j��r>�z��)'��,�*��;L��8���FkwU�`��ގS����R�s;Q$�%y�,��MP�O��5�M��1��Wؼbc/�K�~6��ȏPT ��z���/����0����본�'\�4K��S���{��v)��sDxr;��YY��U��q<-�p����u���#���Z͗F��Û-��۬*gQ���,�'�,�b�"p�.�y��]�l�����}�o�4�X�i��\PO��T�e(�W���}���[F؍�(�W�##s/�l&ċ=ge��#��WEҤ�ǯHG[��B����:s]'U��?\��ߒ')�+]��F��߯����潱�Wgnޟ�a�gМ�]����N���)����ֿ4ΥV����Z,�ƥ�:^O�:0�rW4��Ŕ_Pl�O�S2�x7��)����@�WeEr�}X��{=�o��݉��ܿ�@��Q���(LS���buΌ�׶V{AqU�ݘ���X���}�No��Q�Ƒ?^I�K���"n6���,d�(���
ˤ�l}S��؃��@/���i��QF�ag���3���w�i|�M�o%�H�T�����Hh� z`����#��O ��A�۹�M��neZu��6����&q���\��7Y�9l7Vo.-ԿM�I���0�)֪wRhR�W��x&VT&�xBS�a�oi-��+�i��Ͷ���j�2Hƭ�XӆD��"���/gk픞��"g<�i݄ۗ�������"��T�V:��0���an>/�ó��f�I���s������Sк�A�C\L�f��j>�)�;+��?�e�UʹK+�8��B�Elvd���v�b�z�a<-N��K�n�![N[d.JN�i�^FE�x`Zo(�Ը�+��94`��ŦxD[��"���qsY��a�f��l"�qY��(z�x�x��*�*�������8�-�_�U�]�v��~
w����u�G�$�qˢ �"e��Δ�?0J?Ґ�L9A�Ӏ���qƄ<�d�������=a,���0/�C�Թ(��o΢�$�|Ⱦ0�w� ��+��{b�y��fܢ�`s���tJܪй!�Y<����s��'�Jj��qs:�����9s�$횇�:-n���8=�=KY�LgZ{eKs�K��Z9�A'�{�dn����pn���]+��k�Z�z�q�i}(~�sunb�0��Ts}9�_X5m�_�~ܞ�W�\|*��&��8�p�"��@�R�pb��3�A����>S+��e�H��v���$�0�ϝ�PȎ�n��,{'4=���2@��D�]�L�\��m�puz�F�X\�ʅ?A�GP����&4�ͼ��d�����(E]�	����[Fil��U�ikꌺ�[oͧ�e��R�I�~��Y�\��i�Gq�ԷϒM�J<�'�݈�i�G��yD���.f��bH��)�d���Q1�g����
ъ�^���-�ǆ�N��1�*A��z��?:�Zx�Ϳ#�A���bM�&�cX�;[���@�M�f��nw���Me����sV�bGs�?��e����xm嵀�ݖ� {1m{�����R��!-K��4��lBHMY��Y|�c�'*��z���k��Bgb�F��f��~��ho1��ums�A��ݥ݄7�09ܝ�<�,�L)8��4�i��Y�σ>��3q�&Y�Hj�W�����&^%�%�(��Q�U�\~�gRx�]���� �
c�r�Τq������ X���BLa�c�a�?����ͣ:�݁Q.*?K��@�<�����R�H��k��X�G�Kh
s��3#ݽ�x�Ӯ��*˝+L�'����k.G�hha�ʉd�0��}��!��)Q���0r����Q���3�_�ps(�[ry�Rj�y���T'K]�=��9��)���-0j�B�%6#r;c��l6Hue?�D��O��,�8r׼�M���(vv��:'�x@��n͏f�d���|����$Γ��e�<�E�hQ��ő��R`�&�L�jת��`�&3p�5&s��8Z���eK���W��+�)L�n��Dt��5�\Er[-��(�b����:[��n����tB�c����\(�<N�|B�MҪ�:dy���N:�{�E�!�m�>;�ޑjc�\�1�RBg�r��'y��-y�y�]���yt���I��X}b���hPF�i��+�\{�8o�xB"(�K�i	?�W!IcK�Zy�׺��
�b���0-�J���f�K��aԷ�,��ؼE7!���Q�.�G����vk�eV���ͳ�Q�_���i���12�Q.ʓ��=^�G��m^Wm;O��uy;@ͼ��'�X��}d�+e��R.Kf�N]!	t ���Y��tL��� �Ĕ�3��b��|1��n=!�Uyq�´    #d��ɿ380gt8`�	�+�j�E�"�z���vw߽�`nNa�ܾbJCȺ���F�y��L	SŜ2Nσ����+������Z儸��g���P�3�T颍���W�{�!0����u5@�W�/�bq�mX�M�^��h�ݔ��aR��kw:��/恳J����$H�"2ҋMK����'���8W��m��y���V��?Đj�m7�|�Y3H�b[�$��Y�xI��	�)�R�(���:��j7���nC��(�^�>O�d�~!5	-���hܜ�[���Y�<����-.p�Oy���$.�dBx�bd&U����R��}�$*�a������Pzƙ-)en��A�aܪ���s��	)?3��K��J[�N��V��}�S��p���@������R��J��6�I�Մx��Qr[�26� �ʔ�F����%���_���S��W L�$����b��l�.��m!+��N�������v>8/�f2A2���QU%/���zlﱫ�MC1�9,�r0�5)�)�̴��*S�j�J�< ��r��'�������.s<i^�滊%��5�;]J+��ѩ�v��7���
�I�Y�鮃 �\&�� �PǙ���f;1� �Q<�v]˩�~?`<�?.hp�A=���<�-��c�b{�ԤC�nFҩV���d�;�r��%��)�N�?w�W%a~�!�К���z��[��ʗ��H'X��Zp���&��%v+2������嚺L��򘫧L�u���oe��� [|�˂���֒�Hp���#���We�>?�� �W�)/�{��p�U8���tT՘�J��}S�;b
��w�Y�S�L��~D�v�2�p�_����=Bq���4R����f��3��D9��ë�b^u����{���sW���O�SȂ��nsC~�,G��7�0 �;��#����G�题�gs��D�(ʭF�{�¨�A��(��~�c��-��F�)b6i���j�t� �lC���h���x�r�o���uY��AYXx0^Yo���{��f��À#C��#�4�S��
@�H
��͈a��ݾ�7�-\��hv�8�ڏ)�M{{��2+}�KS4�GYQ���̀P}p�!��'$k6-u��BBx�J~��g�NO��Sih�ß�0g'��"�a�.�v7���6�q)U$d@f���Xh�=��Ԫ'�i�~9P��/Z�~�n�)�h�A�M5�_�$�d�����i��󥓷��w�	�lø�['��qI��*xw�<��R�",�H���ײ��C��E��7��t�>̳��--�_�sҼ�;|sX?�`�YB}buȘUw��Qg��o���੊��1Q�4���X�aO
�kZԉ��\LJȯ�+*��?$t�#y��b��l��~�x�����ϫzӺ�2���˟#�f�TN �!�s�s������[}��v�z0��r�;sUiڇTQ2�.y��*	���BhEgY ��~D_0?�-�P0���Y[�_�JU�6��d=X4^�z����4�<�&��3�ۍ��_^:ΰ�m�4J�ф�l�B����/�הKoo�r2F����͖����!K��}}���Gz@���G����Ǻ���(N~�V3
�>R�;;�Hq�&������<�1oE�C��̷��d�0���W���?�T������	F	<8�^
���o��(�4>����*5-�x�5+��󋫌p���*�ˇP�d�,� J���NX���8vu��]�FE����E=a��UQ歗�<� ���5����Z��n$�}V�IC��ܙX��u���r7�B��b�Z�Ԫ�y`�iU7E3!�U�E?�"`浭���W���7���u*��]�ә��d�aO�m�@���y4MiyC`�\�q�lz=0�d�����g
e�>�����(m_�ꬎ_���:;�>�n{���$U�4�N��@f�?6��`��n`���ο�P�A���%���YƝ��'�ݶ�����Jt8��0e4@f+Iw5$����B)Ls�c�A�����[��"��r�����n����/�ģT�2���|$ə�b\q�W��h;��&Ǿ��O�igp'��(�1�^��|��4���<:���G�����)b�iI0�s[ai!�$�C��{'U7*䘥Gӊ'��H�fjs��A�]�A5
L%-#l\�|���G�[7q������\.��!z���'�G� �ZX�NT(��(r����7�?�M��'�<��č��*��+@�����Q��Ѵu�f��1-�lu��g��Ο<}p-(���#�^M� ����Y�;V�9�v��Ʒ�#�T��h�O[|����:������_���{��)Ϡƹr��}��Y��"��8���`��<��6�s}���Yh��U�5�͗j�nд��kɇa��+�p�3ئQz��$�����?o�N��x�LsEd( ;�TX�O�B��O5��W.�H����1�!����VwoK��]�$�w�y�N�ˤ����Ta�u⚌�?��O��>�ܞ��p���=��Z,hsi�Yܶ����<��(uA�����F����f[��Bs2��s�|J�c�G�J/�u��m�ւ����_ړ,#�ֲ�vv<�	�b�!���Q{�������O�SM�l�Iw���|�s�"���@6���<�j��U"o�y���_?4b�H<���g�GNPG�O6����P��VƔ�vW�r�ח���V	���ݳ]��8�y���5XN�t����us��</���[a�:�Jmq�{�2Y�ڈ�U�X���t!�R
b<�AQz�g��1���g�=DV4&���*N�7}��]���]y�\�ͳa�z��m7?Yoo�3�,�N7��7kP/��"���'�,�J)]���]��z9iIY>Њ�co�H0g�kQi��m+B�iA�}B�#�7�( ��v�Ϥc�65m}�.4��*�Ƽ�"���)`gj��*YHZ��q��V4��4��Z����P�r<v��� �Z&�KVt V�`rG�%��g'�-�B���K䦴��e=���٘��+�L#-�W<���0 �����Ef��X'�VV��'��,%w����V�"��"�vz��y֖E�L8�U��`禺��;���NZ�5�B3��N��(���n/41��1���*f۱e][����R�E�+2;�w�m˵DX=q��Ӎ���y�9ʙ����/2��Bq��j���:��,LG�S�N�OЫ�%�Iq=W
'�����F�Z7�����1��b#�نpy���z�(�*��ybBب�)�篰����.%�S�̂u�k�&�e�zhF��<i�d��3o��o,�0x��Y-��i���6��$�P��1
:l��2�_l�1�@��I�OY�Ů>��Q�XU:ӊ<�9B��ق+�^aӢP��ZN�F�� nMes���~;<���ˁU�?���ޛc�Lp�+��#��(�S�t9�Zddu�I�Y��Y��k�4,d�[�-v�{h�<c�-_���姺X�3)$/�2�P�WI���E�x�7S�0��t�W�\��'"�Y��N#�VB!��^��j>��w����:�nq�q;�)@�
���bĤ��wA�Z���؋�[Ĥ)�&4�~8BK��[��0�@޴���2��̵�Q|@#��=�6�m�6d � w�����r<pWf~)�U�K)�����9�T5����(?��w���.�&��IQ��oT����V��D'!n���U<�|#�U�D�C����Z��|N��2��E�LQ&+��mk����ɵ�t*�����yڪ��5�Bd�R�ʆ���E�-E��	������pl�{Y(Z�j�C������U�⚽D܅P���7��d�̮��xQ��P�咍�<����i�P WOZ��v���z�\�=ʫ���Ad���~��[
Bx�llͷ@9l~ϜX�SӔಓ$���NN��">,餦=*������!��������'R/�� 7��,���e2l2�y�'�(Ӂ'�dC��B솁J��Zc	�9ov�<: ����5Ww��z    ur�������-���|�h�5U8��(K/�RDU`�\��+{�b�d��9�z����,��ʑ>2�O$,]�0��r�׹d�L�8��^Vy��4��\n�S�UpUn�)�-��e(\hKF�1��2z��TE	����W�I��G�ݐ�UO$�k��E����q��A�h	���!k���"���Y�	����yI��x9��4
�y�'L}nH�(2啋p|FQK6������kBe���M"G1�ܷ5���6��q�\���,H΢6�]<!hU�c�8aD��`G$C])z�MP{p)oN�+�,�kh��*���1\�ɜ��/�u6��R�y��1���Qj�tRq�@<��� ȃ��
r
��&vN?���{��i�jB������(΂ߥ��u���X>{3hUkP�C�X��W}ϓ<��I&<mi���GPc~#������u�x2} ��*+۞�MTL�[k����Q7�U�>\E��S�_��I%�Lܶ.�Q����a D�P�1�q���n��"&�O����eXD�������Ųi�a	dG.�M��Sƀ��]O�j9eWK?���<g�h�e�w��P��B��b�=�l��e�G�U^��۸�U�/ m�i�yG���#�����~����+��4��rZ��L�me�g���q�X;E�t@(�m-x�L�'$�݂?�m���(=/-=5��I�����e��Մ^�J3ߩ%Q��M���ŉ�~�$�����E,�xjdfG��2�r���e�.o���Ϫ�Mc�8�E�v�B��$�$��<Q��Ƃ��{H�'���,���l`�A�̅'	�\� t	�~�~��ѨS��K)��vX���jH��q�����=�	j�g��Y$����$���q�ɰɴ��
;Q������Z��Wo1��C����%E�|��$�)��mN=d�D�3����@�l���O�	G�����y��<�dk��Fg��K3'��J���ٷ�N�r�k����~�Tx�:�0������]6��A��й�I�q}@���+�I�
��	6Ӷ#��ן���$۔��8��o�ln��Tn�cW��-%e����;Sk_�"�f~Hw`��d�c"��1��0b�rj2Y�2���H&�#E��N6� t]/c�'�v'<�'j]���p���9c�b�`�dZ�mN�P�*�\���&��,L-�+�c��E���, ��a�~ᰃ���)>Ya�@����hO+�G�V�I�i���i�S����EO��h`���ĉ�tc
�Q��~0��3gۓUYS�<�4���$u�"���V�(H %N�(>8%��u�����	z1A�ѱ�D0�m93�� �U����*29��*	��/`8�	O��ۂO��6����ϙ�ӱ�Q �3��tdV�dB�ig5z�'HZI���:�HV�G�ޠ�m���Ym5N���������lw�U���m:X����Ф�kS��8���jO��~���*A~�[M�c'������x���}X}�n%�l��W�l�F>_�O�x��c�Y:ު\w��5K�z���/n��^�۷q����ۭ��==Y��Wi���p9��2:�A�L�(��ߒt��V@�9����丈3���Wl�Y�3����4���H��^�8^�:i���eFK�j]���ݝy��*KMwG�������V�}NXw&#Kd�����(U[6̈́�V�")��W�=�'\4���
6aξ��b���$C�X���k�ּ37G,-�"r+�@^���g�i)���T	���V�j�� �~���s���_���^������%�)����D�3h�����x{E��|���|�T�\aӾu[.�X1���&�G����ҫ�c���s�Zvth��OY��6{.N��J���4�N����(��4	�,�����9�ru��=>�o/m'�
�:
��	.�|���^I�x�ۡC���J�L�w��d�(�8��d[��7[�%��o�;E[���*:�t�8K9��s�vb��c� �b�d�7���uy�X+*�=��9�[��}#l���mj�����X�ۍx��mEu��b9� �f	���7�L�LM��/\�V��W��2�]w&n
$xmAH��� ���M��i��u&Q��,
,��L����տ�t"rBo�0+:� ��-{mǬ�;,��,v��>��9ERw�_�8�Sq3 ḳX�P.k]�<�u���l����K=@��IF/ZlB8[���<��D����M�OV��s��%����7�%B�M�h����I��fg��Y|�����oW\0AKL���lY(�$Bs�D���CP.P�Ӟ%�C�=u.�7O�*�)��W��Wh�3��-0g{���&<�&y�,�u@��r��V_���J�lq�';zpc'�«�b,��F�V�Ά�r���/�2|�n�,�pٳ��BYX3-�Q(P�����L� ��5/�a;�z�7=.-1j��{����$m.�(���Vv������QyZ'@��i�y�E:���� ?�e)y�������uT����Е��r�+��),,?饭�̚�we}��;F�ܛp�40Q���c���l{�u�E��@���J�5ͪ�+�z����WI���"�K�@=J�;��Jl|���_6�w�P�r���l���n��#��a�|7�<D����&���%F�۪�� -���0j��Z���� ӆ0�^R J�m!p�:��C7`��.��r����T$;,�;��T?�E淏�(�~.�!!ut�:��Fp�'����J夵���mcȑ�L�k�G�xF��ǳ���e�t��e��9��"O���n��:Q�Se膪��<՘��?�x��2s�ּ�y�7�Ue�p���E*�R���.U��!�D�Y���6s}�џN��5�yr�0�u��ݏ�.��Uwy�Gk@��k��r�;��[uXI?fxj6{Qm$:K
+�m�=T�+E�i8A��9PZ�8OG)��rQ$*��&Y�� �{ٱ!$�Qش֌�������LC?�Q0����O���r{4!bXC�Gq�p�qGͳ3>�y^�Ž�jub�g|���u�/��P]�9+�C����2��8�|�R4�rD\FPu]KC�B�ʹ\\.x7����k��^�m>�0�����@D�?=Yi
��4�Х@3%<��Y��JܿN�]O��2�|aX��$�7ݕ/��P��5�qv���7�k�����.s(�G!%Qb�W�<ׂ�#Ϛ^p98�8g�W�ʻ�������oZ$if���e�)�f���L�����QehI+-�^�Z�9�K�|��d<�S�'z���������2r7�|��{�
-����F��H�sf~ y�1z:���/�|��o�P�Vc��ܳ��K>}r�SOBv�<<[Qu��MJ���x�qY��`���V��[��nͷ���ީ��5�����}�N�6�r�#���6QN�$e4��ɫ��������zI�&Ǽ;^�YV�ن�@��K<��ox՘�5�}�� T�``E��.L�N���$��`��`�Iޚ^�uz1{#���㮶Qj���{�V�IL�Nj�xp{o��#�Ng^("�Lu�����H��g���@G= ݱk�N�,��Ip �Ԝƒ5�|2�<JM�	&�w�_�P�sߝ��O
#�*�����-L�	7�f����a��,I٨n�(u�iwO��]�[�Ƴ��8kJ��N��^S6�����j U��īH�X�,�̛��L^�����|>��6��<Dz+Lg�@�b��A�,�&��Ұ*�2����.�,D�qs~J��<��j��`Q��<S�Nh�L�/B�bd�����tA�"��	��c?)��7�v(U$VT��r��� 
vV�!��b�w���oOKi�E^�H�@>Q�^���d�7ƞK.��xy�h'�`���4`+�s�V[N��k�6r6����	��4�+�6Yd�'J��B�_�/�^MD˝�����E�[**5���6�-a�9����F��3�>    � z,�ה�,��FX?t�#`xN�+���Yv��m��iY�~�Q�����q�+�^T�tE��L���d�Gu�X��D���h��oZѳY����DɅ�����ٸ�mg���g����(��J���j��{�h�D	B��~gm^C�n��ZB�4㯘FÛVd5���5��饨䙢�m�6]w��G�έ�G�.d��kul��8�C�y9*�x{�y�%J1r��;ܴy�L��gqTE�l���՘�Sy[]���f ͫ�y���I��+�����6B-oa9��{\b��igO�u��%��ά���3a���]�ǋ.����|�z2��Rb:ɰ�s�� F�y>��u� 5a8�Ҭ�ݴ�@���J���a��_]���+2�)Cw���q�x0��Zj5Gi��+vv/���m:��Z�h�Bx�KQ�y�e�׷���$	��D�-�"kǧ�H3�U��՛�u��!!7���Q���Z��r8��Y�b/҆���ߢ�/�����PTY�����	����z�L;� O:ĺSL����;�qPDs4i�l�I���g�p�º�:7��G�)AV�=j5Հ���3\������P[F�g�����[�〱}�s�$全����3Ig��8k)�_�d�9+��(ǳ�mu�ۏp��0-�@�9^���0զ����{[y��c_�-&n:ߖ�5_k�>#���O>�4x4�O���d]?y
?=���@��$���1է�V�XI9[�m�<���a����,�m�S�D�\3�P\Z�D��P`�"��t��W�U9˞�m������R��/��I}�e�Ē�5D��>F0��������3��H9۷���T�'�+����aXm_G�J����,���rgS�nxD\8������!@T��Z��Z�U7Ky�EuM�]���,��4��^�Vu&�v�}���/�?�"=px�M�Q�9�j��Y���|�_�K�Eu{ߒ��h�SV�[�~�;Y-0�f�C��K��W��:c�m�l�n�n���p�'�˪.�=���KܓX�0����pVw��_5UvāI�܂Y�V�p��:��f�����Smn�/EYE�Q�2�jIZX͵p�F/<h��vx�#��}1��lf�]��I>!be^�G���/0$��1� -RN/��Ҧہ0a'0N��q]U����<-B��X���;���?�Y���..���+��� ϨS�T�1{����sWA��8�y�K��n��r`ռp���ES� 佨Zx��gJa�M-B<���10%����+�z1�~�����&e���w���4���H}����nC�!����o�����KGr��#pWM���G��O��V�*<
�e˘C��`n��F'lA��N�� 'a��X�Ws�9򆤓}%e
1r^�Ŋ��䠻uN���YY��JMS���3C�1����S˧����|���a�1�ce��
z B 
=� �\9Y�z60�I��~c �,�tQK3��#F)���^[Q���V�3z-��
�.�՟�xc������(Ny �3���T���%#S�-O��9c��k�f����(�&�&ӝG��P���b���'�����Żn9���m���4���9p�|�x�%[X�1��b,�� �}��)yU�^2�B����^�7�7@dW_�4��Cjs�#M�E3|�bq�!�d]~{�XDQ�M��*x����R�qW�,Ã ;
r+@�9󾘮H!._�	���Q�PV�q]PB&��Y}V����/�o9�pi��	�����a��B9)��<0��_����uP��L�}��:�V�A�g�5��)kn�yi����a�sD}R2��Gw�٢q#�S�ՂUiK#+c~ �1ff���IoO-E�E>h�	dv.?z@�M�0ә��*��Շ՟D�)�NV�t�#��I�ci���������M�*mwj���jqQ���S8CxK�R
��b����j9#�c�o������鄫�$t�0�sp-�T����j�e�
�nЇ��NTt<J�_'W��6��HY�Vy��.�y��n�_Ld��B[��P���)�G�9ܤ'J�z;}S�����?u�_�M1���e^$��&�����M� ��<ր���"ھ́VJ �!�@��`}A�a���h+��� ҟ9�v�6�1��,+��K���J�(�,��M��Щ|�gy2w�*W�o-1��Р��z
`���G��@r��B�WQ8�lVQ�Ʒe�oy+y��r�mʜˎ�q%���u%�8�����/Ř@yOW6]g*2�cd�g�l��0��諲SY��`��g��X�>�ㆽ�\�"�L��kN~�	�|L�i�̅�7w�]���&P�c"�
+�������<���3��o��ݵS���+�s��˭0f��/�0�����Bi����a@�L�k��u�ʰ�G-c\S��T���[�<y���w�)���i�G�\�K´��[ʴ��!����/�<U�r�Ň������7�QY8�A�ƪ�=��Ҕ��4O:@�IE��u���SD��XӠ��ʠ�z}��i��U�JY�`G�&j�ͨ��r��V��U��*!0�:t�u�4щ���f����s%m��>����}d�4:�j��J+�{[�ˈ@�������(Y�öܪu.��"̪zB�.��ta6lQ|Ѻ۪�Qj�'tW�$^O��<D��dFk9�ֹ��o��LͿt�,��մ� ��8_X5�r�t��ɘ�)\-���(}�����?��4���-�2�'���N�e�>g�(���m��MG��`���9��m/r7H��`�V���
�����`�[�r�&�|����IM��y���v'��p�%��5��cw6y�#4�(W�F�Ia�HM3ۏ�,5��\:��E��j����e��iX�q��5~�qG����Һj�y�Ħ/�d��> ��_�]��ea����}��9����C�&g�-�����2��,R�
=0E�Wэ^���j]�����70T��g���@�l�xw���ۜO�"U���Auo'~G��O�e'-�ٮ�B�/HR�Y#2A) #��*/h���HK��_Q�(k�|4�v�O\�����3+��7�Bu����ӡ���w��kNi�N�-ˢ��I̓���'"8Wn��Y���5�z�1ʖ[O�$�Y�}�dV�sE)�"�r��Vתl��J�D~����՞VOT����"����![
&����/����VDQخo/x�0�oeTR��r�9�F�z��I����:=�{�� )EjZ+(V��a��=uL�zc�"��3�����݌� ��M��H(��k��+Z%A+&���ڊַ�Ni"K���ûm�jeL]T󃻾�U~X=�D!ͪ��#R{�,�E�V�U1��;��@3��;�!���54oh-��N�1)�A�{�w�YX�>ҩ�4�+�����c;ug�!��<��shR 1���=k����Mn�Wq�8C�26m�09'��r��y��M�ȉW���b���мu����o`�Pk�èVw�e�Z�O��$,w����pLe�WN��Z�8'��~����,�@��0�8b������exTp��ju�)�)������F2o�{<��,r�U����2�Rՙ_*]������AF���?�OkPE�eC�skr�iG���J���D�I7���`��SY�F�_�I���.�9�E�K�����odCEu]��������2OƆ�O.vv#���}vM�ͦ��ʓz�8Ĕ�:\0���Z�= 1�ݫpQі�*S�S�I�V��ڱ84�`����E���8��_�#�Ly���Y�������*I|���#�b��h���/�F�Q"�0v�z��
���v������i�T;gz�>�e�y��ޝTyQD�vf�#����$�y�6t��=&�b��L5^��K�������$[��t)�<��*Il��N�S"���\�#T��ȣx���6w�)H�i��'�ԃhR��|$w�*��9�G�֣��"�`��Y    ��XB��oui�s�y�.a�#�Ά�,������Ҫ�_P��%O�"��ʽ&,b�s9���1��U��"�v�9�!8Y~V���+&��n�JƸ�{s�"���fI�\I�U.�uC��kEw��NK����\{*u��K-�vx�R��V�r1 �l�b���R-&bQ�e*zA��:�phK��>V�Te'ǈ�6(�mVO���Z��$�����qѭ'�8L3��I���ܺ�´�<���;kI`���� �d7��}�&��&%s.�d����]}�C��]�YkP��;����I_���&ա���`+��=[P�H-��G�a�6O�'���.�(�g%��\��#voa�\D&�|=�o���j�����DB[}ҍ������RV��%E/WFd<���乘�E�4ݔ�0��ѱ���������;4��V����3���*�vP�E�KB�h�����9����Rh�2,&�:��o����dn���i����e�����,X�����7 
� -P�Q��S�j��#f|��xE��U;!�t���$�s�N�=�0"x�<	��x�1d�>y ��xv��B���m��圗�]y<�p�eVNx�0��<��g�s5�<�+gc�|�m���eۊ��CG�:���b8�0������o6@G�L;�Ť����K��&"q�|�6)��𛰾���ֺ~f �ן.�uEX���U�I�S4�ģ[�2�a'�F[�����訟��>�~�1�\�H�4��W�s9��\D�"n괞�o@n��c�_��9�w���ܮ\ˈB������6��5�)�*��{��N�'��3�����I+�����s����Q�S�;��dY<h���~���e���I�9�o�46R�$��!5W/"�䛍K<��ԖU��0e�p�N�W�3�b�":��t's׋���ɀz�yQ �ȎV�h��X��m��n���fim#�̒[���ǉ�	r�;�ϊ�����@�jj�=���xKv�t[S1XE��+�C��d�Ç�X�>�ޡ�֥��"�r��C�T�����m�R�\_�D����S!���}����A[�8��Y�0�˃VTU�L0e�e6;o%<���'�,FfA���"S�y7!2��m��ҵ��������CW�{,�,h��/~[BeE���>�sH�.��]����>J=����3�|���~ץ1\T�P��o�4��^$lS3�rޟQ` �q��5��������)��b�!����0���-W�v'~j� �0��}�<���������)�*0���4B~�0yf/DCv�VF���yU�+:�c~��P�ޭ����֥k�©���"'��&mQ
�7t��3W�o�KډCY
I\��u�E��@]��Z�1^L�u��b���㦲Y�q��+,�u!�,K�cT�����;&px[]N?(oK��ZL�i6v������'3uV�*���*Z�k��+��V��p�
�T�a_la=۪�ظ_kB!c���4���DJ$AC�p�hv\�%lO���AD�+�Ņ�Ϋ� �&�s H�h���IK`�w����c�}�O��&U]�Br����� �@�{v���b'l:ߊz1l����K�3�c���SD7�
ZH�{�|�b��O\��xɼP$�=��5x6�iX�&+!g�=	<~�r%�L��M1ԗ��77y�Zꀗ(m�&`�&�[p���ߝۻh�O�v���fw�E�ș���s���|���+��jl�BA��y��+H��|w�G?��oA�}��ǡ�rO��1�eY���1w^�Y莫L�sG��E�8LXG��H(X]ĵ(�C�Q�N�8iS�d��[-f02_�(��6��
ܜ�<y%R�xcu�����J� ���q���RD��3Y���fks9�n'T�y��2�T������X׎Џ^))4�`[��	��X�Z�@q.;��l����Z.7���IU&#�W�X{�������N,R�̓*��!�~#�L8R6�v榪���ߣV� �vA�(
��n�'�#8�#e�e1���2Z��� `���m�r�ҳ���&�X���)Ҭ)�\������Njc�����C�W�w�_ |0	V-�I̤۔��-.;Y���&��r��e�|' m:�r�r�Cs���s)s��B1z�����*����<+� ެ�;n����X�����}�V��� I�A��3||m'�J�-?��HT�a����k�(R�R�M^Q {@~v1��#"���"���s/e2��؜������x>x_]�tJ�kw���,�qUT�f­W�U��ڵ��c�@�<NQ8�y]��F�]��.'`1��*�*�'��wSg����ͿH������G��:���I�\�͞i�$d�� C��I-0�e~or8���^���`o��Dl��SJ��L~��С.�{ hͫ:(�#E�VV���g���>�����f����dmmd�� �&-��/�؎��~�~���J<qw���F����%#2����ǽ����cx�c�^�츪����2W6�T�:ODV,�=��;Qε�<�H����+ ��<s��/O_ �Ϸ�Qͮ^�����+'d꺩�ඩ��t���0ԁ���k0�?�0䫏�xM�)���@e��\>g)L��P�e��Ѝ�����UƳ?�gfS'O���of1P/���|��Vl�<̆��T�#�����V`��$�����Z�MCx���Qj���O=�00�A~}�Y��%�낳/���'KMڋ���9�:aͻ��)����&����D�����o�V��'y��=�R�����J����ݭ~~�5��j`]A��Jʾ�%���O���_�[��k˲
C��J>���u��VEO�%%*B������$W���3��<��� ��u4�Mn�j(��7Ke�7Qm�n�����V���R����j�������,f�X�k�� H7�4-t�y"G"СVQ���H��
�Γ|����Y=��3�	�x���}��~�,����1�$��Ps{�X��%y4U�.�lD�ފH
5�qS	����o�_DJ��2�Y��c�VL�TtgS��"~�oLA�G�i�"$���ˊ�u<��b��l��1��^6�	.��6�z8��},z����	���uU����5���� 蝧31�u��i�۳�Y�\����↥�ɏT�TԷ=���R��*���T�`���e4��(6Bf�:�&M��iC�� ��N�xO9O)��b��Ũ/FS�m0[o������2�Ԅ��d	-�;�)��=�H�)�b��D��Ȓo�h5������5��'��]�ʓת�6���H8�r�k��;@�Bn�ՠ�y���'��f9I��,�&������(�,�-M�s��Z*�*�Α �m�`։�ԀQ�*����'40:CASpdy�#i+�tGa>���bt$E�E�����T"��g��G�2w[yx��I����?ʋ�XO�c�������A+)�	�ą��M	'ɷl^wԉ���	r�Gx*��v�:�9���
#ݧpP֏Y����l/v"�,�g��]u�e�϶�����)��j	'K���r�����'��E�J
M|H�y�_``���1*qzpzS,��tڛ���	A��"���R��6�b�~��1���I$"��W�"�ށ�§���ɛr�y�U�<�lV]�B�[����M�F�nL�2ѽY�Bj97�����4�c��m��L�Rpn�>�\�������G��3p�0�"��r��~�=(�����W���b�ơ\כY�נ�z��E�
�q�]�gє����@r����_�X^�i�B���庲���Ʈ����ֽ�v�B���P��wR��į������6t�tPA��a�:�簘��l�,�:[����4Kcm��VuiN1��ԙ_�:�/莇�f;�i�R\����1���m{����)Q�e:\�%��a���Y����K{���<>(��(�@-5�<kw����^�p�#v7|l�Y̶�n���/o��L�!�ɓ�phFq    8닚�{K��N��D(kp�h�(@�(�^(�fI,���_zV1&[6[�m�:�&�p,lPM���6����ty
�PFhӯQ�%&��r�Q�ә�9��?�lZ�&ϻ��ϕ|Ƅ"ƔɈ����L����{�J|�gƥX,��V��2릤�:��x�\k!
�Go >a��d�ĩ2(\�G�zV���A�{�1�r9�ҹ
dS���p��eT�7u�3�ozKѲCa"!/���V'Z'd(�S,�D�js@��0�	@������k���6I����At�ԙ��̡nVb�;��x �����z��0ۜ����_ހ�ڡՃ&��Ha�A���X��n���@ԅ1��/v��f�f����Fk���Y��.@��IN�P�P߬G��k�b��ٰXf�o6�WM^���m�g^@�N��z�0�٣(F(W�� ���O@�2��&���(�`�D7!�5Ь)��h�鞸�t�q�X_?G�f�˗\Mٌ@�6OԤ$�g!P���h�3ɳ�[�ww���e۪΀N�=GE��b��Y���v�|pe�偬\��-@�q!��GG2%�2l�7-������ٲ�	'��븊�e"І���-�����W��2��� p$�r��	�Y�[d ��Ϥ�0���$me�	��ƽ�M���V�D^�λg���9�-D����2���n�rb�����.�hH�!���M��hʼ	͕��:P�]�����`u��{�%7����ݛ�P2kW������<�|��;^��bYx6ok��N��͋"L�l����/�s%�����[�e�KIUZ��s���T���{�+ "o6�)����e���F'����8��̼���XJ���~��}�[�]]�u>��;�9&9��h���:<�,�w���Z]�'���e������-5gE9���{��Ip{P����ܣ�Ew]Հ���L�(uU���(��BD�i�~���^M�h]���������ɜ̦�i�5Q�	���Q�WU�����Z��/6��z��ĄiC.�W����6�.�52�]����4�'��Y���{J*zTD�2��܏lY���	*��PMXt���5�!<Y�Z5����]�HNU�����aUъJ$���@������P�	�HS���G*O~(TK?\﫷����L���#"��0��c�"�;�w@T��#�C�����d��-6j�MQ�M벸�f�*obt��'z�:��8�H�x�!�r4E�'#�_?Ƨ�����OSE��ڴLT>��#��k���׉�z.����M�(w���4("�J��Ŕ8f�0o�b=%�eV��U�'� �z���:�o�H��m9�!�p	P��m�v�U��nT���rmJ6l�Y
�\�����)��C����?&?�������N�Hό���]�Ѥ�A[��j6���N�zBn5y���&y%�л�dԞdƱ	�_���Ph�/S� �_��x��	�&w|�05>�Œ�l܃�ɋ	xg��"��$o�I�-%	��[%1*��cn[�V��%�+�Ro;��6�Γm�>T�5�d���
�`��P�}8���PA���%��Ԁ��a�@.��>��mӦ�'��#~bh��u^{1:�b��z�R(|�oVo"]-8a+p��ZΘx6E�v�
c@m��2fY�B
z���$P�����@
�^�7����ۮJ���S6/b��� ��2�l��kW�hp�z'������{Z����`��X�f�t�#����m1�S�Y���C��˄��o���`�9��B7����*�q��۝k#H� �0�˹%�vr[�\^[(��3X&��T6R�����:ڟ��������};���Y����r�:�:�s
س,D��w"�-�0�u-�ruR����"��(�3^<��ƈ�������s�y^�G#J��t�:��=�/�d!O4	���K�'&E���,H�wC���{��P%�-z/{ut�#�HF`������j���^5Sy`��w_X������Kk˘���T�6$�'� �Ҽ��k��H��Ճ(#�Ƈ�p<0Lp?����-�<�CB�����e�֙)'pS��Iw�fu����Q�\��N-G8fj������/�G|$����;��!=�En&��mm�:H�+V������B���0��J�F+ =��rw.���g#���a�8v&ͲX(B��x��A��~;���#�a���O�9T,8�ry������]:�WA�ѵ	�-�Y�Sv��ٕ<�ga�\�lf��(���_O~�I�ԛՇ�,a}v)�w�����3���h��PZ�hT�]���2D1O���PS�D��[���]�O�VR�r���Bc�����<�![�Yr�X�Q���xu��:�Ǡ�uFv��x������zB��4���<�F3�/8Z���m��i��U�dK��,w�o�Z��h�\��T�����l2-kW^�τ�ZS��W$?bP�N�H$U��Z"n���z����8}0j�9u�f����u�_��)�x�D(�G%�i¦�ZH;�&���E�P@��A*�� +|�O	_4�e�+�:�ټJ~m��8p�4^���7)E(ԇn�a*��60]�}��p��*��u�*4eXS����8T((�{u�x�w|�a+��B�`ܛޥ�Q^�����йR���R�½k!ʍK)GO�|
���|�����:�ޑ��ttݮt#�G���{w0g6/]H@� �82.�.���eM_�����<^�&D�O�#�u�gcvE$|ف�A�����
�����L��3 [�i��,X��&����51��y~��.�����կ�
�CG��)����\��4�W-����`U`Ob���y�z��퓟Ӌs�F>��T���4d\3d�Qd�U���h�{L�J �&�Չ �!��b��]z�	I�IˈV˱�#]���� �.��SYg��cҷ�HN�ڂ줹��]1����:b;���]?���C)o�A�O���Zo	��!��Ù������寂���ӟҝ�@�<�����i�#X׫s���%�b�"N�ٚ��z�)̎��CbP9��
E������R�g�>�N�#8�����̇�}ɋ���3�Q��~�H�'r"B�[_���[��^�ۣz�|޿m�����/��P����][bO�S�	�6����9�x\� �K���l:%y[EW�%�m��ndى(|�?B�3��Ŗ��	�v�(��d�"��'��o͡��2w��B<qX%�q;�y�� ()��jG���+�@Dq�aL�#����um5\�q1ͳ��BL���:h�<!�^�k*!�"�W�j��h��YFE~��M]������cW��U�G~6��q�bʵv/�(��&�vx��ͳ;��pp �CX=��۴��<ge���W�;(��G����E����r��H\��a��Ҝ�����`&��-f�5��
;L8lU^��HQ'?�Ue���ض��,���(����Q�<=�?X�`Ԫ��l��MڵvB����&���k'�뀏�D��=�r(�PcyϘ��us�b6�0\L�v1k��ēf@��P6�c��vP6e=��L(��:g�����l��MQe�	�Ӥi���.�����t�#�|�:�=���������<#g�=���5����-�*�-S�F� �#YP��wBza���-���fd_`6b�r��?%>��/�6MQL���i��[f����!(�3d/�ԑ��bX��fv��	Aʪ*���<��ژ���B\���
������o��8vO�u����@�� M����a�ǧ�\?V��,8��zӕ�_�yQ5e� �"y� вM�� ������/F| ��>����D��L^ēW&pB�{2$~�+K[����bƧ�~A�����n 7MU�B��\?�Bc,H���ުlFeuT�=�P-M�N�I���B2�g�:`3҈ ԝ��έ�������q��M��f��p��j���s��f=�/�K�Q�˖M�F��N���G0�R    �^#���(��I�΅���Զ�_�E�>L��M��űޝ�\�E��{Q����wI��{�Z�����l��::~p��y�`���J/�g��g��vyk/���2/Ҁ-m����}m�;�y�w�mw�gP�b����X�����*�����k��ͽz<`!04		����]N�c.�D?�]�:K�O��2��n�_����H�9yϴ�]�����Aw�Q���j|\��K��uG�}�`W�g�ޢ��n	N��Y�>,�v�]��G��j�����a�����:`�mK6�|���X�v���q��P���	,kԅb�;�`^���7�.n��w�8��!6@��K���j3`F�󣬥�B9��>�����~���;�Im��F[�֭�s�&f��A���	I��Ӕ�p�"?xB��F����r�Us��CZ�F�Em�:��T9���Hԥ���L+<޿!�a�:�X����Se�e�٦�FC���&(�۪H~���7��FI��λu�@?-d�H"J�h��`y�^`l�Q)3��b��l�א�י�<���1�Ve�M��ￄ(�ˇ~�lCé��l���|�ab�|,���fS���Lد�06�cU�}�A�ZZem#i�f����t�]2+���d�#��Ik�+»0�Đ���J��l.���噇	@U�K�RG�"<��͋d���A^�����C�fÄ�d�h6W5�/��7�[�nh�\n1g���^I�"bz�t�,/6W<�~������5�RhW�b���V�y^�^������6��+��&��p���Kۡ�R9�j�`4�k��^i����R]�z�j@pѓ�� ޥ-1��,�;ۄap�L7!�u�D�we�7��U_��-�E^B��t�mH>E��:d�Sa&p��9x�O
k��ؔ�gz�$@WU���ֹlʲ	��N��|�Wn��2�)�oE���ٽ&oO���ǔ��GKOz�?��>ӫ���4w�uyyTcCuTg�{:lw����F��AtH�+���}�"�EO�a�ّ�~�Gu�vY&��f��:��u�T~�D���¼�&���v{�F� ���B����������^>د2SE�|]����ZM
bE]�㮖�
���9u�_=:٤fSn.�"U�摫Q�>���]*>�sVE4(ݯ�w�~P��G�3�ᶡ*�W,FƘk�`��6H�U	���*��� "�<r~	#İ���.q���L�$���f�δS�\�Z�Pq׮#�W����q�;=���@T:��(Bg׵ l�A݊1\T6���I{�ԗ��Uݘ`{e놋���~�0�g^р�W�:���(�g��~ݟ��N��(2��Tcii����� ���a*����ť�+z��O\��a"q��R�P;zvXO�n�
΃��1��<?=dP��n��9)�J۝���)��}�i�{����y��{�Qqs��ݻ���N�#^���	������iN�}��^I��"���Ʉ�Ћ;��;����嬞f+ ��)�	�٤E���$o^�qA-�g�V��^���>�eU��e��o�'�
�l7*�U7��y�u��6��̈́�d�2����[	�v-/}�`����xO*�a�H��z�uh��:���V�Äe)j�"�$M��Tg�l�÷�����P�D���Zs�Ѷ��k�1w<+�^�Yj���y6�5Tc���%�(�崧������������[�=i� <"�u����,v��"m�������.RkÒ�ɓ��i�0�\�$�zP1��rw�t FR���FpN�4�����s;����'��'Z9HPІ�oÂ���7�x�T!��\����˷x��њ�O���,���p�D>�Q�S�&DG�[��g�L��;Z1ޒ������#HQ!�d�����W�5Y[����Y�eeB����]FzQ�k@s�3q��Z�ߋ)vT�S?�g�]���	u��6�-�cU��UM 4�^�M�E�C��vϝ�vz�:&f)�>�z"=l�G>����0�J�W�tw��������b�����Y�����4*���Eɶ.>li�����A����&ͨ��"�N���]�n��><;�&�ev~�+�V���3�T� ��V�󍷲�^O([�ʌ�M	��
���k��^�y�;��	w�e�9�
ѐs$U;d��K�i<����E�Z�N-6Xc���tb��#�������_u�Uz[���:���։�������iO�����^R�^��6�b���n�<m6����ڵ�E@�5�+��	����x�y`�FZm��jw"Lw�<0����]�!T0����$��	gԚ�f�ǈ0'jbG5��r�r/c�߀x�k[$>��(Ř�W�d������&�ӈ�nL�#j��O���9s��nO9�g8RS��i�~mr;4��MٔU<R6y�G�"�2 1��k�$�Z9J䀘)�)��%+���ZTq䔹���gJuେ�<=v��/���I�F��**ٕ�,#�B�_��|y��oT���V�3�A�6�Wrf*��)8>U,fK	�V�~�I*Rm�mެ��ɛ� ��C��<W(oVod�-J�w 2J)u�oE?xb�ՙwYn&��u6�7iBg�i� ��v5���=Tڢo��4�Q���J���Y�����iLӔu
�%�1���CvC沤�@�	��g�C�r�d��_���/붿�Ԙ�u�!`9�p|�U��I��4R���[�	b�����vC�2|�v�����k���Ȳ��p�la��L����n���T(���j����h���6Ɗ�䀆�B�G���`�ȫ��<���Q� ݟ�ՠ����-�ؗ��E��v����)@�ãf
ƭ�z�+V�fsڤ6�
������_�E�α��i<���ee���]`��Ŧs�ZMQ�ﻼ�3�+�b���W��I3b�ذ ��f��a4&[;�(�$z?z�g�Z����c\q�OЍ0y�F�p�$�c��6�%�^r$�:�D�����K���Ec�	|V�*":,ۨ�G	H�8]��%/{Q��۞�{Gӏ��'o�>V2���Yj؋�0�����
[���sW�:���M>�(܋y8z���}$ZWB��H����"��b�ųM�u�O �:A�l��U�?�!�-�h�'�yY��a� �>"lH����\^�ͪG5��%hK�E:Գ��&�	��)�HѱY�A�t;I�l�Y�+?�u�/�/��%�ԺL�u�M��\@s��_�M8��.�C�b��*��u�=V|'q
�3���pA��%�+�t���ה|��g�=�g9me���	e�u�%�l������+3w��E��nm��A4Q��{�����\�ެ����H�"����奶�Ru^y���p��U�(7���p�1��Y�;�p�Ηy,J�y�$ߣ�����8vA�0
ie�9���܍֮_Ȣ�;�����O�U���q�=@�,�m�����hi�O��g.���\�i@�=j������1��]���F�2�����<�Bc���_�&���)��6�ed�Z���	�w��ؑ�� �ѱ�E�<I�]w=��'�߅EL�o�]�F@�*�3��r����ei�	�w6w�tX��`�C,?aIg}��*��qwW0 �@���$}Y{z�E��ܨ�f��� /�;�%�f�������(�(;b��S��C�xWǣ�w��pgw'�>Og�����*�g�D,N�i�� �����A14zkS�O�*W���RT�M��@� �,���=U1���З�ދ����~�R����Zl?���.'N�X����Ǐ��1{�	���'F��M���S�Ջ���$we�凩,m4R����A]U�0�� 6��b�-�\��!]��U/'00��+�괟��U���uk�´5Qп�b�� ���;�R�>�yW�p�FE��z�+��b���f�庨�L\WE��[��^���݄�qu�U"Qۨ;k����$�eO�&�F�y����g�`_��˚��3�7�rS���X$ۘ���ӽ�ቲ�q[=S2 _  5(��b�w{((TI�Ix��-!�1��/����q!YG8D���G>�D��v���c�	7W��:�;�Bjs���C��F �#iչ��wO�&	���#b/oV��E*�A�+2�^�c@ɘu�PQ*����=�;+h"�?�E���9{�UI3�mѵcX�C����,��b��6Z��	�B�|/����7���]M��F����������&�)��_}�_ 3�]{��M3�C����'��
�ӮO���?sѕ}��̠���������M�e:�3.�]��E�/�M�����}S��Y����}ޢ���;]�y��i�|�g����?���/����      �   �   xڕ�=� @Ṝ�{��,]�C���ig��O��h�L([��G�������A@�3�����Z�� UꈹZ$S���PEl?�5oK��G���$K�m���^�9@��W��N��̛
�ԙ/���`�H�R� ��f�      �      x�Ŝ[s�HҮ�g~ž߁�·���H��_�C*I�@�~�N��|�yyu�fw�c�H؎z���[�)i8�IZФ�q7"�MC�4����?!�8�UuS��&e���M�'q�ML%	Y&a$�H2LtHQ��?^��%9����u�3��f8X��l��~�M{ ��ò=�wp���.�i�<�v��ic�ee؆7�KV��v}�X~�Xb�M���{mw�zS�i�õ�[���qr�(�;ۭ������f�������,�i���,^��v�F�ɜ���\o�:�����q/X��A�{6{�M:��[�f���5�~8P�,w�S�>tO����h�yJղ����@����A�_��;A9W��"�醙��j����4*�:_����(I��`�&�)4ƌ ��7���fN>���XM����V����;�]���-Z�u���Jc/{<����Q+�v�r��68.���sg��<e����ZK��H%(U_��D"G&�!��#����0aL�\�?-������>�9��� �ȁ����9ȁ��]��=�{�k��6Q��.:�;^����Vkט��1$�[�?7s��<�i-vG �����OZ)�J���41&�y5!�d�	֌q�U�)�L�×��N��&-o�����ez=,��aP��.�77�C �ckE�l
4(��7˜�w����u�cM���Ei[[��>����y�9o"2|<=�ݶ�yq���������`�.��܎�a�x6���}w��	�2�U������u/e�m��l�r��i��/���c܃?=�h��v-6!�����Z�E�B�	�4i�kj��B`��PcF��$�1�ID�8��D-p��	�|n�B���Fnwkg[�X��l���ς<�~���s���f��[��hfr+��l�ُ�=@~Ԉ��~�F�Zj#��'ؠ�D����HQ��H�b��<":51H���q����K��	Ħ���-�O&��=H5'[���~�>����2#�s�V�������2�9TG/�dׁ��N������ fk�%��˓i��pB��L��ybeg���$(�~�|�z���zO�b���Oz\I����*ij8�e��4��Қ���m�N�dPp@~@�d��Cz�����
�r�a�q��k��Ď$�t/��k<�G�c���퐤���ؽ%����\K�2��/l����p�kZ1ME�	�H	ȥ؄�>O#��PC�4Tݖ!P�
 Dl�Y;V����!=��5��]f��ZZ���N��3��9-�FoV�a���:9�<>��&�Al�f7#��ٯ�%�BH��VB�0�|[!�J�_�
C$BQ�M&(c\�$N�Nn@k��9�t�����$�
�p��y;e%A�"�-�coQ[y�t��7�/�w�����7h�݄�Wz��T��n>��W�s�B��R��Z�R⢞��I+�㒯���P�T@�c&!Q�(�hB���h�3dcw
$: m(!���H��]�vc�G6	��Hע��(N���x�L|gR�CՎKt;"$���V�L:V-y[���A+����~��̄!�� �a�FIe���Z�lv��2���O�k;��N6( � ���~h��k�@�_����<5��ľoǳ��И�V#�)�A�ON��޼����X����	+�R���eK)(�L*�ba��@y
�0����+[��]v�S��I0�!���]�U"�?�l��6�c�9*4�O�P.QF��,�]otxjmNy�%f����I^K���Y�|�18��w!�!,���$�!#JV,��������͋S��w;P�l׋�b����ƶ�{�`Ae+gk��a��U+���>k+vZy��X?�v�z�LU+�J��|OK��VI�	-&SW��1���e"C�R%4�`�G2�8%�����A�t�kP���������q�P�|l[��_mc�����'����^2���ƨ�|����z8,߼��q�V�M�;������rE�Ϭ�F����;�E�ǁ�,f�o�@��NÏ0�� �{���$<��n�g�$FU�����s�-������w}��~��]�/�~4|��������n���_��Y����^�a���w�0�����"ai��z��D�kXQ�#�blC8T�F�V'(7ؠ��{��.~68 �x���}h[�fP��ng����z�hNo������~�^��,:^����9}�����|b�����aR�00��Z
R/10�IKs�u��JI��0!1gLsm��+�g���-� dD�炼��\��w�]��_��H�L���_+����(Y�/���gk�u�=/�q��,�q�7�9ι�Y��b�j�>��B�|�_T�25���_U���A���hqހ��ï2�}�̾%���ZA���GI�bÊv���w�^�E��������b������e�!M�x�<����bz�A�1VO���"�6K��	7(�"��YH�� �,š���Fߖd�����ϚE倝(�l�p�Ao\|7��*�r{�L� ��~�zh5r9?�փ|k:��dF(q���v�G7:��R4����!���S���JhĢT@�X"�Y��������*-FV�y\g+�ʂ[��͋��v|8���1��<�ޯ��b֋�X9�xH��"p�����yЎ�yƷ�:���p���;f?i%
'R|�#��'�����B$t�"!�˜���}���&�!��nב�w�N���=��l�U�9�ײ�(]����l7m����]�m7N.^���Cc�o�i�ki	I�⿦F$�NK�D��G��1*XHJ�HjR�����j��g��8;���S��xc��6�fxߵ��`<���{_�lgsr�l�ux=��O��q�&<=����&-��T�#�3TZ��OZ��i���Hp��~M+����JIHS&9q��8�y�h���k������T�P�>�Z����:�p7v+������a@��	Z��ѣ�:�1�����q��F��Si��#���u*C�!©���~쿫*i�Oh#�0��w2L�m�P1L��<��2����򉍀F��u�cu
 X����_B]Z0�ҍ��-xo9%~�۴z� ڛ�@y����8���5qz�wLC�b�ey>k�ҒLq�?�%B�M��L�c����� �Z0�B)���uM���oV��sE%��J"�tJ?۲�7\;e ��j�^+>�)su���:����"������jgOm�伱���5��X���G~K���Ą�����ǂ ��fFT9Q�2�$)C�b��i��v7�7%vּ�+g܃�U�s;�N	�=3E�M�A~5w��ϊ��|�g��{^�x䏆�����tzc=�ݗ}:��Ŗ�C�x���%�c���BG�6D�Z!��k�U$�TB|��ߘ�سAQ���������[Ȏ�Cfyu�2��¹^k(1��̈́�@X�I;�6���r|:|~{}>��;�z�Lr����H`�	-��_���0���Ĉi��&A,	���
��mi�n���m�-��ܭ-�Q7�&��.��h��k�
O�OO��a�q__���p�H%2��Z��Ǥ?,�b[K���'�8g��XL)!2E�GZK�ol�)�Ir�D؛�v9(���ֱ�����c����8=g|�\\�yI���y�x؜���/q�hND'6�U2����9��I��@�_Ң:�!��Ǜ���h%�N�	�R�8啔ib��Lh���ւ�?/	����o	p��z�P����&�V�����z����_ɼt·ި���>ө��h;{�O�=Yw���K��|'�ĵۄ��� ���-��'(�a�hDU
Q��	�D��h��[���O��vH���l�Jd�6���ރ�V�_q�d���K��{.�y<��v�����G�����ds|�/K�~Z��"wH3�-��.��iEBJ$I�y��Q_�Ti�(cb���g�z٬�38	([�W�je����ɂ�%#�u����y!U_��e��얳yc�� �  O��˜�ì��١s�ZZ� ��'�T��״h( l�;�oҚĠ20 "�Vf��PNL(u���z�����h�z�g��(�ٴ�]�j^�g�`�5�����j�tH��;��]��wo��Wmw��ǒ�޷^=��	M[���OoR�#�^0�ٵ�����І���EJ�0��Ę_���0j��Hθ��$�<���-������ʃܦ����ZU�u�g�Ԟ���e��ؠȵv����4^�-����/�<�����¥8�/x�6�xk�B���C\S��џ����|=7j��g�7��(bIDE��%��H��l[����� A�����
\�g���,�KS^k�a~���u�ؓE��LZ�Q�l�CY<��#�q<�E㰭����׌4����8�>��5z�("!$D'u��8
`
A�ܠ��?\�mf��#����uxஐ��x��*��T#C�yc�(�r���.��[��|�9y�"�'�R�S�9����T�����VD@$��״~� 'IHd�hq-��o��L3Nȍiy˝����3�/pa�G�T�t�%T���\� ,�j�ʗ���$���iv�">.����Jg��ѲSKKL0���ُ��_��o.G	�F��4b�`�8%�iJ��a��Ђ�?���E	�����`�oR�q�"p�\��ʣǅ�B�]X�9���?�[˧�l��<�O�Dw�3:�t7�:���(���i�8���($�.��Ҙ!	R���%2	�k��#���C�u5tҤU�ڷyW���)����(�dl};����ٲ���R��Z�����J��5��.������F�#�wLb�>�-����Dkv�؊"�yu��EHD�I��A�uZh8nlwB���e��V.�|P~�umx���f;;[]��v4r����Jʾ�K����{���f����xS�2�7�Lt=�`4ƒ�O�o�-�Ƅ��r��D##��X�#���*��$v�>q�A5�Wڸ�)Ȁg����񨚤�f9��ת['��,���$��՝F�U0�'*��1��^�����N��;X$Q۸Q]�IK(��g*�w�x��*
 ,����0�J�Y,Cy[Z~��~��l�kz�6�WKZ�1�M���Ʈ6�͵�V]{�v���i�z�����xi�أ�6�.��ܶWjs���+"?�B�4��
�PA�(aa�0�<�`ى��h�����w!��4}Ӆp�7�v֡��1�wn{��#ZA�w�:�S�yhz�<��y89N��۾�/���4�C�Y6ki��B��5�����4�o.�H2�I)ŌEBc�X�R`�0��i�r� ^��c�j/mP�M5��Mn��S�X��]m��,#���4GOs1�iw�'[뾇ȥ|���F�C�완u���`��L��_���}��7�!�`��NK�\�!�A�D������ug]���d>�gNo��s�Y�v�l� ǫN�̵�y�S;A�����e��Z{o�D{�>����v�oqN��۵�T}+�� ����8
᷑P�X�YV�\��	V�o�I^���]vf.~5-�ڴ*ONo �k���m��A^}�a �Z��~m>�ew%'I�1�31x��{�(�Lǖ0�_F�q�Ƞ�#^ϊ����i`�δ?�0
s��1U��4�$M�Dܖ��B@��i��ũ�{`���zl�d�׃l[�r|4����;v��ww�ղ,_�=�<l����}���)��t�]f�e%��5��V�ce���A�T�D�c&H"""��f�e�n@��(^>%A���p�.�h�@�s�� R�.��x[E]���ןO�)� �>�c�&�����׸?XNk~$��Y,6���-S|'��R���q��,�F�
�^�"��1e"ʑ�F�(�\���^V=�vop��`�|RM|�2��ԮH���kŖ��w�}w��p�^��.�o�s�]<�Q�������U--M9e���*B$��5Va,D�0W3�������$�T7��n#���ɂ�mu���ew6��;(�u
�Z��lYu^�������f<qX��H����?%��CO>��q~O�S�Ġ�#�p�F%?iA�4�B��FVb��d(�\�N�.B���h��6�`��O!��X[d{�����7�������m��_�����Q+{���;�=���r���ۆ�Nq��E�m'��7	���!�$N>��ߙiE�9�S�F4f��ЄiL�4�Ƽ�mi���m�WA��A>(�^�P�����u�OK�zn׷I��f�e����"��x/�L�'�.�O��|�rVKK	�)����G�����+1���!�W��$��LD���������)z@��m�֎��նS�Us�+�X����p��f�;E�㡱Z['}���Y�g�tO-[Yv��S|��5[��U�D��P��V��2!�,��I��cF�� �D����mi9�A~-x��cͲ��ɶ;�ҡ�U=��~���3�����t�Jf�Q�[�S�*^PoҌ�q�yS��q�M---)��״�P�kxcCQ�8׉R@)��4�H�U7�$�xra���[ �]T����İ�U�m�8��-�}�I���q멳�m������龽�6�Sd�Ǉ�d����o�:M��4WZ�7�Q�����Q��cK�$a�&�4
��s�!�������ݴ�iB�'�ZS���?� ����E�U:q��n��j�оVl�Q6��MrO�uEg�o��:��R-��Is�͝�.�;B0(x�VE\_��Z+�"'B��4�M���q[Z�#v��;�Ԧj�p��l���,��aV�V+���͹�[��-L�,�����i%_h5�$-���z����X?�ε�8��Oh�	d�k��V�����<�f:B)��#�涴��)��)���OV5��<A4�P�A��U��j��Z�z��κ�죵Q�g���CΞx��)��ɋ;*�e��Ғ�R�I������?�#Q�      �      xڋ���� � �      �   v  xڍ��n���������SEK[���x�֖�
(30?�!��Or�M�DJ(&_��_���-��O��Gm��_�x96z��l`��8d�D���"�#��腞��|a������9D<������#���#�`��0?(G1�y����36��,b��$&�b�^t����?�����,OI���Fϛ��^Z ���/� �����L�AC�F��z���0H��a�,-�t���0J�����(��.�\�US5�C�;��0�ZM�������@h1�@�X�G"�m,B�p������9�i�����xy�h߶��1�Q��4mu�����f7޾�� kd̈��G�\�^��8���2�Ǫ�s��fN0 L�_'�e<Ɋ����|u;�{�=�%�i�]2��C�"��(ܸ�@,b᯹��-1#V�4$��������y������c8�H;�F�;O&�ܳ�z:IQ�@m{HN�91�>$��g�ӡ���K�'C���*{$��?�f2E(`�K&�n�2������ti@[��5$ѿ��F&p�&2N(�]1����C����$���(����H�<6�Ӭ4���7P�{Sp�UI6W�y�Y�m �%�۷d�*H�Rk�L��FAD�R�g
+l��L'�7b[;OF#�"B0�E���:�z?�:�a�VkjM���aw��,��J�۷T܍JJ=�dzA7S�"�@���>_��|Zv��}#�*�Zqm���y��F4�o:�q�Ө��H]F��p�^����TS�7�u���YӺ�D�Q�4k`�/  �c��������t?]��X��Lj��,ߜ?��jãA�OxV(�TT�`6OF�t���[M�=2K �K&�n�2�7���u�)q����暐�l=�O��39����c���a ��k�zGճʱ�w�	�"�;6&�}WH���?﷛XQ��o@�qi(��sҴ�Yue�F2̌BI-���U��7E��,�}e�I`����86��������\�T�(������ F���3��3��ۏ�ٯ��z$L�1�a�!ǗJ�����x]���NJ�R����1�,y岏��5N�~h�K~�Iνa�>j��3�;���s�1>��r�e��s7�]��ϋ�t�+��Q�:F�^�Q?��A7+��I?6+W�e���^��z�;��#�,�@�<��s�n뙾G[;��i#�����y���R���+(ۥ4��Qz �t4Iݽ������e�;�DJ�t�b����i���	�,����w2����KO���Iy�y]��Y�MC�79�Րv-GIk�x�/��U��/��1Xh��%[���G������N�>h����w�v��nT�t9K�BZmSh+���9��@����@�����a~_?v�A�]�As��;/jp ��D��F2��p>�u�+[�����N~b��rp�Y�v/�NXs�^�0��Q�=wԢ� q-�F�ZF�9�L�����
Is/"�ih�7<�	<߈w
��@�s�f�K��3vh��bU`WƓ��k`k�%�RM-���J��I�H��e�S��|�gֳ���G9��#��=�n�q#W�w����n��b;�͖���8�K��:���b7�d�X�j�c�ʧ�lR/V�4��'̍��w@����i��x�f��G19h���G�&,T����֣�t\)�aĆآKrR���������bW��:��a�+�s
&�t�;�r�3�\Y�w4��Ā�] ����nb0�8��Xl��V�V�A\�ǽ��\�f�tmϺ"{擑xȶ��
B�f/��I�����;Yq,*B��*�B���'�-&Q�U��x��0�9�1\��J�2�8-��:��������;�����㑱���y�����EbЃ�l�_6S�H���L�݈������S��RL�?n�_��@#&���DX�q$�.�?+�A�����o�p���;��ِ=�⼚AZ��)�4��j1�^ �?0�X��mL�=&�}��6b"Q�A�t�͋ĝ�j/� 4���$Y���di����Ԑ�.�]��O���	�կ�Bg'�bi��x�r�Ƅ�1�L�L؈�YA1�n]�D��;��"��� �7'{t�`��}> ��]��h��8���'����9��#m�������cro0�O0�FL��Ug�4Kq�J�(>�{���0��Y��j�,[������n�n�h8E�)���O{�I�S�)���lzk}�!�L��wi&@�4��o��T�}�	�/�{�󍝐�H[�-%J�D�4��v��N{q�uY��!���Zt��6f��r�RY�}>%����N�<��9�]sÏ�M�$w_��(.�$N�n҄��|`�C?��8�K��E��������9�|�W!?�����k^P�P�8��Y|�[�0����C)����z"U|/Rѣ�D5��iLl94k�;`Y�1��i=%-iT[+L1��5�1�\.Ձ���ũ7��Q����5go�J��6�X��gԵ��y�w'�A�׃�}jd?;��iP��� ht2B�
L�>�c�A8(ͳ%a׼v�6*}!7W��p>���%�/���� �T���G�Z����������^�I]���ꖺ/�B�z���&�w���Cιv���1J���z���!��>dYwc��)���8���̫���x�ˬY+�oT=N������XVҗV��ժ���XuS�͇#~�����C<����ə���NgLF&�������f��������-l����,�5�o��@��[��t�gu�62�66̗֩y<9� ��7���~q�������yb�T���H�N��ًʲS��#����q�?��k� �^Y�F�;��`���ǩl�q�V��UoC�iH��;o�y�������q      �   Q  xڕ����7����lF�x��A�e&E��e�x[Ӹ����9�6q3;ߴP�{7�>�蛎3]dY�_���~���ӿl�b�����6�3��P}1��ʾ;�|�K��u0�P��b�sTt�(�3]�\.�zY�g
�D�U�
��ɨ�Z�zρ,V��O�Y��dT?�l�4WH���Th�T�}pE��e˷�W�L����]Q����z�+
����D��۹�*T�f�v�S鄧G�2�;6�P��J�ˁ�w+x� .�-�ZC�
UP�W�;��E��<-�:�uX��uJtU��{��*�7�-%�`�R���2*���+Խv�,�:*�"�m@F�
�ᮕ)sȪQ�`Ȝ���%�v�,ְɽg]���Q�S��ݶwV�׎�R��1�&TA���]T�cZ["���-�}G�6�����-�@H T�V��h�_-�Q�.�Y������-$�9ˤie�V#�ԯa�
ջ�tu����,�q{gp��tT��AO�e��8������D�c��8��T�-��\��qu6���B���,���W��D"��J�*��Mn�jg!W��ƺ�SQ`�n�3����d/��'A�jr$�n�P��n��Qu I�z#I�z����'���|޸b�Ճ9[�,_��cV�F��[�Q�?�V���{�F_?:����ʔ��8��>G�W�����#��6=~���+)H�ϩbx[�
���|N�%��{*��?�5\�~�S����`���Sc]���T���r�p�g�{u��16��k�g������55�w.b�������T'z:�3���|X|I=�e�q`����G$�}N�m?Կ�x<�DeO      �     xڥ��r7�������)Wf��k6��W��TQT<~�9MJ��Q�l��_�}�����TJmst��R�:�"�CO1�T\L�?ۗ�@%�4j Z���e[��I�WK��t��V��S*7?4��{8?����?��5��*E+Un���xhS]~��I6���$��fDU�8�� 9�j6�����m��ut,�S�R�>��9�������P�n#�,�2��vR�2�fQ�m�ܕ��6�"���6Ƶ9�q�z���V����}�ۘ�/�׷1n����%��5��v��ȭ�-qSi�&f�F��6����ս��7����6H�ap��vT��Ync�f����R{tbHM�����m��Epm�ۘ�u�׷!n%�g�]u����(�� ���u��6�bu��6�m���q��ڼ��m��u�[�6���e7�y�o7�tIC�s&0��E�-sL%(��m�ۥ��v��$3�V��3@�L���%sUBM���q�ɍ3'�����$7nc�(Z��6��-3� � d����S�|Q�4�ٷQ�s[V�P�RY�wn�ܨu)�CI�;��Q��u#7[��!�D��⹍p��4sa�-Eȶ��RiQ�n�d���Uɍ�An2N�۱?��)t�(��k3e�ېJ�P"xn#\%L��I��]�4��:����m�ܒ��6�"u׉�6ĵ9wN�V��}Du4bf7(ٍȷ�Ur����q����]ː��\�1r�[� A��G{Or�V��ƘRS�R��L�ArѮm%Qo*kU
��fS฽����ja�U\�1r�6lqS��7J�\�g}�j[i6��R���(9��!n�*=U��F�Kd�K֨�"�!5˜���"Ć����\X�R 7-���K#jR"�������mL�^.�q�@��v�1�6���rY���6��b湍q�T�pܦ�7��A{�u#7�poqRq&7�s�&��ฝ�����u"g;ڧ����ny�$��F{�ۭ�>�f���$D�b��:pSq=4��׊$��ݐj]�f7 9��%��*M[^v�q�М݄�c!�&�$Sv��mL��Ƌ$�uo9���B��k�M➺D�Q�-�T���"	�-FVvSt���>�3w��ӖŠ���1/���U��8n�2�����(��["	�Ҳ��m�[��3JV��hG���En��M�-}SQ�F^�Ƹ���%�)1�u���nCd�Ӗ���(y}�6Y��D�&}7�՗���LC�ֶ-}T���FI��jV�����F��ee�I@�w�V�@2���c�b���IZU�a�VssI�\E([�n@�*oU
�v#�����s�c��۷Ar����Xa�ocܤ����K���:{$gӷd7�J���6�mB(�9�]{�E�!՗�v#W%��b*R��ۗĸ1[�%��3���I��<��mT�6�;�Y`�+M���4Fu5���=��-�v�Q?:�����]c�l&/�!5��\qE�4�����R��\�ZQ�c��� z?��Er#	H�mKv��$�Yq��<z��;������NH��ncd��&�1�X�nC�dj��m����F�n�nC�,D�I@[d㹍p�(�q�v"8�FT),{��t%7�(FUR�=�
r���w8P�CRsO�Q#{�T��6��iN�s��E�M���1���nC䢅�Է1��oq�����;5��bHUN�$�����h�/nc� �w�}�J�^q3w�\B�2Jb*Q1�M �˛D8�$�yː�T*\�!r3n�ө�J���R��Jc����Ѽ�m�e���eN�wU�F��r¸6��ɏ�۔��9�N�UY��$J�lrCv���ѓ,߻q���p�v"u߆T����ĆU)T����$����w{i���Oj0���4�m~}߆U���n��j�`%����~����v:L�*�K�L�y�
�Yh��e�7L�}i����۴���|)�oE�RV��4׸�Q;��'�v��{|h�:��:��|�ʕ�����]�����}�����X���PU��]{<�Χ��ݔ�8_��[Ik���[��&p���u���t�S}�͗��T'���T������y:�_��Vh\$����~"G[��әn��ϕ����oXV9�w:���i���]�^ؠp1�/o�ouG�l;<�)��R�+Q#|7v�Dt��cyz|�S�1�$}d�j�lx�t\.�[y:�oS9.���⠌fHg7x����c�e
�SY��
�yy�:3x��m_n�~$k����ky�=���,ꤾ�J������tO{
d�:_�j%m����r��v��9��ݗt8OwT�/�o�Q'�7��>�����������.������U78�8�r���@���?��ߔ���N
��G9�*�>��]n��F����/e��V�Q)R2t;*��O�7�K��s��R�_j�F&�D������]��N�ç����_*Η�^I:���9����/O�����N����y��ϕ�7�2�Ӱ^|<����ǯ����x��8/��7՞�mX��8\�Z����RYƵӥ:�TW�F����&� ?���+u����|��:?W}�x���:e3�WL��<ݧ��������Z�ރ����~�x�{x:=�HC��ǻ��bV�FK< �\�w_����ᥰ�6D���,�l�L���i�>�]�>?���N+�q��	���<Pv�{l'���:_���w���ޓ����u���jx�Bi��:x�����D��%��R�/��5���#M*�����4��h��yZ���RZK�5.�E��n���F���R�/�o��..�����D9��p>��Ki���F��c��d��xO��a�M^*��h������bm�~(�%5��J5�\gp?jp��|=��C��+9(9�|=��C�X��v[e��q���f�mj�����Mjh��܆�M��j�A�(����t�J����C��r��S�۷��nT��(��^�6��uf�qAU��J�$uR���6J��l�۠JQ�ϔ�nC\�Z�2�nS_tQ��E��F��������Th_c�qMr���M�2iD�&Uf$A�4Ln�ۨJ+)q�F�:��\}��J˹���4��:��Q��?/=�����(�[}����[n�*���TY��qk3�_��0���z~�Mj������kD}�ۨJ��p܆�-�.��ܦ!�4�z+Dṍ����6���oC��R��n�K�m��<�Qr�ڽ�mP��"p�F�F�h&C��^��c����xcXn��h��݆U^r(�m���)�%�mj@��Q��!��Fɹ���mTũ�Xn#���͛7���P      �   t	  xڭ�K��*��7W��̐z�Zz��	���5������/�_Od7��N�o�߈�~�	��֋TN��W�D߀ߨ����s���4c���#�h�e��q�Z�����#�m��
��乞�S�f�rn��
��d@�;a��I�f�&6ll��ob���+�ʀ6#>p�g�=����ĥ@�b�4#.x�9#>�(�2���oU������꟟�E����:qʐ�&nyf�C�Q��h��M�ҩy�����q?��w�<�1'�y��$�>��	2�	��SU0zM�x�T2m�33�ĔK�W�S�"3bn�ubq���x��Y��z�Cʌ�1�,V���6Ve��ˑ�|�X8婎��c=牓�C��t����L3�c;�E7.-ox�B�&.C��
q�S��q�:q�;�YNT�#�B�z�)�S�vV?7�U�6�i�J4F��,V&�uϻ
���%���Ɯ�=:d��$	�0�?�ǂ�g	$H�^ʔ8+�z8�o��x� 4�qr���q-�±���7Մ�71#�
� q>3Om|E���M��x��%�P�7��7lll�Ҙ�����FpsL���<'���C��X%�P��qL�1bO3��{bΒl�q�X��b�./�ʊ �QwR�;e_ �y^�xTK�^ϳ�X�#`� &���AA�����YtAƱ�"F| ��A��{NEl�#n��C�!e��9a��"sB9��#�j�8��qE+�	���Hlʈ�M6�i~[3ͯ��ѷ�Y8/�d"��u=��8=~WQ��J��Lb�7?����G�cW `����(�q�8V�ň:62tf��X�#%�p�lW�c�G���Ɲ�1"��],���d���<"E�����oȘ�V�c	:\w�hcG[�m��4D�G� w�ߊM�S���.��wOa���ȭ���m��l�6Lq�`l+j��;��4�!�d#v<�n�@O��8V���s��9Ŋ�c�8Fl��
�}W�q�p;�N����y��-F�����!)��8VUĈ롶A��+ı�)D|���r�G��W�bw��-=T�1+�q��1�b�PEʣZث���^�V�6ړ�-��q�����<'��l)dH)���ň���4d�@��؈��D�@�q���cR!��j�qo����Ѻ��FS�Ƒ�&����*�(L��=��F�0���+�q,VĈK� ��'�8D��y�س.��� ���y.I3-ǲt�8wک�F�(���#���$��A�q,VĈk޸q#y�W���l慈�
��X�9N� 1b�Clυt�ıb3��7.K�1yZ0ql�7Dl�;�؝����pY05���B�� ��X_Z�,�Z!wY'�D��8D++b�%�#�s#!�!�
��xd��`�Xp�+bZ'N@+���#��7T�F/���`��y}��"f�UĢ[��YN҃���aE��c��etk�h� 6���1QĈ����:�)�,��䕾4�>���`��M�q��_��AL�	n�Xu$�����U��n1b�rl�<-�p�
{���2��C9:F�@ύP!��[E�rk��IN�{o%DL��F����"�nP0�E��Z7l���☎C�<�F�f��}�m��c�����s'噡K�8�C���F����r#܊�2��d�\�h����y��O�G����Pl���L.LG�Q�ZY1��]ޯÎ#�����R�6%�V'��x�<9�:qRH��WG�7�Ə�(Oʗ �GϰL�U?�q�Й߰�)��yF\ �s��ŔnbKC�o�8D\����~��8�h��c6������uU��������$f��UZ��?ģkKwt��i���66@�w8���X��'�A����d��q�ĲA��w�c�!UD���Y׉�(���y#����$]Ċ�v��!v�{I�]o�72H�����s�3��J7hGvx�ƍr�\�6��ů��*�(��#��ǈG�ذ���
��(��������?i���b�8B��`���3Ud���M�	�u⑘ﻱ���aE�Q�1�$y�x�71q{�8]�/��a�:1���+2]�W��Y�,�e��:1�M,��B,>��h����d_��Cl��z��gGY�n����q>P�C���*(�<�牧01����L�9O~��f�u$��(�&�q�Yj3�ކ�ׁ������c��y�-��@���}U��p/��#�N�R�Jh�IgկO�̈u��,���
pFo�7o��V;�:0���iG0��(Fg1J!����J:��%�����A�?#^�"�����]G�������m�4�R�?��E��?s�~��\Q���J�à��0GG�t��xD��:)e�?����������\�      �   n  xڭ��n9����dAQ$%��,4#�뤉Ǎ�,�ݗ���L��a`L|&ş?5ّ�!�� 6=�Ӄ�!<_b�l�%�ݟ���r|����t��۷ݿ��|��z:?�}�s�og��@�e+L���L�|����<���1�X3��	5�}��S>����~\)�M� �+�!���4��	5<ۀ=W��P�ĻJ�����m*�k8�OiBx��� b���襦!���=�K��x/��S��7�dܔ7��\B�6!�!�w�*���B�@�C��r����c�>X_	
'�F�  �
���plBX2>�B��@ �C�@�aM���7#�RLC�Q�O�*���G��� n*���zx�lC�s�b{�24"��5l����e"7�#t�R�I֢P�0��n�4�����܄���J�:��ލ툠\����đ�����k�S�#8�L�0o*?^�sz7��X1'4Cϣ�!e��a��=��ġ�$�d4��
�$�6#������4���DC�I?J����7�Ŕ0vJ�E_����8�l���u��rjB���Y�j����B"Ua;e��a�c}�n�jG���p�~�4�Kx�ͅ��:kM-�
���?�@a@���`��u\S�蚐�1�ה|V�#`:����z:�xjC��E��A�zlg�re�,i�g�xT)۔�|������Q�B}��<2쌷��!1����؍���j��!�.�m%�w8R�  �i�`�KP�-_�[�M7v�6�*�b�Hu"�]˴L�:^(�mK��K!48v��F��WަN���TL�%ȭ+!�Da�Hҭj���{*Sܖ�S,W߄`{�u[A ��lKF�s^l���r��̄q(�7�1��-�,'�C	�Q[	�v��#`��Ȟ�S��+�)�ځ$�C	Ե��@,��9�� ��Cɗ��Ԅ@:��ú��e��}�>���l�XsJ
2r�C�t�\�c.s�l�7�����SQ]钆5���)�u�-�9[�x6y[Nr�έ���*n],�@�$h���C�|���4X�W/:4�:�V�e�r�w��P����]�-�w{/r��[Z�������R�y)      �   �  xڥ��n�F���S�8�=�/>f���!�\��E�c.I��<}��)�=l�BnK ?���%Ђ\n9�r�ͭ)�-��ʺ������ �?f��t�^st����#���Tg�<�(���LY�!���b��w��.�5�{Ђ3��*l��3d/mW��W�ﳓ���O���S�B)ƒ��05��Y��m��d�;40D�9?Ķ�� u�(\���YTK��jTKBW��8Um2��B�bSv����L²e"��I^c�����x-�_�=��L���b?�z��P��*�1,c,���(��Ͷ J�.jsp�v�8��q��
�U�4�P%���b	�Y�}����U֡sM���
臼-�$��}JVE��4�j,����E��})�\��C׾d��>N5�F8꩗1��<9�7�^t��60��@_�ȡqE�R��M[����W�rm���
�f=�ůn�^20n��ܹá��8��c�q����h"��j��T�H>+�SRa�[�mB�#fl��yj�C*%�D�4� ����(�h�db�Hk�E�#��}{���U��t��i�s�)
�>�N]P5�Y�O���s��P�n,�d�my:��f�x��L�h��ZC|�I�.V��W��b���&��vSz��:e�?֮{ʠ,���Y��O��,SPF��	��Λ^�'b���Q�6,��ܝ��M��>��Qz3i�y�N5�8��T�ǫ/��M�����h�Z��>��6I�4�fv��hR/�+�έ����F��ڸ���E��,B���RYfgU�����a�;pU>�~�%	����$�{�2:�ɬ.Ŗ}V���':�w�/qϏ�V�f��'���B%��=���wf���[��d����Ǚ
�j�	\���_�Z�r5hE��Δ�E4$�a����,�J,Qf����kA^*���t^���%;��{��~��Z�	Hh�mW��pn������c�.' �g���4�+~�!T��E������{{;^r:�f-��7��&�v��??}=?���K��P���������MĩJ�\�$�����������/��IǏu1�3�����^������ `��fD��Į���"�E��L![���6dA��I�����l��5��j���c�D#]��1
�8o7��b�m��	���}檪}����9	i�MC��ݾ���7 �;Ȧv�⩞洆+u����N1qN��2��N��Qen˲��n��̪v賶�No#=�����I<��V����I�\�ЧR�FA�a�ծ�����^J	����ۧ�Rp��X�/�y9j���J�nU�{։�
._*�����|�ɚ}4��aῂk�rz�7�,�0�f��c�,��8���0�QA�X?����@:     