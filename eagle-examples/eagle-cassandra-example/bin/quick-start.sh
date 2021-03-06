#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export EAGLE_CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export EAGLE_BASE_DIR=$EAGLE_CURRENT_DIR/../../..
export EAGLE_ASSEMBLY_DIR=${EAGLE_BASE_DIR}/eagle-assembly/target/eagle-*-bin/eagle-*/

ls ${EAGLE_ASSEMBLY_DIR} 1>/dev/null 2>/dev/null
if [ "$?" != "0" ];then
	echo "$EAGLE_ASSEMBLY_DIR not exist, build now"
	cd $EAGLE_BASE_DIR
	mvn package -DskipTests
fi

cd $EAGLE_ASSEMBLY_DIR/

bin/eagle-service.sh status

if [ "$?" != "0" ];then
	echo "Starting eagle service ..."
	bin/eagle-service.sh start
	sleep 1
else
	echo "Eagle service has already started"
fi

bin/eagle-topology-init.sh

echo "Starting zookeeper"
bin/zookeeper-server-start.sh -daemon conf/zookeeper-server.properties
sleep 1

echo "Starting kafka"
bin/kafka-server-start.sh -daemon conf/kafka-server.properties
sleep 1

echo "Creating kafka topic: cassandra_querylog_local"
bin/kafka-topics.sh --zookeeper localhost:2181 --create --topic cassandra_querylog_local --partitions 3 --replication-factor 1

$EAGLE_CURRENT_DIR/init.sh
$EAGLE_CURRENT_DIR/send-sample-querylog.sh
$EAGLE_ASSEMBLY_DIR/bin/kafka-stream-monitor.sh cassandraQueryLogStream cassandraQueryLogExecutor $EAGLE_CURRENT_DIR/../conf/cassandra-security-local.conf