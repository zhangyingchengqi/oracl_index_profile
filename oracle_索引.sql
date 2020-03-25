/*
经典三大特性
*/
--1. 索引高度较低（可快速定位） 索引高度较低的直观体验
--环境准备
drop table t1 purge;
drop table t2 purge;
drop table t3 purge;
drop table t4 purge;
drop table t5 purge;
drop table t6 purge;
drop table t7 purge;
create table t1 as select rownum as id ,rownum+1 as id2,rpad('*',1000,'*') as contents from dual connect by level<=1;
create table t2 as select rownum as id ,rownum+1 as id2,rpad('*',1000,'*') as contents from dual connect by level<=10;
create table t3 as select rownum as id ,rownum+1 as id2,rpad('*',1000,'*') as contents from dual connect by level<=100;
create table t4 as select rownum as id ,rownum+1 as id2,rpad('*',1000,'*') as contents from dual connect by level<=1000;
create table t5 as select rownum as id ,rownum+1 as id2,rpad('*',1000,'*') as contents from dual connect by level<=10000;
create table t6 as select rownum as id ,rownum+1 as id2,rpad('*',1000,'*') as contents from dual connect by level<=100000;
create table t7 as select rownum as id ,rownum+1 as id2,rpad('*',1000,'*') as contents from dual connect by level<=1000000;
create index idx_id_t1 on t1(id);
create index idx_id_t2 on t2(id);
create index idx_id_t3 on t3(id);
create index idx_id_t4 on t4(id);
create index idx_id_t5 on t5(id);
create index idx_id_t6 on t6(id);
create index idx_id_t7 on t7(id);
--接下来执行如下语句查询, 分析7张表的索引
-- blevel＝0: 索引只有叶子块,高度为1. 注意：  t1到t7的 num_rows以10倍速增加，而索引增加速度极慢. 这说明索引的高度确实低. 
select index_name,
blevel,
leaf_blocks,
num_rows,
distinct_keys,
clustering_factor
from user_ind_statistics
where table_name in( 'T1','T2','T3','T4','T5','T6','T7');


--2. 高度低有利于索引范围扫描
--只显示统计信息   此命令只能在   sql plus下执行，请参考: blog.csdn.net/zhanglin_1214/article/details/48806553
set autotrace traceonly stat;
--语句1，针对t1表的索引访问和全表扫描访问，如下
select * from t1 where id=1;    --索引 访问
select /*+full(t1)*/ * from t1 where id=1;  --全表访问
--语句2，针对t2表的索引访问和全表扫描访问，如下：
select * from t2 where id=1;
select /*+full(t2)*/ * from t2 where id=1;
--语句3，针对t3表的索引访问和全表扫描访问，如下：
select * from t3 where id=1;
select /*+full(t3)*/ * from t3 where id=1;
--语句4，针对t4表的索引访问和全表扫描访问，如下：
select * from t4 where id=1;
select /*+full(t4)*/ * from t4 where id=1;
--语句5，针对t5表的索引访问和全表扫描访问，如下：
select * from t5 where id=1;
select /*+full(t5)*/ * from t5 where id=1;
--语句6，针对t6表的索引访问和全表扫描访问，如下：
select * from t6 where id=1;
select /*+full(t6)*/ * from t6 where id=1;
--语句7，针对t7表的索引访问和全表扫描访问，如下：
select * from t7 where id=1;
select /*+full(t7)*/ * from t7 where id=1;
/*
  请注意以下统计信息中的  consistent gets 部分。随着记录的增加，索引访问的优势越来越明显。
*/


--索引存储列值（可优化聚合）
--（1）索引特性之存列值优化count
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create index idx1_object_id on t(object_id);
set autotrace on;
select count(*) from t;
/*
   统计信息:  5  recursive calls
          0  db block gets
       1075  consistent gets
       用不到索引 ，因为列中有空值 
*/
select count(*) from t where object_id is not null;
/*
统计信息:
       5  recursive calls
          0  db block gets
        224  consistent gets
      索引不能存空值 ，所以加入一个 is not null后即可。
*/
--修改代码让count用到索引
alter table t modify OBJECT_ID not null;
select count(*) from t;
/*
统计信息:
       145  recursive calls
          0  db block gets
        242  consistent gets
        
    另外：因为主键不能为空，所以主键一定能用到索引。
*/

