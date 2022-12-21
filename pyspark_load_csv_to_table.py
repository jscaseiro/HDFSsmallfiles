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
                .add("extract_dt", "date")
                
tblData = spark.read.csv("hdfs://cdp.18.224.174.227.nip.io:8020/tmp/final_fsck_extract", schema=tblSchema)

tblData.printSchema()

tblData.show(5)

tblData.write.saveAsTable("smallfiles.fsck_smallfiles")

tblraw=spark.sql("select * from smallfiles.fsck_smallfiles limit 5")
tblraw.show()

tblrawdesc=spark.sql("show create table smallfiles.fsck_smallfiles")
tblrawdesc.show(truncate=False)

tbl=spark.sql("select * from smallfiles.fsck_smallfiles where extract_dt='2022-12-20' limit 5")
tbl.show()

tbl=spark.sql("select * from smallfiles.fsck_smallfiles where extract_dt='2022-12-21' limit 5")
tbl.show()