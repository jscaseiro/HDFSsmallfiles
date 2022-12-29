#!/usr/bin/env python3

import pyspark
from pyspark.sql import SparkSession
from pyspark.sql import Row
from pyspark.sql.types import StructType
appName= "hive_pyspark"
master= "yarn"

spark = SparkSession.builder \
	    .master(master).appName(appName).enableHiveSupport().getOrCreate()
        
tblSchema = StructType() \
                .add("path", "string")\
                .add("size_bytes", "integer")\
                .add("nro_blocks", "integer")\
                .add("status", "string")\
                .add("time", "integer")\
                .add("extract_dt", "date")
                
tblData = spark.read.csv("hdfs://cdp.18.224.174.227.nip.io:8020/tmp/final_fsck_extract", schema=tblSchema)

tblData.cache()

tblData.count()\

catalyst_plan = tblData._jdf.queryExecution().logical()

size_bytes = spark._jsparkSession.sessionState().executePlan(catalyst_plan).optimizedPlan().stats().sizeInBytes()

spark.sql("DROP TABLE IF EXISTS smallfiles.fsck_smallfiles")

# Parquet Snappy Compression Ratio 68% (128M + PSCR) and partitioned by extraction date:
if size_bytes >= 225485783:
    tblData.write.format('parquet').option('compression','snappy').partitionBy('extract_dt').saveAsTable('smallfiles.fsck_smallfiles')
    
else:
    tblData.write.format("parquet").saveAsTable("smallfiles.fsck_smallfiles")
    
tblData.unpersist()

tblraw=spark.sql("select * from smallfiles.fsck_smallfiles limit 5")
tblraw.show()

tblrawdesc=spark.sql("show create table smallfiles.fsck_smallfiles")
tblrawdesc.show(truncate=False)

tbl=spark.sql("select * from smallfiles.fsck_smallfiles where extract_dt='2022-12-28' limit 5")
tbl.show()

tbl=spark.sql("select * from smallfiles.fsck_smallfiles where extract_dt='2022-12-29' limit 5")
tbl.show()