--（2）索引特性之存列值优化sum avg
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id);
set autotrace on;
set linesize 1000;
set timing on;
select sum(object_id) from t;

--sum avg不走索引 的代价
select /*+full(t)*/ sum(object_id) from t;
/*
10,11   实测差不多????
*/

--3. 索引本身有序（可优化排序）
--（1）索引特性之有序优化order by
set autotrace traceonly
set linesize 1000
drop table t purge;
create table t as select * from dba_objects;
select * from t where object_id>2 order by object_id;
/*
   输出信息中有：  1  sorts (memory)
          0  sorts (disk)
  小结：无索引的order by 语句必然会排序
*/
--
--索引让order by 语句排序消失
create index idx_t_object_id on t(object_id);
set autotrace traceonly
select * from t where object_id>2 order by object_id;
/*
   输出信息:  0  sorts (memory)
          0  sorts (disk)
*/


--(2)索引特性之有序优化Max/Min
--MAX/MIN 的索引优化
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
alter table t add constraint pk_object_id primary key (OBJECT_ID);
set autotrace on
set linesize 1000
select max(object_id) from t;
/*
系统信息:
         145  recursive calls
          0  db block gets
         86  consistent gets
          1  physical reads
*/
--MAX/MIN 语句用不到索引性能低下
select /*+full(t)*/ max(object_id) from t;
/*
  0  recursive calls
          0  db block gets
       1009  consistent gets
          0  physical reads
*/


--MAX/MIN 用索引与数据量增加的影响
set autotrace off
drop table t_max purge;
create table t_max as select * from dba_objects;
insert into t_max select * from t_max;
insert into t_max select * from t_max;
insert into t_max select * from t_max;
insert into t_max select * from t_max;
insert into t_max select * from t_max;
select count(*) from t_max;
create index idx_t_max_obj on t_max(object_id);
set autotrace on
select max(object_id) from t_max;
/* 系统信息:
         5  recursive calls
          0  db block gets
         71  consistent gets
          2  physical reads
          
      有索引 后，查询最小值 或最大值 可以叶子块的最左边或最右边，比较快.
*/


--组合索引选用
--3. 仅等值无范围查询时，组合的顺序不影响性能
--环境准备：
drop table t purge;
create table t as select * from dba_objects;
insert into t select * from t;
insert into t select * from t;
insert into t select * from t;
update t set object_id=rownum ;
commit;
create index idx_id_type on t(object_id,object_type);
create index idx_type_id on t(object_type,object_id);
set autotrace off
alter session set statistics_level=all ;
set linesize 366
--type_id，id顺序组合索引
select /*+index(t,idx_id_type)*/ * from  t  where object_id=20  and object_type='TABLE';
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
--再用id、type_id顺序组合索引
select /*+index(t,idx_type_id)*/ * from  t  where object_id=20  and object_type='TABLE';
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
--以上两个语句性能一样，表明只有等值查询时，组合索引组合列的顺序不要紧。


--4. 组合索引最佳顺序一般是将等值查询的列置前
--将等值查询的列置前
select /*+index(t,idx_id_type)*/ *  from   t where    object_id>=20 and object_id<2000 and object_type='TABLE' ;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
--将等值查询的列置后
select /*+index(t,idx_type_id)*/ *  from  t  where object_id>=20 and object_id<2000   and object_type='TABLE';
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
/*
   在统计信息中观察buffer值 ，可以发现 索引 idx_type_id性能要优于 idx_id_type, 即等值列在索引中要放在前面，范围查询放在后面。
*/


--2.3　索引扫描类型的分类与构造
--1. INDEX RANGE SCAN
--请记住这个INDEX RANGE SCAN扫描方式
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create  index idx_object_id on t(object_id);      --这是一个    索引范围扫描
set autotrace traceonly
set linesize 1000
--这里要注意  ownname是你登录用户的名字，我在 sql plus上的登录用户名为sys
exec dbms_stats.gather_table_stats(ownname => 'sys',tabname => 'T',estimate_percent => 10,method_opt=> 'for all indexed columns',cascade=>TRUE) ;
select * from t where object_id=8;
/*
---------------------------------------------------------------------------------------------
| Id  | Operation                   | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |               |     1 |   101 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T             |     1 |   101 |     2   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | IDX_OBJECT_ID |     1 |       |     1   (0)| 00:00:01
*/


