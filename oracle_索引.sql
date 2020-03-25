/*
������������
*/
--1. �����߶Ƚϵͣ��ɿ��ٶ�λ�� �����߶Ƚϵ͵�ֱ������
--����׼��
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
--������ִ����������ѯ, ����7�ű������
-- blevel��0: ����ֻ��Ҷ�ӿ�,�߶�Ϊ1. ע�⣺  t1��t7�� num_rows��10�������ӣ������������ٶȼ���. ��˵�������ĸ߶�ȷʵ��. 
select index_name,
blevel,
leaf_blocks,
num_rows,
distinct_keys,
clustering_factor
from user_ind_statistics
where table_name in( 'T1','T2','T3','T4','T5','T6','T7');


--2. �߶ȵ�������������Χɨ��
--ֻ��ʾͳ����Ϣ   ������ֻ����   sql plus��ִ�У���ο�: blog.csdn.net/zhanglin_1214/article/details/48806553
set autotrace traceonly stat;
--���1�����t1����������ʺ�ȫ��ɨ����ʣ�����
select * from t1 where id=1;    --���� ����
select /*+full(t1)*/ * from t1 where id=1;  --ȫ�����
--���2�����t2����������ʺ�ȫ��ɨ����ʣ����£�
select * from t2 where id=1;
select /*+full(t2)*/ * from t2 where id=1;
--���3�����t3����������ʺ�ȫ��ɨ����ʣ����£�
select * from t3 where id=1;
select /*+full(t3)*/ * from t3 where id=1;
--���4�����t4����������ʺ�ȫ��ɨ����ʣ����£�
select * from t4 where id=1;
select /*+full(t4)*/ * from t4 where id=1;
--���5�����t5����������ʺ�ȫ��ɨ����ʣ����£�
select * from t5 where id=1;
select /*+full(t5)*/ * from t5 where id=1;
--���6�����t6����������ʺ�ȫ��ɨ����ʣ����£�
select * from t6 where id=1;
select /*+full(t6)*/ * from t6 where id=1;
--���7�����t7����������ʺ�ȫ��ɨ����ʣ����£�
select * from t7 where id=1;
select /*+full(t7)*/ * from t7 where id=1;
/*
  ��ע������ͳ����Ϣ�е�  consistent gets ���֡����ż�¼�����ӣ��������ʵ�����Խ��Խ���ԡ�
*/


--�����洢��ֵ�����Ż��ۺϣ�
--��1����������֮����ֵ�Ż�count
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create index idx1_object_id on t(object_id);
set autotrace on;
select count(*) from t;
/*
   ͳ����Ϣ:  5  recursive calls
          0  db block gets
       1075  consistent gets
       �ò������� ����Ϊ�����п�ֵ 
*/
select count(*) from t where object_id is not null;
/*
ͳ����Ϣ:
       5  recursive calls
          0  db block gets
        224  consistent gets
      �������ܴ��ֵ �����Լ���һ�� is not null�󼴿ɡ�
*/
--�޸Ĵ�����count�õ�����
alter table t modify OBJECT_ID not null;
select count(*) from t;
/*
ͳ����Ϣ:
       145  recursive calls
          0  db block gets
        242  consistent gets
        
    ���⣺��Ϊ��������Ϊ�գ���������һ�����õ�������
*/

--��2����������֮����ֵ�Ż�sum avg
drop table t purge;
create table t as select * from dba_objects;
create index idx1_object_id on t(object_id);
set autotrace on;
set linesize 1000;
set timing on;
select sum(object_id) from t;

--sum avg�������� �Ĵ���
select /*+full(t)*/ sum(object_id) from t;
/*
10,11   ʵ����????
*/

--3. �����������򣨿��Ż�����
--��1����������֮�����Ż�order by
set autotrace traceonly
set linesize 1000
drop table t purge;
create table t as select * from dba_objects;
select * from t where object_id>2 order by object_id;
/*
   �����Ϣ���У�  1  sorts (memory)
          0  sorts (disk)
  С�᣺��������order by ����Ȼ������
*/
--
--������order by ���������ʧ
create index idx_t_object_id on t(object_id);
set autotrace traceonly
select * from t where object_id>2 order by object_id;
/*
   �����Ϣ:  0  sorts (memory)
          0  sorts (disk)
*/


--(2)��������֮�����Ż�Max/Min
--MAX/MIN �������Ż�
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
alter table t add constraint pk_object_id primary key (OBJECT_ID);
set autotrace on
set linesize 1000
select max(object_id) from t;
/*
ϵͳ��Ϣ:
         145  recursive calls
          0  db block gets
         86  consistent gets
          1  physical reads
*/
--MAX/MIN ����ò����������ܵ���
select /*+full(t)*/ max(object_id) from t;
/*
  0  recursive calls
          0  db block gets
       1009  consistent gets
          0  physical reads
*/


