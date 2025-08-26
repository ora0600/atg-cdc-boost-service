-- Check CLOB Sized in DB for better handling of sizes > 20 MB in dedicated confluent clusters
-- Check CLOB Size checker
-- Connect as Schema user
-- sqlplus ordermgmt/kafka@orclpdb1
create or replace FUNCTION clob2blob (p_in clob) RETURN blob IS 
    v_blob        blob;
    v_desc_offset PLS_INTEGER := 1;
    v_src_offset  PLS_INTEGER := 1;
    v_lang        PLS_INTEGER := 0;
    v_warning     PLS_INTEGER := 0;  
BEGIN
    dbms_lob.createtemporary(v_blob,TRUE);
    dbms_lob.converttoblob
        ( v_blob
        , p_in
        , dbms_lob.getlength(p_in)
        , v_desc_offset
        , v_src_offset
        , dbms_lob.default_csid
        , v_lang
        , v_warning
        );
    RETURN v_blob;
END;
/

-- run Select to get all tables from Schema having CLOB
select 'select '||column_name||', dbms_lob.getlength(clob2blob('||column_name||'))/1024/1024 as in_MBytes from '||owner||'.'||table_name||';' as CLOBS
  from all_tab_columns 
 where owner='ORDERMGMT' and data_type='CLOB';
-- results
-- CLOBS
-- --------------------------------------------------------------------------------
-- select NOTE, dbms_lob.getlength(clob2blob(NOTE))/1024/1024 as nr_MBytes from ORDERMGMT.NOTES;
-- in my case only one table
-- execute this select
select dbms_lob.getlength(clob2blob(NOTE))/1024/1024 as in_MBytes from ORDERMGMT.NOTES;
-- results
-- NR_MBYTES
-- ----------
-- .000020027
-- .000020027
-- .000020027
-- .000020027
-- .000020027
-- I got 5 rows back, for better identification, use the pk
select note_id, dbms_lob.getlength(clob2blob(NOTE))/1024/1024 as in_MBytes from ORDERMGMT.NOTES;
--    NOTE_ID  NR_MBYTES
-- ---------- ----------
--          1 .000020027
--          2 .000020027
--          3 .000020027
--          4 .000020027
--          5 .000020027
-- Now check the average size
select avg(dbms_lob.getlength(clob2blob(NOTE))/1024/1024) as avg_in_MBytes from ORDERMGMT.NOTES;
-- AVG_IN_MBYTES
-- -------------
--    .000020027

-- Now you can limit the search for bigger sizes
select note_id, dbms_lob.getlength(clob2blob(NOTE))/1024/1024 as in_MBytes from ORDERMGMT.NOTES where dbms_lob.getlength(clob2blob(NOTE))/1024/1024>20;
-- results no rows selected


-- or a very generic search would be 
set lines 200
column LOB_OBJECT FORMAT A30
select owner||'.'||table_name||'.'||column_name as lob_object, 
       avg(dbms_lob.getlength(clob2blob(owner||'.'||table_name||'.'||column_name))/1024/1024) as avg_in_MBytes 
  from all_tab_columns 
 where owner='ORDERMGMT' and data_type='CLOB'
 group by owner||'.'||table_name||'.'||column_name;
-- LOB_OBJECT                     AVG_IN_MBYTES
-- ------------------------------ -------------
-- ORDERMGMT.NOTES.NOTE              .000019073