--2. INDEX UNIQUE SCAN
--请注意这个INDEX UNIQUE SCAN扫描方式,在唯一索引情况下使用。
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create unique index idx_object_id on t(object_id);
set autotrace traceonly
set linesize 1000
select * from t where object_id=8;
/*
---------------------------------------------------------------------------------------------
| Id  | Operation                   | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |               |     1 |   207 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T             |     1 |   207 |     2   (0)| 00:00:01 |
|*  2 |   INDEX UNIQUE SCAN         | IDX_OBJECT_ID |     1 |       |     1   (0)| 00:00:01 |
*/


--3. TABLE ACCESS BY USER ROWID
--请注意这个TABLE ACCESS BY USER ROWID扫描方式,直接根据rowid来访问，最快的访问方式！
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
--注意，这里连索引都没建!
--create  index idx_object_id on t(object_id);
set autotrace off
select rowid from t where object_id=8;
--ROWID
-----
--AAARDxAABAAAVeiAAH
set autotrace traceonly
set linesize 1000
select * from t where object_id=8 and rowid='AAARDxAABAAAVeiAAH';
/*
-----------------------------------------------------------------------------------
| Id  | Operation                  | Name | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------
|   0 | SELECT STATEMENT           |      |     1 |   219 |     1   (0)| 00:00:01 |
|*  1 |  TABLE ACCESS BY USER ROWID| T    |     1 |   219 |     1   (0)| 00:00:01 |
*/


--4. INDEX FULL SCAN
--请记住这个INDEX FULL SCAN扫描方式，并体会与下面INDEX FAST FULL SCAN的区别
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
alter table T modify object_id not null;
create  index idx_object_id on t(object_id);
set autotrace traceonly
set linesize 1000
select * from t  order by object_id;


--5. INDEX FAST FULL SCAN
---请记住这个INDEX FAST FULL SCAN扫描方式，并体会与上面INDEX FULL SCAN的区别
drop table t purge;
create table t as select * from dba_objects ;
update t set object_id=rownum;
commit;
alter table T modify object_id not null;
create  index idx_object_id on t(object_id);
set autotrace traceonly
set linesize 1000
select count(*) from t;
/*
-------------------------------------------------------------------------------
| Id  | Operation             | Name          | Rows  | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------
|   0 | SELECT STATEMENT      |               |     1 |    43   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE       |               |     1 |            |          |
|   2 |   INDEX FAST FULL SCAN| IDX_OBJECT_ID | 63284 |    43   (0)| 00:00:01 |
*/


--6. INDEX FULL SCAN (MINMAX)
--请注意这个INDEX FULL SCAN (MIN/MAX)扫描方式
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create  index idx_object_id on t(object_id);
set autotrace traceonly
set linesize 1000
select max(object_id) from t;
/*
--------------------------------------------------------------------------------------------
| Id  | Operation                  | Name          | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT           |               |     1 |    13 |   275   (1)| 00:00:04 |
|   1 |  SORT AGGREGATE            |               |     1 |    13 |            |          |
|   2 |   INDEX FULL SCAN (MIN/MAX)| IDX_OBJECT_ID | 63284 |   803K|            |
*/



--7. INDEX SKIP SCAN
--请记住这个INDEX SKIP SCAN扫描方式
drop table t purge;
create table t as select * from dba_objects;
update t set object_type='TABLE' ;
commit;
update t set object_type='VIEW' where rownum<=30000;
commit;
create  index idx_type_id on t(object_type,object_id);
exec dbms_stats.gather_table_stats(ownname => 'sys',tabname => 'T',estimate_percent => 10,method_opt=> 'for all indexed columns',cascade=>TRUE) ;
set autotrace traceonly
set linesize 1000
select * from t where object_id=8;
/*
-------------------------------------------------------------------------------------------
| Id  | Operation                   | Name        | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |             |     1 |    98 |     4   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T           |     1 |    98 |     4   (0)| 00:00:01 |
|*  2 |   INDEX SKIP SCAN           | IDX_TYPE_ID |     1 |       |     3   (0)| 00:00:01
*/


