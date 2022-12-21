#!/bin/bash

export HADOOP_OPTS="-XX:-UseGCOverheadLimit $HADOOP_OPTS"
export HADOOP_CLIENT_OPTS="-Xmx20480m $HADOOP_CLIENT_OPTS"
export DAY=`date +"%Y-%m-%d"`
export DATE=$(date)

TMPDIR=/tmp/chksmallfiles
test -d $TMPDIR || echo "Directory does not exists and will be created."; mkdir $TMPDIR

hdfs_path_to_raw=/tmp/raw_fsck_extract
hdfs_path_to_final=/tmp/final_fsck_extract

OUTFILE=$TMPDIR/fsck_runlog_$DAY.txt
echo 'Starting fsck run for '$DAY' at '$DATE | tee ${OUTFILE}
echo | tee -a ${OUTFILE}
FSCKRAW=$TMPDIR/fsck_raw_$DAY.out
hdfs fsck / -files -blocks -locations > $FSCKRAW

echo 'Creating blocks and files report at '$DATE | tee ${OUTFILE}
echo | tee -a ${OUTFILE}
ALLBLKFILES=$TMPDIR/all_block_files.out
grep "block(s):  OK" $FSCKRAW > $ALLBLKFILES
sed -i 's/,/\//g' $ALLBLKFILES

# Select path, size-bytes, nro-blocks, status, extract_date
echo 'Creating csv file at '$DATE | tee ${OUTFILE}
echo | tee -a ${OUTFILE}
CSVFILE=$TMPDIR/fsck_allBlockFiles_$DAY.csv
awk '{print $1"," $2"," $6"," $8","}' $ALLBLKFILES > $CSVFILE
sed -i "s|$|$DAY|g" $CSVFILE
sed -i "s| ||g" $CSVFILE

echo 'Uploading files to HDFS at '$DATE | tee ${OUTFILE}
echo | tee -a ${OUTFILE}
## Security setting for supergroup access

if $(hdfs dfs -test -d $hdfs_path_to_raw) ;
	then
	hdfs dfs -chmod 775 $hdfs_path_to_raw
	hdfs dfs -put $FSCKRAW $hdfs_path_to_raw
else
 	hdfs dfs -mkdir -p $hdfs_path_to_raw | tee -a ${OUTFILE} 2>&1
 	hdfs dfs -put $FSCKRAW $hdfs_path_to_raw | tee -a ${OUTFILE} 2>&1
fi

if $(hdfs dfs -test -d $hdfs_path_to_final) ;
	then
	hdfs dfs -chmod 775 $hdfs_path_to_final
	hdfs dfs -put $CSVFILE $hdfs_path_to_final
else
 	hdfs dfs -mkdir -p $hdfs_path_to_final | tee -a ${OUTFILE} 2>&1
 	hdfs dfs -put $CSVFILE $hdfs_path_to_final | tee -a ${OUTFILE} 2>&1
fi
echo | tee -a ${OUTFILE} 2>&1
echo "Checking errors:"  | tee -a ${OUTFILE} 2>&1
grep 'denied/|FAILED' $FSCKRAW | tee -a ${OUTFILE} 2>&1
echo | tee -a ${OUTFILE} 2>&1
echo "The temporary files will be deleted." | tee -a ${OUTFILE} 2>&1
rm -rfv $TMPDIR | tee -a ${OUTFILE} 2>&1