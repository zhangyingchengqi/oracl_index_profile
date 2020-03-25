--2.1　位图索引
--1. 位图索引之如何高效即席查询
--做位图索引与即席查询试验前的准备：
drop table t purge;
set autotrace off
create table t
(name_id,gender not null,location not null,age_group not null,data
)
as
select rownum,decode(ceil(dbms_random.value(0,2)),1,'M',2,'F')gender,ceil(dbms_random.value(1,50)) location,
decode(ceil(dbms_random.value(0,3)),1,'child',2,'young',3,'middle_age',4,'old'),rpad('*',400,'*')
from dual
connect by rownum<=100000;
--注意，以下收集统计信息操作必须先执行。
exec dbms_stats.gather_table_stats(ownname => 'sys',tabname => 'T',estimate_percent => 10,method_opt=> 'for all indexed columns',cascade=>TRUE) ;
--------------------------------------------------------------------------------------------
--即席查询中应用全表扫描的代价：
set linesize 1000
set autotrace traceonly
select *
from t
where gender='M' and location in (1,10,30) and age_group='child';
/*
执行计划
----------------------------------------------------------
Plan hash value: 1601196873

--------------------------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |      |     1 |   237 |  1614   (1)| 00:00:20 |
|*  1 |  TABLE ACCESS FULL| T    |     1 |   237 |  1614   (1)| 00:00:20 |
--------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("GENDER"='M' AND ("LOCATION"=1 OR "LOCATION"=10 OR
              "LOCATION"=30) AND "AGE_GROUP"='child')


统计信息
----------------------------------------------------------
        116  recursive calls
          0  db block gets
       5995  consistent gets
       5940  physical reads
          0  redo size
      13993  bytes sent via SQL*Net to client
        889  bytes received via SQL*Net from client
         45  SQL*Net roundtrips to/from client
          3  sorts (memory)
          0  sorts (disk)
        658  rows processed
        
        全表搜索     回表的代价高  consistent gets 5995
*/
--------------------------------------------------------------------------------------------
--即席查询中应用组合索引的代价
drop index idx_union;
create index idx_union on t(gender,location,age_group);
select *
from t
where gender='M' and location in (1,10,30) and age_group='child';
/*
执行计划
----------------------------------------------------------
Plan hash value: 306189815

------------------------------------------------------------------------------------------
| Id  | Operation                    | Name      | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |           |     3 |   711 |     5   (0)| 00:00:01 |
|   1 |  INLIST ITERATOR             |           |       |       |            |          |
|   2 |   TABLE ACCESS BY INDEX ROWID| T         |     3 |   711 |     5   (0)| 00:00:01 |
|*  3 |    INDEX RANGE SCAN          | IDX_UNION |     1 |       |     4   (0)| 00:00:01 |
------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   3 - access("GENDER"='M' AND ("LOCATION"=1 OR "LOCATION"=10 OR "LOCATION"=30)
              AND "AGE_GROUP"='child')


统计信息
----------------------------------------------------------
          1  recursive calls
          0  db block gets
        698  consistent gets
          5  physical reads
          0  redo size
      13048  bytes sent via SQL*Net to client
        889  bytes received via SQL*Net from client
         45  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
        658  rows processed
        
         INDEX RANGE SCAN   搜索     回表的代价次之  consistent gets   698
*/　
--------------------------------------------------------------------------------------------------------------------
--即席查询应用位图索引，性能有飞跃，Oracle自己选择了使用位图索引：
drop index idx_union;  --删除上面的组合索引
create bitmap index gender_idx on t(gender);
create bitmap index location_idx on t(location);
create bitmap index age_group_idx on t(age_group);
select *
from t
where gender='M' and location in (1,10,30) and age_group='child';
/*
执行计划
----------------------------------------------------------
Plan hash value: 642874377

-----------------------------------------------------------------------------------------------
| Id  | Operation                     | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |               |     1 |   237 |    11   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID  | T             |     1 |   237 |    11   (0)| 00:00:01 |
|   2 |   BITMAP CONVERSION TO ROWIDS |               |       |       |            |          |
|   3 |    BITMAP AND                 |               |       |       |            |          |
|   4 |     BITMAP OR                 |               |       |       |            |          |
|*  5 |      BITMAP INDEX SINGLE VALUE| LOCATION_IDX  |       |       |            |          |
|*  6 |      BITMAP INDEX SINGLE VALUE| LOCATION_IDX  |       |       |            |          |
|*  7 |      BITMAP INDEX SINGLE VALUE| LOCATION_IDX  |       |       |            |          |
|*  8 |     BITMAP INDEX SINGLE VALUE | GENDER_IDX    |       |       |            |          |
|*  9 |     BITMAP INDEX SINGLE VALUE | AGE_GROUP_IDX |       |       |            |          |
-----------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   5 - access("LOCATION"=1)
   6 - access("LOCATION"=10)
   7 - access("LOCATION"=30)
   8 - access("GENDER"='M')
   9 - access("AGE_GROUP"='child')


统计信息
----------------------------------------------------------
        155  recursive calls
          0  db block gets
        671  consistent gets
         16  physical reads
          0  redo size
      13993  bytes sent via SQL*Net to client
        889  bytes received via SQL*Net from client
         45  SQL*Net roundtrips to/from client
          4  sorts (memory)
          0  sorts (disk)
        658  rows processed
        
         BITMAP CONVERSION TO ROWIDS  搜索     回表的代价次之  consistent gets   671
*/



