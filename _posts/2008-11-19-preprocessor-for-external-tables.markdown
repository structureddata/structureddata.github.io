---
author: Greg Rahn
comments: true
date: 2008-11-19T08:00:42.000Z
layout: post
slug: preprocessor-for-external-tables
title: Preprocessor For External Tables
wp_id: 291
wp_categories:
  - 11gR1
  - Oracle
wp_tags:
  - compressed external table
  - external table preprocessor
  - external tables
  - Oracle
  - sqlldr
---

Before [External Tables](http://download.oracle.com/docs/cd/B28359_01/server.111/b28319/et_concepts.htm) existed in the Oracle database, loading from flat files was done via [SQL*Loader](http://download.oracle.com/docs/cd/B28359_01/server.111/b28319/part_ldr.htm#i436326).  One option that some used was to have a compressed text file and load it with SQL\*Loader via a named pipe.  This allowed one not to have to extract the file, which could be several times the size of the compressed file.  As of 11.1.0.7, a similar feature is now available for External Tables (and will be in 10.2.0.5).  This enhancement is a result of [Bug 6522622](https://metalink.oracle.com/metalink/plsql/showdoc?db=NOT&id=6522622.8) which is mentioned in the [Bugs fixed in the 11.1.0.7 Patch Set](https://metalink.oracle.com/CSP/main/article?cmd=show&type=NOT&id=601739.1) note.  Unfortunately it appears that there aren't any notes on how to actually use the External Table Preprocessor so allow me to give some insight into its use.

The `PREPROCESSOR` clause is part of the [`record_format_info`](http://download.oracle.com/docs/cd/B28359_01/server.111/b28319/et_params.htm#i1009499) clause.  The syntax of the `PREPROCESSOR` clause is as follows:

>`PREPROCESSOR [directory_spec:] file_spec [preproc_options_spec]`

It's pretty straight forward when you see an example.   Line 31 contains the new clause.

```
create or replace directory load_dir as '/data/tpc-ds/flat_files/1gb';
create or replace directory log_dir  as '/tmp';
create or replace directory exec_dir as '/bin';
--
-- ET_CUSTOMER_ADDRESS
--
DROP TABLE ET_CUSTOMER_ADDRESS;
CREATE TABLE ET_CUSTOMER_ADDRESS
(
    "CA_ADDRESS_SK"                  NUMBER
   ,"CA_ADDRESS_ID"                  CHAR(16)
   ,"CA_STREET_NUMBER"               CHAR(10)
   ,"CA_STREET_NAME"                 VARCHAR2(60)
   ,"CA_STREET_TYPE"                 CHAR(15)
   ,"CA_SUITE_NUMBER"                CHAR(10)
   ,"CA_CITY"                        VARCHAR2(60)
   ,"CA_COUNTY"                      VARCHAR2(30)
   ,"CA_STATE"                       CHAR(2)
   ,"CA_ZIP"                         CHAR(10)
   ,"CA_COUNTRY"                     VARCHAR2(20)
   ,"CA_GMT_OFFSET"                  NUMBER
   ,"CA_LOCATION_TYPE"               CHAR(20)
)
ORGANIZATION EXTERNAL
(
   TYPE oracle_loader
   DEFAULT DIRECTORY load_dir
   ACCESS PARAMETERS
   (
      RECORDS DELIMITED BY NEWLINE
      PREPROCESSOR exec_dir:'gunzip' OPTIONS '-c'
      BADFILE log_dir: 'CUSTOMER_ADDRESS.bad'
      LOGFILE log_dir: 'CUSTOMER_ADDRESS.log'
      FIELDS TERMINATED BY '|'
      MISSING FIELD VALUES ARE NULL
      (
          "CA_ADDRESS_SK"
         ,"CA_ADDRESS_ID"
         ,"CA_STREET_NUMBER"
         ,"CA_STREET_NAME"
         ,"CA_STREET_TYPE"
         ,"CA_SUITE_NUMBER"
         ,"CA_CITY"
         ,"CA_COUNTY"
         ,"CA_STATE"
         ,"CA_ZIP"
         ,"CA_COUNTRY"
         ,"CA_GMT_OFFSET"
         ,"CA_LOCATION_TYPE"
      )
   )
   LOCATION ('customer_address.dat.gz')
)
REJECT LIMIT UNLIMITED
;

SQL> select count(*) from ET_CUSTOMER_ADDRESS;

  COUNT(*)
----------
     50000
```

Now let's double check:

```
$ gunzip -c customer_address.dat.gz | wc -l
50000
```

**Note:** The preprocessor option does not allow the use`│`, `&`, and `$` characters due to security reasons.

This is a great enhancement for those who transport compressed files around their networks and want to load them directly into their database via External Tables.  One advantage of this feature is that when loading flat files from an NFS staging area, the network traffic is reduced by N, where N is the compression ratio of the file.  For example, if your flat file compresses 10x (which is not uncommon), then you get an effective gain of 10x the throughput for the same network bandwidth.  Or if you like, the required network bandwidth is reduced 10x to transfer the same logical data set.  In this case the compression rate was 4x.

There are a few things to be aware of when using this feature.  If the external table is parallel, then the number of files in the External Table Location clause should be equal or greater than the degree of parallelism (DOP).  This is because the preprocessor outputs a stream and this stream can not be broken down into granules for multiple Parallel Query Slaves to work on, like a normal uncompressed text file.  Each PQ Slave can work on at most, 1 file/stream.   For example, if you have a DOP of 16 set on the External Table, but only have 10 files, 10 PQ Slaves will be busy and 6 will be idle, as there are more slaves than files.  This means that to get optimal throughput the number of files should be a multiple of the DOP.  Obviously this is not always possible so the recommendation is to have more smaller files vs. fewer larger files.  This will limit the skew in the workload for the PQ Slaves if/when there are "remainder" files.

Hopefully you will find this enhancement very useful.  I sure do.