--8. TABLE ACCESS BY INDEX ROWID
--好好地体会前后两个试验，记住这个TABLE ACCESS BY INDEX ROWID
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create  index idx_object_id on t(object_id);
set autotrace traceonly explain
set linesize 1000
select object_id from t where object_id=2 and object_type='TABLE';
--在接下来的试验中，你会看到，哇塞，TABLE ACCESS BY INDEX ROWID消失了。
create  index idx_id_type on t(object_id,object_type);
select object_id from t where object_id=2 and object_type='TABLE';



--3　索引相关优化案例
--3.1　三大特性的相关案例
--1. 分区表各类聚合优化玄机
--语句1：
select max(nbr) max_nbr
from range_part_tab
where deal_date >= TO_DATE('2015-05-01', 'YYYY-MM-DD')
and deal_date < TO_DATE('2015-06-01', 'YYYY-MM-DD');

--走全表扫描   table access full
--------------------------------------------------------------------------------------------
--接下来看语句2：
select max(nbr) max_nbr from range_part_tab partition(p_201505);
--用  index full scan(min/max)
--------------------------------------------------------------------------------------------
--语句3：
select count(*) max_nbr
from range_part_tab
where deal_date >= TO_DATE('2015-05-01', 'YYYY-MM-DD')
and deal_date < TO_DATE('2015-06-01', 'YYYY-MM-DD');
--走全表扫描
--------------------------------------------------------------------------------------------
--语句4：
select count(*) max_nbr from range_part_tab partition(p_201505);
--用  index fast full scan


--------------------------------------------------------------------------------------------
--啥时分区索引性能反而低
--假设有两张表 part_tab,norm_tab,前者为分区表，后者为普通表，记录数一样，在两个表的 col2列都有索引下，比较
-- select * from xxx where col2=8的性能
--环境准备
drop table part_tab purge;
create table part_tab (id int,col2 int,col3 int)
partition by range (id)
(
partition p1 values less than (10000),
partition p2 values less than (20000),
partition p3 values less than (30000),
partition p4 values less than (40000),
partition p5 values less than (50000),
partition p6 values less than (60000),
partition p7 values less than (70000),
partition p8 values less than (80000),
partition p9 values less than (90000),
partition p10 values less than (100000),
partition p11 values less than (maxvalue)
);
insert into part_tab select rownum,rownum+1,rownum+2 from dual connect by rownum <=110000;
commit;
create  index idx_par_tab_col2 on part_tab(col2) local;
create  index idx_par_tab_col3 on part_tab(col3) ;
drop table norm_tab purge;
create table norm_tab  (id int,col2 int,col3 int);
insert into norm_tab select rownum,rownum+1,rownum+2 from dual connect by rownum <=110000;
commit;
create  index idx_nor_tab_col2 on norm_tab(col2) ;
create  index idx_nor_tab_col3 on norm_tab(col3) ;
--------------------------------------------------------------------------------------------
--分区表局部分区扫描的情况
set autotrace traceonly
set linesize 1000
set timing on
select * from part_tab where col2=8 ;
/*
-----------------------------------------------------------------------------------------------------------------------
| Id  | Operation                          | Name             | Rows  | Bytes | Cost (%CPU)| Time     | Pstart| Pstop |
-----------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                   |                  |     1 |    39 |    13   (0)| 00:00:01 |       |       |
|   1 |  PARTITION RANGE ALL               |                  |     1 |    39 |    13   (0)| 00:00:01 |     1 |    11 |
|   2 |   TABLE ACCESS BY LOCAL INDEX ROWID| PART_TAB         |     1 |    39 |    13   (0)| 00:00:01 |     1 |    11 |
|*  3 |    INDEX RANGE SCAN                | IDX_PAR_TAB_COL2 |     1 |       |    12   (0)| 00:00:01 |     1 |    11 |
--------------------------------------------------------------------------------------------------------------
统计信息
----------------------------------------------------------
         52  recursive calls
          0  db block gets
        153  consistent gets
*/
--普通表索引扫描的情况
select * from norm_tab where col2=8 ;
/*
------------------------------------------------------------------------------------------------
| Id  | Operation                   | Name             | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |                  |     1 |    39 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| NORM_TAB         |     1 |    39 |     2   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | IDX_NOR_TAB_COL2 |     1 |       |     1   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------
统计信息
----------------------------------------------------------
         32  recursive calls
          0  db block gets
         80  consistent gets
*/
--小结: norm_tab对应的sql 的consistent gets为１５３，而分区表ｐａｒｔ＿ｔａｂ对应的ｓｑｌ的ｃｏｎｓｉｓｔｅｎｔ　ｇｅｔｓ为　８０
--这个表有分区，但sql却没有这个分区条件，导到处该分区表的局部索引从pstarg1到pstop11遍历11个分区。
--所以当分区表的分区条件无法加上时，全局索引性能要好于分区索引 。



