PGDMP  	        .                z            taiga    12.3 (Debian 12.3-1.pgdg100+1)    13.4 �   0           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            1           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            2           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            3           1262    3232324    taiga    DATABASE     Y   CREATE DATABASE taiga WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE = 'en_US.utf8';
    DROP DATABASE taiga;
                taiga    false            �           1255    3233470    array_distinct(anyarray)    FUNCTION     �   CREATE FUNCTION public.array_distinct(anyarray) RETURNS anyarray
    LANGUAGE sql
    AS $_$
              SELECT ARRAY(SELECT DISTINCT unnest($1))
            $_$;
 /   DROP FUNCTION public.array_distinct(anyarray);
       public          taiga    false            �           1255    3233892 '   clean_key_in_custom_attributes_values()    FUNCTION     �  CREATE FUNCTION public.clean_key_in_custom_attributes_values() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
                       DECLARE
                               key text;
                               project_id int;
                               object_id int;
                               attribute text;
                               tablename text;
                               custom_attributes_tablename text;
                         BEGIN
                               key := OLD.id::text;
                               project_id := OLD.project_id;
                               attribute := TG_ARGV[0]::text;
                               tablename := TG_ARGV[1]::text;
                               custom_attributes_tablename := TG_ARGV[2]::text;

                               EXECUTE 'UPDATE ' || quote_ident(custom_attributes_tablename) || '
                                           SET attributes_values = json_object_delete_keys(attributes_values, ' || quote_literal(key) || ')
                                          FROM ' || quote_ident(tablename) || '
                                         WHERE ' || quote_ident(tablename) || '.project_id = ' || project_id || '
                                           AND ' || quote_ident(custom_attributes_tablename) || '.' || quote_ident(attribute) || ' = ' || quote_ident(tablename) || '.id';
                               RETURN NULL;
                           END; $$;
 >   DROP FUNCTION public.clean_key_in_custom_attributes_values();
       public          taiga    false            �           1255    3233440 !   inmutable_array_to_string(text[])    FUNCTION     �   CREATE FUNCTION public.inmutable_array_to_string(text[]) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$SELECT array_to_string($1, ' ', '')$_$;
 8   DROP FUNCTION public.inmutable_array_to_string(text[]);
       public          taiga    false            �           1255    3233891 %   json_object_delete_keys(json, text[])    FUNCTION     �  CREATE FUNCTION public.json_object_delete_keys(json json, VARIADIC keys_to_delete text[]) RETURNS json
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
                   SELECT COALESCE ((SELECT ('{' || string_agg(to_json("key") || ':' || "value", ',') || '}')
                                       FROM json_each("json")
                                      WHERE "key" <> ALL ("keys_to_delete")),
                                    '{}')::json $$;
 Y   DROP FUNCTION public.json_object_delete_keys(json json, VARIADIC keys_to_delete text[]);
       public          taiga    false            �           1255    3234016 &   json_object_delete_keys(jsonb, text[])    FUNCTION     �  CREATE FUNCTION public.json_object_delete_keys(json jsonb, VARIADIC keys_to_delete text[]) RETURNS jsonb
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
                   SELECT COALESCE ((SELECT ('{' || string_agg(to_json("key") || ':' || "value", ',') || '}')
                                       FROM jsonb_each("json")
                                      WHERE "key" <> ALL ("keys_to_delete")),
                                    '{}')::text::jsonb $$;
 Z   DROP FUNCTION public.json_object_delete_keys(json jsonb, VARIADIC keys_to_delete text[]);
       public          taiga    false            �           1255    3233468    reduce_dim(anyarray)    FUNCTION     �  CREATE FUNCTION public.reduce_dim(anyarray) RETURNS SETOF anyarray
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
            DECLARE
                s $1%TYPE;
            BEGIN
                IF $1 = '{}' THEN
                	RETURN;
                END IF;
                FOREACH s SLICE 1 IN ARRAY $1 LOOP
                    RETURN NEXT s;
                END LOOP;
                RETURN;
            END;
            $_$;
 +   DROP FUNCTION public.reduce_dim(anyarray);
       public          taiga    false            �           1255    3233471    update_project_tags_colors()    FUNCTION     �  CREATE FUNCTION public.update_project_tags_colors() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            DECLARE
            	tags text[];
            	project_tags_colors text[];
            	tag_color text[];
            	project_tags text[];
            	tag text;
            	project_id integer;
            BEGIN
            	tags := NEW.tags::text[];
            	project_id := NEW.project_id::integer;
            	project_tags := '{}';

            	-- Read project tags_colors into project_tags_colors
            	SELECT projects_project.tags_colors INTO project_tags_colors
                FROM projects_project
                WHERE id = project_id;

            	-- Extract just the project tags to project_tags_colors
                IF project_tags_colors != ARRAY[]::text[] THEN
                    FOREACH tag_color SLICE 1 in ARRAY project_tags_colors
                    LOOP
                        project_tags := array_append(project_tags, tag_color[1]);
                    END LOOP;
                END IF;

            	-- Add to project_tags_colors the new tags
                IF tags IS NOT NULL THEN
                    FOREACH tag in ARRAY tags
                    LOOP
                        IF tag != ALL(project_tags) THEN
                            project_tags_colors := array_cat(project_tags_colors,
                                                             ARRAY[ARRAY[tag, NULL]]);
                        END IF;
                    END LOOP;
                END IF;

            	-- Save the result in the tags_colors column
                UPDATE projects_project
                SET tags_colors = project_tags_colors
                WHERE id = project_id;

            	RETURN NULL;
            END; $$;
 3   DROP FUNCTION public.update_project_tags_colors();
       public          taiga    false            �           1255    3233469    array_agg_mult(anyarray) 	   AGGREGATE     w   CREATE AGGREGATE public.array_agg_mult(anyarray) (
    SFUNC = array_cat,
    STYPE = anyarray,
    INITCOND = '{}'
);
 0   DROP AGGREGATE public.array_agg_mult(anyarray);
       public          taiga    false            �           3600    3233368    english_stem_nostop    TEXT SEARCH DICTIONARY     {   CREATE TEXT SEARCH DICTIONARY public.english_stem_nostop (
    TEMPLATE = pg_catalog.snowball,
    language = 'english' );
 8   DROP TEXT SEARCH DICTIONARY public.english_stem_nostop;
       public          taiga    false            �           3602    3233369    english_nostop    TEXT SEARCH CONFIGURATION     �  CREATE TEXT SEARCH CONFIGURATION public.english_nostop (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR asciiword WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR word WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR hword_part WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR hword_asciipart WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR asciihword WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR hword WITH public.english_stem_nostop;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.english_nostop
    ADD MAPPING FOR uint WITH simple;
 6   DROP TEXT SEARCH CONFIGURATION public.english_nostop;
       public          taiga    false    2250            �            1259    3232633    attachments_attachment    TABLE     �  CREATE TABLE public.attachments_attachment (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    attached_file character varying(500),
    is_deprecated boolean NOT NULL,
    description text NOT NULL,
    "order" integer NOT NULL,
    content_type_id integer NOT NULL,
    owner_id bigint,
    project_id bigint NOT NULL,
    name character varying(500) NOT NULL,
    size integer,
    sha1 character varying(40) NOT NULL,
    from_comment boolean NOT NULL,
    CONSTRAINT attachments_attachment_object_id_check CHECK ((object_id >= 0))
);
 *   DROP TABLE public.attachments_attachment;
       public         heap    taiga    false            �            1259    3232679    attachments_attachment_id_seq    SEQUENCE     �   CREATE SEQUENCE public.attachments_attachment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.attachments_attachment_id_seq;
       public          taiga    false    220            4           0    0    attachments_attachment_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.attachments_attachment_id_seq OWNED BY public.attachments_attachment.id;
          public          taiga    false    221            �            1259    3232692 
   auth_group    TABLE     f   CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);
    DROP TABLE public.auth_group;
       public         heap    taiga    false            �            1259    3232690    auth_group_id_seq    SEQUENCE     �   CREATE SEQUENCE public.auth_group_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.auth_group_id_seq;
       public          taiga    false    225            5           0    0    auth_group_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.auth_group_id_seq OWNED BY public.auth_group.id;
          public          taiga    false    224            �            1259    3232702    auth_group_permissions    TABLE     �   CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);
 *   DROP TABLE public.auth_group_permissions;
       public         heap    taiga    false            �            1259    3232700    auth_group_permissions_id_seq    SEQUENCE     �   CREATE SEQUENCE public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.auth_group_permissions_id_seq;
       public          taiga    false    227            6           0    0    auth_group_permissions_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.auth_group_permissions_id_seq OWNED BY public.auth_group_permissions.id;
          public          taiga    false    226            �            1259    3232684    auth_permission    TABLE     �   CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);
 #   DROP TABLE public.auth_permission;
       public         heap    taiga    false            �            1259    3232682    auth_permission_id_seq    SEQUENCE     �   CREATE SEQUENCE public.auth_permission_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.auth_permission_id_seq;
       public          taiga    false    223            7           0    0    auth_permission_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.auth_permission_id_seq OWNED BY public.auth_permission.id;
          public          taiga    false    222            �            1259    3233556    contact_contactentry    TABLE     �   CREATE TABLE public.contact_contactentry (
    id bigint NOT NULL,
    comment text NOT NULL,
    created_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    user_id bigint NOT NULL
);
 (   DROP TABLE public.contact_contactentry;
       public         heap    taiga    false            �            1259    3233589    contact_contactentry_id_seq    SEQUENCE     �   CREATE SEQUENCE public.contact_contactentry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.contact_contactentry_id_seq;
       public          taiga    false    245            8           0    0    contact_contactentry_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.contact_contactentry_id_seq OWNED BY public.contact_contactentry.id;
          public          taiga    false    246                       1259    3233907 %   custom_attributes_epiccustomattribute    TABLE     ~  CREATE TABLE public.custom_attributes_epiccustomattribute (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    description text NOT NULL,
    type character varying(16) NOT NULL,
    "order" bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    extra jsonb
);
 9   DROP TABLE public.custom_attributes_epiccustomattribute;
       public         heap    taiga    false                       1259    3234029 ,   custom_attributes_epiccustomattribute_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_epiccustomattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 C   DROP SEQUENCE public.custom_attributes_epiccustomattribute_id_seq;
       public          taiga    false    258            9           0    0 ,   custom_attributes_epiccustomattribute_id_seq    SEQUENCE OWNED BY     }   ALTER SEQUENCE public.custom_attributes_epiccustomattribute_id_seq OWNED BY public.custom_attributes_epiccustomattribute.id;
          public          taiga    false    260                       1259    3233918 ,   custom_attributes_epiccustomattributesvalues    TABLE     �   CREATE TABLE public.custom_attributes_epiccustomattributesvalues (
    id bigint NOT NULL,
    version integer NOT NULL,
    attributes_values jsonb NOT NULL,
    epic_id bigint NOT NULL
);
 @   DROP TABLE public.custom_attributes_epiccustomattributesvalues;
       public         heap    taiga    false                       1259    3234044 3   custom_attributes_epiccustomattributesvalues_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_epiccustomattributesvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.custom_attributes_epiccustomattributesvalues_id_seq;
       public          taiga    false    259            :           0    0 3   custom_attributes_epiccustomattributesvalues_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_epiccustomattributesvalues_id_seq OWNED BY public.custom_attributes_epiccustomattributesvalues.id;
          public          taiga    false    261            �            1259    3233782 &   custom_attributes_issuecustomattribute    TABLE       CREATE TABLE public.custom_attributes_issuecustomattribute (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    description text NOT NULL,
    "order" bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    type character varying(16) NOT NULL,
    extra jsonb
);
 :   DROP TABLE public.custom_attributes_issuecustomattribute;
       public         heap    taiga    false                       1259    3234059 -   custom_attributes_issuecustomattribute_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_issuecustomattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.custom_attributes_issuecustomattribute_id_seq;
       public          taiga    false    252            ;           0    0 -   custom_attributes_issuecustomattribute_id_seq    SEQUENCE OWNED BY        ALTER SEQUENCE public.custom_attributes_issuecustomattribute_id_seq OWNED BY public.custom_attributes_issuecustomattribute.id;
          public          taiga    false    262            �            1259    3233839 -   custom_attributes_issuecustomattributesvalues    TABLE     �   CREATE TABLE public.custom_attributes_issuecustomattributesvalues (
    id bigint NOT NULL,
    version integer NOT NULL,
    attributes_values jsonb NOT NULL,
    issue_id bigint NOT NULL
);
 A   DROP TABLE public.custom_attributes_issuecustomattributesvalues;
       public         heap    taiga    false                       1259    3234074 4   custom_attributes_issuecustomattributesvalues_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_issuecustomattributesvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 K   DROP SEQUENCE public.custom_attributes_issuecustomattributesvalues_id_seq;
       public          taiga    false    255            <           0    0 4   custom_attributes_issuecustomattributesvalues_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_issuecustomattributesvalues_id_seq OWNED BY public.custom_attributes_issuecustomattributesvalues.id;
          public          taiga    false    263            �            1259    3233793 %   custom_attributes_taskcustomattribute    TABLE     ~  CREATE TABLE public.custom_attributes_taskcustomattribute (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    description text NOT NULL,
    "order" bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    type character varying(16) NOT NULL,
    extra jsonb
);
 9   DROP TABLE public.custom_attributes_taskcustomattribute;
       public         heap    taiga    false                       1259    3234089 ,   custom_attributes_taskcustomattribute_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_taskcustomattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 C   DROP SEQUENCE public.custom_attributes_taskcustomattribute_id_seq;
       public          taiga    false    253            =           0    0 ,   custom_attributes_taskcustomattribute_id_seq    SEQUENCE OWNED BY     }   ALTER SEQUENCE public.custom_attributes_taskcustomattribute_id_seq OWNED BY public.custom_attributes_taskcustomattribute.id;
          public          taiga    false    264                        1259    3233852 ,   custom_attributes_taskcustomattributesvalues    TABLE     �   CREATE TABLE public.custom_attributes_taskcustomattributesvalues (
    id bigint NOT NULL,
    version integer NOT NULL,
    attributes_values jsonb NOT NULL,
    task_id bigint NOT NULL
);
 @   DROP TABLE public.custom_attributes_taskcustomattributesvalues;
       public         heap    taiga    false            	           1259    3234104 3   custom_attributes_taskcustomattributesvalues_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_taskcustomattributesvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 J   DROP SEQUENCE public.custom_attributes_taskcustomattributesvalues_id_seq;
       public          taiga    false    256            >           0    0 3   custom_attributes_taskcustomattributesvalues_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_taskcustomattributesvalues_id_seq OWNED BY public.custom_attributes_taskcustomattributesvalues.id;
          public          taiga    false    265            �            1259    3233804 *   custom_attributes_userstorycustomattribute    TABLE     �  CREATE TABLE public.custom_attributes_userstorycustomattribute (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    description text NOT NULL,
    "order" bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    type character varying(16) NOT NULL,
    extra jsonb
);
 >   DROP TABLE public.custom_attributes_userstorycustomattribute;
       public         heap    taiga    false            
           1259    3234119 1   custom_attributes_userstorycustomattribute_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_userstorycustomattribute_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 H   DROP SEQUENCE public.custom_attributes_userstorycustomattribute_id_seq;
       public          taiga    false    254            ?           0    0 1   custom_attributes_userstorycustomattribute_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_userstorycustomattribute_id_seq OWNED BY public.custom_attributes_userstorycustomattribute.id;
          public          taiga    false    266                       1259    3233865 1   custom_attributes_userstorycustomattributesvalues    TABLE     �   CREATE TABLE public.custom_attributes_userstorycustomattributesvalues (
    id bigint NOT NULL,
    version integer NOT NULL,
    attributes_values jsonb NOT NULL,
    user_story_id bigint NOT NULL
);
 E   DROP TABLE public.custom_attributes_userstorycustomattributesvalues;
       public         heap    taiga    false                       1259    3234134 8   custom_attributes_userstorycustomattributesvalues_id_seq    SEQUENCE     �   CREATE SEQUENCE public.custom_attributes_userstorycustomattributesvalues_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 O   DROP SEQUENCE public.custom_attributes_userstorycustomattributesvalues_id_seq;
       public          taiga    false    257            @           0    0 8   custom_attributes_userstorycustomattributesvalues_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.custom_attributes_userstorycustomattributesvalues_id_seq OWNED BY public.custom_attributes_userstorycustomattributesvalues.id;
          public          taiga    false    267            �            1259    3232362    django_admin_log    TABLE     �  CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id bigint NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);
 $   DROP TABLE public.django_admin_log;
       public         heap    taiga    false            �            1259    3232360    django_admin_log_id_seq    SEQUENCE     �   CREATE SEQUENCE public.django_admin_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.django_admin_log_id_seq;
       public          taiga    false    208            A           0    0    django_admin_log_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.django_admin_log_id_seq OWNED BY public.django_admin_log.id;
          public          taiga    false    207            �            1259    3232338    django_content_type    TABLE     �   CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);
 '   DROP TABLE public.django_content_type;
       public         heap    taiga    false            �            1259    3232336    django_content_type_id_seq    SEQUENCE     �   CREATE SEQUENCE public.django_content_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.django_content_type_id_seq;
       public          taiga    false    205            B           0    0    django_content_type_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.django_content_type_id_seq OWNED BY public.django_content_type.id;
          public          taiga    false    204            �            1259    3232327    django_migrations    TABLE     �   CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);
 %   DROP TABLE public.django_migrations;
       public         heap    taiga    false            �            1259    3232325    django_migrations_id_seq    SEQUENCE     �   CREATE SEQUENCE public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.django_migrations_id_seq;
       public          taiga    false    203            C           0    0    django_migrations_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.django_migrations_id_seq OWNED BY public.django_migrations.id;
          public          taiga    false    202            ;           1259    3236253    django_session    TABLE     �   CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);
 "   DROP TABLE public.django_session;
       public         heap    taiga    false                       1259    3234137    djmail_message    TABLE     �  CREATE TABLE public.djmail_message (
    uuid character varying(40) NOT NULL,
    from_email character varying(1024) NOT NULL,
    to_email text NOT NULL,
    body_text text NOT NULL,
    body_html text NOT NULL,
    subject character varying(1024) NOT NULL,
    data text NOT NULL,
    retry_count smallint NOT NULL,
    status smallint NOT NULL,
    priority smallint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    sent_at timestamp with time zone,
    exception text NOT NULL
);
 "   DROP TABLE public.djmail_message;
       public         heap    taiga    false                       1259    3234148    easy_thumbnails_source    TABLE     �   CREATE TABLE public.easy_thumbnails_source (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL
);
 *   DROP TABLE public.easy_thumbnails_source;
       public         heap    taiga    false                       1259    3234146    easy_thumbnails_source_id_seq    SEQUENCE     �   CREATE SEQUENCE public.easy_thumbnails_source_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.easy_thumbnails_source_id_seq;
       public          taiga    false    270            D           0    0    easy_thumbnails_source_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.easy_thumbnails_source_id_seq OWNED BY public.easy_thumbnails_source.id;
          public          taiga    false    269                       1259    3234156    easy_thumbnails_thumbnail    TABLE     �   CREATE TABLE public.easy_thumbnails_thumbnail (
    id integer NOT NULL,
    storage_hash character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    modified timestamp with time zone NOT NULL,
    source_id integer NOT NULL
);
 -   DROP TABLE public.easy_thumbnails_thumbnail;
       public         heap    taiga    false                       1259    3234154     easy_thumbnails_thumbnail_id_seq    SEQUENCE     �   CREATE SEQUENCE public.easy_thumbnails_thumbnail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.easy_thumbnails_thumbnail_id_seq;
       public          taiga    false    272            E           0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.easy_thumbnails_thumbnail_id_seq OWNED BY public.easy_thumbnails_thumbnail.id;
          public          taiga    false    271                       1259    3234182 #   easy_thumbnails_thumbnaildimensions    TABLE     K  CREATE TABLE public.easy_thumbnails_thumbnaildimensions (
    id integer NOT NULL,
    thumbnail_id integer NOT NULL,
    width integer,
    height integer,
    CONSTRAINT easy_thumbnails_thumbnaildimensions_height_check CHECK ((height >= 0)),
    CONSTRAINT easy_thumbnails_thumbnaildimensions_width_check CHECK ((width >= 0))
);
 7   DROP TABLE public.easy_thumbnails_thumbnaildimensions;
       public         heap    taiga    false                       1259    3234180 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE     �   CREATE SEQUENCE public.easy_thumbnails_thumbnaildimensions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public.easy_thumbnails_thumbnaildimensions_id_seq;
       public          taiga    false    274            F           0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE OWNED BY     y   ALTER SEQUENCE public.easy_thumbnails_thumbnaildimensions_id_seq OWNED BY public.easy_thumbnails_thumbnaildimensions.id;
          public          taiga    false    273            �            1259    3233723 
   epics_epic    TABLE     ~  CREATE TABLE public.epics_epic (
    id bigint NOT NULL,
    tags text[],
    version integer NOT NULL,
    is_blocked boolean NOT NULL,
    blocked_note text NOT NULL,
    ref bigint,
    epics_order bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    subject text NOT NULL,
    description text NOT NULL,
    client_requirement boolean NOT NULL,
    team_requirement boolean NOT NULL,
    assigned_to_id bigint,
    owner_id bigint,
    project_id bigint NOT NULL,
    status_id bigint,
    color character varying(32) NOT NULL,
    external_reference text[]
);
    DROP TABLE public.epics_epic;
       public         heap    taiga    false                       1259    3234233    epics_epic_id_seq    SEQUENCE     z   CREATE SEQUENCE public.epics_epic_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.epics_epic_id_seq;
       public          taiga    false    250            G           0    0    epics_epic_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.epics_epic_id_seq OWNED BY public.epics_epic.id;
          public          taiga    false    275            �            1259    3233734    epics_relateduserstory    TABLE     �   CREATE TABLE public.epics_relateduserstory (
    id bigint NOT NULL,
    "order" bigint NOT NULL,
    epic_id bigint NOT NULL,
    user_story_id bigint NOT NULL
);
 *   DROP TABLE public.epics_relateduserstory;
       public         heap    taiga    false                       1259    3234278    epics_relateduserstory_id_seq    SEQUENCE     �   CREATE SEQUENCE public.epics_relateduserstory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.epics_relateduserstory_id_seq;
       public          taiga    false    251            H           0    0    epics_relateduserstory_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.epics_relateduserstory_id_seq OWNED BY public.epics_relateduserstory.id;
          public          taiga    false    276                       1259    3234281    external_apps_application    TABLE     �   CREATE TABLE public.external_apps_application (
    id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    icon_url text,
    web character varying(255),
    description text,
    next_url text NOT NULL
);
 -   DROP TABLE public.external_apps_application;
       public         heap    taiga    false                       1259    3234291    external_apps_applicationtoken    TABLE     
  CREATE TABLE public.external_apps_applicationtoken (
    id bigint NOT NULL,
    auth_code character varying(255),
    token character varying(255),
    state character varying(255),
    application_id character varying(255) NOT NULL,
    user_id bigint NOT NULL
);
 2   DROP TABLE public.external_apps_applicationtoken;
       public         heap    taiga    false                       1259    3234330 %   external_apps_applicationtoken_id_seq    SEQUENCE     �   CREATE SEQUENCE public.external_apps_applicationtoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.external_apps_applicationtoken_id_seq;
       public          taiga    false    278            I           0    0 %   external_apps_applicationtoken_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.external_apps_applicationtoken_id_seq OWNED BY public.external_apps_applicationtoken.id;
          public          taiga    false    279                       1259    3234335    feedback_feedbackentry    TABLE     �   CREATE TABLE public.feedback_feedbackentry (
    id bigint NOT NULL,
    full_name character varying(256) NOT NULL,
    email character varying(255) NOT NULL,
    comment text NOT NULL,
    created_date timestamp with time zone NOT NULL
);
 *   DROP TABLE public.feedback_feedbackentry;
       public         heap    taiga    false                       1259    3234354    feedback_feedbackentry_id_seq    SEQUENCE     �   CREATE SEQUENCE public.feedback_feedbackentry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.feedback_feedbackentry_id_seq;
       public          taiga    false    280            J           0    0    feedback_feedbackentry_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.feedback_feedbackentry_id_seq OWNED BY public.feedback_feedbackentry.id;
          public          taiga    false    281            �            1259    3233685    history_historyentry    TABLE     .  CREATE TABLE public.history_historyentry (
    id character varying(255) NOT NULL,
    "user" jsonb,
    created_at timestamp with time zone,
    type smallint,
    is_snapshot boolean,
    key character varying(255),
    diff jsonb,
    snapshot jsonb,
    "values" jsonb,
    comment text,
    comment_html text,
    delete_comment_date timestamp with time zone,
    delete_comment_user jsonb,
    is_hidden boolean,
    comment_versions jsonb,
    edit_comment_date timestamp with time zone,
    project_id bigint NOT NULL,
    values_diff_cache jsonb
);
 (   DROP TABLE public.history_historyentry;
       public         heap    taiga    false            �            1259    3232803    issues_issue    TABLE     �  CREATE TABLE public.issues_issue (
    id bigint NOT NULL,
    tags text[],
    version integer NOT NULL,
    is_blocked boolean NOT NULL,
    blocked_note text NOT NULL,
    ref bigint,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    finished_date timestamp with time zone,
    subject text NOT NULL,
    description text NOT NULL,
    assigned_to_id bigint,
    milestone_id bigint,
    owner_id bigint,
    priority_id bigint,
    project_id bigint NOT NULL,
    severity_id bigint,
    status_id bigint,
    type_id bigint,
    external_reference text[],
    due_date date,
    due_date_reason text NOT NULL
);
     DROP TABLE public.issues_issue;
       public         heap    taiga    false                       1259    3234388    issues_issue_id_seq    SEQUENCE     |   CREATE SEQUENCE public.issues_issue_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.issues_issue_id_seq;
       public          taiga    false    229            K           0    0    issues_issue_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.issues_issue_id_seq OWNED BY public.issues_issue.id;
          public          taiga    false    282            �            1259    3233374 
   likes_like    TABLE       CREATE TABLE public.likes_like (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    created_date timestamp with time zone NOT NULL,
    content_type_id integer NOT NULL,
    user_id bigint NOT NULL,
    CONSTRAINT likes_like_object_id_check CHECK ((object_id >= 0))
);
    DROP TABLE public.likes_like;
       public         heap    taiga    false                       1259    3234438    likes_like_id_seq    SEQUENCE     z   CREATE SEQUENCE public.likes_like_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.likes_like_id_seq;
       public          taiga    false    243            L           0    0    likes_like_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.likes_like_id_seq OWNED BY public.likes_like.id;
          public          taiga    false    283            �            1259    3232752    milestones_milestone    TABLE     &  CREATE TABLE public.milestones_milestone (
    id bigint NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    estimated_start date NOT NULL,
    estimated_finish date NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    closed boolean NOT NULL,
    disponibility double precision,
    "order" smallint NOT NULL,
    owner_id bigint,
    project_id bigint NOT NULL,
    CONSTRAINT milestones_milestone_order_check CHECK (("order" >= 0))
);
 (   DROP TABLE public.milestones_milestone;
       public         heap    taiga    false                       1259    3234456    milestones_milestone_id_seq    SEQUENCE     �   CREATE SEQUENCE public.milestones_milestone_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.milestones_milestone_id_seq;
       public          taiga    false    228            M           0    0    milestones_milestone_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.milestones_milestone_id_seq OWNED BY public.milestones_milestone.id;
          public          taiga    false    284            �            1259    3233058 '   notifications_historychangenotification    TABLE     S  CREATE TABLE public.notifications_historychangenotification (
    id bigint NOT NULL,
    key character varying(255) NOT NULL,
    created_datetime timestamp with time zone NOT NULL,
    updated_datetime timestamp with time zone NOT NULL,
    history_type smallint NOT NULL,
    owner_id bigint NOT NULL,
    project_id bigint NOT NULL
);
 ;   DROP TABLE public.notifications_historychangenotification;
       public         heap    taiga    false            �            1259    3233066 7   notifications_historychangenotification_history_entries    TABLE     �   CREATE TABLE public.notifications_historychangenotification_history_entries (
    id bigint NOT NULL,
    historychangenotification_id bigint NOT NULL,
    historyentry_id character varying(255) NOT NULL
);
 K   DROP TABLE public.notifications_historychangenotification_history_entries;
       public         heap    taiga    false            �            1259    3233064 >   notifications_historychangenotification_history_entries_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_historychangenotification_history_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 U   DROP SEQUENCE public.notifications_historychangenotification_history_entries_id_seq;
       public          taiga    false    235            N           0    0 >   notifications_historychangenotification_history_entries_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.notifications_historychangenotification_history_entries_id_seq OWNED BY public.notifications_historychangenotification_history_entries.id;
          public          taiga    false    234                       1259    3234552 .   notifications_historychangenotification_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_historychangenotification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 E   DROP SEQUENCE public.notifications_historychangenotification_id_seq;
       public          taiga    false    233            O           0    0 .   notifications_historychangenotification_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.notifications_historychangenotification_id_seq OWNED BY public.notifications_historychangenotification.id;
          public          taiga    false    286            �            1259    3233074 4   notifications_historychangenotification_notify_users    TABLE     �   CREATE TABLE public.notifications_historychangenotification_notify_users (
    id bigint NOT NULL,
    historychangenotification_id bigint NOT NULL,
    user_id bigint NOT NULL
);
 H   DROP TABLE public.notifications_historychangenotification_notify_users;
       public         heap    taiga    false            �            1259    3233072 ;   notifications_historychangenotification_notify_users_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_historychangenotification_notify_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 R   DROP SEQUENCE public.notifications_historychangenotification_notify_users_id_seq;
       public          taiga    false    237            P           0    0 ;   notifications_historychangenotification_notify_users_id_seq    SEQUENCE OWNED BY     �   ALTER SEQUENCE public.notifications_historychangenotification_notify_users_id_seq OWNED BY public.notifications_historychangenotification_notify_users.id;
          public          taiga    false    236            �            1259    3233015    notifications_notifypolicy    TABLE     a  CREATE TABLE public.notifications_notifypolicy (
    id bigint NOT NULL,
    notify_level smallint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    user_id bigint NOT NULL,
    live_notify_level smallint NOT NULL,
    web_notify_level boolean NOT NULL
);
 .   DROP TABLE public.notifications_notifypolicy;
       public         heap    taiga    false                       1259    3234586 !   notifications_notifypolicy_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_notifypolicy_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 8   DROP SEQUENCE public.notifications_notifypolicy_id_seq;
       public          taiga    false    232            Q           0    0 !   notifications_notifypolicy_id_seq    SEQUENCE OWNED BY     g   ALTER SEQUENCE public.notifications_notifypolicy_id_seq OWNED BY public.notifications_notifypolicy.id;
          public          taiga    false    287            �            1259    3233125    notifications_watched    TABLE     L  CREATE TABLE public.notifications_watched (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    created_date timestamp with time zone NOT NULL,
    content_type_id integer NOT NULL,
    user_id bigint NOT NULL,
    project_id bigint NOT NULL,
    CONSTRAINT notifications_watched_object_id_check CHECK ((object_id >= 0))
);
 )   DROP TABLE public.notifications_watched;
       public         heap    taiga    false                        1259    3234600    notifications_watched_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_watched_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.notifications_watched_id_seq;
       public          taiga    false    238            R           0    0    notifications_watched_id_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.notifications_watched_id_seq OWNED BY public.notifications_watched.id;
          public          taiga    false    288                       1259    3234524    notifications_webnotification    TABLE     P  CREATE TABLE public.notifications_webnotification (
    id bigint NOT NULL,
    created timestamp with time zone NOT NULL,
    read timestamp with time zone,
    event_type integer NOT NULL,
    data jsonb NOT NULL,
    user_id bigint NOT NULL,
    CONSTRAINT notifications_webnotification_event_type_check CHECK ((event_type >= 0))
);
 1   DROP TABLE public.notifications_webnotification;
       public         heap    taiga    false            !           1259    3234615 $   notifications_webnotification_id_seq    SEQUENCE     �   CREATE SEQUENCE public.notifications_webnotification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.notifications_webnotification_id_seq;
       public          taiga    false    285            S           0    0 $   notifications_webnotification_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.notifications_webnotification_id_seq OWNED BY public.notifications_webnotification.id;
          public          taiga    false    289            �            1259    3233481    projects_epicstatus    TABLE        CREATE TABLE public.projects_epicstatus (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    "order" integer NOT NULL,
    is_closed boolean NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL
);
 '   DROP TABLE public.projects_epicstatus;
       public         heap    taiga    false            (           1259    3234762    projects_epicstatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_epicstatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.projects_epicstatus_id_seq;
       public          taiga    false    244            T           0    0    projects_epicstatus_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.projects_epicstatus_id_seq OWNED BY public.projects_epicstatus.id;
          public          taiga    false    296            #           1259    3234643    projects_issueduedate    TABLE       CREATE TABLE public.projects_issueduedate (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    by_default boolean NOT NULL,
    color character varying(20) NOT NULL,
    days_to_due integer,
    project_id bigint NOT NULL
);
 )   DROP TABLE public.projects_issueduedate;
       public         heap    taiga    false            )           1259    3234834    projects_issueduedate_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_issueduedate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.projects_issueduedate_id_seq;
       public          taiga    false    291            U           0    0    projects_issueduedate_id_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.projects_issueduedate_id_seq OWNED BY public.projects_issueduedate.id;
          public          taiga    false    297            �            1259    3232452    projects_issuestatus    TABLE     !  CREATE TABLE public.projects_issuestatus (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    is_closed boolean NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL,
    slug character varying(255) NOT NULL
);
 (   DROP TABLE public.projects_issuestatus;
       public         heap    taiga    false            *           1259    3234852    projects_issuestatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_issuestatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.projects_issuestatus_id_seq;
       public          taiga    false    212            V           0    0    projects_issuestatus_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.projects_issuestatus_id_seq OWNED BY public.projects_issuestatus.id;
          public          taiga    false    298            �            1259    3232460    projects_issuetype    TABLE     �   CREATE TABLE public.projects_issuetype (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL
);
 &   DROP TABLE public.projects_issuetype;
       public         heap    taiga    false            +           1259    3234928    projects_issuetype_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_issuetype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.projects_issuetype_id_seq;
       public          taiga    false    213            W           0    0    projects_issuetype_id_seq    SEQUENCE OWNED BY     W   ALTER SEQUENCE public.projects_issuetype_id_seq OWNED BY public.projects_issuetype.id;
          public          taiga    false    299            �            1259    3232399    projects_membership    TABLE     �  CREATE TABLE public.projects_membership (
    id bigint NOT NULL,
    is_admin boolean NOT NULL,
    email character varying(255),
    created_at timestamp with time zone NOT NULL,
    token character varying(60),
    user_id bigint,
    project_id bigint NOT NULL,
    role_id bigint NOT NULL,
    invited_by_id bigint,
    invitation_extra_text text,
    user_order bigint NOT NULL
);
 '   DROP TABLE public.projects_membership;
       public         heap    taiga    false            ,           1259    3235010    projects_membership_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_membership_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.projects_membership_id_seq;
       public          taiga    false    210            X           0    0    projects_membership_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.projects_membership_id_seq OWNED BY public.projects_membership.id;
          public          taiga    false    300            �            1259    3232468    projects_points    TABLE     �   CREATE TABLE public.projects_points (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    value double precision,
    project_id bigint NOT NULL
);
 #   DROP TABLE public.projects_points;
       public         heap    taiga    false            -           1259    3235022    projects_points_id_seq    SEQUENCE        CREATE SEQUENCE public.projects_points_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.projects_points_id_seq;
       public          taiga    false    214            Y           0    0    projects_points_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.projects_points_id_seq OWNED BY public.projects_points.id;
          public          taiga    false    301            �            1259    3232476    projects_priority    TABLE     �   CREATE TABLE public.projects_priority (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL
);
 %   DROP TABLE public.projects_priority;
       public         heap    taiga    false            .           1259    3235090    projects_priority_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_priority_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.projects_priority_id_seq;
       public          taiga    false    215            Z           0    0    projects_priority_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.projects_priority_id_seq OWNED BY public.projects_priority.id;
          public          taiga    false    302            �            1259    3232407    projects_project    TABLE     .  CREATE TABLE public.projects_project (
    id bigint NOT NULL,
    tags text[],
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    description text,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    total_milestones integer,
    total_story_points double precision,
    is_backlog_activated boolean NOT NULL,
    is_kanban_activated boolean NOT NULL,
    is_wiki_activated boolean NOT NULL,
    is_issues_activated boolean NOT NULL,
    videoconferences character varying(250),
    videoconferences_extra_data character varying(250),
    anon_permissions text[],
    public_permissions text[],
    is_private boolean NOT NULL,
    tags_colors text[],
    owner_id bigint,
    creation_template_id bigint,
    default_issue_status_id bigint,
    default_issue_type_id bigint,
    default_points_id bigint,
    default_priority_id bigint,
    default_severity_id bigint,
    default_task_status_id bigint,
    default_us_status_id bigint,
    issues_csv_uuid character varying(32),
    tasks_csv_uuid character varying(32),
    userstories_csv_uuid character varying(32),
    is_featured boolean NOT NULL,
    is_looking_for_people boolean NOT NULL,
    total_activity integer NOT NULL,
    total_activity_last_month integer NOT NULL,
    total_activity_last_week integer NOT NULL,
    total_activity_last_year integer NOT NULL,
    total_fans integer NOT NULL,
    total_fans_last_month integer NOT NULL,
    total_fans_last_week integer NOT NULL,
    total_fans_last_year integer NOT NULL,
    totals_updated_datetime timestamp with time zone NOT NULL,
    logo character varying(500),
    looking_for_people_note text NOT NULL,
    blocked_code character varying(255),
    transfer_token character varying(255),
    is_epics_activated boolean NOT NULL,
    default_epic_status_id bigint,
    epics_csv_uuid character varying(32),
    is_contact_activated boolean NOT NULL,
    default_swimlane_id bigint,
    workspace_id bigint,
    color integer NOT NULL,
    workspace_member_permissions text[],
    CONSTRAINT projects_project_total_activity_check CHECK ((total_activity >= 0)),
    CONSTRAINT projects_project_total_activity_last_month_check CHECK ((total_activity_last_month >= 0)),
    CONSTRAINT projects_project_total_activity_last_week_check CHECK ((total_activity_last_week >= 0)),
    CONSTRAINT projects_project_total_activity_last_year_check CHECK ((total_activity_last_year >= 0)),
    CONSTRAINT projects_project_total_fans_check CHECK ((total_fans >= 0)),
    CONSTRAINT projects_project_total_fans_last_month_check CHECK ((total_fans_last_month >= 0)),
    CONSTRAINT projects_project_total_fans_last_week_check CHECK ((total_fans_last_week >= 0)),
    CONSTRAINT projects_project_total_fans_last_year_check CHECK ((total_fans_last_year >= 0))
);
 $   DROP TABLE public.projects_project;
       public         heap    taiga    false            /           1259    3235201    projects_project_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_project_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.projects_project_id_seq;
       public          taiga    false    211            [           0    0    projects_project_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.projects_project_id_seq OWNED BY public.projects_project.id;
          public          taiga    false    303            �            1259    3233299    projects_projectmodulesconfig    TABLE     �   CREATE TABLE public.projects_projectmodulesconfig (
    id bigint NOT NULL,
    config jsonb,
    project_id bigint NOT NULL
);
 1   DROP TABLE public.projects_projectmodulesconfig;
       public         heap    taiga    false            0           1259    3235793 $   projects_projectmodulesconfig_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_projectmodulesconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ;   DROP SEQUENCE public.projects_projectmodulesconfig_id_seq;
       public          taiga    false    241            \           0    0 $   projects_projectmodulesconfig_id_seq    SEQUENCE OWNED BY     m   ALTER SEQUENCE public.projects_projectmodulesconfig_id_seq OWNED BY public.projects_projectmodulesconfig.id;
          public          taiga    false    304            �            1259    3232484    projects_projecttemplate    TABLE       CREATE TABLE public.projects_projecttemplate (
    id bigint NOT NULL,
    name character varying(250) NOT NULL,
    slug character varying(250) NOT NULL,
    description text NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    default_owner_role character varying(50) NOT NULL,
    is_backlog_activated boolean NOT NULL,
    is_kanban_activated boolean NOT NULL,
    is_wiki_activated boolean NOT NULL,
    is_issues_activated boolean NOT NULL,
    videoconferences character varying(250),
    videoconferences_extra_data character varying(250),
    default_options jsonb,
    us_statuses jsonb,
    points jsonb,
    task_statuses jsonb,
    issue_statuses jsonb,
    issue_types jsonb,
    priorities jsonb,
    severities jsonb,
    roles jsonb,
    "order" bigint NOT NULL,
    epic_statuses jsonb,
    is_epics_activated boolean NOT NULL,
    is_contact_activated boolean NOT NULL,
    epic_custom_attributes jsonb,
    is_looking_for_people boolean NOT NULL,
    issue_custom_attributes jsonb,
    looking_for_people_note text NOT NULL,
    tags text[],
    tags_colors text[],
    task_custom_attributes jsonb,
    us_custom_attributes jsonb,
    issue_duedates jsonb,
    task_duedates jsonb,
    us_duedates jsonb
);
 ,   DROP TABLE public.projects_projecttemplate;
       public         heap    taiga    false            1           1259    3235808    projects_projecttemplate_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_projecttemplate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.projects_projecttemplate_id_seq;
       public          taiga    false    216            ]           0    0    projects_projecttemplate_id_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.projects_projecttemplate_id_seq OWNED BY public.projects_projecttemplate.id;
          public          taiga    false    305            �            1259    3232497    projects_severity    TABLE     �   CREATE TABLE public.projects_severity (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL
);
 %   DROP TABLE public.projects_severity;
       public         heap    taiga    false            2           1259    3235866    projects_severity_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_severity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.projects_severity_id_seq;
       public          taiga    false    217            ^           0    0    projects_severity_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.projects_severity_id_seq OWNED BY public.projects_severity.id;
          public          taiga    false    306            &           1259    3234693    projects_swimlane    TABLE     �   CREATE TABLE public.projects_swimlane (
    id bigint NOT NULL,
    name text NOT NULL,
    "order" bigint NOT NULL,
    project_id bigint NOT NULL
);
 %   DROP TABLE public.projects_swimlane;
       public         heap    taiga    false            3           1259    3235945    projects_swimlane_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_swimlane_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.projects_swimlane_id_seq;
       public          taiga    false    294            _           0    0    projects_swimlane_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.projects_swimlane_id_seq OWNED BY public.projects_swimlane.id;
          public          taiga    false    307            '           1259    3234710     projects_swimlaneuserstorystatus    TABLE     �   CREATE TABLE public.projects_swimlaneuserstorystatus (
    id bigint NOT NULL,
    wip_limit integer,
    status_id bigint NOT NULL,
    swimlane_id bigint NOT NULL
);
 4   DROP TABLE public.projects_swimlaneuserstorystatus;
       public         heap    taiga    false            4           1259    3236015 '   projects_swimlaneuserstorystatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_swimlaneuserstorystatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 >   DROP SEQUENCE public.projects_swimlaneuserstorystatus_id_seq;
       public          taiga    false    295            `           0    0 '   projects_swimlaneuserstorystatus_id_seq    SEQUENCE OWNED BY     s   ALTER SEQUENCE public.projects_swimlaneuserstorystatus_id_seq OWNED BY public.projects_swimlaneuserstorystatus.id;
          public          taiga    false    308            $           1259    3234651    projects_taskduedate    TABLE       CREATE TABLE public.projects_taskduedate (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    by_default boolean NOT NULL,
    color character varying(20) NOT NULL,
    days_to_due integer,
    project_id bigint NOT NULL
);
 (   DROP TABLE public.projects_taskduedate;
       public         heap    taiga    false            5           1259    3236027    projects_taskduedate_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_taskduedate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.projects_taskduedate_id_seq;
       public          taiga    false    292            a           0    0    projects_taskduedate_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.projects_taskduedate_id_seq OWNED BY public.projects_taskduedate.id;
          public          taiga    false    309            �            1259    3232505    projects_taskstatus    TABLE        CREATE TABLE public.projects_taskstatus (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    is_closed boolean NOT NULL,
    color character varying(20) NOT NULL,
    project_id bigint NOT NULL,
    slug character varying(255) NOT NULL
);
 '   DROP TABLE public.projects_taskstatus;
       public         heap    taiga    false            6           1259    3236045    projects_taskstatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_taskstatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.projects_taskstatus_id_seq;
       public          taiga    false    218            b           0    0    projects_taskstatus_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.projects_taskstatus_id_seq OWNED BY public.projects_taskstatus.id;
          public          taiga    false    310            %           1259    3234659    projects_userstoryduedate    TABLE       CREATE TABLE public.projects_userstoryduedate (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    by_default boolean NOT NULL,
    color character varying(20) NOT NULL,
    days_to_due integer,
    project_id bigint NOT NULL
);
 -   DROP TABLE public.projects_userstoryduedate;
       public         heap    taiga    false            7           1259    3236119     projects_userstoryduedate_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_userstoryduedate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.projects_userstoryduedate_id_seq;
       public          taiga    false    293            c           0    0     projects_userstoryduedate_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.projects_userstoryduedate_id_seq OWNED BY public.projects_userstoryduedate.id;
          public          taiga    false    311            �            1259    3232513    projects_userstorystatus    TABLE     ^  CREATE TABLE public.projects_userstorystatus (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    "order" integer NOT NULL,
    is_closed boolean NOT NULL,
    color character varying(20) NOT NULL,
    wip_limit integer,
    project_id bigint NOT NULL,
    slug character varying(255) NOT NULL,
    is_archived boolean NOT NULL
);
 ,   DROP TABLE public.projects_userstorystatus;
       public         heap    taiga    false            8           1259    3236137    projects_userstorystatus_id_seq    SEQUENCE     �   CREATE SEQUENCE public.projects_userstorystatus_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.projects_userstorystatus_id_seq;
       public          taiga    false    219            d           0    0    projects_userstorystatus_id_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.projects_userstorystatus_id_seq OWNED BY public.projects_userstorystatus.id;
          public          taiga    false    312            ^           1259    3237699    references_project1    SEQUENCE     |   CREATE SEQUENCE public.references_project1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project1;
       public          taiga    false            g           1259    3237717    references_project10    SEQUENCE     }   CREATE SEQUENCE public.references_project10
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project10;
       public          taiga    false            h           1259    3237719    references_project11    SEQUENCE     }   CREATE SEQUENCE public.references_project11
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project11;
       public          taiga    false            i           1259    3237721    references_project12    SEQUENCE     }   CREATE SEQUENCE public.references_project12
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project12;
       public          taiga    false            j           1259    3237723    references_project13    SEQUENCE     }   CREATE SEQUENCE public.references_project13
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project13;
       public          taiga    false            k           1259    3237725    references_project14    SEQUENCE     }   CREATE SEQUENCE public.references_project14
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project14;
       public          taiga    false            l           1259    3237727    references_project15    SEQUENCE     }   CREATE SEQUENCE public.references_project15
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project15;
       public          taiga    false            m           1259    3237729    references_project16    SEQUENCE     }   CREATE SEQUENCE public.references_project16
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project16;
       public          taiga    false            n           1259    3237731    references_project17    SEQUENCE     }   CREATE SEQUENCE public.references_project17
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project17;
       public          taiga    false            o           1259    3237733    references_project18    SEQUENCE     }   CREATE SEQUENCE public.references_project18
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project18;
       public          taiga    false            p           1259    3237735    references_project19    SEQUENCE     }   CREATE SEQUENCE public.references_project19
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project19;
       public          taiga    false            _           1259    3237701    references_project2    SEQUENCE     |   CREATE SEQUENCE public.references_project2
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project2;
       public          taiga    false            q           1259    3237737    references_project20    SEQUENCE     }   CREATE SEQUENCE public.references_project20
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project20;
       public          taiga    false            r           1259    3237739    references_project21    SEQUENCE     }   CREATE SEQUENCE public.references_project21
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project21;
       public          taiga    false            s           1259    3237741    references_project22    SEQUENCE     }   CREATE SEQUENCE public.references_project22
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project22;
       public          taiga    false            t           1259    3237743    references_project23    SEQUENCE     }   CREATE SEQUENCE public.references_project23
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project23;
       public          taiga    false            u           1259    3237745    references_project24    SEQUENCE     }   CREATE SEQUENCE public.references_project24
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project24;
       public          taiga    false            v           1259    3237747    references_project25    SEQUENCE     }   CREATE SEQUENCE public.references_project25
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project25;
       public          taiga    false            w           1259    3237749    references_project26    SEQUENCE     }   CREATE SEQUENCE public.references_project26
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project26;
       public          taiga    false            x           1259    3237751    references_project27    SEQUENCE     }   CREATE SEQUENCE public.references_project27
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project27;
       public          taiga    false            y           1259    3237753    references_project28    SEQUENCE     }   CREATE SEQUENCE public.references_project28
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project28;
       public          taiga    false            z           1259    3237755    references_project29    SEQUENCE     }   CREATE SEQUENCE public.references_project29
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project29;
       public          taiga    false            `           1259    3237703    references_project3    SEQUENCE     |   CREATE SEQUENCE public.references_project3
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project3;
       public          taiga    false            {           1259    3237757    references_project30    SEQUENCE     }   CREATE SEQUENCE public.references_project30
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project30;
       public          taiga    false            |           1259    3237759    references_project31    SEQUENCE     }   CREATE SEQUENCE public.references_project31
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project31;
       public          taiga    false            }           1259    3237761    references_project32    SEQUENCE     }   CREATE SEQUENCE public.references_project32
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project32;
       public          taiga    false            ~           1259    3237763    references_project33    SEQUENCE     }   CREATE SEQUENCE public.references_project33
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project33;
       public          taiga    false                       1259    3237765    references_project34    SEQUENCE     }   CREATE SEQUENCE public.references_project34
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project34;
       public          taiga    false            �           1259    3237767    references_project35    SEQUENCE     }   CREATE SEQUENCE public.references_project35
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project35;
       public          taiga    false            �           1259    3237769    references_project36    SEQUENCE     }   CREATE SEQUENCE public.references_project36
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project36;
       public          taiga    false            �           1259    3237771    references_project37    SEQUENCE     }   CREATE SEQUENCE public.references_project37
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project37;
       public          taiga    false            �           1259    3237773    references_project38    SEQUENCE     }   CREATE SEQUENCE public.references_project38
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project38;
       public          taiga    false            �           1259    3237775    references_project39    SEQUENCE     }   CREATE SEQUENCE public.references_project39
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project39;
       public          taiga    false            a           1259    3237705    references_project4    SEQUENCE     |   CREATE SEQUENCE public.references_project4
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project4;
       public          taiga    false            �           1259    3237777    references_project40    SEQUENCE     }   CREATE SEQUENCE public.references_project40
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project40;
       public          taiga    false            �           1259    3237779    references_project41    SEQUENCE     }   CREATE SEQUENCE public.references_project41
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project41;
       public          taiga    false            �           1259    3237781    references_project42    SEQUENCE     }   CREATE SEQUENCE public.references_project42
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project42;
       public          taiga    false            �           1259    3237783    references_project43    SEQUENCE     }   CREATE SEQUENCE public.references_project43
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project43;
       public          taiga    false            �           1259    3237785    references_project44    SEQUENCE     }   CREATE SEQUENCE public.references_project44
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project44;
       public          taiga    false            �           1259    3237787    references_project45    SEQUENCE     }   CREATE SEQUENCE public.references_project45
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.references_project45;
       public          taiga    false            b           1259    3237707    references_project5    SEQUENCE     |   CREATE SEQUENCE public.references_project5
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project5;
       public          taiga    false            c           1259    3237709    references_project6    SEQUENCE     |   CREATE SEQUENCE public.references_project6
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project6;
       public          taiga    false            d           1259    3237711    references_project7    SEQUENCE     |   CREATE SEQUENCE public.references_project7
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project7;
       public          taiga    false            e           1259    3237713    references_project8    SEQUENCE     |   CREATE SEQUENCE public.references_project8
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project8;
       public          taiga    false            f           1259    3237715    references_project9    SEQUENCE     |   CREATE SEQUENCE public.references_project9
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.references_project9;
       public          taiga    false            9           1259    3236219    references_reference    TABLE     D  CREATE TABLE public.references_reference (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    ref bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    content_type_id integer NOT NULL,
    project_id bigint NOT NULL,
    CONSTRAINT references_reference_object_id_check CHECK ((object_id >= 0))
);
 (   DROP TABLE public.references_reference;
       public         heap    taiga    false            :           1259    3236250    references_reference_id_seq    SEQUENCE     �   CREATE SEQUENCE public.references_reference_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.references_reference_id_seq;
       public          taiga    false    313            e           0    0    references_reference_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.references_reference_id_seq OWNED BY public.references_reference.id;
          public          taiga    false    314            <           1259    3236265    settings_userprojectsettings    TABLE       CREATE TABLE public.settings_userprojectsettings (
    id bigint NOT NULL,
    homepage smallint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    modified_at timestamp with time zone NOT NULL,
    project_id bigint NOT NULL,
    user_id bigint NOT NULL
);
 0   DROP TABLE public.settings_userprojectsettings;
       public         heap    taiga    false            =           1259    3236295 #   settings_userprojectsettings_id_seq    SEQUENCE     �   CREATE SEQUENCE public.settings_userprojectsettings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 :   DROP SEQUENCE public.settings_userprojectsettings_id_seq;
       public          taiga    false    316            f           0    0 #   settings_userprojectsettings_id_seq    SEQUENCE OWNED BY     k   ALTER SEQUENCE public.settings_userprojectsettings_id_seq OWNED BY public.settings_userprojectsettings.id;
          public          taiga    false    317            �            1259    3233154 
   tasks_task    TABLE     �  CREATE TABLE public.tasks_task (
    id bigint NOT NULL,
    tags text[],
    version integer NOT NULL,
    is_blocked boolean NOT NULL,
    blocked_note text NOT NULL,
    ref bigint,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    finished_date timestamp with time zone,
    subject text NOT NULL,
    description text NOT NULL,
    is_iocaine boolean NOT NULL,
    assigned_to_id bigint,
    milestone_id bigint,
    owner_id bigint,
    project_id bigint NOT NULL,
    status_id bigint,
    user_story_id bigint,
    taskboard_order bigint NOT NULL,
    us_order bigint NOT NULL,
    external_reference text[],
    due_date date,
    due_date_reason text NOT NULL
);
    DROP TABLE public.tasks_task;
       public         heap    taiga    false            >           1259    3236344    tasks_task_id_seq    SEQUENCE     z   CREATE SEQUENCE public.tasks_task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.tasks_task_id_seq;
       public          taiga    false    239            g           0    0    tasks_task_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.tasks_task_id_seq OWNED BY public.tasks_task.id;
          public          taiga    false    318            ?           1259    3236366    telemetry_instancetelemetry    TABLE     �   CREATE TABLE public.telemetry_instancetelemetry (
    id bigint NOT NULL,
    instance_id character varying(100) NOT NULL,
    created_at timestamp with time zone NOT NULL
);
 /   DROP TABLE public.telemetry_instancetelemetry;
       public         heap    taiga    false            @           1259    3236379 "   telemetry_instancetelemetry_id_seq    SEQUENCE     �   CREATE SEQUENCE public.telemetry_instancetelemetry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 9   DROP SEQUENCE public.telemetry_instancetelemetry_id_seq;
       public          taiga    false    319            h           0    0 "   telemetry_instancetelemetry_id_seq    SEQUENCE OWNED BY     i   ALTER SEQUENCE public.telemetry_instancetelemetry_id_seq OWNED BY public.telemetry_instancetelemetry.id;
          public          taiga    false    320            �            1259    3233324    timeline_timeline    TABLE     �  CREATE TABLE public.timeline_timeline (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    namespace character varying(250) NOT NULL,
    event_type character varying(250) NOT NULL,
    project_id bigint,
    data jsonb NOT NULL,
    data_content_type_id integer NOT NULL,
    created timestamp with time zone NOT NULL,
    content_type_id integer NOT NULL,
    CONSTRAINT timeline_timeline_object_id_check CHECK ((object_id >= 0))
);
 %   DROP TABLE public.timeline_timeline;
       public         heap    taiga    false            A           1259    3236422    timeline_timeline_id_seq    SEQUENCE     �   CREATE SEQUENCE public.timeline_timeline_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.timeline_timeline_id_seq;
       public          taiga    false    242            i           0    0    timeline_timeline_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.timeline_timeline_id_seq OWNED BY public.timeline_timeline.id;
          public          taiga    false    321            E           1259    3236440    token_denylist_denylistedtoken    TABLE     �   CREATE TABLE public.token_denylist_denylistedtoken (
    id bigint NOT NULL,
    denylisted_at timestamp with time zone NOT NULL,
    token_id bigint NOT NULL
);
 2   DROP TABLE public.token_denylist_denylistedtoken;
       public         heap    taiga    false            D           1259    3236438 %   token_denylist_denylistedtoken_id_seq    SEQUENCE     �   CREATE SEQUENCE public.token_denylist_denylistedtoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.token_denylist_denylistedtoken_id_seq;
       public          taiga    false    325            j           0    0 %   token_denylist_denylistedtoken_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.token_denylist_denylistedtoken_id_seq OWNED BY public.token_denylist_denylistedtoken.id;
          public          taiga    false    324            C           1259    3236427    token_denylist_outstandingtoken    TABLE       CREATE TABLE public.token_denylist_outstandingtoken (
    id bigint NOT NULL,
    jti character varying(255) NOT NULL,
    token text NOT NULL,
    created_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    user_id bigint
);
 3   DROP TABLE public.token_denylist_outstandingtoken;
       public         heap    taiga    false            B           1259    3236425 &   token_denylist_outstandingtoken_id_seq    SEQUENCE     �   CREATE SEQUENCE public.token_denylist_outstandingtoken_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 =   DROP SEQUENCE public.token_denylist_outstandingtoken_id_seq;
       public          taiga    false    323            k           0    0 &   token_denylist_outstandingtoken_id_seq    SEQUENCE OWNED BY     q   ALTER SEQUENCE public.token_denylist_outstandingtoken_id_seq OWNED BY public.token_denylist_outstandingtoken.id;
          public          taiga    false    322            �            1259    3233231    users_authdata    TABLE     �   CREATE TABLE public.users_authdata (
    id bigint NOT NULL,
    key character varying(50) NOT NULL,
    value character varying(300) NOT NULL,
    extra jsonb NOT NULL,
    user_id bigint NOT NULL
);
 "   DROP TABLE public.users_authdata;
       public         heap    taiga    false            G           1259    3236517    users_authdata_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.users_authdata_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.users_authdata_id_seq;
       public          taiga    false    240            l           0    0    users_authdata_id_seq    SEQUENCE OWNED BY     O   ALTER SEQUENCE public.users_authdata_id_seq OWNED BY public.users_authdata.id;
          public          taiga    false    327            �            1259    3232386 
   users_role    TABLE       CREATE TABLE public.users_role (
    id bigint NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" integer NOT NULL,
    computable boolean NOT NULL,
    project_id bigint,
    is_admin boolean NOT NULL
);
    DROP TABLE public.users_role;
       public         heap    taiga    false            H           1259    3236534    users_role_id_seq    SEQUENCE     z   CREATE SEQUENCE public.users_role_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.users_role_id_seq;
       public          taiga    false    209            m           0    0    users_role_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.users_role_id_seq OWNED BY public.users_role.id;
          public          taiga    false    328            �            1259    3232348 
   users_user    TABLE     �  CREATE TABLE public.users_user (
    id bigint NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    is_active boolean NOT NULL,
    full_name character varying(256) NOT NULL,
    color character varying(9) NOT NULL,
    bio text NOT NULL,
    photo character varying(500),
    date_joined timestamp with time zone NOT NULL,
    lang character varying(20),
    timezone character varying(20),
    colorize_tags boolean NOT NULL,
    token character varying(200),
    email_token character varying(200),
    new_email character varying(254),
    is_system boolean NOT NULL,
    theme character varying(100),
    max_private_projects integer,
    max_public_projects integer,
    max_memberships_private_projects integer,
    max_memberships_public_projects integer,
    uuid character varying(32) NOT NULL,
    accepted_terms boolean NOT NULL,
    read_new_terms boolean NOT NULL,
    verified_email boolean NOT NULL,
    is_staff boolean NOT NULL,
    date_cancelled timestamp with time zone
);
    DROP TABLE public.users_user;
       public         heap    taiga    false            I           1259    3236589    users_user_id_seq    SEQUENCE     z   CREATE SEQUENCE public.users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.users_user_id_seq;
       public          taiga    false    206            n           0    0    users_user_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users_user.id;
          public          taiga    false    329            F           1259    3236484    users_workspacerole    TABLE       CREATE TABLE public.users_workspacerole (
    id bigint NOT NULL,
    name character varying(200) NOT NULL,
    slug character varying(250) NOT NULL,
    permissions text[],
    "order" integer NOT NULL,
    is_admin boolean NOT NULL,
    workspace_id bigint NOT NULL
);
 '   DROP TABLE public.users_workspacerole;
       public         heap    taiga    false            J           1259    3237110    users_workspacerole_id_seq    SEQUENCE     �   CREATE SEQUENCE public.users_workspacerole_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.users_workspacerole_id_seq;
       public          taiga    false    326            o           0    0    users_workspacerole_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.users_workspacerole_id_seq OWNED BY public.users_workspacerole.id;
          public          taiga    false    330            K           1259    3237115    userstorage_storageentry    TABLE     
  CREATE TABLE public.userstorage_storageentry (
    id bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    key character varying(255) NOT NULL,
    value jsonb,
    owner_id bigint NOT NULL
);
 ,   DROP TABLE public.userstorage_storageentry;
       public         heap    taiga    false            L           1259    3237153    userstorage_storageentry_id_seq    SEQUENCE     �   CREATE SEQUENCE public.userstorage_storageentry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.userstorage_storageentry_id_seq;
       public          taiga    false    331            p           0    0    userstorage_storageentry_id_seq    SEQUENCE OWNED BY     c   ALTER SEQUENCE public.userstorage_storageentry_id_seq OWNED BY public.userstorage_storageentry.id;
          public          taiga    false    332            �            1259    3232885    userstories_rolepoints    TABLE     �   CREATE TABLE public.userstories_rolepoints (
    id bigint NOT NULL,
    points_id bigint,
    role_id bigint NOT NULL,
    user_story_id bigint NOT NULL
);
 *   DROP TABLE public.userstories_rolepoints;
       public         heap    taiga    false            O           1259    3237244    userstories_rolepoints_id_seq    SEQUENCE     �   CREATE SEQUENCE public.userstories_rolepoints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.userstories_rolepoints_id_seq;
       public          taiga    false    230            q           0    0    userstories_rolepoints_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.userstories_rolepoints_id_seq OWNED BY public.userstories_rolepoints.id;
          public          taiga    false    335            �            1259    3232893    userstories_userstory    TABLE     �  CREATE TABLE public.userstories_userstory (
    id bigint NOT NULL,
    tags text[],
    version integer NOT NULL,
    is_blocked boolean NOT NULL,
    blocked_note text NOT NULL,
    ref bigint,
    is_closed boolean NOT NULL,
    backlog_order bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    finish_date timestamp with time zone,
    subject text NOT NULL,
    description text NOT NULL,
    client_requirement boolean NOT NULL,
    team_requirement boolean NOT NULL,
    assigned_to_id bigint,
    generated_from_issue_id bigint,
    milestone_id bigint,
    owner_id bigint,
    project_id bigint NOT NULL,
    status_id bigint,
    sprint_order bigint NOT NULL,
    kanban_order bigint NOT NULL,
    external_reference text[],
    tribe_gig text,
    due_date date,
    due_date_reason text NOT NULL,
    generated_from_task_id bigint,
    from_task_ref text,
    swimlane_id bigint
);
 )   DROP TABLE public.userstories_userstory;
       public         heap    taiga    false            N           1259    3237201 $   userstories_userstory_assigned_users    TABLE     �   CREATE TABLE public.userstories_userstory_assigned_users (
    id bigint NOT NULL,
    userstory_id bigint NOT NULL,
    user_id bigint NOT NULL
);
 8   DROP TABLE public.userstories_userstory_assigned_users;
       public         heap    taiga    false            M           1259    3237199 +   userstories_userstory_assigned_users_id_seq    SEQUENCE     �   CREATE SEQUENCE public.userstories_userstory_assigned_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 B   DROP SEQUENCE public.userstories_userstory_assigned_users_id_seq;
       public          taiga    false    334            r           0    0 +   userstories_userstory_assigned_users_id_seq    SEQUENCE OWNED BY     {   ALTER SEQUENCE public.userstories_userstory_assigned_users_id_seq OWNED BY public.userstories_userstory_assigned_users.id;
          public          taiga    false    333            P           1259    3237266    userstories_userstory_id_seq    SEQUENCE     �   CREATE SEQUENCE public.userstories_userstory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.userstories_userstory_id_seq;
       public          taiga    false    231            s           0    0    userstories_userstory_id_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.userstories_userstory_id_seq OWNED BY public.userstories_userstory.id;
          public          taiga    false    336            Q           1259    3237349 
   votes_vote    TABLE       CREATE TABLE public.votes_vote (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    content_type_id integer NOT NULL,
    user_id bigint NOT NULL,
    created_date timestamp with time zone NOT NULL,
    CONSTRAINT votes_vote_object_id_check CHECK ((object_id >= 0))
);
    DROP TABLE public.votes_vote;
       public         heap    taiga    false            S           1259    3237399    votes_vote_id_seq    SEQUENCE     z   CREATE SEQUENCE public.votes_vote_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.votes_vote_id_seq;
       public          taiga    false    337            t           0    0    votes_vote_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.votes_vote_id_seq OWNED BY public.votes_vote.id;
          public          taiga    false    339            R           1259    3237358    votes_votes    TABLE        CREATE TABLE public.votes_votes (
    id bigint NOT NULL,
    object_id integer NOT NULL,
    count integer NOT NULL,
    content_type_id integer NOT NULL,
    CONSTRAINT votes_votes_count_check CHECK ((count >= 0)),
    CONSTRAINT votes_votes_object_id_check CHECK ((object_id >= 0))
);
    DROP TABLE public.votes_votes;
       public         heap    taiga    false            T           1259    3237411    votes_votes_id_seq    SEQUENCE     {   CREATE SEQUENCE public.votes_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.votes_votes_id_seq;
       public          taiga    false    338            u           0    0    votes_votes_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.votes_votes_id_seq OWNED BY public.votes_votes.id;
          public          taiga    false    340            U           1259    3237416    webhooks_webhook    TABLE     �   CREATE TABLE public.webhooks_webhook (
    id bigint NOT NULL,
    url character varying(200) NOT NULL,
    key text NOT NULL,
    project_id bigint NOT NULL,
    name character varying(250) NOT NULL
);
 $   DROP TABLE public.webhooks_webhook;
       public         heap    taiga    false            W           1259    3237472    webhooks_webhook_id_seq    SEQUENCE     �   CREATE SEQUENCE public.webhooks_webhook_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.webhooks_webhook_id_seq;
       public          taiga    false    341            v           0    0    webhooks_webhook_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.webhooks_webhook_id_seq OWNED BY public.webhooks_webhook.id;
          public          taiga    false    343            V           1259    3237427    webhooks_webhooklog    TABLE     �  CREATE TABLE public.webhooks_webhooklog (
    id bigint NOT NULL,
    url character varying(200) NOT NULL,
    status integer NOT NULL,
    request_data jsonb NOT NULL,
    response_data text NOT NULL,
    webhook_id bigint NOT NULL,
    created timestamp with time zone NOT NULL,
    duration double precision NOT NULL,
    request_headers jsonb NOT NULL,
    response_headers jsonb NOT NULL
);
 '   DROP TABLE public.webhooks_webhooklog;
       public         heap    taiga    false            X           1259    3237500    webhooks_webhooklog_id_seq    SEQUENCE     �   CREATE SEQUENCE public.webhooks_webhooklog_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.webhooks_webhooklog_id_seq;
       public          taiga    false    342            w           0    0    webhooks_webhooklog_id_seq    SEQUENCE OWNED BY     Y   ALTER SEQUENCE public.webhooks_webhooklog_id_seq OWNED BY public.webhooks_webhooklog.id;
          public          taiga    false    344            �            1259    3233594    wiki_wikilink    TABLE     �   CREATE TABLE public.wiki_wikilink (
    id bigint NOT NULL,
    title character varying(500) NOT NULL,
    href character varying(500) NOT NULL,
    "order" bigint NOT NULL,
    project_id bigint NOT NULL
);
 !   DROP TABLE public.wiki_wikilink;
       public         heap    taiga    false            Y           1259    3237528    wiki_wikilink_id_seq    SEQUENCE     }   CREATE SEQUENCE public.wiki_wikilink_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.wiki_wikilink_id_seq;
       public          taiga    false    247            x           0    0    wiki_wikilink_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.wiki_wikilink_id_seq OWNED BY public.wiki_wikilink.id;
          public          taiga    false    345            �            1259    3233606    wiki_wikipage    TABLE     \  CREATE TABLE public.wiki_wikipage (
    id bigint NOT NULL,
    version integer NOT NULL,
    slug character varying(500) NOT NULL,
    content text NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    last_modifier_id bigint,
    owner_id bigint,
    project_id bigint NOT NULL
);
 !   DROP TABLE public.wiki_wikipage;
       public         heap    taiga    false            Z           1259    3237547    wiki_wikipage_id_seq    SEQUENCE     }   CREATE SEQUENCE public.wiki_wikipage_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.wiki_wikipage_id_seq;
       public          taiga    false    248            y           0    0    wiki_wikipage_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.wiki_wikipage_id_seq OWNED BY public.wiki_wikipage.id;
          public          taiga    false    346            "           1259    3234620    workspaces_workspace    TABLE     S  CREATE TABLE public.workspaces_workspace (
    id bigint NOT NULL,
    name character varying(40) NOT NULL,
    slug character varying(250),
    color integer NOT NULL,
    created_date timestamp with time zone NOT NULL,
    modified_date timestamp with time zone NOT NULL,
    owner_id bigint NOT NULL,
    is_premium boolean NOT NULL
);
 (   DROP TABLE public.workspaces_workspace;
       public         heap    taiga    false            \           1259    3237591    workspaces_workspace_id_seq    SEQUENCE     �   CREATE SEQUENCE public.workspaces_workspace_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.workspaces_workspace_id_seq;
       public          taiga    false    290            z           0    0    workspaces_workspace_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.workspaces_workspace_id_seq OWNED BY public.workspaces_workspace.id;
          public          taiga    false    348            [           1259    3237552    workspaces_workspacemembership    TABLE     �   CREATE TABLE public.workspaces_workspacemembership (
    id bigint NOT NULL,
    user_id bigint,
    workspace_id bigint NOT NULL,
    workspace_role_id bigint NOT NULL
);
 2   DROP TABLE public.workspaces_workspacemembership;
       public         heap    taiga    false            ]           1259    3237686 %   workspaces_workspacemembership_id_seq    SEQUENCE     �   CREATE SEQUENCE public.workspaces_workspacemembership_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.workspaces_workspacemembership_id_seq;
       public          taiga    false    347            {           0    0 %   workspaces_workspacemembership_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.workspaces_workspacemembership_id_seq OWNED BY public.workspaces_workspacemembership.id;
          public          taiga    false    349            :           2604    3232681    attachments_attachment id    DEFAULT     �   ALTER TABLE ONLY public.attachments_attachment ALTER COLUMN id SET DEFAULT nextval('public.attachments_attachment_id_seq'::regclass);
 H   ALTER TABLE public.attachments_attachment ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    221    220            =           2604    3232695    auth_group id    DEFAULT     n   ALTER TABLE ONLY public.auth_group ALTER COLUMN id SET DEFAULT nextval('public.auth_group_id_seq'::regclass);
 <   ALTER TABLE public.auth_group ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    224    225    225            >           2604    3232705    auth_group_permissions id    DEFAULT     �   ALTER TABLE ONLY public.auth_group_permissions ALTER COLUMN id SET DEFAULT nextval('public.auth_group_permissions_id_seq'::regclass);
 H   ALTER TABLE public.auth_group_permissions ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    227    226    227            <           2604    3232687    auth_permission id    DEFAULT     x   ALTER TABLE ONLY public.auth_permission ALTER COLUMN id SET DEFAULT nextval('public.auth_permission_id_seq'::regclass);
 A   ALTER TABLE public.auth_permission ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    223    222    223            R           2604    3233591    contact_contactentry id    DEFAULT     �   ALTER TABLE ONLY public.contact_contactentry ALTER COLUMN id SET DEFAULT nextval('public.contact_contactentry_id_seq'::regclass);
 F   ALTER TABLE public.contact_contactentry ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    246    245            ]           2604    3234031 (   custom_attributes_epiccustomattribute id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_epiccustomattribute_id_seq'::regclass);
 W   ALTER TABLE public.custom_attributes_epiccustomattribute ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    260    258            ^           2604    3234046 /   custom_attributes_epiccustomattributesvalues id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_epiccustomattributesvalues_id_seq'::regclass);
 ^   ALTER TABLE public.custom_attributes_epiccustomattributesvalues ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    261    259            W           2604    3234061 )   custom_attributes_issuecustomattribute id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_issuecustomattribute_id_seq'::regclass);
 X   ALTER TABLE public.custom_attributes_issuecustomattribute ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    262    252            Z           2604    3234076 0   custom_attributes_issuecustomattributesvalues id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_issuecustomattributesvalues_id_seq'::regclass);
 _   ALTER TABLE public.custom_attributes_issuecustomattributesvalues ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    263    255            X           2604    3234091 (   custom_attributes_taskcustomattribute id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_taskcustomattribute_id_seq'::regclass);
 W   ALTER TABLE public.custom_attributes_taskcustomattribute ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    264    253            [           2604    3234106 /   custom_attributes_taskcustomattributesvalues id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_taskcustomattributesvalues_id_seq'::regclass);
 ^   ALTER TABLE public.custom_attributes_taskcustomattributesvalues ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    265    256            Y           2604    3234121 -   custom_attributes_userstorycustomattribute id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_userstorycustomattribute_id_seq'::regclass);
 \   ALTER TABLE public.custom_attributes_userstorycustomattribute ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    266    254            \           2604    3234136 4   custom_attributes_userstorycustomattributesvalues id    DEFAULT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues ALTER COLUMN id SET DEFAULT nextval('public.custom_attributes_userstorycustomattributesvalues_id_seq'::regclass);
 c   ALTER TABLE public.custom_attributes_userstorycustomattributesvalues ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    267    257            %           2604    3232365    django_admin_log id    DEFAULT     z   ALTER TABLE ONLY public.django_admin_log ALTER COLUMN id SET DEFAULT nextval('public.django_admin_log_id_seq'::regclass);
 B   ALTER TABLE public.django_admin_log ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    207    208    208            #           2604    3232341    django_content_type id    DEFAULT     �   ALTER TABLE ONLY public.django_content_type ALTER COLUMN id SET DEFAULT nextval('public.django_content_type_id_seq'::regclass);
 E   ALTER TABLE public.django_content_type ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    204    205    205            "           2604    3232330    django_migrations id    DEFAULT     |   ALTER TABLE ONLY public.django_migrations ALTER COLUMN id SET DEFAULT nextval('public.django_migrations_id_seq'::regclass);
 C   ALTER TABLE public.django_migrations ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    202    203    203            _           2604    3234151    easy_thumbnails_source id    DEFAULT     �   ALTER TABLE ONLY public.easy_thumbnails_source ALTER COLUMN id SET DEFAULT nextval('public.easy_thumbnails_source_id_seq'::regclass);
 H   ALTER TABLE public.easy_thumbnails_source ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    270    269    270            `           2604    3234159    easy_thumbnails_thumbnail id    DEFAULT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail ALTER COLUMN id SET DEFAULT nextval('public.easy_thumbnails_thumbnail_id_seq'::regclass);
 K   ALTER TABLE public.easy_thumbnails_thumbnail ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    271    272    272            a           2604    3234185 &   easy_thumbnails_thumbnaildimensions id    DEFAULT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id SET DEFAULT nextval('public.easy_thumbnails_thumbnaildimensions_id_seq'::regclass);
 U   ALTER TABLE public.easy_thumbnails_thumbnaildimensions ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    274    273    274            U           2604    3234235    epics_epic id    DEFAULT     n   ALTER TABLE ONLY public.epics_epic ALTER COLUMN id SET DEFAULT nextval('public.epics_epic_id_seq'::regclass);
 <   ALTER TABLE public.epics_epic ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    275    250            V           2604    3234280    epics_relateduserstory id    DEFAULT     �   ALTER TABLE ONLY public.epics_relateduserstory ALTER COLUMN id SET DEFAULT nextval('public.epics_relateduserstory_id_seq'::regclass);
 H   ALTER TABLE public.epics_relateduserstory ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    276    251            d           2604    3234332 !   external_apps_applicationtoken id    DEFAULT     �   ALTER TABLE ONLY public.external_apps_applicationtoken ALTER COLUMN id SET DEFAULT nextval('public.external_apps_applicationtoken_id_seq'::regclass);
 P   ALTER TABLE public.external_apps_applicationtoken ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    279    278            e           2604    3234356    feedback_feedbackentry id    DEFAULT     �   ALTER TABLE ONLY public.feedback_feedbackentry ALTER COLUMN id SET DEFAULT nextval('public.feedback_feedbackentry_id_seq'::regclass);
 H   ALTER TABLE public.feedback_feedbackentry ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    281    280            A           2604    3234390    issues_issue id    DEFAULT     r   ALTER TABLE ONLY public.issues_issue ALTER COLUMN id SET DEFAULT nextval('public.issues_issue_id_seq'::regclass);
 >   ALTER TABLE public.issues_issue ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    282    229            O           2604    3234440    likes_like id    DEFAULT     n   ALTER TABLE ONLY public.likes_like ALTER COLUMN id SET DEFAULT nextval('public.likes_like_id_seq'::regclass);
 <   ALTER TABLE public.likes_like ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    283    243            ?           2604    3234458    milestones_milestone id    DEFAULT     �   ALTER TABLE ONLY public.milestones_milestone ALTER COLUMN id SET DEFAULT nextval('public.milestones_milestone_id_seq'::regclass);
 F   ALTER TABLE public.milestones_milestone ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    284    228            E           2604    3234554 *   notifications_historychangenotification id    DEFAULT     �   ALTER TABLE ONLY public.notifications_historychangenotification ALTER COLUMN id SET DEFAULT nextval('public.notifications_historychangenotification_id_seq'::regclass);
 Y   ALTER TABLE public.notifications_historychangenotification ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    286    233            F           2604    3233069 :   notifications_historychangenotification_history_entries id    DEFAULT     �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries ALTER COLUMN id SET DEFAULT nextval('public.notifications_historychangenotification_history_entries_id_seq'::regclass);
 i   ALTER TABLE public.notifications_historychangenotification_history_entries ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    235    234    235            G           2604    3233077 7   notifications_historychangenotification_notify_users id    DEFAULT     �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users ALTER COLUMN id SET DEFAULT nextval('public.notifications_historychangenotification_notify_users_id_seq'::regclass);
 f   ALTER TABLE public.notifications_historychangenotification_notify_users ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    236    237    237            D           2604    3234588    notifications_notifypolicy id    DEFAULT     �   ALTER TABLE ONLY public.notifications_notifypolicy ALTER COLUMN id SET DEFAULT nextval('public.notifications_notifypolicy_id_seq'::regclass);
 L   ALTER TABLE public.notifications_notifypolicy ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    287    232            H           2604    3234602    notifications_watched id    DEFAULT     �   ALTER TABLE ONLY public.notifications_watched ALTER COLUMN id SET DEFAULT nextval('public.notifications_watched_id_seq'::regclass);
 G   ALTER TABLE public.notifications_watched ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    288    238            f           2604    3234617     notifications_webnotification id    DEFAULT     �   ALTER TABLE ONLY public.notifications_webnotification ALTER COLUMN id SET DEFAULT nextval('public.notifications_webnotification_id_seq'::regclass);
 O   ALTER TABLE public.notifications_webnotification ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    289    285            Q           2604    3234764    projects_epicstatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_epicstatus ALTER COLUMN id SET DEFAULT nextval('public.projects_epicstatus_id_seq'::regclass);
 E   ALTER TABLE public.projects_epicstatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    296    244            i           2604    3234836    projects_issueduedate id    DEFAULT     �   ALTER TABLE ONLY public.projects_issueduedate ALTER COLUMN id SET DEFAULT nextval('public.projects_issueduedate_id_seq'::regclass);
 G   ALTER TABLE public.projects_issueduedate ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    297    291            2           2604    3234854    projects_issuestatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_issuestatus ALTER COLUMN id SET DEFAULT nextval('public.projects_issuestatus_id_seq'::regclass);
 F   ALTER TABLE public.projects_issuestatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    298    212            3           2604    3234930    projects_issuetype id    DEFAULT     ~   ALTER TABLE ONLY public.projects_issuetype ALTER COLUMN id SET DEFAULT nextval('public.projects_issuetype_id_seq'::regclass);
 D   ALTER TABLE public.projects_issuetype ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    299    213            (           2604    3235012    projects_membership id    DEFAULT     �   ALTER TABLE ONLY public.projects_membership ALTER COLUMN id SET DEFAULT nextval('public.projects_membership_id_seq'::regclass);
 E   ALTER TABLE public.projects_membership ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    300    210            4           2604    3235024    projects_points id    DEFAULT     x   ALTER TABLE ONLY public.projects_points ALTER COLUMN id SET DEFAULT nextval('public.projects_points_id_seq'::regclass);
 A   ALTER TABLE public.projects_points ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    301    214            5           2604    3235092    projects_priority id    DEFAULT     |   ALTER TABLE ONLY public.projects_priority ALTER COLUMN id SET DEFAULT nextval('public.projects_priority_id_seq'::regclass);
 C   ALTER TABLE public.projects_priority ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    302    215            )           2604    3235203    projects_project id    DEFAULT     z   ALTER TABLE ONLY public.projects_project ALTER COLUMN id SET DEFAULT nextval('public.projects_project_id_seq'::regclass);
 B   ALTER TABLE public.projects_project ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    303    211            L           2604    3235795     projects_projectmodulesconfig id    DEFAULT     �   ALTER TABLE ONLY public.projects_projectmodulesconfig ALTER COLUMN id SET DEFAULT nextval('public.projects_projectmodulesconfig_id_seq'::regclass);
 O   ALTER TABLE public.projects_projectmodulesconfig ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    304    241            6           2604    3235810    projects_projecttemplate id    DEFAULT     �   ALTER TABLE ONLY public.projects_projecttemplate ALTER COLUMN id SET DEFAULT nextval('public.projects_projecttemplate_id_seq'::regclass);
 J   ALTER TABLE public.projects_projecttemplate ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    305    216            7           2604    3235868    projects_severity id    DEFAULT     |   ALTER TABLE ONLY public.projects_severity ALTER COLUMN id SET DEFAULT nextval('public.projects_severity_id_seq'::regclass);
 C   ALTER TABLE public.projects_severity ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    306    217            l           2604    3235947    projects_swimlane id    DEFAULT     |   ALTER TABLE ONLY public.projects_swimlane ALTER COLUMN id SET DEFAULT nextval('public.projects_swimlane_id_seq'::regclass);
 C   ALTER TABLE public.projects_swimlane ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    307    294            m           2604    3236017 #   projects_swimlaneuserstorystatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus ALTER COLUMN id SET DEFAULT nextval('public.projects_swimlaneuserstorystatus_id_seq'::regclass);
 R   ALTER TABLE public.projects_swimlaneuserstorystatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    308    295            j           2604    3236029    projects_taskduedate id    DEFAULT     �   ALTER TABLE ONLY public.projects_taskduedate ALTER COLUMN id SET DEFAULT nextval('public.projects_taskduedate_id_seq'::regclass);
 F   ALTER TABLE public.projects_taskduedate ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    309    292            8           2604    3236047    projects_taskstatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_taskstatus ALTER COLUMN id SET DEFAULT nextval('public.projects_taskstatus_id_seq'::regclass);
 E   ALTER TABLE public.projects_taskstatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    310    218            k           2604    3236121    projects_userstoryduedate id    DEFAULT     �   ALTER TABLE ONLY public.projects_userstoryduedate ALTER COLUMN id SET DEFAULT nextval('public.projects_userstoryduedate_id_seq'::regclass);
 K   ALTER TABLE public.projects_userstoryduedate ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    311    293            9           2604    3236139    projects_userstorystatus id    DEFAULT     �   ALTER TABLE ONLY public.projects_userstorystatus ALTER COLUMN id SET DEFAULT nextval('public.projects_userstorystatus_id_seq'::regclass);
 J   ALTER TABLE public.projects_userstorystatus ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    312    219            n           2604    3236252    references_reference id    DEFAULT     �   ALTER TABLE ONLY public.references_reference ALTER COLUMN id SET DEFAULT nextval('public.references_reference_id_seq'::regclass);
 F   ALTER TABLE public.references_reference ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    314    313            p           2604    3236297    settings_userprojectsettings id    DEFAULT     �   ALTER TABLE ONLY public.settings_userprojectsettings ALTER COLUMN id SET DEFAULT nextval('public.settings_userprojectsettings_id_seq'::regclass);
 N   ALTER TABLE public.settings_userprojectsettings ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    317    316            J           2604    3236346    tasks_task id    DEFAULT     n   ALTER TABLE ONLY public.tasks_task ALTER COLUMN id SET DEFAULT nextval('public.tasks_task_id_seq'::regclass);
 <   ALTER TABLE public.tasks_task ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    318    239            q           2604    3236381    telemetry_instancetelemetry id    DEFAULT     �   ALTER TABLE ONLY public.telemetry_instancetelemetry ALTER COLUMN id SET DEFAULT nextval('public.telemetry_instancetelemetry_id_seq'::regclass);
 M   ALTER TABLE public.telemetry_instancetelemetry ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    320    319            M           2604    3236424    timeline_timeline id    DEFAULT     |   ALTER TABLE ONLY public.timeline_timeline ALTER COLUMN id SET DEFAULT nextval('public.timeline_timeline_id_seq'::regclass);
 C   ALTER TABLE public.timeline_timeline ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    321    242            s           2604    3236443 !   token_denylist_denylistedtoken id    DEFAULT     �   ALTER TABLE ONLY public.token_denylist_denylistedtoken ALTER COLUMN id SET DEFAULT nextval('public.token_denylist_denylistedtoken_id_seq'::regclass);
 P   ALTER TABLE public.token_denylist_denylistedtoken ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    324    325    325            r           2604    3236430 "   token_denylist_outstandingtoken id    DEFAULT     �   ALTER TABLE ONLY public.token_denylist_outstandingtoken ALTER COLUMN id SET DEFAULT nextval('public.token_denylist_outstandingtoken_id_seq'::regclass);
 Q   ALTER TABLE public.token_denylist_outstandingtoken ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    323    322    323            K           2604    3236519    users_authdata id    DEFAULT     v   ALTER TABLE ONLY public.users_authdata ALTER COLUMN id SET DEFAULT nextval('public.users_authdata_id_seq'::regclass);
 @   ALTER TABLE public.users_authdata ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    327    240            '           2604    3236536    users_role id    DEFAULT     n   ALTER TABLE ONLY public.users_role ALTER COLUMN id SET DEFAULT nextval('public.users_role_id_seq'::regclass);
 <   ALTER TABLE public.users_role ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    328    209            $           2604    3236591    users_user id    DEFAULT     n   ALTER TABLE ONLY public.users_user ALTER COLUMN id SET DEFAULT nextval('public.users_user_id_seq'::regclass);
 <   ALTER TABLE public.users_user ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    329    206            t           2604    3237112    users_workspacerole id    DEFAULT     �   ALTER TABLE ONLY public.users_workspacerole ALTER COLUMN id SET DEFAULT nextval('public.users_workspacerole_id_seq'::regclass);
 E   ALTER TABLE public.users_workspacerole ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    330    326            u           2604    3237155    userstorage_storageentry id    DEFAULT     �   ALTER TABLE ONLY public.userstorage_storageentry ALTER COLUMN id SET DEFAULT nextval('public.userstorage_storageentry_id_seq'::regclass);
 J   ALTER TABLE public.userstorage_storageentry ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    332    331            B           2604    3237246    userstories_rolepoints id    DEFAULT     �   ALTER TABLE ONLY public.userstories_rolepoints ALTER COLUMN id SET DEFAULT nextval('public.userstories_rolepoints_id_seq'::regclass);
 H   ALTER TABLE public.userstories_rolepoints ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    335    230            C           2604    3237268    userstories_userstory id    DEFAULT     �   ALTER TABLE ONLY public.userstories_userstory ALTER COLUMN id SET DEFAULT nextval('public.userstories_userstory_id_seq'::regclass);
 G   ALTER TABLE public.userstories_userstory ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    336    231            v           2604    3237204 '   userstories_userstory_assigned_users id    DEFAULT     �   ALTER TABLE ONLY public.userstories_userstory_assigned_users ALTER COLUMN id SET DEFAULT nextval('public.userstories_userstory_assigned_users_id_seq'::regclass);
 V   ALTER TABLE public.userstories_userstory_assigned_users ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    333    334    334            w           2604    3237401    votes_vote id    DEFAULT     n   ALTER TABLE ONLY public.votes_vote ALTER COLUMN id SET DEFAULT nextval('public.votes_vote_id_seq'::regclass);
 <   ALTER TABLE public.votes_vote ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    339    337            y           2604    3237413    votes_votes id    DEFAULT     p   ALTER TABLE ONLY public.votes_votes ALTER COLUMN id SET DEFAULT nextval('public.votes_votes_id_seq'::regclass);
 =   ALTER TABLE public.votes_votes ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    340    338            |           2604    3237474    webhooks_webhook id    DEFAULT     z   ALTER TABLE ONLY public.webhooks_webhook ALTER COLUMN id SET DEFAULT nextval('public.webhooks_webhook_id_seq'::regclass);
 B   ALTER TABLE public.webhooks_webhook ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    343    341            }           2604    3237502    webhooks_webhooklog id    DEFAULT     �   ALTER TABLE ONLY public.webhooks_webhooklog ALTER COLUMN id SET DEFAULT nextval('public.webhooks_webhooklog_id_seq'::regclass);
 E   ALTER TABLE public.webhooks_webhooklog ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    344    342            S           2604    3237530    wiki_wikilink id    DEFAULT     t   ALTER TABLE ONLY public.wiki_wikilink ALTER COLUMN id SET DEFAULT nextval('public.wiki_wikilink_id_seq'::regclass);
 ?   ALTER TABLE public.wiki_wikilink ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    345    247            T           2604    3237549    wiki_wikipage id    DEFAULT     t   ALTER TABLE ONLY public.wiki_wikipage ALTER COLUMN id SET DEFAULT nextval('public.wiki_wikipage_id_seq'::regclass);
 ?   ALTER TABLE public.wiki_wikipage ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    346    248            h           2604    3237593    workspaces_workspace id    DEFAULT     �   ALTER TABLE ONLY public.workspaces_workspace ALTER COLUMN id SET DEFAULT nextval('public.workspaces_workspace_id_seq'::regclass);
 F   ALTER TABLE public.workspaces_workspace ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    348    290            ~           2604    3237688 !   workspaces_workspacemembership id    DEFAULT     �   ALTER TABLE ONLY public.workspaces_workspacemembership ALTER COLUMN id SET DEFAULT nextval('public.workspaces_workspacemembership_id_seq'::regclass);
 P   ALTER TABLE public.workspaces_workspacemembership ALTER COLUMN id DROP DEFAULT;
       public          taiga    false    349    347                      0    3232633    attachments_attachment 
   TABLE DATA           �   COPY public.attachments_attachment (id, object_id, created_date, modified_date, attached_file, is_deprecated, description, "order", content_type_id, owner_id, project_id, name, size, sha1, from_comment) FROM stdin;
    public          taiga    false    220   ��      �          0    3232692 
   auth_group 
   TABLE DATA           .   COPY public.auth_group (id, name) FROM stdin;
    public          taiga    false    225   ��      �          0    3232702    auth_group_permissions 
   TABLE DATA           M   COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
    public          taiga    false    227   ��      �          0    3232684    auth_permission 
   TABLE DATA           N   COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
    public          taiga    false    223   ��      �          0    3233556    contact_contactentry 
   TABLE DATA           ^   COPY public.contact_contactentry (id, comment, created_date, project_id, user_id) FROM stdin;
    public          taiga    false    245   	�      �          0    3233907 %   custom_attributes_epiccustomattribute 
   TABLE DATA           �   COPY public.custom_attributes_epiccustomattribute (id, name, description, type, "order", created_date, modified_date, project_id, extra) FROM stdin;
    public          taiga    false    258   &�      �          0    3233918 ,   custom_attributes_epiccustomattributesvalues 
   TABLE DATA           o   COPY public.custom_attributes_epiccustomattributesvalues (id, version, attributes_values, epic_id) FROM stdin;
    public          taiga    false    259   C�      �          0    3233782 &   custom_attributes_issuecustomattribute 
   TABLE DATA           �   COPY public.custom_attributes_issuecustomattribute (id, name, description, "order", created_date, modified_date, project_id, type, extra) FROM stdin;
    public          taiga    false    252   `�      �          0    3233839 -   custom_attributes_issuecustomattributesvalues 
   TABLE DATA           q   COPY public.custom_attributes_issuecustomattributesvalues (id, version, attributes_values, issue_id) FROM stdin;
    public          taiga    false    255   }�      �          0    3233793 %   custom_attributes_taskcustomattribute 
   TABLE DATA           �   COPY public.custom_attributes_taskcustomattribute (id, name, description, "order", created_date, modified_date, project_id, type, extra) FROM stdin;
    public          taiga    false    253   ��      �          0    3233852 ,   custom_attributes_taskcustomattributesvalues 
   TABLE DATA           o   COPY public.custom_attributes_taskcustomattributesvalues (id, version, attributes_values, task_id) FROM stdin;
    public          taiga    false    256   ��      �          0    3233804 *   custom_attributes_userstorycustomattribute 
   TABLE DATA           �   COPY public.custom_attributes_userstorycustomattribute (id, name, description, "order", created_date, modified_date, project_id, type, extra) FROM stdin;
    public          taiga    false    254   ��      �          0    3233865 1   custom_attributes_userstorycustomattributesvalues 
   TABLE DATA           z   COPY public.custom_attributes_userstorycustomattributesvalues (id, version, attributes_values, user_story_id) FROM stdin;
    public          taiga    false    257   ��      s          0    3232362    django_admin_log 
   TABLE DATA           �   COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
    public          taiga    false    208   �      p          0    3232338    django_content_type 
   TABLE DATA           C   COPY public.django_content_type (id, app_label, model) FROM stdin;
    public          taiga    false    205   +�      n          0    3232327    django_migrations 
   TABLE DATA           C   COPY public.django_migrations (id, app, name, applied) FROM stdin;
    public          taiga    false    203   ��      �          0    3236253    django_session 
   TABLE DATA           P   COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
    public          taiga    false    315   �      �          0    3234137    djmail_message 
   TABLE DATA           �   COPY public.djmail_message (uuid, from_email, to_email, body_text, body_html, subject, data, retry_count, status, priority, created_at, sent_at, exception) FROM stdin;
    public          taiga    false    268   �      �          0    3234148    easy_thumbnails_source 
   TABLE DATA           R   COPY public.easy_thumbnails_source (id, storage_hash, name, modified) FROM stdin;
    public          taiga    false    270         �          0    3234156    easy_thumbnails_thumbnail 
   TABLE DATA           `   COPY public.easy_thumbnails_thumbnail (id, storage_hash, name, modified, source_id) FROM stdin;
    public          taiga    false    272   #      �          0    3234182 #   easy_thumbnails_thumbnaildimensions 
   TABLE DATA           ^   COPY public.easy_thumbnails_thumbnaildimensions (id, thumbnail_id, width, height) FROM stdin;
    public          taiga    false    274   @      �          0    3233723 
   epics_epic 
   TABLE DATA             COPY public.epics_epic (id, tags, version, is_blocked, blocked_note, ref, epics_order, created_date, modified_date, subject, description, client_requirement, team_requirement, assigned_to_id, owner_id, project_id, status_id, color, external_reference) FROM stdin;
    public          taiga    false    250   ]      �          0    3233734    epics_relateduserstory 
   TABLE DATA           U   COPY public.epics_relateduserstory (id, "order", epic_id, user_story_id) FROM stdin;
    public          taiga    false    251   z      �          0    3234281    external_apps_application 
   TABLE DATA           c   COPY public.external_apps_application (id, name, icon_url, web, description, next_url) FROM stdin;
    public          taiga    false    277   �      �          0    3234291    external_apps_applicationtoken 
   TABLE DATA           n   COPY public.external_apps_applicationtoken (id, auth_code, token, state, application_id, user_id) FROM stdin;
    public          taiga    false    278   �      �          0    3234335    feedback_feedbackentry 
   TABLE DATA           ]   COPY public.feedback_feedbackentry (id, full_name, email, comment, created_date) FROM stdin;
    public          taiga    false    280   �      �          0    3233685    history_historyentry 
   TABLE DATA             COPY public.history_historyentry (id, "user", created_at, type, is_snapshot, key, diff, snapshot, "values", comment, comment_html, delete_comment_date, delete_comment_user, is_hidden, comment_versions, edit_comment_date, project_id, values_diff_cache) FROM stdin;
    public          taiga    false    249   �      �          0    3232803    issues_issue 
   TABLE DATA           +  COPY public.issues_issue (id, tags, version, is_blocked, blocked_note, ref, created_date, modified_date, finished_date, subject, description, assigned_to_id, milestone_id, owner_id, priority_id, project_id, severity_id, status_id, type_id, external_reference, due_date, due_date_reason) FROM stdin;
    public          taiga    false    229         �          0    3233374 
   likes_like 
   TABLE DATA           [   COPY public.likes_like (id, object_id, created_date, content_type_id, user_id) FROM stdin;
    public          taiga    false    243   (      �          0    3232752    milestones_milestone 
   TABLE DATA           �   COPY public.milestones_milestone (id, name, slug, estimated_start, estimated_finish, created_date, modified_date, closed, disponibility, "order", owner_id, project_id) FROM stdin;
    public          taiga    false    228   E      �          0    3233058 '   notifications_historychangenotification 
   TABLE DATA           �   COPY public.notifications_historychangenotification (id, key, created_datetime, updated_datetime, history_type, owner_id, project_id) FROM stdin;
    public          taiga    false    233   b      �          0    3233066 7   notifications_historychangenotification_history_entries 
   TABLE DATA           �   COPY public.notifications_historychangenotification_history_entries (id, historychangenotification_id, historyentry_id) FROM stdin;
    public          taiga    false    235         �          0    3233074 4   notifications_historychangenotification_notify_users 
   TABLE DATA           y   COPY public.notifications_historychangenotification_notify_users (id, historychangenotification_id, user_id) FROM stdin;
    public          taiga    false    237   �      �          0    3233015    notifications_notifypolicy 
   TABLE DATA           �   COPY public.notifications_notifypolicy (id, notify_level, created_at, modified_at, project_id, user_id, live_notify_level, web_notify_level) FROM stdin;
    public          taiga    false    232   �      �          0    3233125    notifications_watched 
   TABLE DATA           r   COPY public.notifications_watched (id, object_id, created_date, content_type_id, user_id, project_id) FROM stdin;
    public          taiga    false    238   �      �          0    3234524    notifications_webnotification 
   TABLE DATA           e   COPY public.notifications_webnotification (id, created, read, event_type, data, user_id) FROM stdin;
    public          taiga    false    285   �      �          0    3233481    projects_epicstatus 
   TABLE DATA           d   COPY public.projects_epicstatus (id, name, slug, "order", is_closed, color, project_id) FROM stdin;
    public          taiga    false    244   �      �          0    3234643    projects_issueduedate 
   TABLE DATA           n   COPY public.projects_issueduedate (id, name, "order", by_default, color, days_to_due, project_id) FROM stdin;
    public          taiga    false    291   �      w          0    3232452    projects_issuestatus 
   TABLE DATA           e   COPY public.projects_issuestatus (id, name, "order", is_closed, color, project_id, slug) FROM stdin;
    public          taiga    false    212   �      x          0    3232460    projects_issuetype 
   TABLE DATA           R   COPY public.projects_issuetype (id, name, "order", color, project_id) FROM stdin;
    public          taiga    false    213   V'      u          0    3232399    projects_membership 
   TABLE DATA           �   COPY public.projects_membership (id, is_admin, email, created_at, token, user_id, project_id, role_id, invited_by_id, invitation_extra_text, user_order) FROM stdin;
    public          taiga    false    210   �)      y          0    3232468    projects_points 
   TABLE DATA           O   COPY public.projects_points (id, name, "order", value, project_id) FROM stdin;
    public          taiga    false    214   _2      z          0    3232476    projects_priority 
   TABLE DATA           Q   COPY public.projects_priority (id, name, "order", color, project_id) FROM stdin;
    public          taiga    false    215   9      v          0    3232407    projects_project 
   TABLE DATA             COPY public.projects_project (id, tags, name, slug, description, created_date, modified_date, total_milestones, total_story_points, is_backlog_activated, is_kanban_activated, is_wiki_activated, is_issues_activated, videoconferences, videoconferences_extra_data, anon_permissions, public_permissions, is_private, tags_colors, owner_id, creation_template_id, default_issue_status_id, default_issue_type_id, default_points_id, default_priority_id, default_severity_id, default_task_status_id, default_us_status_id, issues_csv_uuid, tasks_csv_uuid, userstories_csv_uuid, is_featured, is_looking_for_people, total_activity, total_activity_last_month, total_activity_last_week, total_activity_last_year, total_fans, total_fans_last_month, total_fans_last_week, total_fans_last_year, totals_updated_datetime, logo, looking_for_people_note, blocked_code, transfer_token, is_epics_activated, default_epic_status_id, epics_csv_uuid, is_contact_activated, default_swimlane_id, workspace_id, color, workspace_member_permissions) FROM stdin;
    public          taiga    false    211   7;      �          0    3233299    projects_projectmodulesconfig 
   TABLE DATA           O   COPY public.projects_projectmodulesconfig (id, config, project_id) FROM stdin;
    public          taiga    false    241   �R      {          0    3232484    projects_projecttemplate 
   TABLE DATA           �  COPY public.projects_projecttemplate (id, name, slug, description, created_date, modified_date, default_owner_role, is_backlog_activated, is_kanban_activated, is_wiki_activated, is_issues_activated, videoconferences, videoconferences_extra_data, default_options, us_statuses, points, task_statuses, issue_statuses, issue_types, priorities, severities, roles, "order", epic_statuses, is_epics_activated, is_contact_activated, epic_custom_attributes, is_looking_for_people, issue_custom_attributes, looking_for_people_note, tags, tags_colors, task_custom_attributes, us_custom_attributes, issue_duedates, task_duedates, us_duedates) FROM stdin;
    public          taiga    false    216   �R      |          0    3232497    projects_severity 
   TABLE DATA           Q   COPY public.projects_severity (id, name, "order", color, project_id) FROM stdin;
    public          taiga    false    217   �X      �          0    3234693    projects_swimlane 
   TABLE DATA           J   COPY public.projects_swimlane (id, name, "order", project_id) FROM stdin;
    public          taiga    false    294   �[      �          0    3234710     projects_swimlaneuserstorystatus 
   TABLE DATA           a   COPY public.projects_swimlaneuserstorystatus (id, wip_limit, status_id, swimlane_id) FROM stdin;
    public          taiga    false    295   �[      �          0    3234651    projects_taskduedate 
   TABLE DATA           m   COPY public.projects_taskduedate (id, name, "order", by_default, color, days_to_due, project_id) FROM stdin;
    public          taiga    false    292   �[      }          0    3232505    projects_taskstatus 
   TABLE DATA           d   COPY public.projects_taskstatus (id, name, "order", is_closed, color, project_id, slug) FROM stdin;
    public          taiga    false    218   ,^      �          0    3234659    projects_userstoryduedate 
   TABLE DATA           r   COPY public.projects_userstoryduedate (id, name, "order", by_default, color, days_to_due, project_id) FROM stdin;
    public          taiga    false    293   1c      ~          0    3232513    projects_userstorystatus 
   TABLE DATA           �   COPY public.projects_userstorystatus (id, name, "order", is_closed, color, wip_limit, project_id, slug, is_archived) FROM stdin;
    public          taiga    false    219   me      �          0    3236219    references_reference 
   TABLE DATA           k   COPY public.references_reference (id, object_id, ref, created_at, content_type_id, project_id) FROM stdin;
    public          taiga    false    313   �k      �          0    3236265    settings_userprojectsettings 
   TABLE DATA           r   COPY public.settings_userprojectsettings (id, homepage, created_at, modified_at, project_id, user_id) FROM stdin;
    public          taiga    false    316   �k      �          0    3233154 
   tasks_task 
   TABLE DATA           <  COPY public.tasks_task (id, tags, version, is_blocked, blocked_note, ref, created_date, modified_date, finished_date, subject, description, is_iocaine, assigned_to_id, milestone_id, owner_id, project_id, status_id, user_story_id, taskboard_order, us_order, external_reference, due_date, due_date_reason) FROM stdin;
    public          taiga    false    239   �k      �          0    3236366    telemetry_instancetelemetry 
   TABLE DATA           R   COPY public.telemetry_instancetelemetry (id, instance_id, created_at) FROM stdin;
    public          taiga    false    319   l      �          0    3233324    timeline_timeline 
   TABLE DATA           �   COPY public.timeline_timeline (id, object_id, namespace, event_type, project_id, data, data_content_type_id, created, content_type_id) FROM stdin;
    public          taiga    false    242   *l      �          0    3236440    token_denylist_denylistedtoken 
   TABLE DATA           U   COPY public.token_denylist_denylistedtoken (id, denylisted_at, token_id) FROM stdin;
    public          taiga    false    325   ��      �          0    3236427    token_denylist_outstandingtoken 
   TABLE DATA           j   COPY public.token_denylist_outstandingtoken (id, jti, token, created_at, expires_at, user_id) FROM stdin;
    public          taiga    false    323   ǁ      �          0    3233231    users_authdata 
   TABLE DATA           H   COPY public.users_authdata (id, key, value, extra, user_id) FROM stdin;
    public          taiga    false    240   �      t          0    3232386 
   users_role 
   TABLE DATA           l   COPY public.users_role (id, name, slug, permissions, "order", computable, project_id, is_admin) FROM stdin;
    public          taiga    false    209   �      q          0    3232348 
   users_user 
   TABLE DATA           �  COPY public.users_user (id, password, last_login, is_superuser, username, email, is_active, full_name, color, bio, photo, date_joined, lang, timezone, colorize_tags, token, email_token, new_email, is_system, theme, max_private_projects, max_public_projects, max_memberships_private_projects, max_memberships_public_projects, uuid, accepted_terms, read_new_terms, verified_email, is_staff, date_cancelled) FROM stdin;
    public          taiga    false    206   ބ      �          0    3236484    users_workspacerole 
   TABLE DATA           k   COPY public.users_workspacerole (id, name, slug, permissions, "order", is_admin, workspace_id) FROM stdin;
    public          taiga    false    326   �      �          0    3237115    userstorage_storageentry 
   TABLE DATA           i   COPY public.userstorage_storageentry (id, created_date, modified_date, key, value, owner_id) FROM stdin;
    public          taiga    false    331   ��      �          0    3232885    userstories_rolepoints 
   TABLE DATA           W   COPY public.userstories_rolepoints (id, points_id, role_id, user_story_id) FROM stdin;
    public          taiga    false    230   ��      �          0    3232893    userstories_userstory 
   TABLE DATA           �  COPY public.userstories_userstory (id, tags, version, is_blocked, blocked_note, ref, is_closed, backlog_order, created_date, modified_date, finish_date, subject, description, client_requirement, team_requirement, assigned_to_id, generated_from_issue_id, milestone_id, owner_id, project_id, status_id, sprint_order, kanban_order, external_reference, tribe_gig, due_date, due_date_reason, generated_from_task_id, from_task_ref, swimlane_id) FROM stdin;
    public          taiga    false    231   ܏      �          0    3237201 $   userstories_userstory_assigned_users 
   TABLE DATA           Y   COPY public.userstories_userstory_assigned_users (id, userstory_id, user_id) FROM stdin;
    public          taiga    false    334   ��      �          0    3237349 
   votes_vote 
   TABLE DATA           [   COPY public.votes_vote (id, object_id, content_type_id, user_id, created_date) FROM stdin;
    public          taiga    false    337   �      �          0    3237358    votes_votes 
   TABLE DATA           L   COPY public.votes_votes (id, object_id, count, content_type_id) FROM stdin;
    public          taiga    false    338   3�      �          0    3237416    webhooks_webhook 
   TABLE DATA           J   COPY public.webhooks_webhook (id, url, key, project_id, name) FROM stdin;
    public          taiga    false    341   P�      �          0    3237427    webhooks_webhooklog 
   TABLE DATA           �   COPY public.webhooks_webhooklog (id, url, status, request_data, response_data, webhook_id, created, duration, request_headers, response_headers) FROM stdin;
    public          taiga    false    342   m�      �          0    3233594    wiki_wikilink 
   TABLE DATA           M   COPY public.wiki_wikilink (id, title, href, "order", project_id) FROM stdin;
    public          taiga    false    247   ��      �          0    3233606    wiki_wikipage 
   TABLE DATA           �   COPY public.wiki_wikipage (id, version, slug, content, created_date, modified_date, last_modifier_id, owner_id, project_id) FROM stdin;
    public          taiga    false    248   ��      �          0    3234620    workspaces_workspace 
   TABLE DATA           x   COPY public.workspaces_workspace (id, name, slug, color, created_date, modified_date, owner_id, is_premium) FROM stdin;
    public          taiga    false    290   Đ      �          0    3237552    workspaces_workspacemembership 
   TABLE DATA           f   COPY public.workspaces_workspacemembership (id, user_id, workspace_id, workspace_role_id) FROM stdin;
    public          taiga    false    347   �      |           0    0    attachments_attachment_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.attachments_attachment_id_seq', 1, false);
          public          taiga    false    221            }           0    0    auth_group_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);
          public          taiga    false    224            ~           0    0    auth_group_permissions_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);
          public          taiga    false    226                       0    0    auth_permission_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.auth_permission_id_seq', 284, true);
          public          taiga    false    222            �           0    0    contact_contactentry_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.contact_contactentry_id_seq', 1, false);
          public          taiga    false    246            �           0    0 ,   custom_attributes_epiccustomattribute_id_seq    SEQUENCE SET     [   SELECT pg_catalog.setval('public.custom_attributes_epiccustomattribute_id_seq', 1, false);
          public          taiga    false    260            �           0    0 3   custom_attributes_epiccustomattributesvalues_id_seq    SEQUENCE SET     b   SELECT pg_catalog.setval('public.custom_attributes_epiccustomattributesvalues_id_seq', 1, false);
          public          taiga    false    261            �           0    0 -   custom_attributes_issuecustomattribute_id_seq    SEQUENCE SET     \   SELECT pg_catalog.setval('public.custom_attributes_issuecustomattribute_id_seq', 1, false);
          public          taiga    false    262            �           0    0 4   custom_attributes_issuecustomattributesvalues_id_seq    SEQUENCE SET     c   SELECT pg_catalog.setval('public.custom_attributes_issuecustomattributesvalues_id_seq', 1, false);
          public          taiga    false    263            �           0    0 ,   custom_attributes_taskcustomattribute_id_seq    SEQUENCE SET     [   SELECT pg_catalog.setval('public.custom_attributes_taskcustomattribute_id_seq', 1, false);
          public          taiga    false    264            �           0    0 3   custom_attributes_taskcustomattributesvalues_id_seq    SEQUENCE SET     b   SELECT pg_catalog.setval('public.custom_attributes_taskcustomattributesvalues_id_seq', 1, false);
          public          taiga    false    265            �           0    0 1   custom_attributes_userstorycustomattribute_id_seq    SEQUENCE SET     `   SELECT pg_catalog.setval('public.custom_attributes_userstorycustomattribute_id_seq', 1, false);
          public          taiga    false    266            �           0    0 8   custom_attributes_userstorycustomattributesvalues_id_seq    SEQUENCE SET     g   SELECT pg_catalog.setval('public.custom_attributes_userstorycustomattributesvalues_id_seq', 1, false);
          public          taiga    false    267            �           0    0    django_admin_log_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);
          public          taiga    false    207            �           0    0    django_content_type_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.django_content_type_id_seq', 71, true);
          public          taiga    false    204            �           0    0    django_migrations_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.django_migrations_id_seq', 306, true);
          public          taiga    false    202            �           0    0    easy_thumbnails_source_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.easy_thumbnails_source_id_seq', 1, false);
          public          taiga    false    269            �           0    0     easy_thumbnails_thumbnail_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnail_id_seq', 1, false);
          public          taiga    false    271            �           0    0 *   easy_thumbnails_thumbnaildimensions_id_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.easy_thumbnails_thumbnaildimensions_id_seq', 1, false);
          public          taiga    false    273            �           0    0    epics_epic_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.epics_epic_id_seq', 1, false);
          public          taiga    false    275            �           0    0    epics_relateduserstory_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.epics_relateduserstory_id_seq', 1, false);
          public          taiga    false    276            �           0    0 %   external_apps_applicationtoken_id_seq    SEQUENCE SET     T   SELECT pg_catalog.setval('public.external_apps_applicationtoken_id_seq', 1, false);
          public          taiga    false    279            �           0    0    feedback_feedbackentry_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.feedback_feedbackentry_id_seq', 1, false);
          public          taiga    false    281            �           0    0    issues_issue_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.issues_issue_id_seq', 1, false);
          public          taiga    false    282            �           0    0    likes_like_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.likes_like_id_seq', 1, false);
          public          taiga    false    283            �           0    0    milestones_milestone_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.milestones_milestone_id_seq', 1, false);
          public          taiga    false    284            �           0    0 >   notifications_historychangenotification_history_entries_id_seq    SEQUENCE SET     m   SELECT pg_catalog.setval('public.notifications_historychangenotification_history_entries_id_seq', 1, false);
          public          taiga    false    234            �           0    0 .   notifications_historychangenotification_id_seq    SEQUENCE SET     ]   SELECT pg_catalog.setval('public.notifications_historychangenotification_id_seq', 1, false);
          public          taiga    false    286            �           0    0 ;   notifications_historychangenotification_notify_users_id_seq    SEQUENCE SET     j   SELECT pg_catalog.setval('public.notifications_historychangenotification_notify_users_id_seq', 1, false);
          public          taiga    false    236            �           0    0 !   notifications_notifypolicy_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.notifications_notifypolicy_id_seq', 161, true);
          public          taiga    false    287            �           0    0    notifications_watched_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.notifications_watched_id_seq', 1, false);
          public          taiga    false    288            �           0    0 $   notifications_webnotification_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.notifications_webnotification_id_seq', 1, false);
          public          taiga    false    289            �           0    0    projects_epicstatus_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.projects_epicstatus_id_seq', 225, true);
          public          taiga    false    296            �           0    0    projects_issueduedate_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.projects_issueduedate_id_seq', 135, true);
          public          taiga    false    297            �           0    0    projects_issuestatus_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.projects_issuestatus_id_seq', 315, true);
          public          taiga    false    298            �           0    0    projects_issuetype_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.projects_issuetype_id_seq', 135, true);
          public          taiga    false    299            �           0    0    projects_membership_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.projects_membership_id_seq', 161, true);
          public          taiga    false    300            �           0    0    projects_points_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.projects_points_id_seq', 540, true);
          public          taiga    false    301            �           0    0    projects_priority_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.projects_priority_id_seq', 135, true);
          public          taiga    false    302            �           0    0    projects_project_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.projects_project_id_seq', 45, true);
          public          taiga    false    303            �           0    0 $   projects_projectmodulesconfig_id_seq    SEQUENCE SET     S   SELECT pg_catalog.setval('public.projects_projectmodulesconfig_id_seq', 1, false);
          public          taiga    false    304            �           0    0    projects_projecttemplate_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.projects_projecttemplate_id_seq', 2, true);
          public          taiga    false    305            �           0    0    projects_severity_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.projects_severity_id_seq', 225, true);
          public          taiga    false    306            �           0    0    projects_swimlane_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.projects_swimlane_id_seq', 1, false);
          public          taiga    false    307            �           0    0 '   projects_swimlaneuserstorystatus_id_seq    SEQUENCE SET     V   SELECT pg_catalog.setval('public.projects_swimlaneuserstorystatus_id_seq', 1, false);
          public          taiga    false    308            �           0    0    projects_taskduedate_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.projects_taskduedate_id_seq', 135, true);
          public          taiga    false    309            �           0    0    projects_taskstatus_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.projects_taskstatus_id_seq', 225, true);
          public          taiga    false    310            �           0    0     projects_userstoryduedate_id_seq    SEQUENCE SET     P   SELECT pg_catalog.setval('public.projects_userstoryduedate_id_seq', 135, true);
          public          taiga    false    311            �           0    0    projects_userstorystatus_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.projects_userstorystatus_id_seq', 270, true);
          public          taiga    false    312            �           0    0    references_project1    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project1', 1, false);
          public          taiga    false    350            �           0    0    references_project10    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project10', 1, false);
          public          taiga    false    359            �           0    0    references_project11    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project11', 1, false);
          public          taiga    false    360            �           0    0    references_project12    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project12', 1, false);
          public          taiga    false    361            �           0    0    references_project13    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project13', 1, false);
          public          taiga    false    362            �           0    0    references_project14    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project14', 1, false);
          public          taiga    false    363            �           0    0    references_project15    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project15', 1, false);
          public          taiga    false    364            �           0    0    references_project16    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project16', 1, false);
          public          taiga    false    365            �           0    0    references_project17    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project17', 1, false);
          public          taiga    false    366            �           0    0    references_project18    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project18', 1, false);
          public          taiga    false    367            �           0    0    references_project19    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project19', 1, false);
          public          taiga    false    368            �           0    0    references_project2    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project2', 1, false);
          public          taiga    false    351            �           0    0    references_project20    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project20', 1, false);
          public          taiga    false    369            �           0    0    references_project21    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project21', 1, false);
          public          taiga    false    370            �           0    0    references_project22    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project22', 1, false);
          public          taiga    false    371            �           0    0    references_project23    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project23', 1, false);
          public          taiga    false    372            �           0    0    references_project24    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project24', 1, false);
          public          taiga    false    373            �           0    0    references_project25    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project25', 1, false);
          public          taiga    false    374            �           0    0    references_project26    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project26', 1, false);
          public          taiga    false    375            �           0    0    references_project27    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project27', 1, false);
          public          taiga    false    376            �           0    0    references_project28    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project28', 1, false);
          public          taiga    false    377            �           0    0    references_project29    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project29', 1, false);
          public          taiga    false    378            �           0    0    references_project3    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project3', 1, false);
          public          taiga    false    352            �           0    0    references_project30    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project30', 1, false);
          public          taiga    false    379            �           0    0    references_project31    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project31', 1, false);
          public          taiga    false    380            �           0    0    references_project32    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project32', 1, false);
          public          taiga    false    381            �           0    0    references_project33    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project33', 1, false);
          public          taiga    false    382            �           0    0    references_project34    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project34', 1, false);
          public          taiga    false    383            �           0    0    references_project35    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project35', 1, false);
          public          taiga    false    384            �           0    0    references_project36    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project36', 1, false);
          public          taiga    false    385            �           0    0    references_project37    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project37', 1, false);
          public          taiga    false    386            �           0    0    references_project38    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project38', 1, false);
          public          taiga    false    387            �           0    0    references_project39    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project39', 1, false);
          public          taiga    false    388            �           0    0    references_project4    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project4', 1, false);
          public          taiga    false    353            �           0    0    references_project40    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project40', 1, false);
          public          taiga    false    389            �           0    0    references_project41    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project41', 1, false);
          public          taiga    false    390            �           0    0    references_project42    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project42', 1, false);
          public          taiga    false    391            �           0    0    references_project43    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project43', 1, false);
          public          taiga    false    392            �           0    0    references_project44    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project44', 1, false);
          public          taiga    false    393            �           0    0    references_project45    SEQUENCE SET     C   SELECT pg_catalog.setval('public.references_project45', 1, false);
          public          taiga    false    394            �           0    0    references_project5    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project5', 1, false);
          public          taiga    false    354            �           0    0    references_project6    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project6', 1, false);
          public          taiga    false    355            �           0    0    references_project7    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project7', 1, false);
          public          taiga    false    356            �           0    0    references_project8    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project8', 1, false);
          public          taiga    false    357            �           0    0    references_project9    SEQUENCE SET     B   SELECT pg_catalog.setval('public.references_project9', 1, false);
          public          taiga    false    358            �           0    0    references_reference_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.references_reference_id_seq', 1, false);
          public          taiga    false    314            �           0    0 #   settings_userprojectsettings_id_seq    SEQUENCE SET     R   SELECT pg_catalog.setval('public.settings_userprojectsettings_id_seq', 1, false);
          public          taiga    false    317            �           0    0    tasks_task_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.tasks_task_id_seq', 1, false);
          public          taiga    false    318            �           0    0 "   telemetry_instancetelemetry_id_seq    SEQUENCE SET     Q   SELECT pg_catalog.setval('public.telemetry_instancetelemetry_id_seq', 1, false);
          public          taiga    false    320            �           0    0    timeline_timeline_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.timeline_timeline_id_seq', 247, true);
          public          taiga    false    321            �           0    0 %   token_denylist_denylistedtoken_id_seq    SEQUENCE SET     T   SELECT pg_catalog.setval('public.token_denylist_denylistedtoken_id_seq', 1, false);
          public          taiga    false    324            �           0    0 &   token_denylist_outstandingtoken_id_seq    SEQUENCE SET     U   SELECT pg_catalog.setval('public.token_denylist_outstandingtoken_id_seq', 1, false);
          public          taiga    false    322            �           0    0    users_authdata_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.users_authdata_id_seq', 1, false);
          public          taiga    false    327            �           0    0    users_role_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.users_role_id_seq', 93, true);
          public          taiga    false    328            �           0    0    users_user_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.users_user_id_seq', 19, true);
          public          taiga    false    329            �           0    0    users_workspacerole_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.users_workspacerole_id_seq', 44, true);
          public          taiga    false    330            �           0    0    userstorage_storageentry_id_seq    SEQUENCE SET     N   SELECT pg_catalog.setval('public.userstorage_storageentry_id_seq', 1, false);
          public          taiga    false    332            �           0    0    userstories_rolepoints_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.userstories_rolepoints_id_seq', 1, false);
          public          taiga    false    335            �           0    0 +   userstories_userstory_assigned_users_id_seq    SEQUENCE SET     Z   SELECT pg_catalog.setval('public.userstories_userstory_assigned_users_id_seq', 1, false);
          public          taiga    false    333            �           0    0    userstories_userstory_id_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.userstories_userstory_id_seq', 1, false);
          public          taiga    false    336            �           0    0    votes_vote_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.votes_vote_id_seq', 1, false);
          public          taiga    false    339            �           0    0    votes_votes_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.votes_votes_id_seq', 1, false);
          public          taiga    false    340            �           0    0    webhooks_webhook_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.webhooks_webhook_id_seq', 1, false);
          public          taiga    false    343            �           0    0    webhooks_webhooklog_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.webhooks_webhooklog_id_seq', 1, false);
          public          taiga    false    344            �           0    0    wiki_wikilink_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.wiki_wikilink_id_seq', 1, false);
          public          taiga    false    345            �           0    0    wiki_wikipage_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.wiki_wikipage_id_seq', 1, false);
          public          taiga    false    346            �           0    0    workspaces_workspace_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.workspaces_workspace_id_seq', 28, true);
          public          taiga    false    348            �           0    0 %   workspaces_workspacemembership_id_seq    SEQUENCE SET     U   SELECT pg_catalog.setval('public.workspaces_workspacemembership_id_seq', 102, true);
          public          taiga    false    349            
           2606    3232667 2   attachments_attachment attachments_attachment_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.attachments_attachment
    ADD CONSTRAINT attachments_attachment_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.attachments_attachment DROP CONSTRAINT attachments_attachment_pkey;
       public            taiga    false    220                       2606    3232732    auth_group auth_group_name_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);
 H   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_name_key;
       public            taiga    false    225                       2606    3232718 R   auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);
 |   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq;
       public            taiga    false    227    227                       2606    3232707 2   auth_group_permissions auth_group_permissions_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_pkey;
       public            taiga    false    227                       2606    3232697    auth_group auth_group_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.auth_group DROP CONSTRAINT auth_group_pkey;
       public            taiga    false    225                       2606    3232709 F   auth_permission auth_permission_content_type_id_codename_01ab375a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);
 p   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq;
       public            taiga    false    223    223                       2606    3232689 $   auth_permission auth_permission_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_pkey;
       public            taiga    false    223            �           2606    3233579 .   contact_contactentry contact_contactentry_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.contact_contactentry
    ADD CONSTRAINT contact_contactentry_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.contact_contactentry DROP CONSTRAINT contact_contactentry_pkey;
       public            taiga    false    245            �           2606    3235587 \   custom_attributes_epiccustomattribute custom_attributes_epiccu_project_id_name_3850c31d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute
    ADD CONSTRAINT custom_attributes_epiccu_project_id_name_3850c31d_uniq UNIQUE (project_id, name);
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute DROP CONSTRAINT custom_attributes_epiccu_project_id_name_3850c31d_uniq;
       public            taiga    false    258    258            �           2606    3234019 P   custom_attributes_epiccustomattribute custom_attributes_epiccustomattribute_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute
    ADD CONSTRAINT custom_attributes_epiccustomattribute_pkey PRIMARY KEY (id);
 z   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute DROP CONSTRAINT custom_attributes_epiccustomattribute_pkey;
       public            taiga    false    258            �           2606    3234247 e   custom_attributes_epiccustomattributesvalues custom_attributes_epiccustomattributesvalues_epic_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues
    ADD CONSTRAINT custom_attributes_epiccustomattributesvalues_epic_id_key UNIQUE (epic_id);
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues DROP CONSTRAINT custom_attributes_epiccustomattributesvalues_epic_id_key;
       public            taiga    false    259            �           2606    3234034 ^   custom_attributes_epiccustomattributesvalues custom_attributes_epiccustomattributesvalues_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues
    ADD CONSTRAINT custom_attributes_epiccustomattributesvalues_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues DROP CONSTRAINT custom_attributes_epiccustomattributesvalues_pkey;
       public            taiga    false    259            �           2606    3235599 ]   custom_attributes_issuecustomattribute custom_attributes_issuec_project_id_name_6f71f010_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute
    ADD CONSTRAINT custom_attributes_issuec_project_id_name_6f71f010_uniq UNIQUE (project_id, name);
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute DROP CONSTRAINT custom_attributes_issuec_project_id_name_6f71f010_uniq;
       public            taiga    false    252    252            �           2606    3234049 R   custom_attributes_issuecustomattribute custom_attributes_issuecustomattribute_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute
    ADD CONSTRAINT custom_attributes_issuecustomattribute_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute DROP CONSTRAINT custom_attributes_issuecustomattribute_pkey;
       public            taiga    false    252            �           2606    3234407 h   custom_attributes_issuecustomattributesvalues custom_attributes_issuecustomattributesvalues_issue_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues
    ADD CONSTRAINT custom_attributes_issuecustomattributesvalues_issue_id_key UNIQUE (issue_id);
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues DROP CONSTRAINT custom_attributes_issuecustomattributesvalues_issue_id_key;
       public            taiga    false    255            �           2606    3234064 `   custom_attributes_issuecustomattributesvalues custom_attributes_issuecustomattributesvalues_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues
    ADD CONSTRAINT custom_attributes_issuecustomattributesvalues_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues DROP CONSTRAINT custom_attributes_issuecustomattributesvalues_pkey;
       public            taiga    false    255            �           2606    3235611 \   custom_attributes_taskcustomattribute custom_attributes_taskcu_project_id_name_c1c55ac2_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute
    ADD CONSTRAINT custom_attributes_taskcu_project_id_name_c1c55ac2_uniq UNIQUE (project_id, name);
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute DROP CONSTRAINT custom_attributes_taskcu_project_id_name_c1c55ac2_uniq;
       public            taiga    false    253    253            �           2606    3234079 P   custom_attributes_taskcustomattribute custom_attributes_taskcustomattribute_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute
    ADD CONSTRAINT custom_attributes_taskcustomattribute_pkey PRIMARY KEY (id);
 z   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute DROP CONSTRAINT custom_attributes_taskcustomattribute_pkey;
       public            taiga    false    253            �           2606    3234094 ^   custom_attributes_taskcustomattributesvalues custom_attributes_taskcustomattributesvalues_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues
    ADD CONSTRAINT custom_attributes_taskcustomattributesvalues_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues DROP CONSTRAINT custom_attributes_taskcustomattributesvalues_pkey;
       public            taiga    false    256            �           2606    3236348 e   custom_attributes_taskcustomattributesvalues custom_attributes_taskcustomattributesvalues_task_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues
    ADD CONSTRAINT custom_attributes_taskcustomattributesvalues_task_id_key UNIQUE (task_id);
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues DROP CONSTRAINT custom_attributes_taskcustomattributesvalues_task_id_key;
       public            taiga    false    256            �           2606    3235575 a   custom_attributes_userstorycustomattribute custom_attributes_userst_project_id_name_86c6b502_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute
    ADD CONSTRAINT custom_attributes_userst_project_id_name_86c6b502_uniq UNIQUE (project_id, name);
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute DROP CONSTRAINT custom_attributes_userst_project_id_name_86c6b502_uniq;
       public            taiga    false    254    254            �           2606    3234109 Z   custom_attributes_userstorycustomattribute custom_attributes_userstorycustomattribute_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute
    ADD CONSTRAINT custom_attributes_userstorycustomattribute_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute DROP CONSTRAINT custom_attributes_userstorycustomattribute_pkey;
       public            taiga    false    254            �           2606    3237316 q   custom_attributes_userstorycustomattributesvalues custom_attributes_userstorycustomattributesva_user_story_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues
    ADD CONSTRAINT custom_attributes_userstorycustomattributesva_user_story_id_key UNIQUE (user_story_id);
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues DROP CONSTRAINT custom_attributes_userstorycustomattributesva_user_story_id_key;
       public            taiga    false    257            �           2606    3234124 h   custom_attributes_userstorycustomattributesvalues custom_attributes_userstorycustomattributesvalues_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues
    ADD CONSTRAINT custom_attributes_userstorycustomattributesvalues_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues DROP CONSTRAINT custom_attributes_userstorycustomattributesvalues_pkey;
       public            taiga    false    257            �           2606    3232371 &   django_admin_log django_admin_log_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_pkey;
       public            taiga    false    208            �           2606    3232345 E   django_content_type django_content_type_app_label_model_76bd3d3b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);
 o   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq;
       public            taiga    false    205    205            �           2606    3232343 ,   django_content_type django_content_type_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.django_content_type DROP CONSTRAINT django_content_type_pkey;
       public            taiga    false    205            �           2606    3232335 (   django_migrations django_migrations_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.django_migrations DROP CONSTRAINT django_migrations_pkey;
       public            taiga    false    203            4           2606    3236260 "   django_session django_session_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);
 L   ALTER TABLE ONLY public.django_session DROP CONSTRAINT django_session_pkey;
       public            taiga    false    315            �           2606    3234144 "   djmail_message djmail_message_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.djmail_message
    ADD CONSTRAINT djmail_message_pkey PRIMARY KEY (uuid);
 L   ALTER TABLE ONLY public.djmail_message DROP CONSTRAINT djmail_message_pkey;
       public            taiga    false    268            �           2606    3234153 2   easy_thumbnails_source easy_thumbnails_source_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_pkey;
       public            taiga    false    270            �           2606    3234165 M   easy_thumbnails_source easy_thumbnails_source_storage_hash_name_481ce32d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_source
    ADD CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq UNIQUE (storage_hash, name);
 w   ALTER TABLE ONLY public.easy_thumbnails_source DROP CONSTRAINT easy_thumbnails_source_storage_hash_name_481ce32d_uniq;
       public            taiga    false    270    270            �           2606    3234163 Y   easy_thumbnails_thumbnail easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq UNIQUE (storage_hash, name, source_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnai_storage_hash_name_source_fb375270_uniq;
       public            taiga    false    272    272    272            �           2606    3234161 8   easy_thumbnails_thumbnail easy_thumbnails_thumbnail_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thumbnail_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thumbnail_pkey;
       public            taiga    false    272            �           2606    3234189 L   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey PRIMARY KEY (id);
 v   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_pkey;
       public            taiga    false    274            �           2606    3234191 X   easy_thumbnails_thumbnaildimensions easy_thumbnails_thumbnaildimensions_thumbnail_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key UNIQUE (thumbnail_id);
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thumbnaildimensions_thumbnail_id_key;
       public            taiga    false    274            �           2606    3234220    epics_epic epics_epic_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_pkey;
       public            taiga    false    250            �           2606    3234270 2   epics_relateduserstory epics_relateduserstory_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.epics_relateduserstory
    ADD CONSTRAINT epics_relateduserstory_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.epics_relateduserstory DROP CONSTRAINT epics_relateduserstory_pkey;
       public            taiga    false    251            �           2606    3237306 Q   epics_relateduserstory epics_relateduserstory_user_story_id_epic_id_ad704d40_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.epics_relateduserstory
    ADD CONSTRAINT epics_relateduserstory_user_story_id_epic_id_ad704d40_uniq UNIQUE (user_story_id, epic_id);
 {   ALTER TABLE ONLY public.epics_relateduserstory DROP CONSTRAINT epics_relateduserstory_user_story_id_epic_id_ad704d40_uniq;
       public            taiga    false    251    251            �           2606    3236928 \   external_apps_applicationtoken external_apps_applicatio_application_id_user_id_b6a9e9a8_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.external_apps_applicationtoken
    ADD CONSTRAINT external_apps_applicatio_application_id_user_id_b6a9e9a8_uniq UNIQUE (application_id, user_id);
 �   ALTER TABLE ONLY public.external_apps_applicationtoken DROP CONSTRAINT external_apps_applicatio_application_id_user_id_b6a9e9a8_uniq;
       public            taiga    false    278    278            �           2606    3234288 8   external_apps_application external_apps_application_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.external_apps_application
    ADD CONSTRAINT external_apps_application_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.external_apps_application DROP CONSTRAINT external_apps_application_pkey;
       public            taiga    false    277                       2606    3234318 B   external_apps_applicationtoken external_apps_applicationtoken_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.external_apps_applicationtoken
    ADD CONSTRAINT external_apps_applicationtoken_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.external_apps_applicationtoken DROP CONSTRAINT external_apps_applicationtoken_pkey;
       public            taiga    false    278                       2606    3234346 2   feedback_feedbackentry feedback_feedbackentry_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.feedback_feedbackentry
    ADD CONSTRAINT feedback_feedbackentry_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.feedback_feedbackentry DROP CONSTRAINT feedback_feedbackentry_pkey;
       public            taiga    false    280            �           2606    3233692 .   history_historyentry history_historyentry_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.history_historyentry
    ADD CONSTRAINT history_historyentry_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.history_historyentry DROP CONSTRAINT history_historyentry_pkey;
       public            taiga    false    249            ,           2606    3234371    issues_issue issues_issue_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_pkey;
       public            taiga    false    229            �           2606    3236854 E   likes_like likes_like_content_type_id_object_id_user_id_e20903f0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.likes_like
    ADD CONSTRAINT likes_like_content_type_id_object_id_user_id_e20903f0_uniq UNIQUE (content_type_id, object_id, user_id);
 o   ALTER TABLE ONLY public.likes_like DROP CONSTRAINT likes_like_content_type_id_object_id_user_id_e20903f0_uniq;
       public            taiga    false    243    243    243            �           2606    3234430    likes_like likes_like_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.likes_like
    ADD CONSTRAINT likes_like_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.likes_like DROP CONSTRAINT likes_like_pkey;
       public            taiga    false    243                       2606    3235401 G   milestones_milestone milestones_milestone_name_project_id_fe19fd36_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_name_project_id_fe19fd36_uniq UNIQUE (name, project_id);
 q   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_name_project_id_fe19fd36_uniq;
       public            taiga    false    228    228            "           2606    3234443 .   milestones_milestone milestones_milestone_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_pkey;
       public            taiga    false    228            '           2606    3235399 G   milestones_milestone milestones_milestone_slug_project_id_e59bac6a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_slug_project_id_e59bac6a_uniq UNIQUE (slug, project_id);
 q   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_slug_project_id_e59bac6a_uniq;
       public            taiga    false    228    228            Y           2606    3236773 t   notifications_historychangenotification_notify_users notifications_historycha_historychangenotificatio_3b0f323b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users
    ADD CONSTRAINT notifications_historycha_historychangenotificatio_3b0f323b_uniq UNIQUE (historychangenotification_id, user_id);
 �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users DROP CONSTRAINT notifications_historycha_historychangenotificatio_3b0f323b_uniq;
       public            taiga    false    237    237            R           2606    3234556 w   notifications_historychangenotification_history_entries notifications_historycha_historychangenotificatio_8fb55cdd_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries
    ADD CONSTRAINT notifications_historycha_historychangenotificatio_8fb55cdd_uniq UNIQUE (historychangenotification_id, historyentry_id);
 �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries DROP CONSTRAINT notifications_historycha_historychangenotificatio_8fb55cdd_uniq;
       public            taiga    false    235    235            L           2606    3236783 g   notifications_historychangenotification notifications_historycha_key_owner_id_project_id__869f948f_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification
    ADD CONSTRAINT notifications_historycha_key_owner_id_project_id__869f948f_uniq UNIQUE (key, owner_id, project_id, history_type);
 �   ALTER TABLE ONLY public.notifications_historychangenotification DROP CONSTRAINT notifications_historycha_key_owner_id_project_id__869f948f_uniq;
       public            taiga    false    233    233    233    233            W           2606    3233705 t   notifications_historychangenotification_history_entries notifications_historychangenotification_history_entries_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries
    ADD CONSTRAINT notifications_historychangenotification_history_entries_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries DROP CONSTRAINT notifications_historychangenotification_history_entries_pkey;
       public            taiga    false    235            ]           2606    3233079 n   notifications_historychangenotification_notify_users notifications_historychangenotification_notify_users_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users
    ADD CONSTRAINT notifications_historychangenotification_notify_users_pkey PRIMARY KEY (id);
 �   ALTER TABLE ONLY public.notifications_historychangenotification_notify_users DROP CONSTRAINT notifications_historychangenotification_notify_users_pkey;
       public            taiga    false    237            O           2606    3234544 T   notifications_historychangenotification notifications_historychangenotification_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_historychangenotification
    ADD CONSTRAINT notifications_historychangenotification_pkey PRIMARY KEY (id);
 ~   ALTER TABLE ONLY public.notifications_historychangenotification DROP CONSTRAINT notifications_historychangenotification_pkey;
       public            taiga    false    233            F           2606    3234578 :   notifications_notifypolicy notifications_notifypolicy_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.notifications_notifypolicy
    ADD CONSTRAINT notifications_notifypolicy_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.notifications_notifypolicy DROP CONSTRAINT notifications_notifypolicy_pkey;
       public            taiga    false    232            I           2606    3236814 V   notifications_notifypolicy notifications_notifypolicy_project_id_user_id_e7aa5cf2_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_notifypolicy
    ADD CONSTRAINT notifications_notifypolicy_project_id_user_id_e7aa5cf2_uniq UNIQUE (project_id, user_id);
 �   ALTER TABLE ONLY public.notifications_notifypolicy DROP CONSTRAINT notifications_notifypolicy_project_id_user_id_e7aa5cf2_uniq;
       public            taiga    false    232    232            `           2606    3236803 R   notifications_watched notifications_watched_content_type_id_object_i_e7c27769_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watched_content_type_id_object_i_e7c27769_uniq UNIQUE (content_type_id, object_id, user_id, project_id);
 |   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watched_content_type_id_object_i_e7c27769_uniq;
       public            taiga    false    238    238    238    238            b           2606    3234591 0   notifications_watched notifications_watched_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watched_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watched_pkey;
       public            taiga    false    238            	           2606    3234605 @   notifications_webnotification notifications_webnotification_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.notifications_webnotification
    ADD CONSTRAINT notifications_webnotification_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.notifications_webnotification DROP CONSTRAINT notifications_webnotification_pkey;
       public            taiga    false    285            �           2606    3234749 ,   projects_epicstatus projects_epicstatus_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.projects_epicstatus
    ADD CONSTRAINT projects_epicstatus_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.projects_epicstatus DROP CONSTRAINT projects_epicstatus_pkey;
       public            taiga    false    244            �           2606    3235344 E   projects_epicstatus projects_epicstatus_project_id_name_b71c417e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_epicstatus
    ADD CONSTRAINT projects_epicstatus_project_id_name_b71c417e_uniq UNIQUE (project_id, name);
 o   ALTER TABLE ONLY public.projects_epicstatus DROP CONSTRAINT projects_epicstatus_project_id_name_b71c417e_uniq;
       public            taiga    false    244    244            �           2606    3235346 E   projects_epicstatus projects_epicstatus_project_id_slug_f67857e5_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_epicstatus
    ADD CONSTRAINT projects_epicstatus_project_id_slug_f67857e5_uniq UNIQUE (project_id, slug);
 o   ALTER TABLE ONLY public.projects_epicstatus DROP CONSTRAINT projects_epicstatus_project_id_slug_f67857e5_uniq;
       public            taiga    false    244    244                       2606    3234827 0   projects_issueduedate projects_issueduedate_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.projects_issueduedate
    ADD CONSTRAINT projects_issueduedate_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.projects_issueduedate DROP CONSTRAINT projects_issueduedate_pkey;
       public            taiga    false    291                       2606    3235276 I   projects_issueduedate projects_issueduedate_project_id_name_cba303bc_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_issueduedate
    ADD CONSTRAINT projects_issueduedate_project_id_name_cba303bc_uniq UNIQUE (project_id, name);
 s   ALTER TABLE ONLY public.projects_issueduedate DROP CONSTRAINT projects_issueduedate_project_id_name_cba303bc_uniq;
       public            taiga    false    291    291            �           2606    3234839 .   projects_issuestatus projects_issuestatus_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.projects_issuestatus
    ADD CONSTRAINT projects_issuestatus_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.projects_issuestatus DROP CONSTRAINT projects_issuestatus_pkey;
       public            taiga    false    212            �           2606    3235219 G   projects_issuestatus projects_issuestatus_project_id_name_a88dd6c0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuestatus
    ADD CONSTRAINT projects_issuestatus_project_id_name_a88dd6c0_uniq UNIQUE (project_id, name);
 q   ALTER TABLE ONLY public.projects_issuestatus DROP CONSTRAINT projects_issuestatus_project_id_name_a88dd6c0_uniq;
       public            taiga    false    212    212            �           2606    3235221 G   projects_issuestatus projects_issuestatus_project_id_slug_ca3e758d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuestatus
    ADD CONSTRAINT projects_issuestatus_project_id_slug_ca3e758d_uniq UNIQUE (project_id, slug);
 q   ALTER TABLE ONLY public.projects_issuestatus DROP CONSTRAINT projects_issuestatus_project_id_slug_ca3e758d_uniq;
       public            taiga    false    212    212            �           2606    3234921 *   projects_issuetype projects_issuetype_pkey 
   CONSTRAINT     h   ALTER TABLE ONLY public.projects_issuetype
    ADD CONSTRAINT projects_issuetype_pkey PRIMARY KEY (id);
 T   ALTER TABLE ONLY public.projects_issuetype DROP CONSTRAINT projects_issuetype_pkey;
       public            taiga    false    213            �           2606    3235246 C   projects_issuetype projects_issuetype_project_id_name_41b47d87_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuetype
    ADD CONSTRAINT projects_issuetype_project_id_name_41b47d87_uniq UNIQUE (project_id, name);
 m   ALTER TABLE ONLY public.projects_issuetype DROP CONSTRAINT projects_issuetype_project_id_name_41b47d87_uniq;
       public            taiga    false    213    213            �           2606    3234997 ,   projects_membership projects_membership_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_pkey;
       public            taiga    false    210            �           2606    3236615 H   projects_membership projects_membership_user_id_project_id_a2829f61_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_user_id_project_id_a2829f61_uniq UNIQUE (user_id, project_id);
 r   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_user_id_project_id_a2829f61_uniq;
       public            taiga    false    210    210            �           2606    3235015 $   projects_points projects_points_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.projects_points
    ADD CONSTRAINT projects_points_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.projects_points DROP CONSTRAINT projects_points_pkey;
       public            taiga    false    214            �           2606    3235285 =   projects_points projects_points_project_id_name_900c69f4_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_points
    ADD CONSTRAINT projects_points_project_id_name_900c69f4_uniq UNIQUE (project_id, name);
 g   ALTER TABLE ONLY public.projects_points DROP CONSTRAINT projects_points_project_id_name_900c69f4_uniq;
       public            taiga    false    214    214            �           2606    3235083 (   projects_priority projects_priority_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.projects_priority
    ADD CONSTRAINT projects_priority_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.projects_priority DROP CONSTRAINT projects_priority_pkey;
       public            taiga    false    215            �           2606    3235255 A   projects_priority projects_priority_project_id_name_ca316bb1_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_priority
    ADD CONSTRAINT projects_priority_project_id_name_ca316bb1_uniq UNIQUE (project_id, name);
 k   ALTER TABLE ONLY public.projects_priority DROP CONSTRAINT projects_priority_project_id_name_ca316bb1_uniq;
       public            taiga    false    215    215            �           2606    3234766 <   projects_project projects_project_default_epic_status_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_epic_status_id_key UNIQUE (default_epic_status_id);
 f   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_epic_status_id_key;
       public            taiga    false    211            �           2606    3234856 =   projects_project projects_project_default_issue_status_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_issue_status_id_key UNIQUE (default_issue_status_id);
 g   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_issue_status_id_key;
       public            taiga    false    211            �           2606    3234932 ;   projects_project projects_project_default_issue_type_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_issue_type_id_key UNIQUE (default_issue_type_id);
 e   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_issue_type_id_key;
       public            taiga    false    211            �           2606    3235026 7   projects_project projects_project_default_points_id_key 
   CONSTRAINT        ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_points_id_key UNIQUE (default_points_id);
 a   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_points_id_key;
       public            taiga    false    211            �           2606    3235094 9   projects_project projects_project_default_priority_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_priority_id_key UNIQUE (default_priority_id);
 c   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_priority_id_key;
       public            taiga    false    211            �           2606    3235870 9   projects_project projects_project_default_severity_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_severity_id_key UNIQUE (default_severity_id);
 c   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_severity_id_key;
       public            taiga    false    211            �           2606    3235949 9   projects_project projects_project_default_swimlane_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_swimlane_id_key UNIQUE (default_swimlane_id);
 c   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_swimlane_id_key;
       public            taiga    false    211            �           2606    3236049 <   projects_project projects_project_default_task_status_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_task_status_id_key UNIQUE (default_task_status_id);
 f   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_task_status_id_key;
       public            taiga    false    211            �           2606    3236141 :   projects_project projects_project_default_us_status_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_default_us_status_id_key UNIQUE (default_us_status_id);
 d   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_default_us_status_id_key;
       public            taiga    false    211            �           2606    3235159 &   projects_project projects_project_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_pkey;
       public            taiga    false    211            �           2606    3232419 *   projects_project projects_project_slug_key 
   CONSTRAINT     e   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_slug_key UNIQUE (slug);
 T   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_slug_key;
       public            taiga    false    211            v           2606    3235784 @   projects_projectmodulesconfig projects_projectmodulesconfig_pkey 
   CONSTRAINT     ~   ALTER TABLE ONLY public.projects_projectmodulesconfig
    ADD CONSTRAINT projects_projectmodulesconfig_pkey PRIMARY KEY (id);
 j   ALTER TABLE ONLY public.projects_projectmodulesconfig DROP CONSTRAINT projects_projectmodulesconfig_pkey;
       public            taiga    false    241            x           2606    3235236 J   projects_projectmodulesconfig projects_projectmodulesconfig_project_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmodulesconfig
    ADD CONSTRAINT projects_projectmodulesconfig_project_id_key UNIQUE (project_id);
 t   ALTER TABLE ONLY public.projects_projectmodulesconfig DROP CONSTRAINT projects_projectmodulesconfig_project_id_key;
       public            taiga    false    241            �           2606    3235798 6   projects_projecttemplate projects_projecttemplate_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_pkey;
       public            taiga    false    216            �           2606    3232494 :   projects_projecttemplate projects_projecttemplate_slug_key 
   CONSTRAINT     u   ALTER TABLE ONLY public.projects_projecttemplate
    ADD CONSTRAINT projects_projecttemplate_slug_key UNIQUE (slug);
 d   ALTER TABLE ONLY public.projects_projecttemplate DROP CONSTRAINT projects_projecttemplate_slug_key;
       public            taiga    false    216            �           2606    3235859 (   projects_severity projects_severity_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.projects_severity
    ADD CONSTRAINT projects_severity_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.projects_severity DROP CONSTRAINT projects_severity_pkey;
       public            taiga    false    217            �           2606    3235326 A   projects_severity projects_severity_project_id_name_6187c456_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_severity
    ADD CONSTRAINT projects_severity_project_id_name_6187c456_uniq UNIQUE (project_id, name);
 k   ALTER TABLE ONLY public.projects_severity DROP CONSTRAINT projects_severity_project_id_name_6187c456_uniq;
       public            taiga    false    217    217            "           2606    3235935 (   projects_swimlane projects_swimlane_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.projects_swimlane
    ADD CONSTRAINT projects_swimlane_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.projects_swimlane DROP CONSTRAINT projects_swimlane_pkey;
       public            taiga    false    294            %           2606    3235264 A   projects_swimlane projects_swimlane_project_id_name_a949892d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlane
    ADD CONSTRAINT projects_swimlane_project_id_name_a949892d_uniq UNIQUE (project_id, name);
 k   ALTER TABLE ONLY public.projects_swimlane DROP CONSTRAINT projects_swimlane_project_id_name_a949892d_uniq;
       public            taiga    false    294    294            '           2606    3236183 ]   projects_swimlaneuserstorystatus projects_swimlaneusersto_swimlane_id_status_id_d6ff394d_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus
    ADD CONSTRAINT projects_swimlaneusersto_swimlane_id_status_id_d6ff394d_uniq UNIQUE (swimlane_id, status_id);
 �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus DROP CONSTRAINT projects_swimlaneusersto_swimlane_id_status_id_d6ff394d_uniq;
       public            taiga    false    295    295            )           2606    3236007 F   projects_swimlaneuserstorystatus projects_swimlaneuserstorystatus_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus
    ADD CONSTRAINT projects_swimlaneuserstorystatus_pkey PRIMARY KEY (id);
 p   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus DROP CONSTRAINT projects_swimlaneuserstorystatus_pkey;
       public            taiga    false    295                       2606    3236020 .   projects_taskduedate projects_taskduedate_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.projects_taskduedate
    ADD CONSTRAINT projects_taskduedate_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.projects_taskduedate DROP CONSTRAINT projects_taskduedate_pkey;
       public            taiga    false    292                       2606    3235335 G   projects_taskduedate projects_taskduedate_project_id_name_6270950e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskduedate
    ADD CONSTRAINT projects_taskduedate_project_id_name_6270950e_uniq UNIQUE (project_id, name);
 q   ALTER TABLE ONLY public.projects_taskduedate DROP CONSTRAINT projects_taskduedate_project_id_name_6270950e_uniq;
       public            taiga    false    292    292            �           2606    3236032 ,   projects_taskstatus projects_taskstatus_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.projects_taskstatus
    ADD CONSTRAINT projects_taskstatus_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.projects_taskstatus DROP CONSTRAINT projects_taskstatus_pkey;
       public            taiga    false    218            �           2606    3235309 E   projects_taskstatus projects_taskstatus_project_id_name_4b65b78f_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskstatus
    ADD CONSTRAINT projects_taskstatus_project_id_name_4b65b78f_uniq UNIQUE (project_id, name);
 o   ALTER TABLE ONLY public.projects_taskstatus DROP CONSTRAINT projects_taskstatus_project_id_name_4b65b78f_uniq;
       public            taiga    false    218    218            �           2606    3235311 E   projects_taskstatus projects_taskstatus_project_id_slug_30401ba3_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskstatus
    ADD CONSTRAINT projects_taskstatus_project_id_slug_30401ba3_uniq UNIQUE (project_id, slug);
 o   ALTER TABLE ONLY public.projects_taskstatus DROP CONSTRAINT projects_taskstatus_project_id_slug_30401ba3_uniq;
       public            taiga    false    218    218                       2606    3236112 8   projects_userstoryduedate projects_userstoryduedate_pkey 
   CONSTRAINT     v   ALTER TABLE ONLY public.projects_userstoryduedate
    ADD CONSTRAINT projects_userstoryduedate_pkey PRIMARY KEY (id);
 b   ALTER TABLE ONLY public.projects_userstoryduedate DROP CONSTRAINT projects_userstoryduedate_pkey;
       public            taiga    false    293                        2606    3235361 Q   projects_userstoryduedate projects_userstoryduedate_project_id_name_177c510a_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstoryduedate
    ADD CONSTRAINT projects_userstoryduedate_project_id_name_177c510a_uniq UNIQUE (project_id, name);
 {   ALTER TABLE ONLY public.projects_userstoryduedate DROP CONSTRAINT projects_userstoryduedate_project_id_name_177c510a_uniq;
       public            taiga    false    293    293            �           2606    3236124 6   projects_userstorystatus projects_userstorystatus_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.projects_userstorystatus
    ADD CONSTRAINT projects_userstorystatus_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.projects_userstorystatus DROP CONSTRAINT projects_userstorystatus_pkey;
       public            taiga    false    219                       2606    3235370 O   projects_userstorystatus projects_userstorystatus_project_id_name_7c0a1351_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstorystatus
    ADD CONSTRAINT projects_userstorystatus_project_id_name_7c0a1351_uniq UNIQUE (project_id, name);
 y   ALTER TABLE ONLY public.projects_userstorystatus DROP CONSTRAINT projects_userstorystatus_project_id_name_7c0a1351_uniq;
       public            taiga    false    219    219                       2606    3235372 O   projects_userstorystatus projects_userstorystatus_project_id_slug_97a888b5_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstorystatus
    ADD CONSTRAINT projects_userstorystatus_project_id_slug_97a888b5_uniq UNIQUE (project_id, slug);
 y   ALTER TABLE ONLY public.projects_userstorystatus DROP CONSTRAINT projects_userstorystatus_project_id_slug_97a888b5_uniq;
       public            taiga    false    219    219            .           2606    3236242 .   references_reference references_reference_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.references_reference
    ADD CONSTRAINT references_reference_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.references_reference DROP CONSTRAINT references_reference_pkey;
       public            taiga    false    313            1           2606    3236227 F   references_reference references_reference_project_id_ref_82d64d63_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.references_reference
    ADD CONSTRAINT references_reference_project_id_ref_82d64d63_uniq UNIQUE (project_id, ref);
 p   ALTER TABLE ONLY public.references_reference DROP CONSTRAINT references_reference_project_id_ref_82d64d63_uniq;
       public            taiga    false    313    313            7           2606    3236287 >   settings_userprojectsettings settings_userprojectsettings_pkey 
   CONSTRAINT     |   ALTER TABLE ONLY public.settings_userprojectsettings
    ADD CONSTRAINT settings_userprojectsettings_pkey PRIMARY KEY (id);
 h   ALTER TABLE ONLY public.settings_userprojectsettings DROP CONSTRAINT settings_userprojectsettings_pkey;
       public            taiga    false    316            :           2606    3236951 Z   settings_userprojectsettings settings_userprojectsettings_project_id_user_id_330ddee9_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.settings_userprojectsettings
    ADD CONSTRAINT settings_userprojectsettings_project_id_user_id_330ddee9_uniq UNIQUE (project_id, user_id);
 �   ALTER TABLE ONLY public.settings_userprojectsettings DROP CONSTRAINT settings_userprojectsettings_project_id_user_id_330ddee9_uniq;
       public            taiga    false    316    316            i           2606    3236329    tasks_task tasks_task_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_pkey;
       public            taiga    false    239            =           2606    3236374 <   telemetry_instancetelemetry telemetry_instancetelemetry_pkey 
   CONSTRAINT     z   ALTER TABLE ONLY public.telemetry_instancetelemetry
    ADD CONSTRAINT telemetry_instancetelemetry_pkey PRIMARY KEY (id);
 f   ALTER TABLE ONLY public.telemetry_instancetelemetry DROP CONSTRAINT telemetry_instancetelemetry_pkey;
       public            taiga    false    319            �           2606    3236404 (   timeline_timeline timeline_timeline_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.timeline_timeline
    ADD CONSTRAINT timeline_timeline_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.timeline_timeline DROP CONSTRAINT timeline_timeline_pkey;
       public            taiga    false    242            E           2606    3236445 B   token_denylist_denylistedtoken token_denylist_denylistedtoken_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_denylistedtoken
    ADD CONSTRAINT token_denylist_denylistedtoken_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.token_denylist_denylistedtoken DROP CONSTRAINT token_denylist_denylistedtoken_pkey;
       public            taiga    false    325            G           2606    3236447 J   token_denylist_denylistedtoken token_denylist_denylistedtoken_token_id_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_denylistedtoken
    ADD CONSTRAINT token_denylist_denylistedtoken_token_id_key UNIQUE (token_id);
 t   ALTER TABLE ONLY public.token_denylist_denylistedtoken DROP CONSTRAINT token_denylist_denylistedtoken_token_id_key;
       public            taiga    false    325            @           2606    3236437 G   token_denylist_outstandingtoken token_denylist_outstandingtoken_jti_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_outstandingtoken
    ADD CONSTRAINT token_denylist_outstandingtoken_jti_key UNIQUE (jti);
 q   ALTER TABLE ONLY public.token_denylist_outstandingtoken DROP CONSTRAINT token_denylist_outstandingtoken_jti_key;
       public            taiga    false    323            B           2606    3236435 D   token_denylist_outstandingtoken token_denylist_outstandingtoken_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_outstandingtoken
    ADD CONSTRAINT token_denylist_outstandingtoken_pkey PRIMARY KEY (id);
 n   ALTER TABLE ONLY public.token_denylist_outstandingtoken DROP CONSTRAINT token_denylist_outstandingtoken_pkey;
       public            taiga    false    323            q           2606    3233241 5   users_authdata users_authdata_key_value_7ee3acc9_uniq 
   CONSTRAINT     v   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_key_value_7ee3acc9_uniq UNIQUE (key, value);
 _   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_key_value_7ee3acc9_uniq;
       public            taiga    false    240    240            s           2606    3236505 "   users_authdata users_authdata_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_pkey;
       public            taiga    false    240            �           2606    3236522    users_role users_role_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_role
    ADD CONSTRAINT users_role_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_role DROP CONSTRAINT users_role_pkey;
       public            taiga    false    209            �           2606    3235205 3   users_role users_role_slug_project_id_db8c270c_uniq 
   CONSTRAINT     z   ALTER TABLE ONLY public.users_role
    ADD CONSTRAINT users_role_slug_project_id_db8c270c_uniq UNIQUE (slug, project_id);
 ]   ALTER TABLE ONLY public.users_role DROP CONSTRAINT users_role_slug_project_id_db8c270c_uniq;
       public            taiga    false    209    209            �           2606    3232743 )   users_user users_user_email_243f6e77_uniq 
   CONSTRAINT     e   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_email_243f6e77_uniq UNIQUE (email);
 S   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_email_243f6e77_uniq;
       public            taiga    false    206            �           2606    3236573    users_user users_user_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_pkey;
       public            taiga    false    206            �           2606    3232746 "   users_user users_user_username_key 
   CONSTRAINT     a   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_username_key UNIQUE (username);
 L   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_username_key;
       public            taiga    false    206            �           2606    3236475 (   users_user users_user_uuid_6fe513d7_uniq 
   CONSTRAINT     c   ALTER TABLE ONLY public.users_user
    ADD CONSTRAINT users_user_uuid_6fe513d7_uniq UNIQUE (uuid);
 R   ALTER TABLE ONLY public.users_user DROP CONSTRAINT users_user_uuid_6fe513d7_uniq;
       public            taiga    false    206            I           2606    3237098 ,   users_workspacerole users_workspacerole_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.users_workspacerole
    ADD CONSTRAINT users_workspacerole_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.users_workspacerole DROP CONSTRAINT users_workspacerole_pkey;
       public            taiga    false    326            M           2606    3237595 G   users_workspacerole users_workspacerole_slug_workspace_id_1c9aef12_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.users_workspacerole
    ADD CONSTRAINT users_workspacerole_slug_workspace_id_1c9aef12_uniq UNIQUE (slug, workspace_id);
 q   ALTER TABLE ONLY public.users_workspacerole DROP CONSTRAINT users_workspacerole_slug_workspace_id_1c9aef12_uniq;
       public            taiga    false    326    326            Q           2606    3237125 L   userstorage_storageentry userstorage_storageentry_owner_id_key_746399cb_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.userstorage_storageentry
    ADD CONSTRAINT userstorage_storageentry_owner_id_key_746399cb_uniq UNIQUE (owner_id, key);
 v   ALTER TABLE ONLY public.userstorage_storageentry DROP CONSTRAINT userstorage_storageentry_owner_id_key_746399cb_uniq;
       public            taiga    false    331    331            S           2606    3237143 6   userstorage_storageentry userstorage_storageentry_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.userstorage_storageentry
    ADD CONSTRAINT userstorage_storageentry_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.userstorage_storageentry DROP CONSTRAINT userstorage_storageentry_pkey;
       public            taiga    false    331            4           2606    3237235 2   userstories_rolepoints userstories_rolepoints_pkey 
   CONSTRAINT     p   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_pkey PRIMARY KEY (id);
 \   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_pkey;
       public            taiga    false    230            9           2606    3237270 Q   userstories_rolepoints userstories_rolepoints_user_story_id_role_id_dc0ba15e_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_user_story_id_role_id_dc0ba15e_uniq UNIQUE (user_story_id, role_id);
 {   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_user_story_id_role_id_dc0ba15e_uniq;
       public            taiga    false    230    230            U           2606    3237281 `   userstories_userstory_assigned_users userstories_userstory_as_userstory_id_user_id_beae1231_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory_assigned_users
    ADD CONSTRAINT userstories_userstory_as_userstory_id_user_id_beae1231_uniq UNIQUE (userstory_id, user_id);
 �   ALTER TABLE ONLY public.userstories_userstory_assigned_users DROP CONSTRAINT userstories_userstory_as_userstory_id_user_id_beae1231_uniq;
       public            taiga    false    334    334            W           2606    3237206 N   userstories_userstory_assigned_users userstories_userstory_assigned_users_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory_assigned_users
    ADD CONSTRAINT userstories_userstory_assigned_users_pkey PRIMARY KEY (id);
 x   ALTER TABLE ONLY public.userstories_userstory_assigned_users DROP CONSTRAINT userstories_userstory_assigned_users_pkey;
       public            taiga    false    334            @           2606    3237249 0   userstories_userstory userstories_userstory_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_pkey;
       public            taiga    false    231            \           2606    3237369 E   votes_vote votes_vote_content_type_id_object_id_user_id_97d16fa0_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.votes_vote
    ADD CONSTRAINT votes_vote_content_type_id_object_id_user_id_97d16fa0_uniq UNIQUE (content_type_id, object_id, user_id);
 o   ALTER TABLE ONLY public.votes_vote DROP CONSTRAINT votes_vote_content_type_id_object_id_user_id_97d16fa0_uniq;
       public            taiga    false    337    337    337            ^           2606    3237391    votes_vote votes_vote_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.votes_vote
    ADD CONSTRAINT votes_vote_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.votes_vote DROP CONSTRAINT votes_vote_pkey;
       public            taiga    false    337            b           2606    3237367 ?   votes_votes votes_votes_content_type_id_object_id_5abfc91b_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.votes_votes
    ADD CONSTRAINT votes_votes_content_type_id_object_id_5abfc91b_uniq UNIQUE (content_type_id, object_id);
 i   ALTER TABLE ONLY public.votes_votes DROP CONSTRAINT votes_votes_content_type_id_object_id_5abfc91b_uniq;
       public            taiga    false    338    338            d           2606    3237404    votes_votes votes_votes_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.votes_votes
    ADD CONSTRAINT votes_votes_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.votes_votes DROP CONSTRAINT votes_votes_pkey;
       public            taiga    false    338            f           2606    3237463 &   webhooks_webhook webhooks_webhook_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.webhooks_webhook
    ADD CONSTRAINT webhooks_webhook_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.webhooks_webhook DROP CONSTRAINT webhooks_webhook_pkey;
       public            taiga    false    341            i           2606    3237491 ,   webhooks_webhooklog webhooks_webhooklog_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.webhooks_webhooklog
    ADD CONSTRAINT webhooks_webhooklog_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.webhooks_webhooklog DROP CONSTRAINT webhooks_webhooklog_pkey;
       public            taiga    false    342            �           2606    3237516     wiki_wikilink wiki_wikilink_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.wiki_wikilink
    ADD CONSTRAINT wiki_wikilink_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.wiki_wikilink DROP CONSTRAINT wiki_wikilink_pkey;
       public            taiga    false    247            �           2606    3235548 9   wiki_wikilink wiki_wikilink_project_id_href_a39ae7e7_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikilink
    ADD CONSTRAINT wiki_wikilink_project_id_href_a39ae7e7_uniq UNIQUE (project_id, href);
 c   ALTER TABLE ONLY public.wiki_wikilink DROP CONSTRAINT wiki_wikilink_project_id_href_a39ae7e7_uniq;
       public            taiga    false    247    247            �           2606    3237533     wiki_wikipage wiki_wikipage_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_pkey;
       public            taiga    false    248            �           2606    3235532 9   wiki_wikipage wiki_wikipage_project_id_slug_cb5b63e2_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_project_id_slug_cb5b63e2_uniq UNIQUE (project_id, slug);
 c   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_project_id_slug_cb5b63e2_uniq;
       public            taiga    false    248    248                       2606    3237581 .   workspaces_workspace workspaces_workspace_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_pkey;
       public            taiga    false    290                       2606    3234627 2   workspaces_workspace workspaces_workspace_slug_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_slug_key UNIQUE (slug);
 \   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_slug_key;
       public            taiga    false    290            l           2606    3237650 Z   workspaces_workspacemembership workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq UNIQUE (user_id, workspace_id);
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacememb_user_id_workspace_id_92c1b27f_uniq;
       public            taiga    false    347    347            n           2606    3237677 B   workspaces_workspacemembership workspaces_workspacemembership_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacemembership_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacemembership_pkey;
       public            taiga    false    347                       1259    3232658 /   attachments_attachment_content_type_id_35dd9d5d    INDEX     }   CREATE INDEX attachments_attachment_content_type_id_35dd9d5d ON public.attachments_attachment USING btree (content_type_id);
 C   DROP INDEX public.attachments_attachment_content_type_id_35dd9d5d;
       public            taiga    false    220                       1259    3232663 =   attachments_attachment_content_type_id_object_id_3f2e447c_idx    INDEX     �   CREATE INDEX attachments_attachment_content_type_id_object_id_3f2e447c_idx ON public.attachments_attachment USING btree (content_type_id, object_id);
 Q   DROP INDEX public.attachments_attachment_content_type_id_object_id_3f2e447c_idx;
       public            taiga    false    220    220                       1259    3236683 (   attachments_attachment_owner_id_720defb8    INDEX     o   CREATE INDEX attachments_attachment_owner_id_720defb8 ON public.attachments_attachment USING btree (owner_id);
 <   DROP INDEX public.attachments_attachment_owner_id_720defb8;
       public            taiga    false    220                       1259    3235386 *   attachments_attachment_project_id_50714f52    INDEX     s   CREATE INDEX attachments_attachment_project_id_50714f52 ON public.attachments_attachment USING btree (project_id);
 >   DROP INDEX public.attachments_attachment_project_id_50714f52;
       public            taiga    false    220                       1259    3232733    auth_group_name_a6ea08ec_like    INDEX     h   CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);
 1   DROP INDEX public.auth_group_name_a6ea08ec_like;
       public            taiga    false    225                       1259    3232729 (   auth_group_permissions_group_id_b120cbf9    INDEX     o   CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);
 <   DROP INDEX public.auth_group_permissions_group_id_b120cbf9;
       public            taiga    false    227                       1259    3232730 -   auth_group_permissions_permission_id_84c5c92e    INDEX     y   CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);
 A   DROP INDEX public.auth_group_permissions_permission_id_84c5c92e;
       public            taiga    false    227                       1259    3232715 (   auth_permission_content_type_id_2f476e4b    INDEX     o   CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);
 <   DROP INDEX public.auth_permission_content_type_id_2f476e4b;
       public            taiga    false    223            �           1259    3235521 (   contact_contactentry_project_id_27bfec4e    INDEX     o   CREATE INDEX contact_contactentry_project_id_27bfec4e ON public.contact_contactentry USING btree (project_id);
 <   DROP INDEX public.contact_contactentry_project_id_27bfec4e;
       public            taiga    false    245            �           1259    3236863 %   contact_contactentry_user_id_f1f19c5f    INDEX     i   CREATE INDEX contact_contactentry_user_id_f1f19c5f ON public.contact_contactentry USING btree (user_id);
 9   DROP INDEX public.contact_contactentry_user_id_f1f19c5f;
       public            taiga    false    245            �           1259    3234248 -   custom_attributes_epiccu_epic_id_d413e57a_idx    INDEX     �   CREATE INDEX custom_attributes_epiccu_epic_id_d413e57a_idx ON public.custom_attributes_epiccustomattributesvalues USING btree (epic_id);
 A   DROP INDEX public.custom_attributes_epiccu_epic_id_d413e57a_idx;
       public            taiga    false    259            �           1259    3235588 9   custom_attributes_epiccustomattribute_project_id_ad2cfaa8    INDEX     �   CREATE INDEX custom_attributes_epiccustomattribute_project_id_ad2cfaa8 ON public.custom_attributes_epiccustomattribute USING btree (project_id);
 M   DROP INDEX public.custom_attributes_epiccustomattribute_project_id_ad2cfaa8;
       public            taiga    false    258            �           1259    3234408 .   custom_attributes_issuec_issue_id_868161f8_idx    INDEX     �   CREATE INDEX custom_attributes_issuec_issue_id_868161f8_idx ON public.custom_attributes_issuecustomattributesvalues USING btree (issue_id);
 B   DROP INDEX public.custom_attributes_issuec_issue_id_868161f8_idx;
       public            taiga    false    255            �           1259    3235600 :   custom_attributes_issuecustomattribute_project_id_3b4acff5    INDEX     �   CREATE INDEX custom_attributes_issuecustomattribute_project_id_3b4acff5 ON public.custom_attributes_issuecustomattribute USING btree (project_id);
 N   DROP INDEX public.custom_attributes_issuecustomattribute_project_id_3b4acff5;
       public            taiga    false    252            �           1259    3236349 -   custom_attributes_taskcu_task_id_3d1ccf5e_idx    INDEX     �   CREATE INDEX custom_attributes_taskcu_task_id_3d1ccf5e_idx ON public.custom_attributes_taskcustomattributesvalues USING btree (task_id);
 A   DROP INDEX public.custom_attributes_taskcu_task_id_3d1ccf5e_idx;
       public            taiga    false    256            �           1259    3235612 9   custom_attributes_taskcustomattribute_project_id_f0f622a8    INDEX     �   CREATE INDEX custom_attributes_taskcustomattribute_project_id_f0f622a8 ON public.custom_attributes_taskcustomattribute USING btree (project_id);
 M   DROP INDEX public.custom_attributes_taskcustomattribute_project_id_f0f622a8;
       public            taiga    false    253            �           1259    3237317 3   custom_attributes_userst_user_story_id_99b10c43_idx    INDEX     �   CREATE INDEX custom_attributes_userst_user_story_id_99b10c43_idx ON public.custom_attributes_userstorycustomattributesvalues USING btree (user_story_id);
 G   DROP INDEX public.custom_attributes_userst_user_story_id_99b10c43_idx;
       public            taiga    false    257            �           1259    3235576 >   custom_attributes_userstorycustomattribute_project_id_2619cf6c    INDEX     �   CREATE INDEX custom_attributes_userstorycustomattribute_project_id_2619cf6c ON public.custom_attributes_userstorycustomattribute USING btree (project_id);
 R   DROP INDEX public.custom_attributes_userstorycustomattribute_project_id_2619cf6c;
       public            taiga    false    254            �           1259    3232382 )   django_admin_log_content_type_id_c4bce8eb    INDEX     q   CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);
 =   DROP INDEX public.django_admin_log_content_type_id_c4bce8eb;
       public            taiga    false    208            �           1259    3236604 !   django_admin_log_user_id_c564eba6    INDEX     a   CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);
 5   DROP INDEX public.django_admin_log_user_id_c564eba6;
       public            taiga    false    208            2           1259    3236262 #   django_session_expire_date_a5c62663    INDEX     e   CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);
 7   DROP INDEX public.django_session_expire_date_a5c62663;
       public            taiga    false    315            5           1259    3236261 (   django_session_session_key_c0390e0f_like    INDEX     ~   CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);
 <   DROP INDEX public.django_session_session_key_c0390e0f_like;
       public            taiga    false    315            �           1259    3234145 !   djmail_message_uuid_8dad4f24_like    INDEX     p   CREATE INDEX djmail_message_uuid_8dad4f24_like ON public.djmail_message USING btree (uuid varchar_pattern_ops);
 5   DROP INDEX public.djmail_message_uuid_8dad4f24_like;
       public            taiga    false    268            �           1259    3234168 $   easy_thumbnails_source_name_5fe0edc6    INDEX     g   CREATE INDEX easy_thumbnails_source_name_5fe0edc6 ON public.easy_thumbnails_source USING btree (name);
 8   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6;
       public            taiga    false    270            �           1259    3234169 )   easy_thumbnails_source_name_5fe0edc6_like    INDEX     �   CREATE INDEX easy_thumbnails_source_name_5fe0edc6_like ON public.easy_thumbnails_source USING btree (name varchar_pattern_ops);
 =   DROP INDEX public.easy_thumbnails_source_name_5fe0edc6_like;
       public            taiga    false    270            �           1259    3234166 ,   easy_thumbnails_source_storage_hash_946cbcc9    INDEX     w   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9 ON public.easy_thumbnails_source USING btree (storage_hash);
 @   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9;
       public            taiga    false    270            �           1259    3234167 1   easy_thumbnails_source_storage_hash_946cbcc9_like    INDEX     �   CREATE INDEX easy_thumbnails_source_storage_hash_946cbcc9_like ON public.easy_thumbnails_source USING btree (storage_hash varchar_pattern_ops);
 E   DROP INDEX public.easy_thumbnails_source_storage_hash_946cbcc9_like;
       public            taiga    false    270            �           1259    3234177 '   easy_thumbnails_thumbnail_name_b5882c31    INDEX     m   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31 ON public.easy_thumbnails_thumbnail USING btree (name);
 ;   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31;
       public            taiga    false    272            �           1259    3234178 ,   easy_thumbnails_thumbnail_name_b5882c31_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_name_b5882c31_like ON public.easy_thumbnails_thumbnail USING btree (name varchar_pattern_ops);
 @   DROP INDEX public.easy_thumbnails_thumbnail_name_b5882c31_like;
       public            taiga    false    272            �           1259    3234179 ,   easy_thumbnails_thumbnail_source_id_5b57bc77    INDEX     w   CREATE INDEX easy_thumbnails_thumbnail_source_id_5b57bc77 ON public.easy_thumbnails_thumbnail USING btree (source_id);
 @   DROP INDEX public.easy_thumbnails_thumbnail_source_id_5b57bc77;
       public            taiga    false    272            �           1259    3234175 /   easy_thumbnails_thumbnail_storage_hash_f1435f49    INDEX     }   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49 ON public.easy_thumbnails_thumbnail USING btree (storage_hash);
 C   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49;
       public            taiga    false    272            �           1259    3234176 4   easy_thumbnails_thumbnail_storage_hash_f1435f49_like    INDEX     �   CREATE INDEX easy_thumbnails_thumbnail_storage_hash_f1435f49_like ON public.easy_thumbnails_thumbnail USING btree (storage_hash varchar_pattern_ops);
 H   DROP INDEX public.easy_thumbnails_thumbnail_storage_hash_f1435f49_like;
       public            taiga    false    272            �           1259    3236901 "   epics_epic_assigned_to_id_13e08004    INDEX     c   CREATE INDEX epics_epic_assigned_to_id_13e08004 ON public.epics_epic USING btree (assigned_to_id);
 6   DROP INDEX public.epics_epic_assigned_to_id_13e08004;
       public            taiga    false    250            �           1259    3236914    epics_epic_owner_id_b09888c4    INDEX     W   CREATE INDEX epics_epic_owner_id_b09888c4 ON public.epics_epic USING btree (owner_id);
 0   DROP INDEX public.epics_epic_owner_id_b09888c4;
       public            taiga    false    250            �           1259    3235561    epics_epic_project_id_d98aaef7    INDEX     [   CREATE INDEX epics_epic_project_id_d98aaef7 ON public.epics_epic USING btree (project_id);
 2   DROP INDEX public.epics_epic_project_id_d98aaef7;
       public            taiga    false    250            �           1259    3233762    epics_epic_ref_aa52eb4a    INDEX     M   CREATE INDEX epics_epic_ref_aa52eb4a ON public.epics_epic USING btree (ref);
 +   DROP INDEX public.epics_epic_ref_aa52eb4a;
       public            taiga    false    250            �           1259    3234807    epics_epic_status_id_4cf3af1a    INDEX     Y   CREATE INDEX epics_epic_status_id_4cf3af1a ON public.epics_epic USING btree (status_id);
 1   DROP INDEX public.epics_epic_status_id_4cf3af1a;
       public            taiga    false    250            �           1259    3234238 '   epics_relateduserstory_epic_id_57605230    INDEX     m   CREATE INDEX epics_relateduserstory_epic_id_57605230 ON public.epics_relateduserstory USING btree (epic_id);
 ;   DROP INDEX public.epics_relateduserstory_epic_id_57605230;
       public            taiga    false    251            �           1259    3237307 -   epics_relateduserstory_user_story_id_329a951c    INDEX     y   CREATE INDEX epics_relateduserstory_user_story_id_329a951c ON public.epics_relateduserstory USING btree (user_story_id);
 A   DROP INDEX public.epics_relateduserstory_user_story_id_329a951c;
       public            taiga    false    251            �           1259    3234302 *   external_apps_application_id_e9988cf8_like    INDEX     �   CREATE INDEX external_apps_application_id_e9988cf8_like ON public.external_apps_application USING btree (id varchar_pattern_ops);
 >   DROP INDEX public.external_apps_application_id_e9988cf8_like;
       public            taiga    false    277                        1259    3234313 6   external_apps_applicationtoken_application_id_0e934655    INDEX     �   CREATE INDEX external_apps_applicationtoken_application_id_0e934655 ON public.external_apps_applicationtoken USING btree (application_id);
 J   DROP INDEX public.external_apps_applicationtoken_application_id_0e934655;
       public            taiga    false    278                       1259    3234314 ;   external_apps_applicationtoken_application_id_0e934655_like    INDEX     �   CREATE INDEX external_apps_applicationtoken_application_id_0e934655_like ON public.external_apps_applicationtoken USING btree (application_id varchar_pattern_ops);
 O   DROP INDEX public.external_apps_applicationtoken_application_id_0e934655_like;
       public            taiga    false    278                       1259    3236929 /   external_apps_applicationtoken_user_id_6e2f1e8a    INDEX     }   CREATE INDEX external_apps_applicationtoken_user_id_6e2f1e8a ON public.external_apps_applicationtoken USING btree (user_id);
 C   DROP INDEX public.external_apps_applicationtoken_user_id_6e2f1e8a;
       public            taiga    false    278            �           1259    3233698 %   history_historyentry_id_ff18cc9f_like    INDEX     x   CREATE INDEX history_historyentry_id_ff18cc9f_like ON public.history_historyentry USING btree (id varchar_pattern_ops);
 9   DROP INDEX public.history_historyentry_id_ff18cc9f_like;
       public            taiga    false    249            �           1259    3233699 !   history_historyentry_key_c088c4ae    INDEX     a   CREATE INDEX history_historyentry_key_c088c4ae ON public.history_historyentry USING btree (key);
 5   DROP INDEX public.history_historyentry_key_c088c4ae;
       public            taiga    false    249            �           1259    3233700 &   history_historyentry_key_c088c4ae_like    INDEX     z   CREATE INDEX history_historyentry_key_c088c4ae_like ON public.history_historyentry USING btree (key varchar_pattern_ops);
 :   DROP INDEX public.history_historyentry_key_c088c4ae_like;
       public            taiga    false    249            �           1259    3235478 (   history_historyentry_project_id_9b008f70    INDEX     o   CREATE INDEX history_historyentry_project_id_9b008f70 ON public.history_historyentry USING btree (project_id);
 <   DROP INDEX public.history_historyentry_project_id_9b008f70;
       public            taiga    false    249            (           1259    3236708 $   issues_issue_assigned_to_id_c6054289    INDEX     g   CREATE INDEX issues_issue_assigned_to_id_c6054289 ON public.issues_issue USING btree (assigned_to_id);
 8   DROP INDEX public.issues_issue_assigned_to_id_c6054289;
       public            taiga    false    229            )           1259    3234459 "   issues_issue_milestone_id_3c2695ee    INDEX     c   CREATE INDEX issues_issue_milestone_id_3c2695ee ON public.issues_issue USING btree (milestone_id);
 6   DROP INDEX public.issues_issue_milestone_id_3c2695ee;
       public            taiga    false    229            *           1259    3236725    issues_issue_owner_id_5c361b47    INDEX     [   CREATE INDEX issues_issue_owner_id_5c361b47 ON public.issues_issue USING btree (owner_id);
 2   DROP INDEX public.issues_issue_owner_id_5c361b47;
       public            taiga    false    229            -           1259    3235135 !   issues_issue_priority_id_93842a93    INDEX     a   CREATE INDEX issues_issue_priority_id_93842a93 ON public.issues_issue USING btree (priority_id);
 5   DROP INDEX public.issues_issue_priority_id_93842a93;
       public            taiga    false    229            .           1259    3235415     issues_issue_project_id_4b0f3e2f    INDEX     _   CREATE INDEX issues_issue_project_id_4b0f3e2f ON public.issues_issue USING btree (project_id);
 4   DROP INDEX public.issues_issue_project_id_4b0f3e2f;
       public            taiga    false    229            /           1259    3232860    issues_issue_ref_4c1e7f8f    INDEX     Q   CREATE INDEX issues_issue_ref_4c1e7f8f ON public.issues_issue USING btree (ref);
 -   DROP INDEX public.issues_issue_ref_4c1e7f8f;
       public            taiga    false    229            0           1259    3235911 !   issues_issue_severity_id_695dade0    INDEX     a   CREATE INDEX issues_issue_severity_id_695dade0 ON public.issues_issue USING btree (severity_id);
 5   DROP INDEX public.issues_issue_severity_id_695dade0;
       public            taiga    false    229            1           1259    3234897    issues_issue_status_id_64473cf1    INDEX     ]   CREATE INDEX issues_issue_status_id_64473cf1 ON public.issues_issue USING btree (status_id);
 3   DROP INDEX public.issues_issue_status_id_64473cf1;
       public            taiga    false    229            2           1259    3234973    issues_issue_type_id_c1063362    INDEX     Y   CREATE INDEX issues_issue_type_id_c1063362 ON public.issues_issue USING btree (type_id);
 1   DROP INDEX public.issues_issue_type_id_c1063362;
       public            taiga    false    229            �           1259    3233405 #   likes_like_content_type_id_8ffc2116    INDEX     e   CREATE INDEX likes_like_content_type_id_8ffc2116 ON public.likes_like USING btree (content_type_id);
 7   DROP INDEX public.likes_like_content_type_id_8ffc2116;
       public            taiga    false    243            �           1259    3236855    likes_like_user_id_aae4c421    INDEX     U   CREATE INDEX likes_like_user_id_aae4c421 ON public.likes_like USING btree (user_id);
 /   DROP INDEX public.likes_like_user_id_aae4c421;
       public            taiga    false    243                       1259    3232781 "   milestones_milestone_name_23fb0698    INDEX     c   CREATE INDEX milestones_milestone_name_23fb0698 ON public.milestones_milestone USING btree (name);
 6   DROP INDEX public.milestones_milestone_name_23fb0698;
       public            taiga    false    228                       1259    3232782 '   milestones_milestone_name_23fb0698_like    INDEX     |   CREATE INDEX milestones_milestone_name_23fb0698_like ON public.milestones_milestone USING btree (name varchar_pattern_ops);
 ;   DROP INDEX public.milestones_milestone_name_23fb0698_like;
       public            taiga    false    228                        1259    3236695 &   milestones_milestone_owner_id_216ba23b    INDEX     k   CREATE INDEX milestones_milestone_owner_id_216ba23b ON public.milestones_milestone USING btree (owner_id);
 :   DROP INDEX public.milestones_milestone_owner_id_216ba23b;
       public            taiga    false    228            #           1259    3235402 (   milestones_milestone_project_id_6151cb75    INDEX     o   CREATE INDEX milestones_milestone_project_id_6151cb75 ON public.milestones_milestone USING btree (project_id);
 <   DROP INDEX public.milestones_milestone_project_id_6151cb75;
       public            taiga    false    228            $           1259    3232783 "   milestones_milestone_slug_08e5995e    INDEX     c   CREATE INDEX milestones_milestone_slug_08e5995e ON public.milestones_milestone USING btree (slug);
 6   DROP INDEX public.milestones_milestone_slug_08e5995e;
       public            taiga    false    228            %           1259    3232784 '   milestones_milestone_slug_08e5995e_like    INDEX     |   CREATE INDEX milestones_milestone_slug_08e5995e_like ON public.milestones_milestone USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.milestones_milestone_slug_08e5995e_like;
       public            taiga    false    228            S           1259    3233106 6   notifications_historycha_historyentry_id_ad550852_like    INDEX     �   CREATE INDEX notifications_historycha_historyentry_id_ad550852_like ON public.notifications_historychangenotification_history_entries USING btree (historyentry_id varchar_pattern_ops);
 J   DROP INDEX public.notifications_historycha_historyentry_id_ad550852_like;
       public            taiga    false    235            T           1259    3234557 >   notifications_historychang_historychangenotification__65e52ffd    INDEX     �   CREATE INDEX notifications_historychang_historychangenotification__65e52ffd ON public.notifications_historychangenotification_history_entries USING btree (historychangenotification_id);
 R   DROP INDEX public.notifications_historychang_historychangenotification__65e52ffd;
       public            taiga    false    235            Z           1259    3234568 >   notifications_historychang_historychangenotification__d8e98e97    INDEX     �   CREATE INDEX notifications_historychang_historychangenotification__d8e98e97 ON public.notifications_historychangenotification_notify_users USING btree (historychangenotification_id);
 R   DROP INDEX public.notifications_historychang_historychangenotification__d8e98e97;
       public            taiga    false    237            U           1259    3233105 3   notifications_historychang_historyentry_id_ad550852    INDEX     �   CREATE INDEX notifications_historychang_historyentry_id_ad550852 ON public.notifications_historychangenotification_history_entries USING btree (historyentry_id);
 G   DROP INDEX public.notifications_historychang_historyentry_id_ad550852;
       public            taiga    false    235            [           1259    3236774 +   notifications_historychang_user_id_f7bd2448    INDEX     �   CREATE INDEX notifications_historychang_user_id_f7bd2448 ON public.notifications_historychangenotification_notify_users USING btree (user_id);
 ?   DROP INDEX public.notifications_historychang_user_id_f7bd2448;
       public            taiga    false    237            M           1259    3236784 9   notifications_historychangenotification_owner_id_6f63be8a    INDEX     �   CREATE INDEX notifications_historychangenotification_owner_id_6f63be8a ON public.notifications_historychangenotification USING btree (owner_id);
 M   DROP INDEX public.notifications_historychangenotification_owner_id_6f63be8a;
       public            taiga    false    233            P           1259    3235470 ;   notifications_historychangenotification_project_id_52cf5e2b    INDEX     �   CREATE INDEX notifications_historychangenotification_project_id_52cf5e2b ON public.notifications_historychangenotification USING btree (project_id);
 O   DROP INDEX public.notifications_historychangenotification_project_id_52cf5e2b;
       public            taiga    false    233            G           1259    3235460 .   notifications_notifypolicy_project_id_aa5da43f    INDEX     {   CREATE INDEX notifications_notifypolicy_project_id_aa5da43f ON public.notifications_notifypolicy USING btree (project_id);
 B   DROP INDEX public.notifications_notifypolicy_project_id_aa5da43f;
       public            taiga    false    232            J           1259    3236815 +   notifications_notifypolicy_user_id_2902cbeb    INDEX     u   CREATE INDEX notifications_notifypolicy_user_id_2902cbeb ON public.notifications_notifypolicy USING btree (user_id);
 ?   DROP INDEX public.notifications_notifypolicy_user_id_2902cbeb;
       public            taiga    false    232            ^           1259    3233149 .   notifications_watched_content_type_id_7b3ab729    INDEX     {   CREATE INDEX notifications_watched_content_type_id_7b3ab729 ON public.notifications_watched USING btree (content_type_id);
 B   DROP INDEX public.notifications_watched_content_type_id_7b3ab729;
       public            taiga    false    238            c           1259    3235449 )   notifications_watched_project_id_c88baa46    INDEX     q   CREATE INDEX notifications_watched_project_id_c88baa46 ON public.notifications_watched USING btree (project_id);
 =   DROP INDEX public.notifications_watched_project_id_c88baa46;
       public            taiga    false    238            d           1259    3236804 &   notifications_watched_user_id_1bce1955    INDEX     k   CREATE INDEX notifications_watched_user_id_1bce1955 ON public.notifications_watched USING btree (user_id);
 :   DROP INDEX public.notifications_watched_user_id_1bce1955;
       public            taiga    false    238                       1259    3234540 .   notifications_webnotification_created_b17f50f8    INDEX     {   CREATE INDEX notifications_webnotification_created_b17f50f8 ON public.notifications_webnotification USING btree (created);
 B   DROP INDEX public.notifications_webnotification_created_b17f50f8;
       public            taiga    false    285            
           1259    3236792 .   notifications_webnotification_user_id_f32287d5    INDEX     {   CREATE INDEX notifications_webnotification_user_id_f32287d5 ON public.notifications_webnotification USING btree (user_id);
 B   DROP INDEX public.notifications_webnotification_user_id_f32287d5;
       public            taiga    false    285            �           1259    3235347 '   projects_epicstatus_project_id_d2c43c29    INDEX     m   CREATE INDEX projects_epicstatus_project_id_d2c43c29 ON public.projects_epicstatus USING btree (project_id);
 ;   DROP INDEX public.projects_epicstatus_project_id_d2c43c29;
       public            taiga    false    244            �           1259    3233509 !   projects_epicstatus_slug_63c476c8    INDEX     a   CREATE INDEX projects_epicstatus_slug_63c476c8 ON public.projects_epicstatus USING btree (slug);
 5   DROP INDEX public.projects_epicstatus_slug_63c476c8;
       public            taiga    false    244            �           1259    3233510 &   projects_epicstatus_slug_63c476c8_like    INDEX     z   CREATE INDEX projects_epicstatus_slug_63c476c8_like ON public.projects_epicstatus USING btree (slug varchar_pattern_ops);
 :   DROP INDEX public.projects_epicstatus_slug_63c476c8_like;
       public            taiga    false    244                       1259    3235277 )   projects_issueduedate_project_id_ec077eb7    INDEX     q   CREATE INDEX projects_issueduedate_project_id_ec077eb7 ON public.projects_issueduedate USING btree (project_id);
 =   DROP INDEX public.projects_issueduedate_project_id_ec077eb7;
       public            taiga    false    291            �           1259    3235222 (   projects_issuestatus_project_id_1988ebf4    INDEX     o   CREATE INDEX projects_issuestatus_project_id_1988ebf4 ON public.projects_issuestatus USING btree (project_id);
 <   DROP INDEX public.projects_issuestatus_project_id_1988ebf4;
       public            taiga    false    212            �           1259    3233282 "   projects_issuestatus_slug_2c528947    INDEX     c   CREATE INDEX projects_issuestatus_slug_2c528947 ON public.projects_issuestatus USING btree (slug);
 6   DROP INDEX public.projects_issuestatus_slug_2c528947;
       public            taiga    false    212            �           1259    3233283 '   projects_issuestatus_slug_2c528947_like    INDEX     |   CREATE INDEX projects_issuestatus_slug_2c528947_like ON public.projects_issuestatus USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.projects_issuestatus_slug_2c528947_like;
       public            taiga    false    212            �           1259    3235247 &   projects_issuetype_project_id_e831e4ae    INDEX     k   CREATE INDEX projects_issuetype_project_id_e831e4ae ON public.projects_issuetype USING btree (project_id);
 :   DROP INDEX public.projects_issuetype_project_id_e831e4ae;
       public            taiga    false    213            �           1259    3236629 *   projects_membership_invited_by_id_a2c6c913    INDEX     s   CREATE INDEX projects_membership_invited_by_id_a2c6c913 ON public.projects_membership USING btree (invited_by_id);
 >   DROP INDEX public.projects_membership_invited_by_id_a2c6c913;
       public            taiga    false    210            �           1259    3235295 '   projects_membership_project_id_5f65bf3f    INDEX     m   CREATE INDEX projects_membership_project_id_5f65bf3f ON public.projects_membership USING btree (project_id);
 ;   DROP INDEX public.projects_membership_project_id_5f65bf3f;
       public            taiga    false    210            �           1259    3236537 $   projects_membership_role_id_c4bd36ef    INDEX     g   CREATE INDEX projects_membership_role_id_c4bd36ef ON public.projects_membership USING btree (role_id);
 8   DROP INDEX public.projects_membership_role_id_c4bd36ef;
       public            taiga    false    210            �           1259    3236616 $   projects_membership_user_id_13374535    INDEX     g   CREATE INDEX projects_membership_user_id_13374535 ON public.projects_membership USING btree (user_id);
 8   DROP INDEX public.projects_membership_user_id_13374535;
       public            taiga    false    210            �           1259    3235286 #   projects_points_project_id_3b8f7b42    INDEX     e   CREATE INDEX projects_points_project_id_3b8f7b42 ON public.projects_points USING btree (project_id);
 7   DROP INDEX public.projects_points_project_id_3b8f7b42;
       public            taiga    false    214            �           1259    3235256 %   projects_priority_project_id_936c75b2    INDEX     i   CREATE INDEX projects_priority_project_id_936c75b2 ON public.projects_priority USING btree (project_id);
 9   DROP INDEX public.projects_priority_project_id_936c75b2;
       public            taiga    false    215            �           1259    3235811 .   projects_project_creation_template_id_b5a97819    INDEX     {   CREATE INDEX projects_project_creation_template_id_b5a97819 ON public.projects_project USING btree (creation_template_id);
 B   DROP INDEX public.projects_project_creation_template_id_b5a97819;
       public            taiga    false    211            �           1259    3233512 (   projects_project_epics_csv_uuid_cb50f2ee    INDEX     o   CREATE INDEX projects_project_epics_csv_uuid_cb50f2ee ON public.projects_project USING btree (epics_csv_uuid);
 <   DROP INDEX public.projects_project_epics_csv_uuid_cb50f2ee;
       public            taiga    false    211            �           1259    3233513 -   projects_project_epics_csv_uuid_cb50f2ee_like    INDEX     �   CREATE INDEX projects_project_epics_csv_uuid_cb50f2ee_like ON public.projects_project USING btree (epics_csv_uuid varchar_pattern_ops);
 A   DROP INDEX public.projects_project_epics_csv_uuid_cb50f2ee_like;
       public            taiga    false    211            �           1259    3233316 )   projects_project_issues_csv_uuid_e6a84723    INDEX     q   CREATE INDEX projects_project_issues_csv_uuid_e6a84723 ON public.projects_project USING btree (issues_csv_uuid);
 =   DROP INDEX public.projects_project_issues_csv_uuid_e6a84723;
       public            taiga    false    211            �           1259    3233317 .   projects_project_issues_csv_uuid_e6a84723_like    INDEX     �   CREATE INDEX projects_project_issues_csv_uuid_e6a84723_like ON public.projects_project USING btree (issues_csv_uuid varchar_pattern_ops);
 B   DROP INDEX public.projects_project_issues_csv_uuid_e6a84723_like;
       public            taiga    false    211            �           1259    3235160 %   projects_project_name_id_44f44a5f_idx    INDEX     f   CREATE INDEX projects_project_name_id_44f44a5f_idx ON public.projects_project USING btree (name, id);
 9   DROP INDEX public.projects_project_name_id_44f44a5f_idx;
       public            taiga    false    211    211            �           1259    3236642 "   projects_project_owner_id_b940de39    INDEX     c   CREATE INDEX projects_project_owner_id_b940de39 ON public.projects_project USING btree (owner_id);
 6   DROP INDEX public.projects_project_owner_id_b940de39;
       public            taiga    false    211            �           1259    3232445 #   projects_project_slug_2d50067a_like    INDEX     t   CREATE INDEX projects_project_slug_2d50067a_like ON public.projects_project USING btree (slug varchar_pattern_ops);
 7   DROP INDEX public.projects_project_slug_2d50067a_like;
       public            taiga    false    211            �           1259    3233318 (   projects_project_tasks_csv_uuid_ecd0b1b5    INDEX     o   CREATE INDEX projects_project_tasks_csv_uuid_ecd0b1b5 ON public.projects_project USING btree (tasks_csv_uuid);
 <   DROP INDEX public.projects_project_tasks_csv_uuid_ecd0b1b5;
       public            taiga    false    211            �           1259    3233319 -   projects_project_tasks_csv_uuid_ecd0b1b5_like    INDEX     �   CREATE INDEX projects_project_tasks_csv_uuid_ecd0b1b5_like ON public.projects_project USING btree (tasks_csv_uuid varchar_pattern_ops);
 A   DROP INDEX public.projects_project_tasks_csv_uuid_ecd0b1b5_like;
       public            taiga    false    211            �           1259    3234636    projects_project_textquery_idx    INDEX     �  CREATE INDEX projects_project_textquery_idx ON public.projects_project USING gin ((((setweight(to_tsvector('simple'::regconfig, (COALESCE(name, ''::character varying))::text), 'A'::"char") || setweight(to_tsvector('simple'::regconfig, COALESCE(public.inmutable_array_to_string(tags), ''::text)), 'B'::"char")) || setweight(to_tsvector('simple'::regconfig, COALESCE(description, ''::text)), 'C'::"char"))));
 2   DROP INDEX public.projects_project_textquery_idx;
       public            taiga    false    211    211    211    211    395            �           1259    3233430 (   projects_project_total_activity_edf1a486    INDEX     o   CREATE INDEX projects_project_total_activity_edf1a486 ON public.projects_project USING btree (total_activity);
 <   DROP INDEX public.projects_project_total_activity_edf1a486;
       public            taiga    false    211            �           1259    3233431 3   projects_project_total_activity_last_month_669bff3e    INDEX     �   CREATE INDEX projects_project_total_activity_last_month_669bff3e ON public.projects_project USING btree (total_activity_last_month);
 G   DROP INDEX public.projects_project_total_activity_last_month_669bff3e;
       public            taiga    false    211            �           1259    3233432 2   projects_project_total_activity_last_week_961ca1b0    INDEX     �   CREATE INDEX projects_project_total_activity_last_week_961ca1b0 ON public.projects_project USING btree (total_activity_last_week);
 F   DROP INDEX public.projects_project_total_activity_last_week_961ca1b0;
       public            taiga    false    211            �           1259    3233433 2   projects_project_total_activity_last_year_12ea6dbe    INDEX     �   CREATE INDEX projects_project_total_activity_last_year_12ea6dbe ON public.projects_project USING btree (total_activity_last_year);
 F   DROP INDEX public.projects_project_total_activity_last_year_12ea6dbe;
       public            taiga    false    211            �           1259    3233434 $   projects_project_total_fans_436fe323    INDEX     g   CREATE INDEX projects_project_total_fans_436fe323 ON public.projects_project USING btree (total_fans);
 8   DROP INDEX public.projects_project_total_fans_436fe323;
       public            taiga    false    211            �           1259    3233435 /   projects_project_total_fans_last_month_455afdbb    INDEX     }   CREATE INDEX projects_project_total_fans_last_month_455afdbb ON public.projects_project USING btree (total_fans_last_month);
 C   DROP INDEX public.projects_project_total_fans_last_month_455afdbb;
       public            taiga    false    211            �           1259    3233436 .   projects_project_total_fans_last_week_c65146b1    INDEX     {   CREATE INDEX projects_project_total_fans_last_week_c65146b1 ON public.projects_project USING btree (total_fans_last_week);
 B   DROP INDEX public.projects_project_total_fans_last_week_c65146b1;
       public            taiga    false    211            �           1259    3233437 .   projects_project_total_fans_last_year_167b29c2    INDEX     {   CREATE INDEX projects_project_total_fans_last_year_167b29c2 ON public.projects_project USING btree (total_fans_last_year);
 B   DROP INDEX public.projects_project_total_fans_last_year_167b29c2;
       public            taiga    false    211            �           1259    3233438 1   projects_project_totals_updated_datetime_1bcc5bfa    INDEX     �   CREATE INDEX projects_project_totals_updated_datetime_1bcc5bfa ON public.projects_project USING btree (totals_updated_datetime);
 E   DROP INDEX public.projects_project_totals_updated_datetime_1bcc5bfa;
       public            taiga    false    211            �           1259    3233320 .   projects_project_userstories_csv_uuid_6e83c6c1    INDEX     {   CREATE INDEX projects_project_userstories_csv_uuid_6e83c6c1 ON public.projects_project USING btree (userstories_csv_uuid);
 B   DROP INDEX public.projects_project_userstories_csv_uuid_6e83c6c1;
       public            taiga    false    211            �           1259    3233321 3   projects_project_userstories_csv_uuid_6e83c6c1_like    INDEX     �   CREATE INDEX projects_project_userstories_csv_uuid_6e83c6c1_like ON public.projects_project USING btree (userstories_csv_uuid varchar_pattern_ops);
 G   DROP INDEX public.projects_project_userstories_csv_uuid_6e83c6c1_like;
       public            taiga    false    211            �           1259    3237608 &   projects_project_workspace_id_7ea54f67    INDEX     k   CREATE INDEX projects_project_workspace_id_7ea54f67 ON public.projects_project USING btree (workspace_id);
 :   DROP INDEX public.projects_project_workspace_id_7ea54f67;
       public            taiga    false    211            �           1259    3232611 +   projects_projecttemplate_slug_2731738e_like    INDEX     �   CREATE INDEX projects_projecttemplate_slug_2731738e_like ON public.projects_projecttemplate USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_projecttemplate_slug_2731738e_like;
       public            taiga    false    216            �           1259    3235327 %   projects_severity_project_id_9ab920cd    INDEX     i   CREATE INDEX projects_severity_project_id_9ab920cd ON public.projects_severity USING btree (project_id);
 9   DROP INDEX public.projects_severity_project_id_9ab920cd;
       public            taiga    false    217            #           1259    3235265 %   projects_swimlane_project_id_06871cf8    INDEX     i   CREATE INDEX projects_swimlane_project_id_06871cf8 ON public.projects_swimlane USING btree (project_id);
 9   DROP INDEX public.projects_swimlane_project_id_06871cf8;
       public            taiga    false    294            *           1259    3236184 3   projects_swimlaneuserstorystatus_status_id_2f3fda91    INDEX     �   CREATE INDEX projects_swimlaneuserstorystatus_status_id_2f3fda91 ON public.projects_swimlaneuserstorystatus USING btree (status_id);
 G   DROP INDEX public.projects_swimlaneuserstorystatus_status_id_2f3fda91;
       public            taiga    false    295            +           1259    3235992 5   projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21    INDEX     �   CREATE INDEX projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21 ON public.projects_swimlaneuserstorystatus USING btree (swimlane_id);
 I   DROP INDEX public.projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21;
       public            taiga    false    295                       1259    3235336 (   projects_taskduedate_project_id_775d850d    INDEX     o   CREATE INDEX projects_taskduedate_project_id_775d850d ON public.projects_taskduedate USING btree (project_id);
 <   DROP INDEX public.projects_taskduedate_project_id_775d850d;
       public            taiga    false    292            �           1259    3235312 '   projects_taskstatus_project_id_8b32b2bb    INDEX     m   CREATE INDEX projects_taskstatus_project_id_8b32b2bb ON public.projects_taskstatus USING btree (project_id);
 ;   DROP INDEX public.projects_taskstatus_project_id_8b32b2bb;
       public            taiga    false    218            �           1259    3233284 !   projects_taskstatus_slug_cf358ffa    INDEX     a   CREATE INDEX projects_taskstatus_slug_cf358ffa ON public.projects_taskstatus USING btree (slug);
 5   DROP INDEX public.projects_taskstatus_slug_cf358ffa;
       public            taiga    false    218            �           1259    3233285 &   projects_taskstatus_slug_cf358ffa_like    INDEX     z   CREATE INDEX projects_taskstatus_slug_cf358ffa_like ON public.projects_taskstatus USING btree (slug varchar_pattern_ops);
 :   DROP INDEX public.projects_taskstatus_slug_cf358ffa_like;
       public            taiga    false    218                       1259    3235362 -   projects_userstoryduedate_project_id_ab7b1680    INDEX     y   CREATE INDEX projects_userstoryduedate_project_id_ab7b1680 ON public.projects_userstoryduedate USING btree (project_id);
 A   DROP INDEX public.projects_userstoryduedate_project_id_ab7b1680;
       public            taiga    false    293            �           1259    3235373 ,   projects_userstorystatus_project_id_cdf95c9c    INDEX     w   CREATE INDEX projects_userstorystatus_project_id_cdf95c9c ON public.projects_userstorystatus USING btree (project_id);
 @   DROP INDEX public.projects_userstorystatus_project_id_cdf95c9c;
       public            taiga    false    219                       1259    3233286 &   projects_userstorystatus_slug_d574ed51    INDEX     k   CREATE INDEX projects_userstorystatus_slug_d574ed51 ON public.projects_userstorystatus USING btree (slug);
 :   DROP INDEX public.projects_userstorystatus_slug_d574ed51;
       public            taiga    false    219                       1259    3233287 +   projects_userstorystatus_slug_d574ed51_like    INDEX     �   CREATE INDEX projects_userstorystatus_slug_d574ed51_like ON public.projects_userstorystatus USING btree (slug varchar_pattern_ops);
 ?   DROP INDEX public.projects_userstorystatus_slug_d574ed51_like;
       public            taiga    false    219            ,           1259    3236238 -   references_reference_content_type_id_c134e05e    INDEX     y   CREATE INDEX references_reference_content_type_id_c134e05e ON public.references_reference USING btree (content_type_id);
 A   DROP INDEX public.references_reference_content_type_id_c134e05e;
       public            taiga    false    313            /           1259    3236239 (   references_reference_project_id_00275368    INDEX     o   CREATE INDEX references_reference_project_id_00275368 ON public.references_reference USING btree (project_id);
 <   DROP INDEX public.references_reference_project_id_00275368;
       public            taiga    false    313            8           1259    3236283 0   settings_userprojectsettings_project_id_0bc686ce    INDEX        CREATE INDEX settings_userprojectsettings_project_id_0bc686ce ON public.settings_userprojectsettings USING btree (project_id);
 D   DROP INDEX public.settings_userprojectsettings_project_id_0bc686ce;
       public            taiga    false    316            ;           1259    3236952 -   settings_userprojectsettings_user_id_0e7fdc25    INDEX     y   CREATE INDEX settings_userprojectsettings_user_id_0e7fdc25 ON public.settings_userprojectsettings USING btree (user_id);
 A   DROP INDEX public.settings_userprojectsettings_user_id_0e7fdc25;
       public            taiga    false    316            e           1259    3236823 "   tasks_task_assigned_to_id_e8821f61    INDEX     c   CREATE INDEX tasks_task_assigned_to_id_e8821f61 ON public.tasks_task USING btree (assigned_to_id);
 6   DROP INDEX public.tasks_task_assigned_to_id_e8821f61;
       public            taiga    false    239            f           1259    3234491     tasks_task_milestone_id_64cc568f    INDEX     _   CREATE INDEX tasks_task_milestone_id_64cc568f ON public.tasks_task USING btree (milestone_id);
 4   DROP INDEX public.tasks_task_milestone_id_64cc568f;
       public            taiga    false    239            g           1259    3236838    tasks_task_owner_id_db3dcc3e    INDEX     W   CREATE INDEX tasks_task_owner_id_db3dcc3e ON public.tasks_task USING btree (owner_id);
 0   DROP INDEX public.tasks_task_owner_id_db3dcc3e;
       public            taiga    false    239            j           1259    3235490    tasks_task_project_id_a2815f0c    INDEX     [   CREATE INDEX tasks_task_project_id_a2815f0c ON public.tasks_task USING btree (project_id);
 2   DROP INDEX public.tasks_task_project_id_a2815f0c;
       public            taiga    false    239            k           1259    3233201    tasks_task_ref_9f55bd37    INDEX     M   CREATE INDEX tasks_task_ref_9f55bd37 ON public.tasks_task USING btree (ref);
 +   DROP INDEX public.tasks_task_ref_9f55bd37;
       public            taiga    false    239            l           1259    3236090    tasks_task_status_id_899d2b90    INDEX     Y   CREATE INDEX tasks_task_status_id_899d2b90 ON public.tasks_task USING btree (status_id);
 1   DROP INDEX public.tasks_task_status_id_899d2b90;
       public            taiga    false    239            m           1259    3237290 !   tasks_task_user_story_id_47ceaf1d    INDEX     a   CREATE INDEX tasks_task_user_story_id_47ceaf1d ON public.tasks_task USING btree (user_story_id);
 5   DROP INDEX public.tasks_task_user_story_id_47ceaf1d;
       public            taiga    false    239            y           1259    3236401    timeline_ti_content_1af26f_idx    INDEX     �   CREATE INDEX timeline_ti_content_1af26f_idx ON public.timeline_timeline USING btree (content_type_id, object_id, created DESC);
 2   DROP INDEX public.timeline_ti_content_1af26f_idx;
       public            taiga    false    242    242    242            z           1259    3236400    timeline_ti_namespa_89bca1_idx    INDEX     o   CREATE INDEX timeline_ti_namespa_89bca1_idx ON public.timeline_timeline USING btree (namespace, created DESC);
 2   DROP INDEX public.timeline_ti_namespa_89bca1_idx;
       public            taiga    false    242    242            {           1259    3233356 *   timeline_timeline_content_type_id_5731a0c6    INDEX     s   CREATE INDEX timeline_timeline_content_type_id_5731a0c6 ON public.timeline_timeline USING btree (content_type_id);
 >   DROP INDEX public.timeline_timeline_content_type_id_5731a0c6;
       public            taiga    false    242            |           1259    3236382 "   timeline_timeline_created_4e9e3a68    INDEX     c   CREATE INDEX timeline_timeline_created_4e9e3a68 ON public.timeline_timeline USING btree (created);
 6   DROP INDEX public.timeline_timeline_created_4e9e3a68;
       public            taiga    false    242            }           1259    3233355 /   timeline_timeline_data_content_type_id_0689742e    INDEX     }   CREATE INDEX timeline_timeline_data_content_type_id_0689742e ON public.timeline_timeline USING btree (data_content_type_id);
 C   DROP INDEX public.timeline_timeline_data_content_type_id_0689742e;
       public            taiga    false    242            ~           1259    3233357 %   timeline_timeline_event_type_cb2fcdb2    INDEX     i   CREATE INDEX timeline_timeline_event_type_cb2fcdb2 ON public.timeline_timeline USING btree (event_type);
 9   DROP INDEX public.timeline_timeline_event_type_cb2fcdb2;
       public            taiga    false    242                       1259    3233358 *   timeline_timeline_event_type_cb2fcdb2_like    INDEX     �   CREATE INDEX timeline_timeline_event_type_cb2fcdb2_like ON public.timeline_timeline USING btree (event_type varchar_pattern_ops);
 >   DROP INDEX public.timeline_timeline_event_type_cb2fcdb2_like;
       public            taiga    false    242            �           1259    3233360 $   timeline_timeline_namespace_26f217ed    INDEX     g   CREATE INDEX timeline_timeline_namespace_26f217ed ON public.timeline_timeline USING btree (namespace);
 8   DROP INDEX public.timeline_timeline_namespace_26f217ed;
       public            taiga    false    242            �           1259    3233361 )   timeline_timeline_namespace_26f217ed_like    INDEX     �   CREATE INDEX timeline_timeline_namespace_26f217ed_like ON public.timeline_timeline USING btree (namespace varchar_pattern_ops);
 =   DROP INDEX public.timeline_timeline_namespace_26f217ed_like;
       public            taiga    false    242            �           1259    3235505 %   timeline_timeline_project_id_58d5eadd    INDEX     i   CREATE INDEX timeline_timeline_project_id_58d5eadd ON public.timeline_timeline USING btree (project_id);
 9   DROP INDEX public.timeline_timeline_project_id_58d5eadd;
       public            taiga    false    242            >           1259    3236453 1   token_denylist_outstandingtoken_jti_70fa66b5_like    INDEX     �   CREATE INDEX token_denylist_outstandingtoken_jti_70fa66b5_like ON public.token_denylist_outstandingtoken USING btree (jti varchar_pattern_ops);
 E   DROP INDEX public.token_denylist_outstandingtoken_jti_70fa66b5_like;
       public            taiga    false    323            C           1259    3236960 0   token_denylist_outstandingtoken_user_id_c6f48986    INDEX        CREATE INDEX token_denylist_outstandingtoken_user_id_c6f48986 ON public.token_denylist_outstandingtoken USING btree (user_id);
 D   DROP INDEX public.token_denylist_outstandingtoken_user_id_c6f48986;
       public            taiga    false    323            n           1259    3233247    users_authdata_key_c3b89eef    INDEX     U   CREATE INDEX users_authdata_key_c3b89eef ON public.users_authdata USING btree (key);
 /   DROP INDEX public.users_authdata_key_c3b89eef;
       public            taiga    false    240            o           1259    3233248     users_authdata_key_c3b89eef_like    INDEX     n   CREATE INDEX users_authdata_key_c3b89eef_like ON public.users_authdata USING btree (key varchar_pattern_ops);
 4   DROP INDEX public.users_authdata_key_c3b89eef_like;
       public            taiga    false    240            t           1259    3236592    users_authdata_user_id_9625853a    INDEX     ]   CREATE INDEX users_authdata_user_id_9625853a ON public.users_authdata USING btree (user_id);
 3   DROP INDEX public.users_authdata_user_id_9625853a;
       public            taiga    false    240            �           1259    3235206    users_role_project_id_2837f877    INDEX     [   CREATE INDEX users_role_project_id_2837f877 ON public.users_role USING btree (project_id);
 2   DROP INDEX public.users_role_project_id_2837f877;
       public            taiga    false    209            �           1259    3232395    users_role_slug_ce33b471    INDEX     O   CREATE INDEX users_role_slug_ce33b471 ON public.users_role USING btree (slug);
 ,   DROP INDEX public.users_role_slug_ce33b471;
       public            taiga    false    209            �           1259    3232396    users_role_slug_ce33b471_like    INDEX     h   CREATE INDEX users_role_slug_ce33b471_like ON public.users_role USING btree (slug varchar_pattern_ops);
 1   DROP INDEX public.users_role_slug_ce33b471_like;
       public            taiga    false    209            �           1259    3232744    users_user_email_243f6e77_like    INDEX     j   CREATE INDEX users_user_email_243f6e77_like ON public.users_user USING btree (email varchar_pattern_ops);
 2   DROP INDEX public.users_user_email_243f6e77_like;
       public            taiga    false    206            �           1259    3236471    users_user_upper_idx    INDEX     ^   CREATE INDEX users_user_upper_idx ON public.users_user USING btree (upper('username'::text));
 (   DROP INDEX public.users_user_upper_idx;
       public            taiga    false    206            �           1259    3236472    users_user_upper_idx1    INDEX     \   CREATE INDEX users_user_upper_idx1 ON public.users_user USING btree (upper('email'::text));
 )   DROP INDEX public.users_user_upper_idx1;
       public            taiga    false    206            �           1259    3232747 !   users_user_username_06e46fe6_like    INDEX     p   CREATE INDEX users_user_username_06e46fe6_like ON public.users_user USING btree (username varchar_pattern_ops);
 5   DROP INDEX public.users_user_username_06e46fe6_like;
       public            taiga    false    206            �           1259    3236476    users_user_uuid_6fe513d7_like    INDEX     h   CREATE INDEX users_user_uuid_6fe513d7_like ON public.users_user USING btree (uuid varchar_pattern_ops);
 1   DROP INDEX public.users_user_uuid_6fe513d7_like;
       public            taiga    false    206            J           1259    3236500 !   users_workspacerole_slug_2db99758    INDEX     a   CREATE INDEX users_workspacerole_slug_2db99758 ON public.users_workspacerole USING btree (slug);
 5   DROP INDEX public.users_workspacerole_slug_2db99758;
       public            taiga    false    326            K           1259    3236501 &   users_workspacerole_slug_2db99758_like    INDEX     z   CREATE INDEX users_workspacerole_slug_2db99758_like ON public.users_workspacerole USING btree (slug varchar_pattern_ops);
 :   DROP INDEX public.users_workspacerole_slug_2db99758_like;
       public            taiga    false    326            N           1259    3237596 )   users_workspacerole_workspace_id_30155f00    INDEX     q   CREATE INDEX users_workspacerole_workspace_id_30155f00 ON public.users_workspacerole USING btree (workspace_id);
 =   DROP INDEX public.users_workspacerole_workspace_id_30155f00;
       public            taiga    false    326            O           1259    3237131 *   userstorage_storageentry_owner_id_c4c1ffc0    INDEX     s   CREATE INDEX userstorage_storageentry_owner_id_c4c1ffc0 ON public.userstorage_storageentry USING btree (owner_id);
 >   DROP INDEX public.userstorage_storageentry_owner_id_c4c1ffc0;
       public            taiga    false    331            5           1259    3235067 )   userstories_rolepoints_points_id_cfcc5a79    INDEX     q   CREATE INDEX userstories_rolepoints_points_id_cfcc5a79 ON public.userstories_rolepoints USING btree (points_id);
 =   DROP INDEX public.userstories_rolepoints_points_id_cfcc5a79;
       public            taiga    false    230            6           1259    3236552 '   userstories_rolepoints_role_id_94ac7663    INDEX     m   CREATE INDEX userstories_rolepoints_role_id_94ac7663 ON public.userstories_rolepoints USING btree (role_id);
 ;   DROP INDEX public.userstories_rolepoints_role_id_94ac7663;
       public            taiga    false    230            7           1259    3237271 -   userstories_rolepoints_user_story_id_ddb4c558    INDEX     y   CREATE INDEX userstories_rolepoints_user_story_id_ddb4c558 ON public.userstories_rolepoints USING btree (user_story_id);
 A   DROP INDEX public.userstories_rolepoints_user_story_id_ddb4c558;
       public            taiga    false    230            :           1259    3236742 -   userstories_userstory_assigned_to_id_5ba80653    INDEX     y   CREATE INDEX userstories_userstory_assigned_to_id_5ba80653 ON public.userstories_userstory USING btree (assigned_to_id);
 A   DROP INDEX public.userstories_userstory_assigned_to_id_5ba80653;
       public            taiga    false    231            X           1259    3237220 5   userstories_userstory_assigned_users_user_id_6de6e8a7    INDEX     �   CREATE INDEX userstories_userstory_assigned_users_user_id_6de6e8a7 ON public.userstories_userstory_assigned_users USING btree (user_id);
 I   DROP INDEX public.userstories_userstory_assigned_users_user_id_6de6e8a7;
       public            taiga    false    334            Y           1259    3237282 :   userstories_userstory_assigned_users_userstory_id_fcb98e26    INDEX     �   CREATE INDEX userstories_userstory_assigned_users_userstory_id_fcb98e26 ON public.userstories_userstory_assigned_users USING btree (userstory_id);
 N   DROP INDEX public.userstories_userstory_assigned_users_userstory_id_fcb98e26;
       public            taiga    false    334            ;           1259    3234391 6   userstories_userstory_generated_from_issue_id_afe43198    INDEX     �   CREATE INDEX userstories_userstory_generated_from_issue_id_afe43198 ON public.userstories_userstory USING btree (generated_from_issue_id);
 J   DROP INDEX public.userstories_userstory_generated_from_issue_id_afe43198;
       public            taiga    false    231            <           1259    3237226 5   userstories_userstory_generated_from_task_id_8e958d43    INDEX     �   CREATE INDEX userstories_userstory_generated_from_task_id_8e958d43 ON public.userstories_userstory USING btree (generated_from_task_id);
 I   DROP INDEX public.userstories_userstory_generated_from_task_id_8e958d43;
       public            taiga    false    231            =           1259    3234476 +   userstories_userstory_milestone_id_37f31d22    INDEX     u   CREATE INDEX userstories_userstory_milestone_id_37f31d22 ON public.userstories_userstory USING btree (milestone_id);
 ?   DROP INDEX public.userstories_userstory_milestone_id_37f31d22;
       public            taiga    false    231            >           1259    3236757 '   userstories_userstory_owner_id_df53c64e    INDEX     m   CREATE INDEX userstories_userstory_owner_id_df53c64e ON public.userstories_userstory USING btree (owner_id);
 ;   DROP INDEX public.userstories_userstory_owner_id_df53c64e;
       public            taiga    false    231            A           1259    3235432 )   userstories_userstory_project_id_03e85e9c    INDEX     q   CREATE INDEX userstories_userstory_project_id_03e85e9c ON public.userstories_userstory USING btree (project_id);
 =   DROP INDEX public.userstories_userstory_project_id_03e85e9c;
       public            taiga    false    231            B           1259    3232960 "   userstories_userstory_ref_824701c0    INDEX     c   CREATE INDEX userstories_userstory_ref_824701c0 ON public.userstories_userstory USING btree (ref);
 6   DROP INDEX public.userstories_userstory_ref_824701c0;
       public            taiga    false    231            C           1259    3236192 (   userstories_userstory_status_id_858671dd    INDEX     o   CREATE INDEX userstories_userstory_status_id_858671dd ON public.userstories_userstory USING btree (status_id);
 <   DROP INDEX public.userstories_userstory_status_id_858671dd;
       public            taiga    false    231            D           1259    3237232 *   userstories_userstory_swimlane_id_8ecab79d    INDEX     s   CREATE INDEX userstories_userstory_swimlane_id_8ecab79d ON public.userstories_userstory USING btree (swimlane_id);
 >   DROP INDEX public.userstories_userstory_swimlane_id_8ecab79d;
       public            taiga    false    231            Z           1259    3237380 #   votes_vote_content_type_id_c8375fe1    INDEX     e   CREATE INDEX votes_vote_content_type_id_c8375fe1 ON public.votes_vote USING btree (content_type_id);
 7   DROP INDEX public.votes_vote_content_type_id_c8375fe1;
       public            taiga    false    337            _           1259    3237381    votes_vote_user_id_24a74629    INDEX     U   CREATE INDEX votes_vote_user_id_24a74629 ON public.votes_vote USING btree (user_id);
 /   DROP INDEX public.votes_vote_user_id_24a74629;
       public            taiga    false    337            `           1259    3237387 $   votes_votes_content_type_id_29583576    INDEX     g   CREATE INDEX votes_votes_content_type_id_29583576 ON public.votes_votes USING btree (content_type_id);
 8   DROP INDEX public.votes_votes_content_type_id_29583576;
       public            taiga    false    338            g           1259    3237441 $   webhooks_webhook_project_id_76846b5e    INDEX     g   CREATE INDEX webhooks_webhook_project_id_76846b5e ON public.webhooks_webhook USING btree (project_id);
 8   DROP INDEX public.webhooks_webhook_project_id_76846b5e;
       public            taiga    false    341            j           1259    3237475 '   webhooks_webhooklog_webhook_id_646c2008    INDEX     m   CREATE INDEX webhooks_webhooklog_webhook_id_646c2008 ON public.webhooks_webhooklog USING btree (webhook_id);
 ;   DROP INDEX public.webhooks_webhooklog_webhook_id_646c2008;
       public            taiga    false    342            �           1259    3233632    wiki_wikilink_href_46ee8855    INDEX     U   CREATE INDEX wiki_wikilink_href_46ee8855 ON public.wiki_wikilink USING btree (href);
 /   DROP INDEX public.wiki_wikilink_href_46ee8855;
       public            taiga    false    247            �           1259    3233633     wiki_wikilink_href_46ee8855_like    INDEX     n   CREATE INDEX wiki_wikilink_href_46ee8855_like ON public.wiki_wikilink USING btree (href varchar_pattern_ops);
 4   DROP INDEX public.wiki_wikilink_href_46ee8855_like;
       public            taiga    false    247            �           1259    3235549 !   wiki_wikilink_project_id_7dc700d7    INDEX     a   CREATE INDEX wiki_wikilink_project_id_7dc700d7 ON public.wiki_wikilink USING btree (project_id);
 5   DROP INDEX public.wiki_wikilink_project_id_7dc700d7;
       public            taiga    false    247            �           1259    3236873 '   wiki_wikipage_last_modifier_id_38be071c    INDEX     m   CREATE INDEX wiki_wikipage_last_modifier_id_38be071c ON public.wiki_wikipage USING btree (last_modifier_id);
 ;   DROP INDEX public.wiki_wikipage_last_modifier_id_38be071c;
       public            taiga    false    248            �           1259    3236887    wiki_wikipage_owner_id_f1f6c5fd    INDEX     ]   CREATE INDEX wiki_wikipage_owner_id_f1f6c5fd ON public.wiki_wikipage USING btree (owner_id);
 3   DROP INDEX public.wiki_wikipage_owner_id_f1f6c5fd;
       public            taiga    false    248            �           1259    3235533 !   wiki_wikipage_project_id_03a1e2ca    INDEX     a   CREATE INDEX wiki_wikipage_project_id_03a1e2ca ON public.wiki_wikipage USING btree (project_id);
 5   DROP INDEX public.wiki_wikipage_project_id_03a1e2ca;
       public            taiga    false    248            �           1259    3233650    wiki_wikipage_slug_10d80dc1    INDEX     U   CREATE INDEX wiki_wikipage_slug_10d80dc1 ON public.wiki_wikipage USING btree (slug);
 /   DROP INDEX public.wiki_wikipage_slug_10d80dc1;
       public            taiga    false    248            �           1259    3233651     wiki_wikipage_slug_10d80dc1_like    INDEX     n   CREATE INDEX wiki_wikipage_slug_10d80dc1_like ON public.wiki_wikipage USING btree (slug varchar_pattern_ops);
 4   DROP INDEX public.wiki_wikipage_slug_10d80dc1_like;
       public            taiga    false    248                       1259    3237582 )   workspaces_workspace_name_id_69b27cd8_idx    INDEX     n   CREATE INDEX workspaces_workspace_name_id_69b27cd8_idx ON public.workspaces_workspace USING btree (name, id);
 =   DROP INDEX public.workspaces_workspace_name_id_69b27cd8_idx;
       public            taiga    false    290    290                       1259    3236941 &   workspaces_workspace_owner_id_d8b120c0    INDEX     k   CREATE INDEX workspaces_workspace_owner_id_d8b120c0 ON public.workspaces_workspace USING btree (owner_id);
 :   DROP INDEX public.workspaces_workspace_owner_id_d8b120c0;
       public            taiga    false    290                       1259    3234633 '   workspaces_workspace_slug_c37054a2_like    INDEX     |   CREATE INDEX workspaces_workspace_slug_c37054a2_like ON public.workspaces_workspace USING btree (slug varchar_pattern_ops);
 ;   DROP INDEX public.workspaces_workspace_slug_c37054a2_like;
       public            taiga    false    290            o           1259    3237575 /   workspaces_workspacemembership_user_id_091e94f3    INDEX     }   CREATE INDEX workspaces_workspacemembership_user_id_091e94f3 ON public.workspaces_workspacemembership USING btree (user_id);
 C   DROP INDEX public.workspaces_workspacemembership_user_id_091e94f3;
       public            taiga    false    347            p           1259    3237651 4   workspaces_workspacemembership_workspace_id_d634b215    INDEX     �   CREATE INDEX workspaces_workspacemembership_workspace_id_d634b215 ON public.workspaces_workspacemembership USING btree (workspace_id);
 H   DROP INDEX public.workspaces_workspacemembership_workspace_id_d634b215;
       public            taiga    false    347            q           1259    3237577 9   workspaces_workspacemembership_workspace_role_id_39c459bf    INDEX     �   CREATE INDEX workspaces_workspacemembership_workspace_role_id_39c459bf ON public.workspaces_workspacemembership USING btree (workspace_role_id);
 M   DROP INDEX public.workspaces_workspacemembership_workspace_role_id_39c459bf;
       public            taiga    false    347            �           2620    3233932 ^   custom_attributes_epiccustomattribute update_epiccustomvalues_after_remove_epiccustomattribute    TRIGGER       CREATE TRIGGER update_epiccustomvalues_after_remove_epiccustomattribute AFTER DELETE ON public.custom_attributes_epiccustomattribute FOR EACH ROW EXECUTE FUNCTION public.clean_key_in_custom_attributes_values('epic_id', 'epics_epic', 'custom_attributes_epiccustomattributesvalues');
 w   DROP TRIGGER update_epiccustomvalues_after_remove_epiccustomattribute ON public.custom_attributes_epiccustomattribute;
       public          taiga    false    258    412            �           2620    3233901 a   custom_attributes_issuecustomattribute update_issuecustomvalues_after_remove_issuecustomattribute    TRIGGER     !  CREATE TRIGGER update_issuecustomvalues_after_remove_issuecustomattribute AFTER DELETE ON public.custom_attributes_issuecustomattribute FOR EACH ROW EXECUTE FUNCTION public.clean_key_in_custom_attributes_values('issue_id', 'issues_issue', 'custom_attributes_issuecustomattributesvalues');
 z   DROP TRIGGER update_issuecustomvalues_after_remove_issuecustomattribute ON public.custom_attributes_issuecustomattribute;
       public          taiga    false    412    252            �           2620    3233741 4   epics_epic update_project_tags_colors_on_epic_insert    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_epic_insert AFTER INSERT ON public.epics_epic FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 M   DROP TRIGGER update_project_tags_colors_on_epic_insert ON public.epics_epic;
       public          taiga    false    250    398            �           2620    3233740 4   epics_epic update_project_tags_colors_on_epic_update    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_epic_update AFTER UPDATE ON public.epics_epic FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 M   DROP TRIGGER update_project_tags_colors_on_epic_update ON public.epics_epic;
       public          taiga    false    250    398            �           2620    3233477 7   issues_issue update_project_tags_colors_on_issue_insert    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_issue_insert AFTER INSERT ON public.issues_issue FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 P   DROP TRIGGER update_project_tags_colors_on_issue_insert ON public.issues_issue;
       public          taiga    false    229    398            �           2620    3233476 7   issues_issue update_project_tags_colors_on_issue_update    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_issue_update AFTER UPDATE ON public.issues_issue FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 P   DROP TRIGGER update_project_tags_colors_on_issue_update ON public.issues_issue;
       public          taiga    false    398    229            �           2620    3233475 4   tasks_task update_project_tags_colors_on_task_insert    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_task_insert AFTER INSERT ON public.tasks_task FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 M   DROP TRIGGER update_project_tags_colors_on_task_insert ON public.tasks_task;
       public          taiga    false    398    239            �           2620    3233474 4   tasks_task update_project_tags_colors_on_task_update    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_task_update AFTER UPDATE ON public.tasks_task FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 M   DROP TRIGGER update_project_tags_colors_on_task_update ON public.tasks_task;
       public          taiga    false    398    239            �           2620    3233473 D   userstories_userstory update_project_tags_colors_on_userstory_insert    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_userstory_insert AFTER INSERT ON public.userstories_userstory FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 ]   DROP TRIGGER update_project_tags_colors_on_userstory_insert ON public.userstories_userstory;
       public          taiga    false    231    398            �           2620    3233472 D   userstories_userstory update_project_tags_colors_on_userstory_update    TRIGGER     �   CREATE TRIGGER update_project_tags_colors_on_userstory_update AFTER UPDATE ON public.userstories_userstory FOR EACH ROW EXECUTE FUNCTION public.update_project_tags_colors();
 ]   DROP TRIGGER update_project_tags_colors_on_userstory_update ON public.userstories_userstory;
       public          taiga    false    231    398            �           2620    3233900 ^   custom_attributes_taskcustomattribute update_taskcustomvalues_after_remove_taskcustomattribute    TRIGGER       CREATE TRIGGER update_taskcustomvalues_after_remove_taskcustomattribute AFTER DELETE ON public.custom_attributes_taskcustomattribute FOR EACH ROW EXECUTE FUNCTION public.clean_key_in_custom_attributes_values('task_id', 'tasks_task', 'custom_attributes_taskcustomattributesvalues');
 w   DROP TRIGGER update_taskcustomvalues_after_remove_taskcustomattribute ON public.custom_attributes_taskcustomattribute;
       public          taiga    false    253    412            �           2620    3233899 j   custom_attributes_userstorycustomattribute update_userstorycustomvalues_after_remove_userstorycustomattrib    TRIGGER     <  CREATE TRIGGER update_userstorycustomvalues_after_remove_userstorycustomattrib AFTER DELETE ON public.custom_attributes_userstorycustomattribute FOR EACH ROW EXECUTE FUNCTION public.clean_key_in_custom_attributes_values('user_story_id', 'userstories_userstory', 'custom_attributes_userstorycustomattributesvalues');
 �   DROP TRIGGER update_userstorycustomvalues_after_remove_userstorycustomattrib ON public.custom_attributes_userstorycustomattribute;
       public          taiga    false    254    412            �           2606    3232643 Q   attachments_attachment attachments_attachme_content_type_id_35dd9d5d_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.attachments_attachment
    ADD CONSTRAINT attachments_attachme_content_type_id_35dd9d5d_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.attachments_attachment DROP CONSTRAINT attachments_attachme_content_type_id_35dd9d5d_fk_django_co;
       public          taiga    false    205    3460    220            �           2606    3236991 B   attachments_attachment attachments_attachment_owner_id_720defb8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.attachments_attachment
    ADD CONSTRAINT attachments_attachment_owner_id_720defb8_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.attachments_attachment DROP CONSTRAINT attachments_attachment_owner_id_720defb8_fk;
       public          taiga    false    220    3465    206            �           2606    3235697 D   attachments_attachment attachments_attachment_project_id_50714f52_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.attachments_attachment
    ADD CONSTRAINT attachments_attachment_project_id_50714f52_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.attachments_attachment DROP CONSTRAINT attachments_attachment_project_id_50714f52_fk;
       public          taiga    false    3519    220    211            �           2606    3232724 O   auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm;
       public          taiga    false    223    227    3600            �           2606    3232719 P   auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.auth_group_permissions DROP CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id;
       public          taiga    false    227    3605    225            �           2606    3232710 E   auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 o   ALTER TABLE ONLY public.auth_permission DROP CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co;
       public          taiga    false    223    205    3460            �           2606    3235742 @   contact_contactentry contact_contactentry_project_id_27bfec4e_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.contact_contactentry
    ADD CONSTRAINT contact_contactentry_project_id_27bfec4e_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.contact_contactentry DROP CONSTRAINT contact_contactentry_project_id_27bfec4e_fk;
       public          taiga    false    3519    211    245            �           2606    3237051 =   contact_contactentry contact_contactentry_user_id_f1f19c5f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.contact_contactentry
    ADD CONSTRAINT contact_contactentry_user_id_f1f19c5f_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 g   ALTER TABLE ONLY public.contact_contactentry DROP CONSTRAINT contact_contactentry_user_id_f1f19c5f_fk;
       public          taiga    false    206    3465    245            �           2606    3234263 Z   custom_attributes_epiccustomattributesvalues custom_attributes_epiccus_epic_id_d413e57a_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues
    ADD CONSTRAINT custom_attributes_epiccus_epic_id_d413e57a_fk FOREIGN KEY (epic_id) REFERENCES public.epics_epic(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattributesvalues DROP CONSTRAINT custom_attributes_epiccus_epic_id_d413e57a_fk;
       public          taiga    false    250    259    3761            �           2606    3235767 b   custom_attributes_epiccustomattribute custom_attributes_epiccustomattribute_project_id_ad2cfaa8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute
    ADD CONSTRAINT custom_attributes_epiccustomattribute_project_id_ad2cfaa8_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_epiccustomattribute DROP CONSTRAINT custom_attributes_epiccustomattribute_project_id_ad2cfaa8_fk;
       public          taiga    false    258    211    3519            �           2606    3234423 \   custom_attributes_issuecustomattributesvalues custom_attributes_issuecu_issue_id_868161f8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues
    ADD CONSTRAINT custom_attributes_issuecu_issue_id_868161f8_fk FOREIGN KEY (issue_id) REFERENCES public.issues_issue(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattributesvalues DROP CONSTRAINT custom_attributes_issuecu_issue_id_868161f8_fk;
       public          taiga    false    3628    229    255            �           2606    3235772 d   custom_attributes_issuecustomattribute custom_attributes_issuecustomattribute_project_id_3b4acff5_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute
    ADD CONSTRAINT custom_attributes_issuecustomattribute_project_id_3b4acff5_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_issuecustomattribute DROP CONSTRAINT custom_attributes_issuecustomattribute_project_id_3b4acff5_fk;
       public          taiga    false    3519    252    211            �           2606    3236359 Z   custom_attributes_taskcustomattributesvalues custom_attributes_taskcus_task_id_3d1ccf5e_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues
    ADD CONSTRAINT custom_attributes_taskcus_task_id_3d1ccf5e_fk FOREIGN KEY (task_id) REFERENCES public.tasks_task(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattributesvalues DROP CONSTRAINT custom_attributes_taskcus_task_id_3d1ccf5e_fk;
       public          taiga    false    3689    239    256            �           2606    3235777 b   custom_attributes_taskcustomattribute custom_attributes_taskcustomattribute_project_id_f0f622a8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute
    ADD CONSTRAINT custom_attributes_taskcustomattribute_project_id_f0f622a8_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_taskcustomattribute DROP CONSTRAINT custom_attributes_taskcustomattribute_project_id_f0f622a8_fk;
       public          taiga    false    211    3519    253            �           2606    3235762 [   custom_attributes_userstorycustomattribute custom_attributes_usersto_project_id_2619cf6c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute
    ADD CONSTRAINT custom_attributes_usersto_project_id_2619cf6c_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattribute DROP CONSTRAINT custom_attributes_usersto_project_id_2619cf6c_fk;
       public          taiga    false    254    3519    211            �           2606    3237342 e   custom_attributes_userstorycustomattributesvalues custom_attributes_usersto_user_story_id_99b10c43_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues
    ADD CONSTRAINT custom_attributes_usersto_user_story_id_99b10c43_fk FOREIGN KEY (user_story_id) REFERENCES public.userstories_userstory(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.custom_attributes_userstorycustomattributesvalues DROP CONSTRAINT custom_attributes_usersto_user_story_id_99b10c43_fk;
       public          taiga    false    231    3648    257            r           2606    3232372 G   django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co;
       public          taiga    false    3460    208    205            s           2606    3236976 5   django_admin_log django_admin_log_user_id_c564eba6_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 _   ALTER TABLE ONLY public.django_admin_log DROP CONSTRAINT django_admin_log_user_id_c564eba6_fk;
       public          taiga    false    3465    206    208            �           2606    3234170 N   easy_thumbnails_thumbnail easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnail
    ADD CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum FOREIGN KEY (source_id) REFERENCES public.easy_thumbnails_source(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.easy_thumbnails_thumbnail DROP CONSTRAINT easy_thumbnails_thum_source_id_5b57bc77_fk_easy_thum;
       public          taiga    false    270    272    3817            �           2606    3234192 [   easy_thumbnails_thumbnaildimensions easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum    FK CONSTRAINT     �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions
    ADD CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum FOREIGN KEY (thumbnail_id) REFERENCES public.easy_thumbnails_thumbnail(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.easy_thumbnails_thumbnaildimensions DROP CONSTRAINT easy_thumbnails_thum_thumbnail_id_c3a0c549_fk_easy_thum;
       public          taiga    false    3827    272    274            �           2606    3237066 0   epics_epic epics_epic_assigned_to_id_13e08004_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_assigned_to_id_13e08004_fk FOREIGN KEY (assigned_to_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 Z   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_assigned_to_id_13e08004_fk;
       public          taiga    false    250    206    3465            �           2606    3237071 *   epics_epic epics_epic_owner_id_b09888c4_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_owner_id_b09888c4_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 T   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_owner_id_b09888c4_fk;
       public          taiga    false    206    250    3465            �           2606    3235757 ,   epics_epic epics_epic_project_id_d98aaef7_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_project_id_d98aaef7_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 V   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_project_id_d98aaef7_fk;
       public          taiga    false    250    3519    211            �           2606    3234820 +   epics_epic epics_epic_status_id_4cf3af1a_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_epic
    ADD CONSTRAINT epics_epic_status_id_4cf3af1a_fk FOREIGN KEY (status_id) REFERENCES public.projects_epicstatus(id) DEFERRABLE INITIALLY DEFERRED;
 U   ALTER TABLE ONLY public.epics_epic DROP CONSTRAINT epics_epic_status_id_4cf3af1a_fk;
       public          taiga    false    3724    250    244            �           2606    3234258 A   epics_relateduserstory epics_relateduserstory_epic_id_57605230_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_relateduserstory
    ADD CONSTRAINT epics_relateduserstory_epic_id_57605230_fk FOREIGN KEY (epic_id) REFERENCES public.epics_epic(id) DEFERRABLE INITIALLY DEFERRED;
 k   ALTER TABLE ONLY public.epics_relateduserstory DROP CONSTRAINT epics_relateduserstory_epic_id_57605230_fk;
       public          taiga    false    250    251    3761            �           2606    3237337 G   epics_relateduserstory epics_relateduserstory_user_story_id_329a951c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.epics_relateduserstory
    ADD CONSTRAINT epics_relateduserstory_user_story_id_329a951c_fk FOREIGN KEY (user_story_id) REFERENCES public.userstories_userstory(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.epics_relateduserstory DROP CONSTRAINT epics_relateduserstory_user_story_id_329a951c_fk;
       public          taiga    false    3648    231    251            �           2606    3234303 X   external_apps_applicationtoken external_apps_applic_application_id_0e934655_fk_external_    FK CONSTRAINT     �   ALTER TABLE ONLY public.external_apps_applicationtoken
    ADD CONSTRAINT external_apps_applic_application_id_0e934655_fk_external_ FOREIGN KEY (application_id) REFERENCES public.external_apps_application(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.external_apps_applicationtoken DROP CONSTRAINT external_apps_applic_application_id_0e934655_fk_external_;
       public          taiga    false    277    278    3837            �           2606    3237076 Q   external_apps_applicationtoken external_apps_applicationtoken_user_id_6e2f1e8a_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.external_apps_applicationtoken
    ADD CONSTRAINT external_apps_applicationtoken_user_id_6e2f1e8a_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.external_apps_applicationtoken DROP CONSTRAINT external_apps_applicationtoken_user_id_6e2f1e8a_fk;
       public          taiga    false    278    206    3465            �           2606    3235727 @   history_historyentry history_historyentry_project_id_9b008f70_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.history_historyentry
    ADD CONSTRAINT history_historyentry_project_id_9b008f70_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.history_historyentry DROP CONSTRAINT history_historyentry_project_id_9b008f70_fk;
       public          taiga    false    249    3519    211            �           2606    3237001 4   issues_issue issues_issue_assigned_to_id_c6054289_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_assigned_to_id_c6054289_fk FOREIGN KEY (assigned_to_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 ^   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_assigned_to_id_c6054289_fk;
       public          taiga    false    229    206    3465            �           2606    3234506 2   issues_issue issues_issue_milestone_id_3c2695ee_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_milestone_id_3c2695ee_fk FOREIGN KEY (milestone_id) REFERENCES public.milestones_milestone(id) DEFERRABLE INITIALLY DEFERRED;
 \   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_milestone_id_3c2695ee_fk;
       public          taiga    false    3618    229    228            �           2606    3237006 .   issues_issue issues_issue_owner_id_5c361b47_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_owner_id_5c361b47_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 X   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_owner_id_5c361b47_fk;
       public          taiga    false    206    3465    229            �           2606    3235152 1   issues_issue issues_issue_priority_id_93842a93_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_priority_id_93842a93_fk FOREIGN KEY (priority_id) REFERENCES public.projects_priority(id) DEFERRABLE INITIALLY DEFERRED;
 [   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_priority_id_93842a93_fk;
       public          taiga    false    229    215    3558            �           2606    3235707 0   issues_issue issues_issue_project_id_4b0f3e2f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_project_id_4b0f3e2f_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 Z   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_project_id_4b0f3e2f_fk;
       public          taiga    false    211    229    3519            �           2606    3235928 1   issues_issue issues_issue_severity_id_695dade0_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_severity_id_695dade0_fk FOREIGN KEY (severity_id) REFERENCES public.projects_severity(id) DEFERRABLE INITIALLY DEFERRED;
 [   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_severity_id_695dade0_fk;
       public          taiga    false    217    3568    229            �           2606    3234914 /   issues_issue issues_issue_status_id_64473cf1_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_status_id_64473cf1_fk FOREIGN KEY (status_id) REFERENCES public.projects_issuestatus(id) DEFERRABLE INITIALLY DEFERRED;
 Y   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_status_id_64473cf1_fk;
       public          taiga    false    229    3539    212            �           2606    3234990 -   issues_issue issues_issue_type_id_c1063362_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.issues_issue
    ADD CONSTRAINT issues_issue_type_id_c1063362_fk FOREIGN KEY (type_id) REFERENCES public.projects_issuetype(id) DEFERRABLE INITIALLY DEFERRED;
 W   ALTER TABLE ONLY public.issues_issue DROP CONSTRAINT issues_issue_type_id_c1063362_fk;
       public          taiga    false    229    3548    213            �           2606    3233395 H   likes_like likes_like_content_type_id_8ffc2116_fk_django_content_type_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.likes_like
    ADD CONSTRAINT likes_like_content_type_id_8ffc2116_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 r   ALTER TABLE ONLY public.likes_like DROP CONSTRAINT likes_like_content_type_id_8ffc2116_fk_django_content_type_id;
       public          taiga    false    243    205    3460            �           2606    3237046 )   likes_like likes_like_user_id_aae4c421_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.likes_like
    ADD CONSTRAINT likes_like_user_id_aae4c421_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 S   ALTER TABLE ONLY public.likes_like DROP CONSTRAINT likes_like_user_id_aae4c421_fk;
       public          taiga    false    206    243    3465            �           2606    3236996 >   milestones_milestone milestones_milestone_owner_id_216ba23b_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_owner_id_216ba23b_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_owner_id_216ba23b_fk;
       public          taiga    false    228    206    3465            �           2606    3235702 @   milestones_milestone milestones_milestone_project_id_6151cb75_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.milestones_milestone
    ADD CONSTRAINT milestones_milestone_project_id_6151cb75_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.milestones_milestone DROP CONSTRAINT milestones_milestone_project_id_6151cb75_fk;
       public          taiga    false    228    211    3519            �           2606    3233706 r   notifications_historychangenotification_history_entries notifications_histor_historyentry_id_ad550852_fk_history_h    FK CONSTRAINT       ALTER TABLE ONLY public.notifications_historychangenotification_history_entries
    ADD CONSTRAINT notifications_histor_historyentry_id_ad550852_fk_history_h FOREIGN KEY (historyentry_id) REFERENCES public.history_historyentry(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.notifications_historychangenotification_history_entries DROP CONSTRAINT notifications_histor_historyentry_id_ad550852_fk_history_h;
       public          taiga    false    249    235    3756            �           2606    3235722 L   notifications_notifypolicy notifications_notifypolicy_project_id_aa5da43f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_notifypolicy
    ADD CONSTRAINT notifications_notifypolicy_project_id_aa5da43f_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.notifications_notifypolicy DROP CONSTRAINT notifications_notifypolicy_project_id_aa5da43f_fk;
       public          taiga    false    232    3519    211            �           2606    3237031 I   notifications_notifypolicy notifications_notifypolicy_user_id_2902cbeb_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_notifypolicy
    ADD CONSTRAINT notifications_notifypolicy_user_id_2902cbeb_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.notifications_notifypolicy DROP CONSTRAINT notifications_notifypolicy_user_id_2902cbeb_fk;
       public          taiga    false    206    3465    232            �           2606    3233134 P   notifications_watched notifications_watche_content_type_id_7b3ab729_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watche_content_type_id_7b3ab729_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 z   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watche_content_type_id_7b3ab729_fk_django_co;
       public          taiga    false    3460    205    238            �           2606    3235717 B   notifications_watched notifications_watched_project_id_c88baa46_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watched_project_id_c88baa46_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watched_project_id_c88baa46_fk;
       public          taiga    false    238    3519    211            �           2606    3237026 ?   notifications_watched notifications_watched_user_id_1bce1955_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_watched
    ADD CONSTRAINT notifications_watched_user_id_1bce1955_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 i   ALTER TABLE ONLY public.notifications_watched DROP CONSTRAINT notifications_watched_user_id_1bce1955_fk;
       public          taiga    false    238    3465    206            �           2606    3237021 O   notifications_webnotification notifications_webnotification_user_id_f32287d5_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.notifications_webnotification
    ADD CONSTRAINT notifications_webnotification_user_id_f32287d5_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.notifications_webnotification DROP CONSTRAINT notifications_webnotification_user_id_f32287d5_fk;
       public          taiga    false    206    3465    285            �           2606    3235682 >   projects_epicstatus projects_epicstatus_project_id_d2c43c29_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_epicstatus
    ADD CONSTRAINT projects_epicstatus_project_id_d2c43c29_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.projects_epicstatus DROP CONSTRAINT projects_epicstatus_project_id_d2c43c29_fk;
       public          taiga    false    3519    244    211            �           2606    3235652 B   projects_issueduedate projects_issueduedate_project_id_ec077eb7_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_issueduedate
    ADD CONSTRAINT projects_issueduedate_project_id_ec077eb7_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.projects_issueduedate DROP CONSTRAINT projects_issueduedate_project_id_ec077eb7_fk;
       public          taiga    false    3519    211    291            {           2606    3235627 @   projects_issuestatus projects_issuestatus_project_id_1988ebf4_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuestatus
    ADD CONSTRAINT projects_issuestatus_project_id_1988ebf4_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.projects_issuestatus DROP CONSTRAINT projects_issuestatus_project_id_1988ebf4_fk;
       public          taiga    false    212    3519    211            |           2606    3235637 <   projects_issuetype projects_issuetype_project_id_e831e4ae_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_issuetype
    ADD CONSTRAINT projects_issuetype_project_id_e831e4ae_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 f   ALTER TABLE ONLY public.projects_issuetype DROP CONSTRAINT projects_issuetype_project_id_e831e4ae_fk;
       public          taiga    false    213    211    3519            u           2606    3235662 >   projects_membership projects_membership_project_id_5f65bf3f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_project_id_5f65bf3f_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_project_id_5f65bf3f_fk;
       public          taiga    false    210    3519    211            v           2606    3236561 ;   projects_membership projects_membership_role_id_c4bd36ef_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_role_id_c4bd36ef_fk FOREIGN KEY (role_id) REFERENCES public.users_role(id) DEFERRABLE INITIALLY DEFERRED;
 e   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_role_id_c4bd36ef_fk;
       public          taiga    false    210    3479    209            w           2606    3236981 ;   projects_membership projects_membership_user_id_13374535_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_membership
    ADD CONSTRAINT projects_membership_user_id_13374535_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 e   ALTER TABLE ONLY public.projects_membership DROP CONSTRAINT projects_membership_user_id_13374535_fk;
       public          taiga    false    3465    206    210            }           2606    3235657 6   projects_points projects_points_project_id_3b8f7b42_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_points
    ADD CONSTRAINT projects_points_project_id_3b8f7b42_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 `   ALTER TABLE ONLY public.projects_points DROP CONSTRAINT projects_points_project_id_3b8f7b42_fk;
       public          taiga    false    3519    214    211            ~           2606    3235642 :   projects_priority projects_priority_project_id_936c75b2_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_priority
    ADD CONSTRAINT projects_priority_project_id_936c75b2_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.projects_priority DROP CONSTRAINT projects_priority_project_id_936c75b2_fk;
       public          taiga    false    3519    211    215            x           2606    3235852 B   projects_project projects_project_creation_template_id_b5a97819_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_creation_template_id_b5a97819_fk FOREIGN KEY (creation_template_id) REFERENCES public.projects_projecttemplate(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_creation_template_id_b5a97819_fk;
       public          taiga    false    216    3563    211            y           2606    3236986 6   projects_project projects_project_owner_id_b940de39_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_owner_id_b940de39_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 `   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_owner_id_b940de39_fk;
       public          taiga    false    3465    206    211            z           2606    3237665 :   projects_project projects_project_workspace_id_7ea54f67_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_project
    ADD CONSTRAINT projects_project_workspace_id_7ea54f67_fk FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.projects_project DROP CONSTRAINT projects_project_workspace_id_7ea54f67_fk;
       public          taiga    false    290    211    3854            �           2606    3235632 R   projects_projectmodulesconfig projects_projectmodulesconfig_project_id_eff1c253_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_projectmodulesconfig
    ADD CONSTRAINT projects_projectmodulesconfig_project_id_eff1c253_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.projects_projectmodulesconfig DROP CONSTRAINT projects_projectmodulesconfig_project_id_eff1c253_fk;
       public          taiga    false    3519    241    211                       2606    3235672 :   projects_severity projects_severity_project_id_9ab920cd_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_severity
    ADD CONSTRAINT projects_severity_project_id_9ab920cd_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.projects_severity DROP CONSTRAINT projects_severity_project_id_9ab920cd_fk;
       public          taiga    false    3519    217    211            �           2606    3235647 :   projects_swimlane projects_swimlane_project_id_06871cf8_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlane
    ADD CONSTRAINT projects_swimlane_project_id_06871cf8_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.projects_swimlane DROP CONSTRAINT projects_swimlane_project_id_06871cf8_fk;
       public          taiga    false    3519    211    294            �           2606    3236207 W   projects_swimlaneuserstorystatus projects_swimlaneuserstorystatus_status_id_2f3fda91_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus
    ADD CONSTRAINT projects_swimlaneuserstorystatus_status_id_2f3fda91_fk FOREIGN KEY (status_id) REFERENCES public.projects_userstorystatus(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus DROP CONSTRAINT projects_swimlaneuserstorystatus_status_id_2f3fda91_fk;
       public          taiga    false    3582    219    295            �           2606    3236000 Y   projects_swimlaneuserstorystatus projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus
    ADD CONSTRAINT projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21_fk FOREIGN KEY (swimlane_id) REFERENCES public.projects_swimlane(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.projects_swimlaneuserstorystatus DROP CONSTRAINT projects_swimlaneuserstorystatus_swimlane_id_1d3f2b21_fk;
       public          taiga    false    294    3874    295            �           2606    3235677 @   projects_taskduedate projects_taskduedate_project_id_775d850d_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskduedate
    ADD CONSTRAINT projects_taskduedate_project_id_775d850d_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.projects_taskduedate DROP CONSTRAINT projects_taskduedate_project_id_775d850d_fk;
       public          taiga    false    292    3519    211            �           2606    3235667 >   projects_taskstatus projects_taskstatus_project_id_8b32b2bb_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_taskstatus
    ADD CONSTRAINT projects_taskstatus_project_id_8b32b2bb_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.projects_taskstatus DROP CONSTRAINT projects_taskstatus_project_id_8b32b2bb_fk;
       public          taiga    false    211    3519    218            �           2606    3235687 J   projects_userstoryduedate projects_userstoryduedate_project_id_ab7b1680_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstoryduedate
    ADD CONSTRAINT projects_userstoryduedate_project_id_ab7b1680_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.projects_userstoryduedate DROP CONSTRAINT projects_userstoryduedate_project_id_ab7b1680_fk;
       public          taiga    false    3519    293    211            �           2606    3235692 H   projects_userstorystatus projects_userstorystatus_project_id_cdf95c9c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.projects_userstorystatus
    ADD CONSTRAINT projects_userstorystatus_project_id_cdf95c9c_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 r   ALTER TABLE ONLY public.projects_userstorystatus DROP CONSTRAINT projects_userstorystatus_project_id_cdf95c9c_fk;
       public          taiga    false    211    3519    219            �           2606    3236228 O   references_reference references_reference_content_type_id_c134e05e_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.references_reference
    ADD CONSTRAINT references_reference_content_type_id_c134e05e_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.references_reference DROP CONSTRAINT references_reference_content_type_id_c134e05e_fk_django_co;
       public          taiga    false    3460    313    205            �           2606    3236233 T   references_reference references_reference_project_id_00275368_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.references_reference
    ADD CONSTRAINT references_reference_project_id_00275368_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 ~   ALTER TABLE ONLY public.references_reference DROP CONSTRAINT references_reference_project_id_00275368_fk_projects_project_id;
       public          taiga    false    313    3519    211            �           2606    3236273 R   settings_userprojectsettings settings_userproject_project_id_0bc686ce_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.settings_userprojectsettings
    ADD CONSTRAINT settings_userproject_project_id_0bc686ce_fk_projects_ FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.settings_userprojectsettings DROP CONSTRAINT settings_userproject_project_id_0bc686ce_fk_projects_;
       public          taiga    false    3519    316    211            �           2606    3237086 M   settings_userprojectsettings settings_userprojectsettings_user_id_0e7fdc25_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.settings_userprojectsettings
    ADD CONSTRAINT settings_userprojectsettings_user_id_0e7fdc25_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 w   ALTER TABLE ONLY public.settings_userprojectsettings DROP CONSTRAINT settings_userprojectsettings_user_id_0e7fdc25_fk;
       public          taiga    false    206    3465    316            �           2606    3237036 0   tasks_task tasks_task_assigned_to_id_e8821f61_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_assigned_to_id_e8821f61_fk FOREIGN KEY (assigned_to_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 Z   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_assigned_to_id_e8821f61_fk;
       public          taiga    false    3465    239    206            �           2606    3234516 .   tasks_task tasks_task_milestone_id_64cc568f_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_milestone_id_64cc568f_fk FOREIGN KEY (milestone_id) REFERENCES public.milestones_milestone(id) DEFERRABLE INITIALLY DEFERRED;
 X   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_milestone_id_64cc568f_fk;
       public          taiga    false    228    3618    239            �           2606    3237041 *   tasks_task tasks_task_owner_id_db3dcc3e_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_owner_id_db3dcc3e_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 T   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_owner_id_db3dcc3e_fk;
       public          taiga    false    239    3465    206            �           2606    3235732 ,   tasks_task tasks_task_project_id_a2815f0c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_project_id_a2815f0c_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 V   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_project_id_a2815f0c_fk;
       public          taiga    false    3519    239    211            �           2606    3236105 +   tasks_task tasks_task_status_id_899d2b90_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_status_id_899d2b90_fk FOREIGN KEY (status_id) REFERENCES public.projects_taskstatus(id) DEFERRABLE INITIALLY DEFERRED;
 U   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_status_id_899d2b90_fk;
       public          taiga    false    218    3573    239            �           2606    3237332 /   tasks_task tasks_task_user_story_id_47ceaf1d_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.tasks_task
    ADD CONSTRAINT tasks_task_user_story_id_47ceaf1d_fk FOREIGN KEY (user_story_id) REFERENCES public.userstories_userstory(id) DEFERRABLE INITIALLY DEFERRED;
 Y   ALTER TABLE ONLY public.tasks_task DROP CONSTRAINT tasks_task_user_story_id_47ceaf1d_fk;
       public          taiga    false    231    3648    239            �           2606    3233345 I   timeline_timeline timeline_timeline_content_type_id_5731a0c6_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.timeline_timeline
    ADD CONSTRAINT timeline_timeline_content_type_id_5731a0c6_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 s   ALTER TABLE ONLY public.timeline_timeline DROP CONSTRAINT timeline_timeline_content_type_id_5731a0c6_fk_django_co;
       public          taiga    false    205    3460    242            �           2606    3233340 N   timeline_timeline timeline_timeline_data_content_type_id_0689742e_fk_django_co    FK CONSTRAINT     �   ALTER TABLE ONLY public.timeline_timeline
    ADD CONSTRAINT timeline_timeline_data_content_type_id_0689742e_fk_django_co FOREIGN KEY (data_content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 x   ALTER TABLE ONLY public.timeline_timeline DROP CONSTRAINT timeline_timeline_data_content_type_id_0689742e_fk_django_co;
       public          taiga    false    205    3460    242            �           2606    3235737 :   timeline_timeline timeline_timeline_project_id_58d5eadd_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.timeline_timeline
    ADD CONSTRAINT timeline_timeline_project_id_58d5eadd_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 d   ALTER TABLE ONLY public.timeline_timeline DROP CONSTRAINT timeline_timeline_project_id_58d5eadd_fk;
       public          taiga    false    242    3519    211            �           2606    3236455 R   token_denylist_denylistedtoken token_denylist_denyl_token_id_dca79910_fk_token_den    FK CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_denylistedtoken
    ADD CONSTRAINT token_denylist_denyl_token_id_dca79910_fk_token_den FOREIGN KEY (token_id) REFERENCES public.token_denylist_outstandingtoken(id) DEFERRABLE INITIALLY DEFERRED;
 |   ALTER TABLE ONLY public.token_denylist_denylistedtoken DROP CONSTRAINT token_denylist_denyl_token_id_dca79910_fk_token_den;
       public          taiga    false    3906    325    323            �           2606    3237091 S   token_denylist_outstandingtoken token_denylist_outstandingtoken_user_id_c6f48986_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.token_denylist_outstandingtoken
    ADD CONSTRAINT token_denylist_outstandingtoken_user_id_c6f48986_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 }   ALTER TABLE ONLY public.token_denylist_outstandingtoken DROP CONSTRAINT token_denylist_outstandingtoken_user_id_c6f48986_fk;
       public          taiga    false    206    323    3465            �           2606    3236971 1   users_authdata users_authdata_user_id_9625853a_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_authdata
    ADD CONSTRAINT users_authdata_user_id_9625853a_fk FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 [   ALTER TABLE ONLY public.users_authdata DROP CONSTRAINT users_authdata_user_id_9625853a_fk;
       public          taiga    false    3465    206    240            t           2606    3235622 ,   users_role users_role_project_id_2837f877_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_role
    ADD CONSTRAINT users_role_project_id_2837f877_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 V   ALTER TABLE ONLY public.users_role DROP CONSTRAINT users_role_project_id_2837f877_fk;
       public          taiga    false    211    3519    209            �           2606    3237660 @   users_workspacerole users_workspacerole_workspace_id_30155f00_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.users_workspacerole
    ADD CONSTRAINT users_workspacerole_workspace_id_30155f00_fk FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.users_workspacerole DROP CONSTRAINT users_workspacerole_workspace_id_30155f00_fk;
       public          taiga    false    3854    290    326            �           2606    3237126 T   userstorage_storageentry userstorage_storageentry_owner_id_c4c1ffc0_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstorage_storageentry
    ADD CONSTRAINT userstorage_storageentry_owner_id_c4c1ffc0_fk_users_user_id FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 ~   ALTER TABLE ONLY public.userstorage_storageentry DROP CONSTRAINT userstorage_storageentry_owner_id_c4c1ffc0_fk_users_user_id;
       public          taiga    false    3465    331    206            �           2606    3235076 C   userstories_rolepoints userstories_rolepoints_points_id_cfcc5a79_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_points_id_cfcc5a79_fk FOREIGN KEY (points_id) REFERENCES public.projects_points(id) DEFERRABLE INITIALLY DEFERRED;
 m   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_points_id_cfcc5a79_fk;
       public          taiga    false    3553    214    230            �           2606    3236566 A   userstories_rolepoints userstories_rolepoints_role_id_94ac7663_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_role_id_94ac7663_fk FOREIGN KEY (role_id) REFERENCES public.users_role(id) DEFERRABLE INITIALLY DEFERRED;
 k   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_role_id_94ac7663_fk;
       public          taiga    false    3479    230    209            �           2606    3237327 G   userstories_rolepoints userstories_rolepoints_user_story_id_ddb4c558_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_rolepoints
    ADD CONSTRAINT userstories_rolepoints_user_story_id_ddb4c558_fk FOREIGN KEY (user_story_id) REFERENCES public.userstories_userstory(id) DEFERRABLE INITIALLY DEFERRED;
 q   ALTER TABLE ONLY public.userstories_rolepoints DROP CONSTRAINT userstories_rolepoints_user_story_id_ddb4c558_fk;
       public          taiga    false    3648    230    231            �           2606    3237221 U   userstories_userstory userstories_userstor_generated_from_task__8e958d43_fk_tasks_tas    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstor_generated_from_task__8e958d43_fk_tasks_tas FOREIGN KEY (generated_from_task_id) REFERENCES public.tasks_task(id) DEFERRABLE INITIALLY DEFERRED;
    ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstor_generated_from_task__8e958d43_fk_tasks_tas;
       public          taiga    false    231    239    3689            �           2606    3237227 L   userstories_userstory userstories_userstor_swimlane_id_8ecab79d_fk_projects_    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstor_swimlane_id_8ecab79d_fk_projects_ FOREIGN KEY (swimlane_id) REFERENCES public.projects_swimlane(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstor_swimlane_id_8ecab79d_fk_projects_;
       public          taiga    false    231    3874    294            �           2606    3237214 W   userstories_userstory_assigned_users userstories_userstor_user_id_6de6e8a7_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory_assigned_users
    ADD CONSTRAINT userstories_userstor_user_id_6de6e8a7_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.userstories_userstory_assigned_users DROP CONSTRAINT userstories_userstor_user_id_6de6e8a7_fk_users_use;
       public          taiga    false    3465    206    334            �           2606    3237011 F   userstories_userstory userstories_userstory_assigned_to_id_5ba80653_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_assigned_to_id_5ba80653_fk FOREIGN KEY (assigned_to_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 p   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_assigned_to_id_5ba80653_fk;
       public          taiga    false    3465    231    206            �           2606    3234418 O   userstories_userstory userstories_userstory_generated_from_issue_id_afe43198_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_generated_from_issue_id_afe43198_fk FOREIGN KEY (generated_from_issue_id) REFERENCES public.issues_issue(id) DEFERRABLE INITIALLY DEFERRED;
 y   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_generated_from_issue_id_afe43198_fk;
       public          taiga    false    231    3628    229            �           2606    3234511 D   userstories_userstory userstories_userstory_milestone_id_37f31d22_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_milestone_id_37f31d22_fk FOREIGN KEY (milestone_id) REFERENCES public.milestones_milestone(id) DEFERRABLE INITIALLY DEFERRED;
 n   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_milestone_id_37f31d22_fk;
       public          taiga    false    231    3618    228            �           2606    3237016 @   userstories_userstory userstories_userstory_owner_id_df53c64e_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_owner_id_df53c64e_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 j   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_owner_id_df53c64e_fk;
       public          taiga    false    3465    231    206            �           2606    3235712 B   userstories_userstory userstories_userstory_project_id_03e85e9c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_project_id_03e85e9c_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 l   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_project_id_03e85e9c_fk;
       public          taiga    false    231    3519    211            �           2606    3236212 A   userstories_userstory userstories_userstory_status_id_858671dd_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.userstories_userstory
    ADD CONSTRAINT userstories_userstory_status_id_858671dd_fk FOREIGN KEY (status_id) REFERENCES public.projects_userstorystatus(id) DEFERRABLE INITIALLY DEFERRED;
 k   ALTER TABLE ONLY public.userstories_userstory DROP CONSTRAINT userstories_userstory_status_id_858671dd_fk;
       public          taiga    false    231    219    3582            �           2606    3237370 H   votes_vote votes_vote_content_type_id_c8375fe1_fk_django_content_type_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.votes_vote
    ADD CONSTRAINT votes_vote_content_type_id_c8375fe1_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 r   ALTER TABLE ONLY public.votes_vote DROP CONSTRAINT votes_vote_content_type_id_c8375fe1_fk_django_content_type_id;
       public          taiga    false    3460    205    337            �           2606    3237375 7   votes_vote votes_vote_user_id_24a74629_fk_users_user_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.votes_vote
    ADD CONSTRAINT votes_vote_user_id_24a74629_fk_users_user_id FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 a   ALTER TABLE ONLY public.votes_vote DROP CONSTRAINT votes_vote_user_id_24a74629_fk_users_user_id;
       public          taiga    false    337    3465    206            �           2606    3237382 J   votes_votes votes_votes_content_type_id_29583576_fk_django_content_type_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.votes_votes
    ADD CONSTRAINT votes_votes_content_type_id_29583576_fk_django_content_type_id FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;
 t   ALTER TABLE ONLY public.votes_votes DROP CONSTRAINT votes_votes_content_type_id_29583576_fk_django_content_type_id;
       public          taiga    false    3460    205    338            �           2606    3237436 L   webhooks_webhook webhooks_webhook_project_id_76846b5e_fk_projects_project_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.webhooks_webhook
    ADD CONSTRAINT webhooks_webhook_project_id_76846b5e_fk_projects_project_id FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 v   ALTER TABLE ONLY public.webhooks_webhook DROP CONSTRAINT webhooks_webhook_project_id_76846b5e_fk_projects_project_id;
       public          taiga    false    211    3519    341            �           2606    3237484 >   webhooks_webhooklog webhooks_webhooklog_webhook_id_646c2008_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.webhooks_webhooklog
    ADD CONSTRAINT webhooks_webhooklog_webhook_id_646c2008_fk FOREIGN KEY (webhook_id) REFERENCES public.webhooks_webhook(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.webhooks_webhooklog DROP CONSTRAINT webhooks_webhooklog_webhook_id_646c2008_fk;
       public          taiga    false    342    341    3942            �           2606    3235752 2   wiki_wikilink wiki_wikilink_project_id_7dc700d7_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikilink
    ADD CONSTRAINT wiki_wikilink_project_id_7dc700d7_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 \   ALTER TABLE ONLY public.wiki_wikilink DROP CONSTRAINT wiki_wikilink_project_id_7dc700d7_fk;
       public          taiga    false    247    3519    211            �           2606    3237056 8   wiki_wikipage wiki_wikipage_last_modifier_id_38be071c_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_last_modifier_id_38be071c_fk FOREIGN KEY (last_modifier_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 b   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_last_modifier_id_38be071c_fk;
       public          taiga    false    248    206    3465            �           2606    3237061 0   wiki_wikipage wiki_wikipage_owner_id_f1f6c5fd_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_owner_id_f1f6c5fd_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 Z   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_owner_id_f1f6c5fd_fk;
       public          taiga    false    3465    248    206            �           2606    3235747 2   wiki_wikipage wiki_wikipage_project_id_03a1e2ca_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.wiki_wikipage
    ADD CONSTRAINT wiki_wikipage_project_id_03a1e2ca_fk FOREIGN KEY (project_id) REFERENCES public.projects_project(id) DEFERRABLE INITIALLY DEFERRED;
 \   ALTER TABLE ONLY public.wiki_wikipage DROP CONSTRAINT wiki_wikipage_project_id_03a1e2ca_fk;
       public          taiga    false    248    211    3519            �           2606    3237081 >   workspaces_workspace workspaces_workspace_owner_id_d8b120c0_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspace
    ADD CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk FOREIGN KEY (owner_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 h   ALTER TABLE ONLY public.workspaces_workspace DROP CONSTRAINT workspaces_workspace_owner_id_d8b120c0_fk;
       public          taiga    false    290    3465    206            �           2606    3237560 Q   workspaces_workspacemembership workspaces_workspace_user_id_091e94f3_fk_users_use    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_user_id_091e94f3_fk_users_use FOREIGN KEY (user_id) REFERENCES public.users_user(id) DEFERRABLE INITIALLY DEFERRED;
 {   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_user_id_091e94f3_fk_users_use;
       public          taiga    false    3465    206    347            �           2606    3237570 [   workspaces_workspacemembership workspaces_workspace_workspace_role_id_39c459bf_fk_users_wor    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspace_workspace_role_id_39c459bf_fk_users_wor FOREIGN KEY (workspace_role_id) REFERENCES public.users_workspacerole(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspace_workspace_role_id_39c459bf_fk_users_wor;
       public          taiga    false    326    3913    347            �           2606    3237670 V   workspaces_workspacemembership workspaces_workspacemembership_workspace_id_d634b215_fk    FK CONSTRAINT     �   ALTER TABLE ONLY public.workspaces_workspacemembership
    ADD CONSTRAINT workspaces_workspacemembership_workspace_id_d634b215_fk FOREIGN KEY (workspace_id) REFERENCES public.workspaces_workspace(id) DEFERRABLE INITIALLY DEFERRED;
 �   ALTER TABLE ONLY public.workspaces_workspacemembership DROP CONSTRAINT workspaces_workspacemembership_workspace_id_d634b215_fk;
       public          taiga    false    347    3854    290                  xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   �
  xڍ��r�:���S�	nY��z�3ۙͭ�Rlu��m�l�Sy��H�8 ����E~e$!�"��p����6�/��1�׬�L��!/-u���]��eO�y\"ֵ![[��4~IrmA�	^����-+����y��Q�w�zD�w��������8_����ۘU�	ߴ���}�`���,⽃�/�ψ��
�
^?F�^k�ʋ�e���}d̻��]c�z�.xt��w���w�X�̳}̋:��w���B�{�rϮ!g�c��=�=k�c�?�RL���q����n8 &���u����1��_^���br�^�� ��_v Lm�m����=<���iX���~}^�J�iļL�ٌ�w�I���YϘ��5�?���x�.�F;�JLg%��F1��ƻi`�+�@��,�}0ι	h��G��&a%���)4�Dā�P�����P��Ș��c�����[����j�V@�m�k3I����hJJ����,)���2���x�>O�e<�ȭ5��%"2S*?<%���)!DrJf��D��y:�]a��My#�\����h�<<��va�l��ZǾ��6�� X�����XX�G�mrX,��e�.��m�?>�[V�Ր[�F$��� -r��� �n!H���$g��}��x\�­��1o��!�'w���ސ8�2����pԚm�sM~��|d�sͶ������G!Q��B ���k���vWv���u{�5�賃�1�诃��[B�Wr$��麘�e�=�:F�g���/��G��3�'�D�p���򝕵���9�r&2�"����L�����g#s~:��d����yX���p����
�����T	�(��2�05p��=��7�4��C+�����<Q0�D�P��?V�Ѵ��xn�^�|��"�"�{������"1��_D+qְ��o�>�<l;i���dp$�&>�(%�U��������T\���<>�C��=+:�������
	m@Fd�OE��!cD�(�{)��Kd g�?��1�=~6�>���6�[u���ɿ�b/�D�� x�"ޏY�"��+�x�=���ɣ<��e�6�'^T�2Ƣ��"\�X�`��Ƃ(m0^���B��!y�D��@aI�BP���4B&�m���Ʉ�[��qBau:��V&V�A�k�����]��g�4p�
1*΀�2P� !��!�
�a"mV{�s�=Ym��P4(m�J�1m+��U뗐�$^�����x�G��p�uh0�,}!I0�ea*��%1D]a�x�~|��\vòܧ��a����}yQ%��)���Ķ>es�6���)�#��J�J-oB���Z�Δr�6Ѩ\�29U�h�ܚ2r��w�\�m�2�j;��ܛ2�`m����)kqNVְ.����R�"r���ٜ��z�A�k��@B�?۬^���!��f�*���f�����֪~+��V�2��v0���eL����d��!���B����l��c���N���_2/�0�����f���7��1��p%O2:aT�L�R�,�n�ᘣM4꼓2'm���@)�0����o��i��&�m^�4��b�b�������,b��������x���ܤt��jw�����,5+��Fd{��#�4�͕)�9[_�e�������hp��u����"+�E�Wi�("�T�����^��#}��+�e�@^���[�GK�+R���9�{&͕���0�?u�g����c<e��~�G��}���d ҧ� B��}g���-�۰��h4"��d�R�,�R� b%��S:7*��aR�p���@�jw"���!Y�"�������C�����(g���/�(���O�^"������fժ������R��M��OxD�!�OxB� ;T�]	�V�\0�^��N�P{a!pc�Z�E�#+ �X��h�:f�;o���O�H�V��V��k�K� �}_P�����ө��k?,�Q��u� Q�w��l��(�~��Ms�Pu������EE��2Tk�8*ڤġz�Ģ����j���}il�p��l,e�7��V���.�p'+𥼚t���T�7k�j��6J�+B�Q�]��Ta�d�ve�1���8�fW�L�!>���p�4H-WN�y�%Y�tG���J�������t�`��`��̿"|�7 G���9����8�o�����P"�H�-�"nK+,�&�tk*s���6���t���9/eES��g�%��g��K"�����M���e�>��5��B��;*��M�����V���p/���H�L��G��CX�>�2b]?L�!ֵ	]4L���L�Ja�@�
Z�ѹL��L�1kݚG�1��
FE�"J9�Q�W]�`����8�ކ��M[�R��MeyMK�˱JD�Vy�cĴ�؁Ċ�������Ǽ�e-�x���"��Ȼ{�bWOm�=TŞ�W���F�L�!넃K'�$�$^���V�K4���N�L��V�J6�!y%y%����w�W8����X���l�"q�.���t.���в%�G",T����B<<a�Nݶ�z9f��(���x��J��+��� "p�
�+	�
`�XI �'`�N%A���y_<�%pOy)�'��_�D42Fs	�Xd�}�%>�}</o�a:g���@�󐤴��l�0%f���.5�iOw'�����f�Ⱥ�t�����t?��#��"����;��r�B;��z����b��e\�έ��:�Nny�R��&�r/�T��8��MrR�v�J��_y���$�u      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      s      xڋ���� � �      p   �  xڕUђ� }&sGT��˝�PM+���]��FE�jwf�����D8���Y��S�)�!^��5C	+����{t����l�V�U�4k̓Xv����W����������e�3z	�A%�-�7V>��}q�9�A}�P��r���;/u��c� ���U�*0�_���U�=}��[UJ?��ӟ��\�ޚ,�cv7
�V=��x~�:S-:��]=�/���T���_^�Z�1��h��(�	�o�ՀTN�8~)�t��&�o�t�2V��]�?qw	�=p��������>���=U�J��Dg�X��������i3�w��K�	]tW�U���R��@H�7�-�[�aOU=�7Ĺ'f��Hݧl�����ft�]�+?�~�f�Y���}��4f�xu����j5�&m�-k�i��T���S���
RqT���e�(\Y���v2�9kUC�M+��4S��
�ew�NQ;{�	�D|i�y����vV�o�l�H�2&CO���fg"�6�WY�e���jԼ�46A/�U�,.�H��_�0�#jm�i�._[{+`���U���bvG�n�l6!�K����4n KO=��ד�{v�5��2 �Y��I�� vnJ7+J7^}=t7M�f��r�l"���ʊ���9� [��2dJOO�� �?����      n      xڕ\�r*��}��b�'!���-Q��l�1`�����tIE���ҽ���TR^V^�\m���x�\~��B�a�L���ѿ��迄�[�ɭ�5޻��/Z}����1QD�6����\D�����"4�oX���p?�?�����n�c(K:a���*���2��~�6lߏ�[�bi�C²��)?���" Yiyig��Qڭ�N���˂m��Q�wR��%� ��^j�js�l��x�O�k�7:
J1���o�������p�|���4�wg��t&m��s(u{#��x�y뤖	�� �1� �<�'�6��9����}� !8���9��-�
+� I)D�
����v����=~�x$%l�o���ߖ��3Ha,Gk�US�9H6��xj5�xo��{���	]���b��I��bi��������?�W+��%`	W*��O����<)���װo�+K㔓Ց�a��M?7��)��i�%�F�0�?iAǯo;�6�!��i1���%:�	����9���[�P,������P�iq��8�+!sqe)?����\��s���t<����y�Y ���γ��d��p��	�ݐ��-�"%U^��BIQ��N��e0F���7��r������ߍN���v:)��)����^�����de����.uD+��ج��	���j�A��#�ewx����x9��Ɇ�����j)���W��"����Y�L�����xy�M�w�v�9����xxΌ�Z
�2gQn���^"���0��|~G�ѴD�@�$�\rN��1�Q�-�j�~�{8�vI������w.-F�9�n,�"�PÁ� ��^��t a��X��e����SiH� �?�A��5�2��D7��7}O�a;�p�{ʻc�p�Yɨ΂�%������$\Cl]�g|ھO?㎇�:Y��)������5�"oQOO��D�!�\�i��A��|���O_0���I,�}���ǳ
�&�/V��ez��I�1A�Hg/e��}J;�@H��b��V�3>i�Z�e�$���YП����0�"�s���CNt�
��n7���Ƙ�]�+��}s@�����*�)��M��A!ru����3�F�l.����c�Y�=*���N2���byoA����Ɛ~����qx��X��d�V�.���S���vr��VV�?���($i��*I/rZ��	IJqЪ����+�+(w����Y��Eq�4��*nqK�v��Ń'���Vq׉C�D N��:��������m���ȵ�op�2�� �>��#u��8�#����˧%/n��ٱ8Q�}+�\�x ��+��0�f�H`-2\͋;��O��*c�D�&���+~�KZ�t�縟�sk���/;݅;�8BT����t�C��	v�iM�PH*�l����G�dm₮������v����2v��4|w��1�{e��a6��f��v�0�:�3*�A/:���� �e3��CPw�A���:]������+QL�E�&^uP-+���Ѓ���$����u�5����ѝ�vry� �5���;-I�0x������W��?�ٴ��ө���D�2²�X�����Uv�J#<q&���T�l���ةs5.V�, �$��!��ۈ���#x�z�Atm]Ѧ�=Z�X�=�U�NSI�46e�)l� �x��"t�J�+o>JY"B ]O::�v3��c��#(�g�ۡ�Qj7�aE1z��ùV:��v3}4Z�G�(��贒Z�bi��l,x&�N+��Z	�}��@.��B�D�u6fռJ�]�\B��˼�a����sb] |���߹P�c<~L��l���k?�hNX�;>����� !�/+�tR�����������j-��N)������v䅁*��;}T�F�jh��,�"ם!:�T*���y�~��q�ʈ��We�J*ݼ���y<�+x��*s�{���1zǃha}�.��t ��\�p�.�6�^.�id��k��*��k+Bv\`��o!)Av�6�y ;�B�(4�hF��O��tU�2�ꋑ>�����������^��	٩�V��JtF�΀R���Y�B�w<��*3"�I![��2_"�DT���eM-�m��<��[�*#;�ձjszHi}�A��FiH�^���íM	��OJ� �Br#Q4 zYZ
 gKR6�fYZj�#����S`�Z�����Y+<���WF�ooQ����o�l�"������WL�u4�<�M���9����{,@p^���^/[�2v�V���S��a�饩���5m�����kd
�Q�XMkd+��� ����9UCiCN:xY��Tu�Դ��1�;m�/���:ojt��m��	��ҁU�75&g*@��a�a�x�)�iz���"�H�B�>�z�t�'o��7Q���3�P��v��G�*�k�����uvI�lp!�*(n���1=[�[Â�*'�o2��y��k��G����"g˦��D�,1�xV�Ly���J�s���\�>�i��,��5#I�\/祖"�Ԍ�2���0�l���e��e��P�ʃO[�_[�Mzo�."�/o��m��ێEź��ׯ���u0�Y�[G~BE�U�[��l4ǖ3Tp8c�iB���I䮸ԾB�e��!�A
P�Vk�$f���o�����e�F�\f��G�њ��D��ܨ�wm�����#r�#�Ry�����~ �b$�t��4&�1e�yG�BrxM#p������~��N�J��4�i��|�
),��c�Uŀ�mz=���'AY���" NtͬPX����Khc�!�-��sW+qǄV���+��ɊU"��G�B(����*T�B"o����r�^���r?��iz����L;G)�x������~6��Kbg���n5V���z" �H�=ͯGU��ٍ��>{�m�7Yǭ���=��4��_��Ã�I���1���]k�4��K���3�u�ZX,���@9ʶ�.�C��X�1��F� �J�F��c��5?��ˆr�N�Xa�%�a5`�K�V:�bI��k���Q��18�'�0Ȳ��Z#�Ȧ�|-��L(X��4���뀥Y,OZ��x�hHTĊܑ+ +h�J�u��WBE"�P�+��X*��\����0�%�S᩼�_���7���(��g��HQ��@Wʎ ��Sfb
6����ߟ/ ��?�z$����ĩ���>�ÃiB@9��6�Ɨ.�L3�\R塐�F�U�_�OB>h'K	��*or|[R����.�T�L�hM�k�`�m�w˴�bW�L��%�n��|}==L��������r<|�/�.�����RΗ"��X�������'ĩ�<g-�qt�>F��J{�B��y/}�l^(��٬;�9K�)�^�q���~<�XP{S�Aurל����0��/Q1����zy��ؾ�����%R0��P�H�}:��� �ʲX�z;���?9�-YX蘱��u�8��5�ȷ�#�戊-��'맡P��Y�m��65�e�F �`r�3�A��i�|�=���JX�.���kX�D��ig�/��ܦ�s��U2��J���ڄk�YR��Hq�� hPy�]�*��?�Q/|fj$�C�7�s��&`��,7�R�6 A�) ~r�%Q���,�3���c�fQ�8��9gC ����Жz��0�)����pܐ>�S�G�����'�~��<���(k�{L�r���_��*���{����]v=$�Ne��ɑR���Y�s<}��6ۧ)+$���¢��e\K�b�>p)P�ЪjQ��2���a�s;��A��M��+㌀庞��7�]�����gG��b ,�Z}��Y`e�G5�E��f]F�z�:���;�!�|-��N�]�	�:�)s��~������s�9�� v�̸R߹��&8�bq���S3��W���w���{�󂴒"�+_�j�J2E�FO"�b�|�w�l��Y��yr����F�e�E(x0�r��b��I{P�����g�w� �  ��ϗ����t�F"YΛ�w�5�%��
����|��e��r���q�3��,�m,�[�X�e������L�Hu��=�
�]2OА��-KM�O�N�������Ob\���",������9���ı,���j��n��3�o��te�L�J�o��T >Xc�%H�:����Ӈ�p����y�\��S�m@�t�=�:���u'˯��k�w�c�u��a=&̐�cU>�����]Q<�1.��+�}!���KzB�M���u_.&�����u_^b���i1�z�կ.�~�/Oo�DA�V� ;���M�h��aE��E�/m[���ؑex�1`�6�r�Vv�Y��]�ei�]CTt\ ��8a�>�~&�7$*gS=��8�0�sq��{����H�<]w*�J	���{���ّ�H��;#��E�qN�x�ʜ0!��AT����i�Y:�(S@j/�Ԃ�ĺ`BY�i���):r��V��mڨ�ܶf�aL��!ך��W1�L�ݾ��a��u���o&i#����A-�y���O~���,t1@[���k��'$0�._�g"�*|���~��+O�o�/@yoBy���W�#C�\�y����[��+�/�F�n��, r�P�[uN�40���QXY�B(�J�t���ʭsj� )��F�pF����� �]�f������"���tv�*���XW�F]*E�*������� ` ��
U���O ���@]�fڼ=�SQ��e�������х����ϑ�;��E�R��0������:���͠|�3"?��.U�_�xO˳(^�Pr?��.�uELXK�m)���u��(�3�
k����7ݥm.�n�o��3��W����w��}���0���]�v�ȿX<�8Wj�~~�].t�a�CЦ,�n/4˺-&&<�������A!��P�3|�x�����nq�HJ)��Ey���b����-�Z����-#b����$!��*�d������]�w�ś�0P�WK��-*��?������t����Ut'GC���:�$�8��*�	w_?������!���>l���ݍ�x�J��rhI*�� ��$eC�D��;�'�@��A"B'햝�D2��z���h��đ!����]$Wi�`�!I�8�]��n�v�ڽ�:l�P3��N�
����#@ho�l�3������2�y��0/}�J��]��s��da��e�i��D)����g��_�?�Jv      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   �  x�}�M�,�	���Vṣ+�/��C��&y<����]���E�_���^�7����Z[���{-����_���È#�j��jHsh= y�g-���iuڈ�̄9��6��"N�rR�hN<bRb�)Uf\�� �z~A��H�#P�L�zx@���v�SVj<�F�:�q��q`D��E�A�M"@RvvG�T�O�zֈ��6�T�!��2�)>�T�Ő:݄��i;DJ��C�7��۱��|�j���������k��U{����� �&=A��i�͒#R,4q-��2�  ��I�W��%r!PT=��T�F�� m�)qO@mnf�99�0�T�cr�E��|I`R�]l�7����Vj��n������R�Ҡ1#o��l���־IBގ�:����$�Y�Iz��|d-?���j<Y:��@�;��w����B�������[��&HURW%a@ڜ�^�TmP{Iqt����h7��N@P��uԥDpT���Q�߈�Jb��!)�=��+W 9Gl8�Rۓ>�dn�a�]�n�52���l0I��uI�ld���١R=�B'm��H�ñ�<�9ݾ[{��v��=����z�lA$�I��d��7 e�U�-=��$�*يH�J�R�cksoC �JA��"�[����2���>N�wp�H�x����S�| �L[�B�j�uC҅Hy�X��>���!�����jؐ�������0�R��Zck�+rxN�9Fm̓Πz������;�cn���U��8�"T�6�:��5A o?�H��%]#�:v$ *՞�D��X�e#R����+O�$/}�T��r`�l&ey�;��� i�9g�ԾY�}71��:�a�J�J�k�	B-h���z������A��'=��1�y]��!*�C��D!�G�j�앪1�^0��r������Q�/S�`���1)EP/��Uz��Ը���C�ln�H�L�z�B�8�[�i��a �MxLS��Z�;G��F��V].j��J)O[�Tb���.8�Hy�YQu3ڃ�L"9��*4�6�A&7���Rπz�dqσC��c�>dr75<w��#Q�z��<��l0���8=y����YqZÏ��})r("^NU�$��� R���G�9��7߈����ã���Os����A�V�nv*7��܉1*U��kw�$Yu�E�R/�Z�I�XZ՛�k�@(�#�C��\a�k&@i�(��*�_��e����ZL0���k��S�|nrB�J��>}_�=��z�?Ԥ
9=O�t`T�v���K] �����gݬ���w��'w6>������/5q J4D�J����^�PyC^o�c���8��&A�V��y�_�t-C}�G������
�RӀ��hbH6$$��
�*uj��Y�� VOЛt���J�����#Y����K���t{7{|VnZf�Q���j�L�kb�C遬]�˺v8�����>���M�#��*����j+�d���*u��qڝ�a&V��~�4<��Lj�:�/~�S,���F�T�n�g���g|�"��m�Q��tt_�t=#=�<�R�{W�ڔ��2�*��+�צ�,�9�g1�}��7[��y�\�*�ܨ�gI����&��}Y7�����MB�=~{鯆�������Γ�}5��h~�k�B��ݢc�/�ꜽA�kUgו/���\?O��FG�����6BIV^�J��t���
͏�8-�
�ꄬ���ABG[t��FŚ���e~v֣޶���rĪ��@�-�ue�����a�su9߸޻����+D�hc-�����0�Jէ��w��Q���TP�uw�H�/.A����ՎZ�/�X₺���Q��t�R��r��GՋ�a@������^����A�:��t���]źq9`�O�+�9"��ݸ�]��8e��V{�(����.ͯs�-T�Z�q�&���i}�5�1+վK��ŀ����cLu~��+��]S���rd�G��įx�7N��k2f�juG�nz�HZإ漴�~��yZ_k(�֣Z���u�:���v7bU�7\V�,G,�+d�mɯ���P�k'��{��U3��&*W�`��Ĩ������wQ�c�(��cݟ�1`����@���޿���H����K��TU�9U��R��z�P��R�
�5����_�Y� V�=�źq`�	�!��n��_I}���Q���R�t��n�z^UBq=*�o����wT�k���juY�{K5��māX�>A�_I}��ǇL`X���c�:��|����?��}�      �      xڋ���� � �      �      xڋ���� � �      �   �  xڕ�=�Q���W,l��}�;�ucag�dFf��95`ԧ�
����<ɥ�����OwƟ�{��~m��n��};�x��]����2M����ݗ�������t�u��O��=������t�o������~�eO�������/>=w�.�S�ʿ��{���DY���*��ٖz�f{���xH���)G4%b��L�+M�c��퉘�`Et��D��EgkZ1'���(ƕ(ұ�bM�"�D1X]lT�HǢ��Z1'���(ƕ(ұ�f�Ẻb�"�٤D��Ew��(bN�Q�+Q�cѡ�I���L9YA���TَY��ń���0Y��0/�'4a�llQ���,�6[�-��m	lQ���,�b^ڢ	�ɖ�5i�ɒ�d��E����-j��%[�K[4a��آ&m1Y�]l��h�v�-�EM�b�d�yi�&l7�[Ԥ-&K����M����I[L�l1/m��B����ɥ �����^ �c�6 i^�9_� �%�Qs
����-)sŒʌBO��yN*s���R�Q(c�
�1�Ie���q@�d��(3'�9ZR���(��@�9��ђ2�5ͣP^�e�2GK�< ���(3'�9ZR���y�;R�̜T�hI��2��[&��<�}���r��(^��	�9�ɗc-�����Q(�	6:�Ie���q@.u�2����Ie���y@*3
e�2�n�9��ђ2_�JeF��[&X�<'�9ZR���(�q�[��2GK�8 =�B�L��yN*s���R�Q(�	�=�Ie���q@�|�2n�`��T�hI��2��t�[&��<'?_p����&w?���Ӏ��=�}�����G�ܐe�2GK�8 w?�ByD
����-)�Tf���(3'�9ZR��9�Q(�\�̜T�hI���l�?��?�*�X      �   ,  x�}ױn1Eњ���wI�N���Tqa��3��U}��ڃ�m��z�<��K+��>��R>~�f^�ח����˭��nk�ZZ����������P��{=F�j��\t;i�m�b��ŰE�a��d��p3��h�����a�x�h��FOkG3NͶht�W��h4���4��i4�A����ь�F�M|���׾ZT|�36�M1O8eeP�TsF���V����2v�պu楊�X;��0U$����i����2Edֆ�L�)��6�`j�hM��ekSEn��ͫ�-��ћ7;ٛ*zS�OX~��|Ĳ�g,#z󰓽�����y���Tћ"z��{SEo���O�M�)�76ٛ*zSDo>m�7U����|�do��M�E��޲.���ޢ�bo��M���bo��M�Ǽ���Y�x����"����vFr����c�2��Qݮ�.�$��ng��+ʋ�5�����bfe};#�]�_��pg�+�5+TvD�+*�-+3���ge�;#�]�bOP�wF���?s�){�;��?t���'�`�;�Ƭof�●�      w   {  x�}�MkG���������oG�q��r�%�rp��&�>��ٙ��~�&4�J�B�~�j:����D���w5Un�^>~|�q�ӧǻ��O??����������^�{��=9�鏇���w���������$o/������K���_޿=<��ÿO/_Nzz=�{{��>_?yΗ�����ݧǯO�����\�������˃s�|�>�^ޥ\ߥ�����Z>}��ߟ^^�?=^^R��&Sm���%�o�?�������uS���1�hTηrb��6�d��{;)�gO9�˵�
��_g���(_������s�˞����3�|]~���g���1��(_o�\P���:�W��@�����5_���=���1_x��o�"(?�|�q~��%��l����W�_|~�嗐�G������4�/{�2�/&_%��k�*̯._�,�����(�n��W������w�_M~N!�]�3����3���1?�(�m���7���8������f�k��K~�����Y~?�4���B(����<��{~��M~�ȝt�/�'��2%O
�C��m�'�t �d�}��B�8�E}u�>�:�_�_�o�_��s�����V�5�V�@�
lSR``2�66�@rl �d$ؐ�R�E
�b��-H�m�A
lC���9H΃x�;!Y�(BZH�1	ɛ�OMH�}�B�Tء
ɱ��qaG.$�aH�)aR>�a4�!R�6R�@$'DJ��d�H	!��)E&RY���H�0�)��a�H�� �y�����ɚ�(��5a6�w#��T��C:R݇�H��$YAGB�bHb�H�$�2��#������!@J��$1�$M#NRsÈ������aSTRP%ɐ�����?R�$cK�K��$��䅗$ؗ�}I2&�8��09�À�����ɞ0!d�E&iT&/�$��d�Lҩ398�tMޠI
��N����LvȚLn��F^�19r<�9���c<u��c���1�G��ѣ={���џ>Fs�z��1:�p����x�����2Cw�s' O6���V�T"=Y��XlO���2�'|R�7}R��d�� �d��@ euÈ�U���S�rh
�w�V(P��@�lZ�@�	�F��*Њ��֩@9
�ʻ@({�6 P�mH��ڢ@yh��@�T�چ�]�
��@([�6$Pv�Q��
�c��A�}*P��C��.��^���@;(;��(P^ڱ@� �>(�r
�7�r���Z@�l�		��@9E��"PNX���i*PIqC�Jڇ*�T�]�!��(S���m�/P��@%�i(P��*N�L@�BvH�BnQ���0�@��y*P	e
T6�2C��(3��2#�
��`��y���0�Kp����e^��M��U�݅\��m�D��m�*���L*q'.C�ʾ(P�{q�$Pq�q��E��X����� P֡@e(+�8����(+�X��F�JY��*�0��@��a*�@9C��(g P1�*V���@e(g,P��<��xud(P��0�@��a �J��@+P.Q����x�r�
T�@�*m�I*N�\�@���47�(P��0�@��1�D�֡@eh�/�
*V�	T�@k���X�zh�
T�@�P���B��hU+І�N�-
TW�6,P=�M�Q�m(P�ڠ@����hCU'���@�ڧ�(�>���P��ځ@�
�#��h��U�T�S�jh
Tw�v(Pu��F���@�
T��B��W'W2�@%�/e�J_��*	_�T?t5S�0��LuÈ��~&a����T��h�P����$(P��4	T�MMBU+�?:����|      x   6  x�uֱ�T1����5�G�����< =B#�`(�}��Sz�i�K��Y���=n��ۘ��������{v܆����ُ��������������۽�G�e�d�	��L��2�Є�E&\���.�h$ލ�D�2D;Z��AV"�e��h%�Y�t��)��J�+Y�dee�9Z��NV"��r��h%�'Y����&vAoM�1qѴP7���U�|30��*auq�8c�W�ڥC���l����r�9[լ�t�9󜭂�)���Hg��uɀ�30��*k�d@��lU�5Pv����Ve��	eg`���|���9���U��rB���h�ʶ.���dg��mȄ�30�٪l;eB���lU�MYPv&;[�mK�����Ve�%���dg���ɂ�#\Lv�*�U.(;����v����dg{9;����Gzz��Qi{��ޅ�ޱ��8(��c�qV4(|F|�j�g\X�.L�����x��wa�w����GH}f}Ǌ��x�ڳ�c��5!�]��+�n������X�� l��.�}F9���gwzxg��{ v�~�>��O"����m      u   �  xڍZ;�-���W��P��'y^��� �ڿ��U�1��^��M�����?�?������~���~���˯�8��_����#ȅ�(��1���~  �����'§~�/�p�O=q��SK���D�+����1���?%�'[���� _�nK0��yz9a�O���Kv#��v�O��觜V����X�k�Ã^br����1���Nlb�T	,����`���*<Ax�'���o݂P�O=��HO�\C%c3��얓�S}�ԐP~�է8��VzAB�:p���� ��0|�\W�i��\\����������	,������J��S 8͑�v��@�����e����1�Ƚ��ˁ�`��ގ���]Ag��F,1�"��8�='�"B��C�C>�a,%�=�S��*q��^q�ޕ��d��&	F8.5���n�%I9p���lv����],ba㷮W�7��L4���d)�=x��.{$����E���5K���Wzr�1��C}2f�mt����$�IyM'�����z2���~��f���HG���'@W� ��5�<� ��\('5��ƍ�
�x�9�¡[� ���$F���[dt۪�<�q/��e�&V��M��q���!����S��7��`"� k��9	g�̒Xt��"��£;&�2�`<�/�n��@3�Zj�ɤ��8�mAS�O�6�~5+D6EO��ԅX�`�<KMq�)9���g�W��"��<��i�u�S��F.�T�k�)�ZN|�UÀ2�}t�{��nt��:���5�m�X||�l�:z=O.��$�|R��q��A̢��ݒ0��r�'(]���N��49���	��d#��k+�dd�������R�|�R��p����s��Y��=-��]�׸����$����ps1�����U�diG�9sz����Nμ��q��K���(�����L�Ҵ�|*�-{in!bX���.�$<z�]����1���+x��-�\�'�$h�$����[Y��
hRV��f��m%G��EeE��04OB˝����7[�]��^讂I�6�M���̖�_������EM6��.d�k{�lM��R��3�;�_d�dE�$�"��&r�Q��?��w��?�.Ns�}%.C�z�������ʕ��e�? �Y}0do�������v�v����ZY�jl���Α<22����Ҩk��E���5=c�!�����>MD���$����J8-���@kP�LB�U��c��	2��"_�B{�2Eri(��J ���8�E5�������
@B��=EqA�ֈ=�Z�{8��[�^���$���+���ZXͻ�v�y���9U��%�]���C�NXX|{ɑ̾r�>�,J�5�����8�U��l�P�n�t�3E�=�����>ܣD�W�3�/Us\g�g%�t��̑��$��9�s+�>��(��L{�M�9^*O��0��I	�H���u���lD��I�17w�r�_������huO(L�w�2��W!�lIͪ����֍Z�7�4��������Ե�"֍��W�ڻU丬c=��#�ih�ml��*}�9�C`^�>p{��GGy�*�i�S����Vn@%}s=E�;b��\�X
���-.�@���	@����`�)3B�ңy��K2"P�,���4_��Y6���X}����n�G�Ֆa*v[`eO���_U#�����U������lY=D��v��\��|7G_��c����2cw-��]��[�P��ٽ���B�a�q�:jRD�0X	C����G�)YC�ԉ�	Oz:�=���<6����YO�++��o%5�Md����#���u�{Y�{�.�v�l��#���e�.gx
���U��6�w�_?xoB���\>��-/� [�{6�^���/Ϥ$����1#s�*���8�^��fo+-d{`ͯ��xpj++���YE���C�)�d�g	��a��)�:jV$N�~} ���J�ُ�k����78��FU6q��\�o�͂��&�y����вi���Hz�Hj�gXO2 ���=T�$B_�%l_,RTb�C/ۤ�^4�;�*J��bc٢t_.���(1V�؋f�\?��{�\I,��,��8�(IAI��z��QM���d{�Æ�D�,�oP)��@	
J�%u�*�0�Z��:��~��      y   �  x�U�M��4��q{1��O��+`��@ҍd��s�c���{q��?���߿�e���?��>���g�|�:��q��g'�*�qa�?˸?�X��|?����>��,��?�ǲ~v����9�:��9�G�<��`y=���~���9�:�/�s$,��	X癠m�	�癠�g��z>g��3��s&,ϙ��}�3a�<g�r}΄�3�<t�3A�<t�L����LX��L��?�3a�<g�r}΄���	��9�G���L�5���L��g:��}΄�Rg��LXnϙ�ܟ3ay<g��|΄�3�<��g:���g�����˞n�㍥�K8��p,=�X�?�U3ՌC5�Pf��g˞q�3��gK�8���kܞq,�5�P�8T3e��q{Ʊ�=�Xz����c���3��q�f��jơ��o�<�X����l�s�)��cε�k:�sҩu�f��a'3���4ϻ��ϼ�<��'_��s�Ś�
��j@N�y���<7�'�'��'��'��'���z?��~�����Sǂ���>�.DnDp%�;\
��a�"V/r#W3r�Y6��]�6܎�z���.HpC¬H���*I���Դ�{�(n�NJpS��\�଄ٕXa�U�\iɳ���O[ī-n�-"mi�H[D�"�-�ۢ�-�����	�-��7�����E�-"m����n������-��7�����E�������j���n������-��7����%mi�H[D�Ev[t�Ew[�l��-��6ִE�-"mi�H[D�Ev[t�Ew[t�Z���^�%t[�p[��ܖ��%̶�jK���ڒ�֊W��m	ݖ6ܖ��%�-�m	�-��jK������W�����n�����w"o1�����d�~���m���:m�|�q[B���%�-�r[��ܖ0��-�ڒ�-9m�;䶄n���ܖ��%�-a�%V[r�%W[�l��[`�"^mq#mi�H[D�"�Qm���mx�����	�-��7�����E�-"m���r�Ew[�l���j�i�H[D�"�0��j���n������-��7�����i�H[D�Ev[t�Ew[�l��-��6r� �-"mi�H[D�Ev[t�Ew[t�ھc����mi�m	nKp[��ܖ0��-�ڢ��AN[��-��҆�ܖ��%�-a�E�=�\m�Ֆ���r[B���%�-�m	n��݄0��-�ڒ�-y��mP���m7rG�F�}��[9"�rD�̑}7G����st��x/綄nk�5��ܖ��%�-a�%V[r�%W[�l�{�2�W[�H[D�"�����ET[d�Ew[p�eȳ�J[ī-n�-"mi�H[D�"�-��2�n������-��7�����E�- wB�Ev[t�Ew[�l���j�i�H[@�2��E�-��"�-�ۢ�-z�����j�������E�-��"�-�ۢ�-:m�߱�.C趴��%�-�m	nK�m�Ֆ\m�}�!��}�ܖ�mi�m	nKp[��ܖ0�"�.C���jKN[�
�-��҆�ܖ����f[b�%W[r�%��}�ܖ�mi�m	n��]���%̶�jK���jK�_�v(ߖ���%l�.C�&"ߘ�|e"򝉨/Mdk��k�ߛ���&�-��7�����E�-"m��m��?hu[���1��q�2�      z     x�m�1�P1����ۣ�N^��!Q N@CH��h��zRθ���>���׷�W�^^��׏��n~}{���ǟ+2��c��q}����5���2Z�M]�ݼt[�ۺ{x�M���۬��lA�i}�8��q��Ʒ��㬛��/�㬝�ٜ��<t�u�8ۤ�c~�8��q��8��S�hM�d�OH��
,#�nQ Cf���EAY�e��7d�����Q�Cr�l��6
tȢ���e�p�,�Y^�6z�b����f�Y�!�?o6�o�����]�C����sV=r������<�.�!�������U�C��ϧ����Cd~�*�!�?D���v�Y�!�?߶�����c���,��_4ۅ�̏�Cd��)�!�?D�nO�Y�!ʡͣZ���zlqm`�m��Ӆ�l0����TfyQ[��t�x*K������b�T�;c��t�x*{�'c�ty*�-ca�婬r�����sx�B��B�T�9қ8O��!�A��� �~QY�HoQ�<]tf�������R�      v      x��[[�G�|ƿ��?7���o�-���,Y��ul�u�i	hDÌ���7�if`ٳ�`.U4�'��d�*��_�=^^��vք*��]yt�-Vi9Jۖzh�����)��e���n����b�i���9��nմs7�a�&�f�"�oB���1�
��i�\���ϧ�o5ʸ��W8]���?5�u�/�F�n��S)%$-߹X�oSXM��N��O�9��(q1Y/e�j*���%�HI�c>$��d\��n2m/����l/������_�r_/ۮ��cn��ꏴl�U;MK7�
�2���(���K���W=���J��>�X��T��|U]5��0�M�1�
�9܎�@ǌXM�.jB&r&�1o�ԂS�uМ!B2�&"�����,P%U Zg#M�8lT����x�uͬ)�9V�]��Y=m�ⲍ�j������u�w:ջ��.��� �v�*�n�8`��E�Z����2�w��a�4�*�%��u���pX�4��o�Ğ�>(1�N��"R�%'�%OdLR�D��h�4�&Y�M�:��!P���*P�˖�̵��8P|�(�񬝺e�`�i�汎��*ͫn�HKD8��i��v���������Ǘ���S7�iYݶ�BYA%?Z���ǩ���Bt�.08З��(g�PB����D���!)eb���T�w�$�d=��8b�,��ā{Vm��X��f.����e�wzԻ=�G����������-WM��j��ҴjW� �Z��.cu�v�fu8� FZ���b�"✌b΃E�㰰��J�=*��!�d�zŭ�Lfǔ牐hT!3��AV�^���&1���4k+�8K�V���e�����:\��<M1O֋k��5�g��.�!F��������c������	�>��jzSE�rUwٮ�m��M����:�4G���ؠn��$�����o�l{8�>Nl|L�UlOК�����Tq�2��&ܒ�cԅ`�����LLF�̭Ֆ�̂d��)�<`��2^���6Do�~_�]�w�W��F�N���^��Wݼy|��%�]\�*`0���*u�L�^��.�Bz�&�q����@}@��B�Wy��Ƈ�ĭ:\�h�9���3��p�j��h�O8��L(7Ba2�X�DD��Ro25��**tR�i.�H�K"�<G���7
��7z���ğ۰�]*y�]��&�t��l��{�;���^��߽~3c�o�����W�����FX���׊�Ե�eH�1R�H	��ˇ��� �1�B`vY�"4�g�P�"3�3��ܖQK	��������t�)5����A2�2����2^up-yـ�0�!�����ӴMU�+��n���O}ק~�~�n��~^^8�����9��H����`�cFq1�0�ֳ�6%��J��	D�DI��������&����6�Z@���d'3�P�)C���񰣢��%��tKW ���M�f����K�Q7��}k��Z__�Z���G�i��j�$S[�\0fi�1W´��l��]�ex���yY͊���0P�Zf��F���'%1�|����*�ԋ(���*E�h`^�Y2����
2�	�q�R:1mp�=�Q��5lNo�f09�շK��lB�}��EٍܶO=��/6}�fۧ&����=�ߴ�b�6�g1c���������VP�� ���TZ�9j�wDz��H��1���·��I*�H��>L$-a`6�( �,%+iv�SLc���o�J��f' �#�CԗūR�e!�����]!���t�Fnh�o����ھ���ݫ�#��W0����i��5@�W���6����j/`a7��
d�z/��Ҕ�#ɨo�= f�F
�K����q�#	�GU�⌡�S�Ө<#�Fj]�k�&@Nr)��ٖ���ޞ�l(7о�����py�M�VF���z�PG��ďC�WS�����64iu3>|a�py$�}�8KV�|���Ɗ����Р0�ak���'�cT�E�gL�1A�tR����PkQ������?k��C�/|��Z�_��v��H[���ii:�C���uߡ�~���:z�dS<��&߸�q)գY��vs�h��A�]��^PۮxY��sq,%�	��*{@��p;����=�0-2�;�����,K�X�.�Ed�apC�90��F�$��H�	�zD��«9|̲s���o�[�T���5t�E����G}ۣ��Q_h����=\�Cӫ�����VUp�p��t�Y)�ha�|SDz�����9H	|vzd�Y��U��� ���!�@nH����ґ�8L7;����DE"!��R�A
�Jx_�|�>VZ��1���J���S(U�%Pn��xU��j(;�[��k����bG_�7ղmgՕ�³�f:�V����+�֘#5Ҿu���9O��1L��6�m����H��!�J�����$-�r��`d���D|:E�B���K_M�~>o�\_9�Sp�}�'����Qp�\_���~������T�?�v�Ž�A�<	.A����U����8r�v�K)�R�/�*@B|�N�����9b�k崏��*��QD��4��.PrJ���_��M�o�E5�pa�8xɝ��]��^�:>��f�-�O�V�
s��pٶ���ż]�.�գ�[�R�!�Sz����̌��VY�+���UH=��Kk3֊@Xݯ�:H5�3ă\S"4rQ�<��\�cL�D�&Q�4J��aJzG#?%��~�չ�����[��U6����R+���~�r��W��G��H�o���"�߯��/Lt�f�k�q�M�K�V7�z٥i��q�@�֪���a����c0��ӳ�)@����X��(�W�ET�	p��sL0'M ��y�U�H�R2�x�"1�1�a�[jD'`��k_lx�l/��B��zCwӭ�{�_4�T�i�>T6����f�z5{<��-������a���r0 tX��� :E�j�CB����Ș�l	q�ȝ F��yV�
;��#0�AA$pQ4����!���5�Ē ��>��'<�- ��D���]z���g�G?Bmͫ����@��f�YG���o�iՆ>�B�G�L������p@�F�޽�Xf)��.���zږ�� ��B5k���LQ�v��0�*������)��S��.ǩ�����ԛ��o^>����觛�r�]YyX!�L���]6�"�7����M{�|�oX�F��^u�~1b\=q��7�ǘ6���W(�x�e�����b,S��*����\3�j\����f�u�n�j[���\�3���>dC��z�,�8�8:_ϫ�0sg�U_W�J�i��X>��0`���%�v�æC��R�g�8�U�6yvU1�_o�Ś�y��;\U�M������(�b&�jN���بF�<�8pTshq/'0� ��RC8��e&��GK�tQ�L�,e"������V��2'\�Ɇ7�FІb���峴,��&Hٻ�zq�P��9�l��h��U�x�a�@.��K�Q���M��JWw(���������ݗ���QV��4M�T������l�)����u�n��/�O�χ����O�g�-��B�d������:��W���M���$�VM�D��"\ó8���!�,D*~RBn�	��"GD�}�p�ÛnJz[���&�6/���i�K;Mݨۼ���U��.����٫2?�}��MY�3�R�|�)�hz�U����Dݲ*E��\����Ľ;25F��Q�7���Қ}kɠ��$��iN��Y��	��DA@i�D@���lN���j���*7�통�B�x[��ۚ��_�wݯ�QBH�w]�5�/��-Z�ڬ��a��8۾��R��Vc@+�[�3�Za�gp��i"Y�W'��L[xzo5I�)��^y�=��3n�ز���6���-��{������v[}�v���t���۴k>k�٘%�^�5 �/HpT
��3{_����+A��j�38FH���2+O��D�7�Yo#�����ś�s������Y]w�ӮoA�o�S<x��1}ĔmZ����3|�Ҳ~��x��K]p�ɓΞ�s��� m  ����:�bʔʀ�d.���ӑ�W��F^�����ٓ����ȟ�:r��Xԕ2|w�ʇ	�.�5��qРA^�ȯ\��z�aV�}-�����l� x#��);����*�\b �~�1�saD�ȳ�%���[��=�> `��Y3H�������e��O�J[��QL�}�pC_I����Z֤�Āj@�P�NkE#�V��8���3R���E��˚�?9�U�ٸ�G�����*�W������V�'�?�N��½K{,�heT}Vz�c
� v��OL��q)RDc���,�K4(�˾:*2b���Qd�ABJ�Q0�?�P9�i}i]������OG���LJ!��UK��#�H�^y�A�pHht�0�srƌ���+�i�B��}9���TD]���ё�����݋������0����/DZH+r,�hU�sG����[#�R�wH��r"] lᲵ�L}����&q���T�,X%�rVG�����E��E�֗���c�"]�G�:iS���i1&L�����Q��@`+OX�Y�Ģ�C"Cµ2��P����r�"��!N���G!b?Ҍ�F���������:Ҹ,���G�o��~�H3�����B��DR�Yf�چēx�I呸Y�>�l��6�xI$�v�E�>.���T��T2Z��׿-���c�	�ͱȣ�}f�/eTӽ}�L�߼�B�TٓdB��0�=N����9sǓ"&;�A�<st;y>���r��r���v�>���y�y�,c�Q��1,�0���r& �R� 2�\�ew�عXH�	3�G���4_��:���,F=�ZB!F�!�I�� �Zy\�>����C�s�5����֯�פ[���Q-���A^�/{��o�S�k?-�מ%X�j=+��S���/����1�EI����}$ aNY�	��S�#^�����+�~/�G=��K)�Ea��ʉ��mΉ��Ò�6�	4n@�DQ��"	^P�2X?X�?�]64dZqJ��H*{m)�dp7)s�)E_O����{���H��iC��c9cǂm#�|�P�
�_�:<�B,<���K�Si��X)���iĉT����ғ�8�k˩cNjbB�m�`�̥�������O���v��whC�m������W�߾��Sy�z���aLT�Q"���h,�H(�G�-�ܢ��O�� ������T����S�N��j�o�ua5�G���\��C�<��H�CR~����d��Eo@B�����G}H�d���&�ui�7�sW��C^>��B"9���cЕNtR��{��;P��(3�Ĝ�V�c�I��Q�۳�5ல��?�5�cΉON��Ķ?a��K�t%�dI���i�BHpZ��eO� �B�#1B,������F��}kP��_�Y�l��?����z| �i������ǰޮŷ��r˅���ED(������H.-y���"���˭�@��~%&ڜ���&brR�y��H�e*��ځ@�e�Fz��9��c�B|���ŷ/O��W·L������t<sx�#��n^Ϛ��/���p}�z���?'�VJI��m�4�$]o�mu+����x���I���i��	�j
������[2��>C�`�b�� �2�<�?��z�Q�s{_�0J?D]lP7�P��v���P��v��������Ǩ�*�=��3���:����t�hӂ<Z��t��o�������\��b�h���E%@Ngh&�)���Wf�����;s}ؚ+6�a�Eݞ��߿{��u����ǜ)~�F�Ǌ1%�'�n��$�xP˘���e��'����Ѵ�����$#ɹl'1ΘD�cT;�}�o(we�2drFm��JH9��r�� u�3�������� <H�      �      xڋ���� � �      {   �  x��X�o�6~v�
�{��lO����K�&�Vt�@��`���F"U�����Ǔ%��S;풢�<�>�������e��T�����H!ERƚ���6s�8�	S���LH�ٿ���.%(�1�$\S���R��mVh&�""%4�HZ�4cz�LKƇ^l\�ȻpB�"[�����0��"\h�!��\-��ԸB`��K�f����j@�"��4ELfF"�2#B<>��Ո`֋݉�B�爥Al�̥X�/(���)�	����h�Qj{i�>ӊĥ�"�z��C/���pz�G���O������t��?>�OCo4#|D�����_��_�z���`f�S���~�U+\
���
�`WZ��	�.�ٗ�DS���^���P�xWUSu�9���w���i��ʌm3��a,2!q��ě�_P&d(�+��8
3Ni��Ȗ��e,g��x�ek5*���*����_@���^6�-�Wa�E@�t ^s̊�9@ʆ����`&�g�?q4�9"D��;a�'�����)|:H��$��[�gS� �}�r�e���Ϛ�j�,'gg/�m�_������w4+������Y�hz#�Q��9�U�\���6�~�f�ރF1h)��aj�-��V�X�QKqj+N-�i{�N�N���ȁ�{�nh����=
�v�\��]
Q��.�'�r��>��&�t�~dy�7�}�D���t_$���pw�H���nD�dz1�w��w�z�nw���n	="HX���%��w�c��P�0�B�z!�F�/3'�3�.��E�w �Y��6%�!߁3�7Us\����lqr���X���ݛ�Μ��|q�.�\\�Z`'t� ;��`�h:�׃Q��~=��´?��̳�u|�C��^�vv1��h_(ΰ;1��T��������Z���b���7le��t�L�U���rVw}h��j�{տv��+p�uT#�oE�[��Ԕ�_�&I����\�G	d���"a��ƾ���q��f\h���f���?���	{�o�"}���Y����_���}��?���9���2k�>Ib�h{woV���ޤvBWj��,y�߸(�(Ѿ������)��qr����*M�Ɂ?�z���"�E�1�9
zo(���w��Z��Lhz!����)�sd*o�Xf�́,����HN /T�Y���Ҧ�j�1��i��,H�"�)�84AsHj���߀T#S�!�/�H�Š!��T��M��+��t%�@�iǍC3ƙ9�5%L]�zQ����
S3��h��K)���Z���c	%�Z�f��'��x�0������V�fڑ��ّ��ّ��ّ�����_�lv�fGj>���	�aRs7o��;��l�f����z>Kj�p� 5���]��AGjv�fG�u��"�e�������X��      |     x�uػ�QEѸ�7���۷_�28�S'N'��h����J{W��@��R�4���}�>�i�l���o�m�q�xm���ַ��<��x����p���z�����������p���-�2\����>�8o��+}]���u-��׵8��ZL#}��D_8�t*�P��Ш���Y�LUv�h�TG���T�*;5�S�k��S���\cF�::���NEp��S:�ѹ�|v*�S��{tt���~v*�S��Щ��i�~���ԙ�Z�z@�G�!Uz����H?FX�b�*��q���X<�
bU+b-,���+�UI�\�{l,���%6��X�ka����X��ʅx���X��bU+b-,���=v��X��q�X��8@�Jb�B�������B�N��u]�y��m�rFguvf��\�{��Dw/쾠�������Lv����^خ�	��dw/���ʅ��;�ݽ�{b���Z��Lv�®�O�\ؾi�3���'�{a����dw/��,˅��;�ݽ�{b���z��F���l��gZ.�cJ�j���{������v�Cp�e&�{a��[.l��=�;�ݽ�{b�����-3�������������۽�]�\p���^�5����������۽�]��r���^�5�9����A�����۽��(z���L���������}�r�g{v���\�޴�ݙ��]�u��}�vg��vOl��v��vg��vM��h^�����Lv����K����{�|      �      xڋ���� � �      �      xڋ���� � �      �   ,  x�}ױn1Eњ���wI�N���Tqa��3��U}��ڃ�m��z�<��K+��>��R>~�f^�ח����˭��nk�ZZ����������P��{=F�j��\t;i�m�b��ŰE�a��d��p3��h�����a�x�h��FOkG3NͶht�W��h4���4��i4�A����ь�F�M|���׾ZT|�36�M1O8eeP�TsF���V����2v�պu楊�X;��0U$����i����2Edֆ�L�)��6�`j�hM��ekSEn��ͫ�-��ћ7;ٛ*zS�OX~��|Ĳ�g,#z󰓽�����y���Tћ"z��{SEo���O�M�)�76ٛ*zSDo>m�7U����|�do��M�E��޲.���ޢ�bo��M���bo��M�Ǽ���Y�x����"����vFr����c�2��Qݮ�.�$��ng��+ʋ�5�����bfe};#�]�_��pg�+�5+TvD�+*�-+3���ge�;#�]�bOP�wF���?s�){�;��?t���'�`�;�Ƭof�●�      }   �  x�}�AkGFϳ�B��tU�t�1(
��Cι�hA
Z���h�wZ�U�݌g1U��>�NX�8_��|�k�������-__��{���|�,���1懸�Ͽ��ߞ�x����ӏ��׷����}��ч��G�>���?�����������}��ky��O�s��S�g9?]<�.���I!���:������ഩ��:qv'&1qA�<q�&���a�F��#��f������b� 9�<u0A�1�K���ulc���jl�v��M.��ylҴS�?��Nbl���<6���1�K;��5�������ؐ���6io��٥�}�5�|�}�Y~�@�y�M��ۥ��ؚvic����.jl�v��]����QӮױ�O���#�]�7�I�c���[�޿:�s���O��!�����&��s7۸į��'�<4G& IiɄ5�<�lQS���L�f��K_&�]3��gn>w!���ެ��R�殼���qn>wa����Թ�ҝ����{f���g6�7f�]
4c�ʠ��~(4�܅C���I4�ҢsW�6�ã��.DZ�ͤp�*-��ri��2->wa�bpo:-���i�ܕP���0j���V�{sjܥT+殬Zm�V��]x�1ԼZAI�VDʫ�N�u4�EB�a�䩙5�>z�j+dOʭa5�S��)��� �iZ ���F��,��Ը@/S��4�)�S�uj�)�>��d��J�QA��T�8SIw��t�6��JB���UJ��p�ۀ���o�������\���� ئ�6��}�ú��W�F�R�n 	Ky�}_@�7�Ky,�_ ���� �@��(z�����$���f� ����[��72�u,�_���x���uZ ^�W��y&�������nb�<�W.kۙ���~�4���MJ�'��emb�uy�؏]�&6j���A��dbܻ�Ml/����o����A��db��MlW/�����F�r71_�L�˗�����ab�}Y�؈_�&�˓�q��6�ݿ<L�0K��� �y21n`�&�#����
fib#���t0O&�!���v	�0���,Ml�0w���ĸ�Y���a&�{���� ��Ġ��db��Q��n⸎7W��+ab2�8�7����41�&���d7qc�1��P_ \���H/`_�01�MI�=4.�LL���41�&���d7q䱀��}p�8-�/����[��V��5�8����L�pqG��n�8���M�����t:���ֻ      �   ,  x�}ױn1Eњ���wI�N���Tqa��3��U}��ڃ�m��z�<��K+��>��R>~�f^�ח����˭��nk�ZZ����������P��{=F�j��\t;i�m�b��ŰE�a��d��p3��h�����a�x�h��FOkG3NͶht�W��h4���4��i4�A����ь�F�M|���׾ZT|�36�M1O8eeP�TsF���V����2v�պu楊�X;��0U$����i����2Edֆ�L�)��6�`j�hM��ekSEn��ͫ�-��ћ7;ٛ*zS�OX~��|Ĳ�g,#z󰓽�����y���Tћ"z��{SEo���O�M�)�76ٛ*zSDo>m�7U����|�do��M�E��޲.���ޢ�bo��M���bo��M�Ǽ���Y�x����"����vFr����c�2��Qݮ�.�$��ng��+ʋ�5�����bfe};#�]�_��pg�+�5+TvD�+*�-+3���ge�;#�]�bOP�wF���?s�){�;��?t���'�`�;�Ƭof�●�      ~   9  xڅڻn7��z�Sp���[�8��Ej7F,%n�@��s�#�Ù�7K�/@���>��������!s�u�������.��~�������j�����˗.������o>�������^���������}�7ߞ�<���������o�������.q���������]��?�=���W.i�{�㯯�����#������G>�O�/m�׍o侱z����b$�G���V�3y?��ם�x�����r\�K,�p����\*�Ҋ�j��x���L�R=,e^,��R�T�RVs��rDKc[���8�foi<.-��,�pilK%�K�~�Z�^��AQ���RYa��Kk��R��4-��� )���H���J�|^�X�ܖ�-R�/U(Ry]��H�/UW�r\����X�җ�"�i)��.��H�/��H��4�D��W)������F(�����T���}�k�����J�[Ok�J�G[:�,]��M�%j���F���J:fRZv�d��H%���XJP'j���hSr}�c2�P�)c��GS�����24�Z6e)ݔ]��Ny��r��)��m�hj���OŠ�F=�*:�SYaE��
֊z@�+�
�`�ZB˫�P���Qe���bx�3�:^MU�W-����(��{uL���
�T5��1U����ث�S��j�T��ʧ?�`���`�գ��C֔U�Y-�(Xh����UN��l��p���\e^��j�Ed�52�ȷ�ZDK�*���Ы���ה[D�/}���jW0��+�8���0� �F���"��q�.b�1�E�:���"^A� ���dLc�MӼ�Tq_mV�n�^u:���:���jZ�sju8���q?�C3�]����d���+���8�[3���j�ڏ��x���K�t��#Śqo1R[3�b�k�jK��[�kO���E��ЬEG�)�(b�Z�Q�4K��Y_�c�Q\j����Y��Ҽk��jK��[�kvj����Y24m���6KX��f��l�f����fi�j�dh6�,9��m��f�Ͳ�ٮͲ�٩��R3�f��l�Yv4��,Cͤ�Y64�]�eW39�Y^i&��2�LF�[3�۬@ͤ�Y14�]�W39�YYi&��
�LF�[3�۬@ͤ�Y14�]�W39�Y]i&��*�LF�U[3�۬�;��fպUܵY��OmV�7��ͪq�8ڬ:����E���FC3�]1W39]2��f���L�Ec�5���1`��ec�4�]7_�ӅcXj����Yo3&G��͘�f�͘,���:����fLK�@�1�����,ͫ�f���4˻վf�t������Yo3fG��͘�f�͘-�F�1�����f�64+c��Y�Wc�Z��X��6c�5;��R��^�04�m��h6��LC_mh�a���L�i�J3h5�L�xY��L�6c��i�K�t����یu���6cŚ)�նfJ�j��r_mh��[�j��6��LA�qĚio3��f��AP3mm���LG�qt5S9�^i��Vc�T�j[3�y5~���Y���ڵY���:�YZ���,6K�[`s�%��x��l�f����fi�j�dh6�,;�Mm�����?0��O      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      x���[s�6� �g�S`�zJ-%i�n�M��iz:;s��h�1E*$e���w_@/�$6#�X��l��AH��O@#6Z�a�t�#��A�E8�������<�yM����#>�R"��S*�b4��#~�u�U��.K��cbc �SʞB9��K%׹��X�*�rsUa�ֹґ\�*�r�rUc��6R�\�]��`�r��:W>Bp�����"x8c�a���M��2ct0c,�d��!��[f�fLA��3V#D6ˌ���)�
o�L�"�əZ�L�̨jSz�mN5dy�!v0gN$��ֶh���OaP<��_>���s�.�hQ��o��q�x����ğ�W�<�̣$ʋ�/�����/;Ѥ_�d�?���4M�y�ɍ~M��'��й�Dy���Da���$�6���b��o&�$̃,ZQ��C~c���,�' H�4Q�H|����O4�VݑBp�1'pU�HS��9�Hi(:�UL�6)�#E�!%�B�F/�4Ͻ��Vi6_�,�~��O�Q,���l���� os��<d3�l���@��*
��!}��W���{���Ks�~"L=n1A��:o"L��
�u����0�����D�x�u�=j,��¤.լ�8��X���Y�qc��oY5k��0���G�,�������E�-W�uK[�Qu�=m=����{��*y�#�B���(ҹG��:Y:YEt7M+�N�5�{������f)�R�YΗQ��-�0��zO�\�K��u�(J�`���ut�qRN9�e�f���©5���S��&����h�Rp�wYjJy��&;uNI7}�&4m���NN~F�ѣ�8'�q��N�,k���NN��G��N��Iw8�}���W��u��i�g�M:	�~2�&Yt& _.�')2���&�<��:��>���{���~g���*m�"ɲ�L�e�ұUlZ������[�aS�a�
�F�|ݔ+R�B�~~��,M�e��b��^3��I�����-߃�cz����8qx� -f���,�lfi����a<�D \bfy�s�{	� �)
�iJ�D�|!²���%Ԃ��Q��UM��!��2�T������g=��i�),D����~�����i9|��S'�G��Uk���BGw�N�ѣ�݁G��g
�ϳPf�4�ӻ���������S���p�h�s�����f~��q8�ŵ�M�"���32_4�[��c�[�x�1���W/ý�8aR�7`�>�g�2��|����_N&a��6ՙ�	иI:��`��JD�@eh
�{���'���G���'�˱���
U�8N��������.��Ѳ�͐e}���WW����.�����/0Ҝ7�p�������^����Mn���T�W�a�k�_���Iѕn9A��Mټq��s��>���xy={X�GNg�R�<����2��:�tk���eQ���U:?(����ý���a_2&*Y>�Ƙ�3��ڗ?����)���&,�����W?�����D���*�g>����G�`14_���=��r���ո���_88`�0*;θ�� ������8>8_)1-G�8�zj���_W��Ђ�Cf���{.,{������[prp��3Z>:͕��/N����L�Q���+w}Y�'�e#�w�K�)5i�����Lo�W]��L�0��c��}��8���^���9���:M������(�,����f�9��0[M<��<]fA�&*)Ǥ��S������}�(9eQɄ*봂XNp�6��v�Qޡ��4(�D��f�Yux9�VH�ȏ���)�ª�A�BjGy��<0s
�tu�HTwqۡ-g�n��$<z\�S�d��r�J"���l�Ԏ���JxBZMƒ��Pβ�RS��s�K�D,�b���Kf�=�,�-5���;�<K�h9j/�哫���RK�Q5��}"�ڥ�*D�;>���E��$�1;��4:��r.�h8.�ɽ:�W'����{ɦ~}Ym����95�  ����͌
�dU���qd2~�ਮ�ܵ�uS�wKؚ;�~�g�����A4_��<�,���MBo���N�]O?,��{ȞűIZ���<���wA�����s�Xh��Ӥ���YvM���UTc9ʮ)�<m<5'����20����#���"V���NLmI���]j'#*�U5R�.��<��Ԝ��'J1���e��üS[�jl�׾c��Fp��
hk�e��W�����2�3�:��( �4{��Ef���-�{���t�܋��T����>��&M�Ҿ�5|��n*LB�։o�X׳h��b�.�Òl9���T�.,��AE��$�# mJ��-F��wrm�p�-����T)"��Ab�>w��"��:�N�q}��]��I�HH�KT�S�T3\E��, '�"i {i�xn��[F���F���1t'�"�!Q/-~��a��!�}����AF��Gu��]���ۈ�NK�l-��lrev ���5?(.�1�y\E�DK\n9n�zUR���S$_~����\� 2�Y'Q��k]	X�~V�?ϗ�iXl&�} ��&����WH&yu�D�9���Y�Kܒ��J�U��0҉,o����F���|0�
	B������\��jXe1+�b��d��"X!9W{W͊a/�8\>���{�#l=��h�Akd{i����rXOF�rʹڻ�~�bl(��N@�J-��r���5������� .G����P�������=�c�(%գ*XY��\��Y	�=�wu*�]�{�fu�@y���f����<�&f��d����b��['�6	����Gx����&���t�4��⦍�r	�G���RƸ�n1�i=�o�!��#b�B�0H��#N�7oB9�
fw����}Ĉ��M���#��j��a8d1¿u��fg�U�(�1�!xh
Gu����5�������U_i�<����e�Y�`�0R7}&���NZo������+�o��Yh���n�s�������y�E������b���U�[@W>����<M�m��c���j]v�6������U��=�ZW�����!���g��Nn��z�%<�H���I��r�N� M&~v.��:'��\�h�֓){Ubo+�7�ջ�5�D��df����׾�_��*Jc�~šY�h�&yt�u���2��:Gkg��ظ�&�J���[��Yw�6Լ��V��B��&!�ڽκ�����b��.c�'/���N?j�ΚS~��Ff��x>���ScLp��/b���8�Cg�GL�Js�E5!�Y����l�i/�h:Lj�����e�k^;�Cg�KLÁR"q5,ʄm���~0�q�mxh���Ss��Y��v!�ph��w���<�K���/5�T^�E�Ŧ�]�oG�p��pk|t�LZ��I���h<�c�<�Y����/Cp�sP���1�`=|̑]w��ZE�a�V zZ�4m�gu9�����P�^"?^-)e��)��b��P�^">Z-A�������a[*�Gd�ǋ��U+�[J;	�U�?�ڱv��"��pq`be�9��i�gїpΣ�e���ߴ�&�͆��u,�{uz�Vzo�������E����?ҭ#_���Y��5�S�K�f�l���r��P7��K�[X�n,&�c"�+f��Yu��6��[�Nh��K��`� �c����F���r0���z�`��* ���հ�>b�Ŗ1��[Ŭ�m���հ�^�p(�J^��eۄw���ղ��j0�\H\=�/-�b����a��-&�b+�İz�N��*���հ�vX��9j��n�Md�Fns�ŋ,�so��j��M�a�����}`V�o�[��]���y��e\<����g���OiR����e\�vϋ�XM����bp�.�<�/�Y|]�~� �i˓j��7�̶G�aw�6ּ��VC�VL��Za9��Qw�6Ҳ��6�7"�#X*��K�v7m��`�-��-�Up+dW�vԝ��4��썡��~V�kt8�n����$�����LYY?�贻i�^Z�|��fڐ�zJ�倠��Dm�{iM�!s+N�ne�|���D�ϰ�Wվ��� k  ����}�u�t��洺�Y:��<��B��� w�f5�d%[ڋ:��Jꭓz������=�?��eX�0*fai�y'ڶ�*p�9���r8��Ͱ��"�?r8	͐pv�f8�͘�N�Fa�Z��
�*�l��ub�(�}D�|�d
SB� Vu<ǵ�0�G���N&����0���*n	�k`��1<��^3ݧ"m�
��,���ů�m�S���g�?��xA� {2�V�aaV\6�W$�<��|�8sa�lz�߀E�j����.A�����,���Vy4_���ܿ<��Fc�"U� �N�r��j��5��g>6��z�~��n�p�7ߟ�4��Y�ڌ�m~ޝ�8����U^��j��:ki��<��TPU �ty��V�Y��Y�Y�*���^��G���8������snm̵���[��OB��N_��������t�9_����yi��[B���N]��"]ר������i�:1�[�6�~x^�y�P�r?>���<���4���1dU;�b}�Y�ǀ`���D��~JZ�d���;�:[s�S}��[����a�^����W?��Qʪ������*V� b<���:FZ�L�_wH:�>[Kd5H�^��1I�o�@B�TU1Blcd  ƃ�H�_/i�'���rщ�'�{I��E~���#�Fa�B6����� @��z�9��CIv�Z�	�O���(o6��/�H�b�ZPc�z�@����7���f��V�@�H�^��`�}�||��W'�cL	U����D{�j��9���Cv�����Vu߮���)���5��߁�|���q�^��.�(��Cĺ>;p,c�뺢��v.�����-����������/��)�ƘQZ-ᇉu��D����ֳ�I�pٝ�+,o������2�O����߯��;֟u�aE�������Ƅ5�s�g`��ֽ$�����v
�N�[�ZF��V�����џ���]D�"BT}Ǳ���X��{Whk�
��L��7����Y=\P����ޛg�/t����<����"e�:]�{�t�d�׷_���Zކտ�TM"��/I�<�k��g�/���n���ETs�������iO��"��[Dw;G��D������*
��o���so+�N!�.����ʯ
�*�MƇK p	p$���f7r��w�_�������hk_�����S	���J�\�6����vA�}a��q�~9��8���*�Y�m>�*��ܾ���P����lznwB��8rq�Ҡ#Z���~@����P��["o�V9Tų] �V�l�CU<������7Y B7�Yc�e��+�#�)�"���������G^�T [��P��Qv�>��8�F�q�U}~���Ǒ����{|vv�_�_�      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      t   �  x�͙Ko�@����B 3w^^�b�Ub��L=��$�@��9n(/E]��EeG�3s*��|q�yܯ���~�u�3^���|y������`zq���n��n���8�lʮ[����v}�K/���lF��eUƂ���/�n?��n,p�������t�t��~ܴ�E#D���W���<��#5OT�Gj�D��5OV���<-�'�<v�(P���%E$҄��Di�BB"�
�4a!#Å�4��E"��
�Z5���h�8�v�U� ap,��i�48���4�BCup�a!�b�AT1� # ��0��U��C�H��b,B(F@#D#��0��#�&F8x�g��^#<�SO�G��=�#<�������悺$3�5�5��C���\�yt�����c�jn���6�]�fan��cY۲3�ϳY{H�����!k^��U�8���������W�����)�܁�� ��@HY�L&HY�f:- C
�Y ���)d&)��2����C�VS&RdV`HQ��
)2+0�4e�!E�C��!0��0B�h41B��hF,ib�����zR��z��ROgK]P�X�zR5�(�D,J=�X�z���U,J=3�Q�Y��z�zf֣��ف�h���G��t���i�^f�ȣ�r{�:h����=���w�3��O�lh�V�Z�~��i����      q   	  xڕ�io"G�_��y�Z���R��c0��X��	�c�O��l`cBkhڣ�U�U�A�|C�!H|g�;QWZr��W�21cG�]�qH����8
o�jd�qGU`��KO�h`�F	� ?J��Oe.�1�Lf���ͱ��d�b�=!A��8S�[i�V;�e0Q͉��ao�Pj-WH�&� �z�Na
��03��?�?�4��.Ɉ
I�`TbM��x�)��FX�������?3�Q:\�o�b��#ʜ'�#Ɣr�y'#!�uݡ�J�����Kj��䇭L�(|��^р��A�ojjb�pǈ��G#G<2'��ͣ5�3�ɿ؊�+��:g+�!�	E<aX0Ew!��cQ�C[ѿm51��1�d��,2(�of�0l�������V�l�%rR��U�ȲY� �a�1�q�XP�kla�LP)���!r�e���@��⌭�����lE$f|��,J�TD�X���)vh+������[�Tp������K������[ud'x s�����R���a�H�p����;��y����1��r�
�����c	(>c%Lfg�D��3˱��rc�������J<�j�>��-��p�����c��T�q�n�����f�+��l:������uL�[�^SљWL�Ѹ���o��u��w*�#}���@�1~:�}����W.�����h�.L�,�����~g�;�W㿸`�c�`7�{��$�D`47L2����x�Nߨ�/�D�c�m�:	�ۦX��إ����m�T��q�u\�\1�H��b)�zJ�"�f���c�uǿ}l�-���#f|�&��z������r�K�i�1�¿#u���f�_����@�0�"�՘(壇��G���S�w5�%ۇ޳������֗�e7]<����7ݻըq���ݫra],���̋���{v@M>�c�d1��d2Z�Y��C�$�����Yn����[�!�SmQp��R{�!����Y����]�益P�>o����V���!ݏ���k�_Lv������M�d�m稘���Coӏ�8���$�fP9§��
a��8�JB]��jH��k�8��h��t�?߷7��CR��B�]*�g���e�_yqo��F�u��t𰿭����4�]��q��L;HT���c<o��fv�3��[�+
Ý��H@�:K�!�B�A�Fb��s�@�@��9F�c�o�
��b����W�*��Bv-S�˭L-�Z����ɗNW�Un��F�z��ڭ�×�����c<�n�4,.j�,$Ӱ�e.���S�Z`�ϡ;���@y���PC�PW ���=�t�?G7��XY��^�&��v{��+d��kTYn<�m9�VC;���ݒ��s�q{���Iu^h�j��c<FoC�E�����!$�ȩ'Љ��s��!�)�Zf��RQ�H�#����f�_(wJ����=̸���q6�~<��H�W����~5+�B#���ʗ'��ͽ<����	�4��l.n�p38�v�N�s*)��;,��a �f lTT�ȑ-�툝~Ξ��G��t[~l.�Q�e�C#�+U:_���/�k\��.�箦wm|3����J�̶]2��nW�)��*M��!B�st&�&gk�[Db�GP�Zj"�@�.��o���p��ԼMC�p+�W[��cu����(}H6�Ay1ڔGw��`�*�t�}��ݒ���P��r�EM�����r\�LG�wp+���'�9��Y.F�-(hb��+i�q��5ʃ�>矃����Y���s�Rww�R]5ڐ�s�k�8Mm���7w<OH/_����n�ꃗ�޶����Pà_������'��V��T!t��CŎZ�ߺ*�-E�p�EJ(���OH�ڸlV՛}���-�n�Oه��]�&+�XM
l����~���ڝ��mI?+�nD�a�9�F���)����a ������*RTp}>Թ'ZY��5#�h��^��4Pǡ~B�����M}���|�/�Lm�4��}��W���,�7Cߝ'����뮛/�SI�/����������1���{q;	���K������&��u�:^�@�3!�v� �$���<�?��&O�G6h�w�W아m<N��eJ�k��lԞІ�l���TQ�����,aeS#bs�=�99�4n&5�HG���\BC�?ů4�gK;u!�4��2��,��П+����#�bn2�Փ�0��U%_|�M��v�}��+jo���0��^�_�����t�D��t��Ǫ;�?'���3��,�o��S����y��sn�6h��C;�q�������˟%D�      �   �  xڝ�KO�@��=�EM�i;]B$��	��<䙖�`���s2��"�|9_�����b���e�ߖAv}
����4>m�e��&�]���u��(ʟ��`X2Tо}Q?T��6����L-�eI
�Ԉ�C�φ�GQ#�%E020F�(��A�w�(ư��D2Ҁر���Q��GZBɲR��&�"G��g�<�W$�HXb�qD�:j;��D-�
�X��`rߠdy��}�
E`ai(kG��O�}���pV(K[c��#��z���D-"J���p��NUo;���E��%=C���(랋��'j�ư�r7��:4R��YD��Pn[L3�T�/�"¶p�����2�}i�p[8���%�v�Q�9l��nhw[�ѯ�'_����_XZ?_      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �      xڋ���� � �      �   :  xڅV�r�8<S_�cR�q ���x�8gmG���BR�D�����w@R$�%6�
݅n43��z��I��>$*)�z��2M�
�T�� �(���*˳a�l�q�7D�,p��!F��5�[��T]�0K�݄i#!\���N�M"��u����Li%������
�]���h���l��j�T�jg�i�������ʖ5
}�#�Á��������O�')DO�&�Zu�*��>좔9���bi��^�����I�4��`J+!�}�<�ó�
����B���V�����</a�Eb�"m���� ����~���yN�0z���Q���V��2�ݓgi�eo�Fɪc@�"h���zw�4݊ �0K�;c�X�P���{-�Ilt	��` ��l�w�A�A}cIh��xn�����2[��!��U��Y8V�F�B������;��R�M ���D�C0�up�.���Q��}��j(:�J]�&��[�O�?��IUC�����92YWI��S8�@�)�pu���)���B@4�
A�YPjm��ql��][�:���cI7W�v����B@�m�(�q0kV�棌@�K��Zƻ�H�m"�8zL80唠��/_���kr��������0�
��Jn�1S��]�U�N��h��o.��}¸��k���a��;�s��4��lG�0�&]�V�=M��[C2�Z�o,����YY�����$�n�T<�#�on����ס�+D�����q�VYk<��IV�<�4����a�$H'���?�>�\�9�P�'�$�{�(+��8�5+���t��� At���^��{�F'�{9���[���]V{[n6I�༰Փ:����.!)��뭡�� [��*��BXXeMU
g�S.�m�j�&'u8r`�9�U��a貂� 0�a��Δ�?�
�2�N�C*���. ����h#��#	:R	w�C��ɔ�ǍF��T�`ԺhT]d�cQ�����v�����n�0�Z9#	��G�7|�2���P;�֪;z�J��]�����z��������ke�����y��we��?�3#��ޅ�*d\�7�y�����%,�e�Έ�gLpO�hQ���%���.miS=������p�����<Z�zK�g����Q�])�{tKȻ��L��τ���&��[��u����>\gI�����9�Z+��H�#�����=��6[&��X~�M�G�W���T�c��Ytt4��y0�~�U��b��c�ǋ�M�4����b�ko��l�g��FE�<8��߯nk����!�s�:�o��-���      �   �  x�-�ّ� D���lYq�2�Ǳ�U3��Ζ�27Gp�6lbr��H;�����m�_��!s�����߄�h�<|n��y�S<->xj3-���6w�3~�ǂ6o�3�����"�QeԦ�STRa1+QV�����n�N�ݺP��Q��1ma�:&�,� Y.��0Dr :�]��U����-F��S4�fY%�,f'���'Q5F�eS�K9�#Hyh�"5M��.�>6.�ʀ�4���k��|}�_˗����RS��{��ȎU�=\�֬褏%x,9J*[�'��d�[~͕e)hcWf�'^
����P�x��U�����-u��I�:O��88?)-6Ws�
�k�(��8W�Q���)���N������g�X�=?䍛�Ow�)�w�L��>��}�O�X~�>P�5�]R�pؿ��^~ ����k     