--MAX/MIN �����������������ӵ�Ӱ��
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
/* ϵͳ��Ϣ:
         5  recursive calls
          0  db block gets
         71  consistent gets
          2  physical reads
          
      ������ �󣬲�ѯ��Сֵ �����ֵ ����Ҷ�ӿ������߻����ұߣ��ȽϿ�.
*/


--�������ѡ��
--3. ����ֵ�޷�Χ��ѯʱ����ϵ�˳��Ӱ������
--����׼����
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
--type_id��id˳���������
select /*+index(t,idx_id_type)*/ * from  t  where object_id=20  and object_type='TABLE';
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
--����id��type_id˳���������
select /*+index(t,idx_type_id)*/ * from  t  where object_id=20  and object_type='TABLE';
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
--���������������һ��������ֻ�е�ֵ��ѯʱ�������������е�˳��Ҫ����


--4. ����������˳��һ���ǽ���ֵ��ѯ������ǰ
--����ֵ��ѯ������ǰ
select /*+index(t,idx_id_type)*/ *  from   t where    object_id>=20 and object_id<2000 and object_type='TABLE' ;
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
--����ֵ��ѯ�����ú�
select /*+index(t,idx_type_id)*/ *  from  t  where object_id>=20 and object_id<2000   and object_type='TABLE';
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
/*
   ��ͳ����Ϣ�й۲�bufferֵ �����Է��� ���� idx_type_id����Ҫ���� idx_id_type, ����ֵ����������Ҫ����ǰ�棬��Χ��ѯ���ں��档
*/


--2.3������ɨ�����͵ķ����빹��
--1. INDEX RANGE SCAN
--���ס���INDEX RANGE SCANɨ�跽ʽ
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create  index idx_object_id on t(object_id);      --����һ��    ������Χɨ��
set autotrace traceonly
set linesize 1000
--����Ҫע��  ownname�����¼�û������֣����� sql plus�ϵĵ�¼�û���Ϊsys
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
--��ע�����INDEX UNIQUE SCANɨ�跽ʽ,��Ψһ���������ʹ�á�
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
--��ע�����TABLE ACCESS BY USER ROWIDɨ�跽ʽ,ֱ�Ӹ���rowid�����ʣ����ķ��ʷ�ʽ��
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
--ע�⣬������������û��!
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
--���ס���INDEX FULL SCANɨ�跽ʽ�������������INDEX FAST FULL SCAN������
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
---���ס���INDEX FAST FULL SCANɨ�跽ʽ�������������INDEX FULL SCAN������
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
--��ע�����INDEX FULL SCAN (MIN/MAX)ɨ�跽ʽ
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
--���ס���INDEX SKIP SCANɨ�跽ʽ
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
--�úõ����ǰ���������飬��ס���TABLE ACCESS BY INDEX ROWID
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create  index idx_object_id on t(object_id);
set autotrace traceonly explain
set linesize 1000
select object_id from t where object_id=2 and object_type='TABLE';
--�ڽ������������У���ῴ����������TABLE ACCESS BY INDEX ROWID��ʧ�ˡ�
create  index idx_id_type on t(object_id,object_type);
select object_id from t where object_id=2 and object_type='TABLE';



--3����������Ż�����
--3.1���������Ե���ذ���
--1. ���������ۺ��Ż�����
--���1��
select max(nbr) max_nbr
from range_part_tab
where deal_date >= TO_DATE('2015-05-01', 'YYYY-MM-DD')
and deal_date < TO_DATE('2015-06-01', 'YYYY-MM-DD');

--��ȫ��ɨ��   table access full
--------------------------------------------------------------------------------------------
--�����������2��
select max(nbr) max_nbr from range_part_tab partition(p_201505);
--��  index full scan(min/max)
--------------------------------------------------------------------------------------------
--���3��
select count(*) max_nbr
from range_part_tab
where deal_date >= TO_DATE('2015-05-01', 'YYYY-MM-DD')
and deal_date < TO_DATE('2015-06-01', 'YYYY-MM-DD');
--��ȫ��ɨ��
--------------------------------------------------------------------------------------------
--���4��
select count(*) max_nbr from range_part_tab partition(p_201505);
--��  index fast full scan


--------------------------------------------------------------------------------------------
--ɶʱ�����������ܷ�����
--���������ű� part_tab,norm_tab,ǰ��Ϊ����������Ϊ��ͨ����¼��һ������������� col2�ж��������£��Ƚ�
-- select * from xxx where col2=8������
--����׼��
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
--������ֲ�����ɨ������
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
ͳ����Ϣ
----------------------------------------------------------
         52  recursive calls
          0  db block gets
        153  consistent gets