--------------------------------------------------------------------------------------------
--3. 同时取最大最小值的案例
--环境准备
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
alter table t add constraint pk_object_id primary key (OBJECT_ID);
set autotrace on
set linesize 1000
--看看执行计划是什么：
set linesize 1000
set autotrace on
select max(object_id),min(object_id) from t;
/*
执行计划
----------------------------------------------------------
Plan hash value: 1265209789

--------------------------------------------------------------------------------------
| Id  | Operation             | Name         | Rows  | Bytes | Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT      |              |     1 |    13 |    40   (0)| 00:00:01 |
|   1 |  SORT AGGREGATE       |              |     1 |    13 |            |          |
|   2 |   INDEX FAST FULL SCAN| PK_OBJECT_ID | 54956 |   697K|    40   (0)| 00:00:01 |
--------------------------------------------------------------------------------------

Note
-----
   - dynamic sampling used for this statement


统计信息
----------------------------------------------------------
        145  recursive calls
          0  db block gets
        224  consistent gets
        142  physical reads
          0  redo size
        494  bytes sent via SQL*Net to client
        416  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          4  sorts (memory)
          0  sorts (disk)
          1  rows processed
*/
/*
小结: 执行计划并没有走高效的index full scan (min/max)扫描方式，而是走index fast full scan模式。
这是因为oracle不能同时在索引 相同的两段寻找最大值 和最小值 。
以上语句修改成以下利用笛卡尔积的查询方式完成.
*/
--同时取最大最小值的语句的改造写法
select max, min
from (select max(object_id) max from t ) a,
(select min(object_id) min from t ) b;
/*
执行计划
----------------------------------------------------------
Plan hash value: 3319831621

---------------------------------------------------------------------------------------------
| Id  | Operation                    | Name         | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT             |              |     1 |    26 |     4   (0)| 00:00:01 |
|   1 |  NESTED LOOPS                |              |     1 |    26 |     4   (0)| 00:00:01 |
|   2 |   VIEW                       |              |     1 |    13 |     2   (0)| 00:00:01 |
|   3 |    SORT AGGREGATE            |              |     1 |    13 |            |          |
|   4 |     INDEX FULL SCAN (MIN/MAX)| PK_OBJECT_ID | 54956 |   697K|     2   (0)| 00:00:01 |
|   5 |   VIEW                       |              |     1 |    13 |     2   (0)| 00:00:01 |
|   6 |    SORT AGGREGATE            |              |     1 |    13 |            |          |
|   7 |     INDEX FULL SCAN (MIN/MAX)| PK_OBJECT_ID | 54956 |   697K|     2   (0)| 00:00:01 |
---------------------------------------------------------------------------------------------

Note
-----
   - dynamic sampling used for this statement


统计信息
----------------------------------------------------------
          7  recursive calls
          0  db block gets
        118  consistent gets
          0  physical reads
          0  redo size
        472  bytes sent via SQL*Net to client
        416  bytes received via SQL*Net from client
          2  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
          1  rows processed
*/
--性能在 consistent gets上得到了提升.