--------------------------------------------------------------------------------------------
--2.　位图索引之如何快速统计条数
--Count性能试验的环境准备
drop table t purge;
set autotrace off
create table t as select * from dba_objects;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
update t set object_id=rownum;
commit;
--------------------------------------------------------------------------------------------
--场景1   Count（*）应用全表扫描的代价
set autotrace on
set linesize 1000
select count(*) from t;
/*
执行计划
----------------------------------------------------------
Plan hash value: 2966233522

-------------------------------------------------------------------
| Id  | Operation          | Name | Rows  | Cost (%CPU)| Time     |
-------------------------------------------------------------------
|   0 | SELECT STATEMENT   |      |     1 | 17392   (1)| 00:03:29 |
|   1 |  SORT AGGREGATE    |      |     1 |            |          |
|   2 |   TABLE ACCESS FULL| T    |  4865K| 17392   (1)| 00:03:29 |
-------------------------------------------------------------------

Note
-----
   - dynamic sampling used for this statement


统计信息
----------------------------------------------------------
          4  recursive calls
          0  db block gets
     128107  consistent gets
      65573  physical reads
       5156  redo size
        422  bytes sent via SQL*Net to client
        416  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          1  rows processed
*/
--------------------------------------------------------------------------------------------
--场景2，  Count应用普通索引的代价 
create index idx_t_obj on t(object_id);
alter table T modify object_id not null;
set autotrace on
select count(*) from t;
/*
执行计划
----------------------------------------------------------
Plan hash value: 278572740

---------------------------------------------------------------------------
| Id  | Operation             | Name      | Rows  | Cost (%CPU)| Time     |
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT      |           |     1 |  2802   (1)| 00:00:34 |
|   1 |  SORT AGGREGATE       |           |     1 |            |          |
|   2 |   INDEX FAST FULL SCAN| IDX_T_OBJ |  4865K|  2802   (1)| 00:00:34 |
---------------------------------------------------------------------------

Note
-----
   - dynamic sampling used for this statement


统计信息
----------------------------------------------------------
        145  recursive calls
          0  db block gets
      10366  consistent gets
      11490  physical reads
          0  redo size
        422  bytes sent via SQL*Net to client
        416  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          4  sorts (memory)
          0  sorts (disk)
          1  rows processed
*/
--------------------------------------------------------------------------------------------
--观察COUNT(*)用位图索引的代价
create bitmap index idx_bitm_t_status on t(status);
select count(*) from t;
select count(*) from t;
/*
执行计划
----------------------------------------------------------
Plan hash value: 4272013625

-------------------------------------------------------------------------------------------
| Id  | Operation                     | Name              | Rows  | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |                   |     1 |    98   (0)| 00:00:02 |
|   1 |  SORT AGGREGATE               |                   |     1 |            |          |
|   2 |   BITMAP CONVERSION COUNT     |                   |  4865K|    98   (0)| 00:00:02 |
|   3 |    BITMAP INDEX FAST FULL SCAN| IDX_BITM_T_STATUS |       |            |          |
-------------------------------------------------------------------------------------------

Note
-----
   - dynamic sampling used for this statement


统计信息
----------------------------------------------------------
          0  recursive calls
          0  db block gets
        115  consistent gets
          0  physical reads
          0  redo size
        422  bytes sent via SQL*Net to client
        416  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          1  rows processed
*/