*/
--��ͨ������ɨ������
select * from norm_tab where col2=8 ;
/*
------------------------------------------------------------------------------------------------
| Id  | Operation                   | Name             | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT            |                  |     1 |    39 |     2   (0)| 00:00:01 |
|   1 |  TABLE ACCESS BY INDEX ROWID| NORM_TAB         |     1 |    39 |     2   (0)| 00:00:01 |
|*  2 |   INDEX RANGE SCAN          | IDX_NOR_TAB_COL2 |     1 |       |     1   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------
ͳ����Ϣ
----------------------------------------------------------
         32  recursive calls
          0  db block gets
         80  consistent gets
*/
--С��: norm_tab��Ӧ��sql ��consistent getsΪ���������������������ߣ�����Ӧ�ģ���ģ�������������������Ϊ������
--������з�������sqlȴû����������������������÷�����ľֲ�������pstarg1��pstop11����11��������
--���Ե�������ķ��������޷�����ʱ��ȫ����������Ҫ���ڷ������� ��



--------------------------------------------------------------------------------------------
--3. ͬʱȡ�����Сֵ�İ���
--����׼��
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
alter table t add constraint pk_object_id primary key (OBJECT_ID);
set autotrace on
set linesize 1000
--����ִ�мƻ���ʲô��
set linesize 1000
set autotrace on
select max(object_id),min(object_id) from t;
/*
ִ�мƻ�
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


ͳ����Ϣ
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
С��: ִ�мƻ���û���߸�Ч��index full scan (min/max)ɨ�跽ʽ��������index fast full scanģʽ��
������Ϊoracle����ͬʱ������ ��ͬ������Ѱ�����ֵ ����Сֵ ��
��������޸ĳ��������õѿ������Ĳ�ѯ��ʽ���.
*/
--ͬʱȡ�����Сֵ�����ĸ���д��
select max, min
from (select max(object_id) max from t ) a,
(select min(object_id) min from t ) b;
/*
ִ�мƻ�
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


ͳ����Ϣ
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
--������ consistent gets�ϵõ�������.

--------------------------------------------------------------------------------------------------------------------
--3.2����������ľ��䰸��
--1. ���������д��
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
ִ�мƻ�
----------------------------------------------------------
Plan hash value: 3713220770

----------------------------------------------------------------------------------------------------
| Id  | Operation                         | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                  |                |  8168 | 16336 |    29   (0)| 00:00:01 |
|   1 |  COLLECTION ITERATOR PICKLER FETCH| DISPLAY_CURSOR |       |       |            |          |
----------------------------------------------------------------------------------------------------


ͳ����Ϣ
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
--���������Inд��
select  /*+index(t,idx_id_type)*/ * from t t where object_TYPE='TABLE'  AND  OBJECT_ID IN (20,21);
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
/*
ִ�мƻ�
----------------------------------------------------------
Plan hash value: 3713220770

----------------------------------------------------------------------------------------------------
| Id  | Operation                         | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                  |                |  8168 | 16336 |    29   (0)| 00:00:01 |
|   1 |  COLLECTION ITERATOR PICKLER FETCH| DISPLAY_CURSOR |       |       |            |          |
----------------------------------------------------------------------------------------------------


ͳ����Ϣ
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
--2. ������������Ӽ�������
--����׼��
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
--д��1  δ����OBJECT_ID�е�д��
set autotrace on
select * from t where object_type='VIEW' and OWNER='SYS';
/*
ִ�мƻ�
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


ͳ����Ϣ
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
*/��
--д��2   ����OBJECT_ID�е�д��
select /*+index(T IDX_UNION)*/
* from t T where object_type='VIEW'
and OBJECT_ID IN (20,21,22)
AND OWNER='LJB';
select * from table(dbms_xplan.display_cursor(null,null,'allstats last'));
/*
ִ�мƻ�
----------------------------------------------------------
Plan hash value: 3713220770

----------------------------------------------------------------------------------------------------
| Id  | Operation                         | Name           | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                  |                |  8168 | 16336 |    29   (0)| 00:00:01 |
|   1 |  COLLECTION ITERATOR PICKLER FETCH| DISPLAY_CURSOR |       |       |            |          |
----------------------------------------------------------------------------------------------------


ͳ����Ϣ
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
*/��
--С�᣺��������������ص㣺���������� �����������ڶ��У��ڶ���������һ��











2. INDEX UNIQUE SCAN
--��ע�����INDEX UNIQUE SCANɨ�跽ʽ,��Ψһ���������ʹ�á�
drop table t purge;
create table t as select * from dba_objects;
update t set object_id=rownum;
commit;
create unique index idx_object_id on t(object_id);
set autotrace traceonly
set linesize 1000
select * from t where object_id=8;