--------------------------------------------------------------------------------------------------------------------
--3.2　组合索引的经典案例
--1. 组合索引的写法
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum ;
create index idx_id_type on t(object_id,object_type);
UPDATE t SET OBJECT_ID=20 WHERE ROWNUM<=26000;
UPDATE t SET OBJECT_ID=21 WHERE OBJECT_ID<>20;
COMMIT;
set linesize 1000
set pagesize 1
alter session set statistics_level=all ;
select  /*+index(t,idx1_object_id)*/ * from t  where object_TYPE='TABLE'  AND OBJECT_ID >= 20 AND OBJECT_ID<= 21;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
/*
执行计划
----------------------------------------------------------
Plan hash value: 3713220770

----------------------------------------------------------------------------------------------------
| Id  | Operation                         | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                  |                |  8168 | 16336 |    29   (0)| 00:00:01 |
|   1 |  COLLECTION ITERATOR PICKLER FETCH| DISPLAY_CURSOR |       |       |            |          |
----------------------------------------------------------------------------------------------------


统计信息
----------------------------------------------------------
         19  recursive calls
          0  db block gets
          0  consistent gets
          0  physical reads
          0  redo size
       1512  bytes sent via SQL*Net to client
        427  bytes received via SQL*Net from client
          3  SQL*Net roundtrips to/from client
          3  sorts (memory)
          0  sorts (disk)
         18  rows processed
*/
--组合索引与In写法
select  /*+index(t,idx_id_type)*/ * from t t where object_TYPE='TABLE'  AND  OBJECT_ID IN (20,21);
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
/*
执行计划
----------------------------------------------------------
Plan hash value: 3713220770

----------------------------------------------------------------------------------------------------
| Id  | Operation                         | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                  |                |  8168 | 16336 |    29   (0)| 00:00:01 |
|   1 |  COLLECTION ITERATOR PICKLER FETCH| DISPLAY_CURSOR |       |       |            |          |
----------------------------------------------------------------------------------------------------


统计信息
----------------------------------------------------------
         14  recursive calls
          0  db block gets
          0  consistent gets
          0  physical reads
          0  redo size
       1512  bytes sent via SQL*Net to client
        427  bytes received via SQL*Net from client
          3  SQL*Net roundtrips to/from client
          3  sorts (memory)
          0  sorts (disk)
         18  rows processed
*/


--------------------------------------------------------------------------------------------
--2. 组合索引与增加检索条件
--环境准备
drop table t purge;
create table t as select * from dba_objects;
UPDATE t SET OBJECT_ID=20 WHERE ROWNUM<=26000;
UPDATE t SET OBJECT_ID=21 WHERE OBJECT_ID<>20;
Update t set object_id=22 where rownum<=10000;
COMMIT;
create index idx_union on t(object_type,object_id,owner);
set autotrace off
alter session set statistics_level=all ;
set linesize 1000
--写法1  未增加OBJECT_ID列的写法
set autotrace on
select * from t where object_type='VIEW' and OWNER='SYS';
/*
执行计划
----------------------------------------------------------
Plan hash value: 1570829420

-----------------------------------------------------------------------------------------
| Id  | Operation                   | Name      | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |           |  3286 |   664K|    42   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| T         |  3286 |   664K|    42   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | IDX_UNION |    30 |       |    40   (0)| 00:00:01 |
-----------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - access("OBJECT_TYPE"='VIEW' AND "OWNER"='SYS')
       filter("OWNER"='SYS')

Note
-----
   - dynamic sampling used for this statement


统计信息
----------------------------------------------------------
          0  recursive calls
          0  db block gets
        595  consistent gets
          0  physical reads
          0  redo size
     125958  bytes sent via SQL*Net to client
       2935  bytes received via SQL*Net from client
        231  SQL*Net roundtrips to/from client
          0  sorts (memory)
          0  sorts (disk)
       3445  rows processed
*/　
--写法2   增加OBJECT_ID列的写法
select /*+index(T IDX_UNION)*/
* from t T where object_type='VIEW'
and OBJECT_ID IN (20,21,22)
AND OWNER='LJB';
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
/*
执行计划
----------------------------------------------------------
Plan hash value: 3713220770

----------------------------------------------------------------------------------------------------
| Id  | Operation                         | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                  |                |  8168 | 16336 |    29   (0)| 00:00:01 |
|   1 |  COLLECTION ITERATOR PICKLER FETCH| DISPLAY_CURSOR |       |       |            |          |
----------------------------------------------------------------------------------------------------


统计信息
----------------------------------------------------------
         18  recursive calls
          0  db block gets
          0  consistent gets
          0  physical reads
          0  redo size
       1512  bytes sent via SQL*Net to client
        427  bytes received via SQL*Net from client
          3  SQL*Net roundtrips to/from client
          3  sorts (memory)
          0  sorts (disk)
         18  rows processed
*/　
--小结：三列组合索引的特点：互相依赖。 第三列依赖第二列，第二列依赖第一列











2. INDEX UNIQUE SCAN
--请注意这个INDEX UNIQUE SCAN扫描方式,在唯一索引情况下使用。
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create unique index idx_object_id on t(object_id);
set autotrace traceonly
set linesize 1000
select * from t where object_id=8;






