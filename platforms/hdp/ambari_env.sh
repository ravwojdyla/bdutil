# Copyright 2014 Google Inc. All Rights Reserved.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS-IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


## ambari_env.sh
##
## Purpose: called directly from 'bdutil' to provision
##  Hortonworks Data Platform Clusters on the google CLoud Platform
##
## Usage: see README.md


########################################################################
## There should be nothing to edit here, use ambari.conf              ##
########################################################################

# import for GCS_CONNECTOR_JAR settings
import_env hadoop2_env.sh

## Defaults to override bdutil_env.sh
NUM_WORKERS=4 # default to 4 workers plus one master for good spreading of master daemons
GCE_IMAGE='centos-6' # bdutil for HDP is only tested with centos and rhel 6
MASTER_UI_PORTS=('8080') ## Ambari administrative port

## import configuration overrides
import_env platforms/hdp/ambari.conf

## Use HDFS
readonly DEFAULT_FS='hdfs'

## Attach disks
USE_ATTACHED_PDS=${USE_ATTACHED_PDS-true}
WORKER_ATTACHED_PDS_SIZE_GB=${WORKER_ATTACHED_PDS_SIZE_GB-1500}
MASTER_ATTACHED_PD_SIZE_GB=${MASTER_ATTACHED_PD_SIZE_GB-1500}

## If 'true', URLs for web interfaces, such as the jobtracker will be
## linked from Ambari with the public IP.
## Default is false. You will need to SSH to reach the host in this case.
AMBARI_PUBLIC=${AMBARI_PUBLIC-false}

## Services passed to Ambari for generating blueprint recommendations
AMBARI_SERVICES="${AMBARI_SERVICES-FALCON FLUME GANGLIA HBASE HDFS HIVE
 KAFKA KERBEROS MAPREDUCE2 NAGIOS OOZIE PIG SLIDER SQOOP STORM TEZ YARN ZOOKEEPER}"
AMBARI_SERVICES='FALCON FLUME GANGLIA HBASE HDFS HIVE KAFKA KERBEROS MAPREDUCE2
    NAGIOS OOZIE PIG SLIDER SQOOP STORM TEZ YARN ZOOKEEPER'

HDP_VERSION="${HDP_VERSION-2.2}"
AMBARI_API="${AMBARI_API-http://localhost:8080/api/v1}"
AMBARI_CURL="curl -su admin:admin -H X-Requested-By:ambari"
AMBARI_VERSION="1.7.0"
AMBARI_REPO=${AMBARI_REPO-http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/${AMBARI_VERSION}/ambari.repo}

## Install JDK with compiler/tools instead of the minimal JRE.
INSTALL_JDK_DEVEL=true
JAVA_HOME="${JAVA_HOME-/etc/alternatives/java_sdk}"

normalize_boolean 'AMBARI_PUBLIC'
normalize_boolean 'INSTALL_JDK_DEVEL'

## timing for ambari_wait()
AMBARI_TIMEOUT=3600
POLLING_INTERVAL=10

function ambari_wait() {
  local condition="$1"
  local goal="$2"
  local failed="FAILED"
  local limit=$(( ${AMBARI_TIMEOUT} / ${POLLING_INTERVAL} + 1 ))

  for (( i=0; i<${limit}; i++ )); do
    local status=$(bash -c "${condition}")
    if [ "${status}" = "${goal}" ]; then
      break
    elif [ "${status}" = "${failed}" ]; then
      echo "Ambari operiation failed with status: ${status}" >&2
      return 1
    fi
    echo "ambari_wait status: ${status}" >&2
    sleep ${POLLING_INTERVAL}
  done

  if [ ${i} -eq ${limit} ]; then
    echo "ambari_wait did not finish within" \
        "'${AMBARI_TIMEOUT}' seconds. Exiting." >&2
    return 1
  fi
}


UPLOAD_FILES=(
  'hadoop2_env.sh'
  'libexec/hadoop_helpers.sh'
  'platforms/hdp/ambari.conf'
  'platforms/hdp/configuration.json'
  'platforms/hdp/create_blueprint.py'
  'platforms/hdp/resources/public-hostname-gcloud.sh'
  'platforms/hdp/resources/thp-disable.sh'
)

GCS_CACHE_CLEANER_USER='hdfs'
GCS_CACHE_CLEANER_LOG_DIRECTORY="/var/log/hadoop/${GCS_CACHE_CLEANER_USER}"
GCS_CACHE_CLEANER_LOGGER='INFO,RFA'
HADOOP_CONF_DIR="/etc/hadoop/conf"
HADOOP_INSTALL_DIR="/usr/local/lib/hadoop"

COMMAND_GROUPS+=(
  "ambari-setup:
     libexec/mount_disks.sh
     libexec/install_java.sh
     libexec/setup_hadoop_user.sh
     platforms/hdp/install_ambari.sh
  "

  "install-ambari-components:
     platforms/hdp/install_ambari_components.sh
  "

  "install-gcs-connector-on-ambari:
     platforms/hdp/install_gcs_connector_on_ambari.sh
  "
)

COMMAND_STEPS=(
  'ambari-setup,ambari-setup'
  'deploy-master-nfs-setup,*'
  'deploy-client-nfs-setup,deploy-client-nfs-setup'
  'install-ambari-components,*'
  'install-gcs-connector-on-ambari,install-gcs-connector-on-ambari'
)