--------------------------------------------------------------------------------------------------------------------
--2.2　函数索引
--1. 函数索引妙用之部分记录建索引
--首先看一个例子，普通索引的情况，如下：
drop table t purge;
set autotrace off
create table t (id int ,status varchar2(2));
--建立普通索引
create index id_normal on t(status);
insert into t select rownum ,'Y' from dual connect by rownum<=1000000;
insert into t select 1 ,'N' from dual;
commit;
analyze table t compute statistics for table for all indexes for all indexed columns;
set linesize 1000
set autotrace traceonly
select * from t where status='N';
/*
执行计划
----------------------------------------------------------
Plan hash value: 2252729315

-----------------------------------------------------------------------------------------
| Id  | Operation                   | Name      | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |           |     1 |    10 |     4   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T         |     1 |    10 |     4   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | ID_NORMAL |     1 |       |     3   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("STATUS"='N')


统计信息
----------------------------------------------------------
          1  recursive calls
          0  db block gets
          5  consistent gets
          0  physical reads
          0  redo size
        471  bytes sent via SQL*Net to client
        416  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          1  rows processed
*/
--看索引情况
set autotrace off
analyze index id_normal validate structure;
select name,btree_space,lf_rows,height from index_stats;
set autotrace off
analyze index id_normal validate structure;
select name,btree_space,lf_rows,height from index_stats;
/*                                           索引叶子数        高度
ID_NORMAL                         15992192    1000001          3
*/
------------------------------------------------------------------------------------------
--建函数索引的情况:因为绝大部分记录都是y,只有极少数 n,所以对n的情况建立索引 。
drop index id_normal;
create index id_status on  t (Case when status= 'N' then 'N' end);
analyze table t compute statistics for table for all indexes for all indexed columns;
/*以下这个select * from t where (case when status='N' then 'N' end)='N'
写法不能变,如果是select * from t where status='N'将无效!笔者见过有些人设置了选择性索引，却这样调用的，结果根本起不到任何效果！
*/
set autotrace traceonly
select * from t where (case when status='N' then 'N' end)='N';
/*
执行计划
----------------------------------------------------------
Plan hash value: 1835552001

-----------------------------------------------------------------------------------------
| Id  | Operation                   | Name      | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |           |     1 |    10 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T         |     1 |    10 |     2   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | ID_STATUS |     1 |       |     1   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access(CASE "STATUS" WHEN 'N' THEN 'N' END ='N')


统计信息
----------------------------------------------------------
         15  recursive calls
          0  db block gets
          6  consistent gets
          0  physical reads
          0  redo size
        471  bytes sent via SQL*Net to client
        416  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          1  rows processed
*/
--接着观察id_status（即函数索引）索引的情况
set autotrace off
analyze index id_status validate structure;
select name,btree_space,lf_rows,height from index_stats;
/*
                                                  索引叶子数   高度
ID_STATUS                             8000          1          1
*/

------------------------------------------------------------------------------------
--2. 函数索引妙用之减少递归调用
--首先构造自定义函数的环境，如下所示：
drop table t1 purge;
drop table t2 purge;
create table t1 (first_name varchar2(200),last_name varchar2(200),id number);
create table t2 as select * from dba_objects where rownum<=1000;
insert into t1 (first_name,last_name,id) select object_name,object_type,rownum from dba_objects where rownum<=1000;
commit;
create or replace function get_obj_name(p_id t2.object_id%type) return t2.object_name%type DETERMINISTIC is
v_name t2.object_name%type;
begin
select object_name
into v_name
from t2
where object_id=p_id;
return v_name;
end;
/
--------------------------------------------------------------------------------------------
--未建函数索引的函数调用性能
set linesize 1000
set autotrace traceonly
select *   from t1 where get_obj_name(id)='TEST'  ;
/*
执行计划
----------------------------------------------------------
Plan hash value: 3617692013

--------------------------------------------------------------------------
| Id  | Operation         | Name | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------
|   0 | SELECT STATEMENT  |      |    10 |  2170 |     3   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS FULL| T1   |    10 |  2170 |     3   (0)| 00:00:01 |
--------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   1 - filter("GET_OBJ_NAME"("ID")='TEST')

Note
-----
   - dynamic sampling used for this statement


统计信息
----------------------------------------------------------
       1175  recursive calls
          0  db block gets
      16064  consistent gets
         13  physical reads
          0  redo size
        398  bytes sent via SQL*Net to client
        405  bytes received via SQL*Net from client
          1  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          0  rows processed
*/
------------------------------------------------------------------------------------------------------------
--建自定义函数get_obj_name的函数索引
create index idx_func_id on t1(get_obj_name(id));
select *   from t1 where get_obj_name(id)='TEST'  ;
/*
执行计划
----------------------------------------------------------
Plan hash value: 4083325411

-------------------------------------------------------------------------------------------
| Id  | Operation                   | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |             |    10 | 22190 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T1          |    10 | 22190 |     2   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | IDX_FUNC_ID |     4 |       |     1   (0)| 00:00:01 |
-------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("SYS"."GET_OBJ_NAME"("ID")='TEST')

Note
-----
   - dynamic sampling used for this statement


统计信息
----------------------------------------------------------
         48  recursive calls
          0  db block gets
         14  consistent gets
          1  physical reads
          0  redo size
        398  bytes sent via SQL*Net to client
        405  bytes received via SQL*Net from client
          1  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          0  rows processed
*/


