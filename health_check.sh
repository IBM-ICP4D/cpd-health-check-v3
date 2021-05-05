#!/bin/bash

#output file
OUTPUT="/tmp/HealthCheckResult"
rm -f ${OUTPUT}

# formatting
LINE=$(printf "%*s\n" "30" | tr ' ' "#")


setup() {
  export HOME_DIR=`pwd`
  export UTIL_DIR=`pwd`"/util"
  export NH="--no-headers"

  export LINE=500
  export NODE_TIMEDIFF=400

  #source $UTIL_DIR/util.sh
  #. $UTIL_DIR/get_params.sh 
}

function log() {
    if [[ "$1" =~ ^ERROR* ]]; then
	eval "$2='\033[91m\033[1m$1\033[0m'"
    elif [[ "$1" =~ ^Running* ]]; then
	eval "$2='\033[1m$1\033[0m'"
    elif [[ "$1" =~ ^WARNING* ]]; then
	eval "$2='\033[1m$1\033[0m'"
    elif [[ "$1" =~ ^NOTE* ]]; then
        eval "$2='\033[1m$1\033[0m'"
    else
	eval "$2='\033[92m\033[1m$1\033[0m'"
    fi
}

function printout() {
    echo -e "$1" | tee -a ${OUTPUT}
}


function check_oc_logged_in(){
    output=""
    echo -e "\nChecking for logged into OpenShift" | tee -a ${OUTPUT}
    cmd=$(oc whoami)
    echo "${cmd}" | tee -a ${OUTPUT}
    exists=$(oc whoami) 

    if [[ $? -ne 0 ]]; then
        log "ERROR: You need to login to OpenShift to run healthcheck." result
        ERROR=1
    else
        log "Checking for logged into OpenShift [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_cluster_admin(){
    output=""
    echo -e "\nChecking for cluster-admin role" | tee -a ${OUTPUT}
    cluster_admin=$(oc get clusterrolebindings/cluster-admin)
    echo "${cluster_admin}" | tee -a ${OUTPUT}
    exists=$(oc get $NH clusterrolebindings/cluster-admin | egrep -i 'cluster-admin') 

    if [[ -z ${exists} ]]; then
        log "ERROR: You need cluster-admin role to run healthcheck." result
        ERROR=1
    else
        log "Checking for cluster-admin role [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_node_status() {
    output=""
    echo -e "\nChecking node status" | tee -a ${OUTPUT}
    cmd=$(oc get nodes | egrep -vw 'Ready')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_node_count=$(oc get $NH nodes |egrep -vw 'Ready'|wc -l) 

    if [ $down_node_count -gt 0 ]; then
        log "ERROR: Not all nodes are ready." result
        ERROR=1
    else
        log "Checking node status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_node_cpu_utilization() {
    output=""
    echo -e "\nChecking node CPU utilization" | tee -a ${OUTPUT}
    cmd=$(oc adm top nodes)
    echo "${cmd}" | tee -a ${OUTPUT}
    high_cpu_usage=$(oc adm top nodes $NH | egrep -v "unknown" | \
                   awk '{ gsub(/[%]+/," "); print $1 " " $3}'| awk '{if ($2 >= "80" ) print }' | wc -l) 

    if [ $high_cpu_usage -gt 0 ]; then
        log "WARNING: Some nodes have above 80% CPU utilization." result
        ERROR=1
    else
        log "Checking node CPU utilization [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_node_memory_utilization() {
    output=""
    echo -e "\nChecking node memory utilization" | tee -a ${OUTPUT}
    cmd=$(oc adm top nodes)
    echo "${cmd}" | tee -a ${OUTPUT}
    high_memory_usage=$(oc adm top nodes $NH | egrep -v "unknown" | \
                   awk '{ gsub(/[%]+/," "); print $1 " " $5}'| awk '{if ($2 >= "80" ) print }' | wc -l) 

    if [ $high_memory_usage -gt 0 ]; then
        log "WARNING: Some nodes have above 80% memory utilization." result
        ERROR=1
    else
        log "Checking node memory utilization [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_node_time_difference() {
    output=""
    #all_nodes=`oc get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{.name}{'\n'}"`
    all_nodes=`oc get nodes $NH | grep -w Ready | awk '{print $1}'`
    echo -e "\nChecking time difference between nodes" | tee -a ${OUTPUT}
    for i in `echo ${all_nodes}`
        do
            diff=`clockdiff $i | awk '{print $3}'`
            (( diff = $diff < 0 ? $diff * -1 : $diff ))
            if [ $diff -lt  $NODE_TIMEDIFF ]; then
               log "Time difference with node $i [Passed]" result
            else
               log "ERROR: Time difference with node $i [Failed]" result
               ERROR=1
            fi
            LOCALTEST=1
            output+="$result"

            if [[ ${LOCALTEST} -eq 1 ]]; then
                printout "$output"
                output=""
            fi
        done    
}

function check_node_memory_status() {
    output=""
    all_nodes=`oc get nodes $NH | grep -w Ready | awk '{print $1}'`
    echo -e "\nChecking memory status on nodes" | tee -a ${OUTPUT}
    for i in `echo ${all_nodes}`
        do
            mem=$(oc describe node $i | grep 'MemoryPressure   False' |  wc -l)
            if [ $mem -eq 0 ]; then
               log "ERROR: Memory pressure on node $i [Failed]" result
               ERROR=1
            else
               log "Memory pressure on node $i [Passed]" result
            fi
            LOCALTEST=1
            output+="$result"

            if [[ ${LOCALTEST} -eq 1 ]]; then
                printout "$output"
                output=""
            fi
        done    
}

function check_node_disk_status() {
    output=""
    all_nodes=`oc get nodes $NH | grep -w Ready | awk '{print $1}'`
    echo -e "\nChecking disk status on nodes" | tee -a ${OUTPUT}
    for i in `echo ${all_nodes}`
        do
            mem=$(oc describe node $i | grep 'DiskPressure     False' |  wc -l)
            if [ $mem -eq 0 ]; then
               log "ERROR: Disk pressure on node $i [Failed]" result
               ERROR=1
            else
               log "Disk pressure on node $i [Passed]" result
            fi
            LOCALTEST=1
            output+="$result"

            if [[ ${LOCALTEST} -eq 1 ]]; then
                printout "$output"
                output=""
            fi
        done    
}

function check_node_pid_status() {
    output=""
    all_nodes=`oc get nodes $NH | grep -w Ready | awk '{print $1}'`
    echo -e "\nChecking disk status on nodes" | tee -a ${OUTPUT}
    for i in `echo ${all_nodes}`
        do
            mem=$(oc describe node $i | grep 'PIDPressure      False' |  wc -l)
            if [ $mem -eq 0 ]; then
               log "ERROR: PID pressure on node $i [Failed]" result
               ERROR=1
            else
               log "PID pressure on node $i [Passed]" result
            fi
            LOCALTEST=1
            output+="$result"

            if [[ ${LOCALTEST} -eq 1 ]]; then
                printout "$output"
                output=""
            fi
        done    
}

function check_deployments() {
    output=""
    echo -e "\nChecking deployment status" | tee -a ${OUTPUT}
    cmd=$(oc get deployment --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_deployment_count=$(oc get $NH deployment --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9' | wc -l) 

    if [ $down_deployment_count -gt 0 ]; then
        log "ERROR: Not all deployments are ready." result
        ERROR=1
    else
        log "Checking deployment status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_statefulsets() {
    output=""
    echo -e "\nChecking StatefulSet status" | tee -a ${OUTPUT}
    cmd=$(oc get sts --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_sts_count=$(oc get $NH sts --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9' | wc -l) 

    if [ $down_sts_count -gt 0 ]; then
        log "ERROR: Not all StatefulSets are ready." result
        ERROR=1
    else
        log "Checking StatefulSets status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_replicasets() {
    output=""
    echo -e "\nChecking replicaset status" | tee -a ${OUTPUT}
    cmd=$(oc get rs --all-namespaces | awk '{if ($3 != $4) print $0}')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_rs_count=$(oc get rs $NH --all-namespaces | awk '{if ($3 != $4) print $0}' | wc -l) 

    if [ $down_rs_count -gt 0 ]; then
        log "ERROR: Not all replicasets are ready." result
        ERROR=1
    else
        log "Checking replicasets status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}


## Check OpenShift CLI autentication ##
function User_Authentication_Check() {
    check_oc_logged_in
    check_cluster_admin

    if [[ ${ERROR} -eq 1 ]]; then
        output=""
        log "NOTE: User Authentication Failed. Exiting." result
        output+="$result"
        printout "$output"
        exit 1
    fi
}


## Platform checks related to nodes ##
function Nodes_Check() {
    check_node_status
    check_node_cpu_utilization
    check_node_memory_utilization
    check_node_time_difference
    check_node_memory_status
    check_node_disk_status
    check_node_pid_status
}


## Platform checks related to applications ##
function Applications_Check() {
    check_deployments
    check_statefulsets
    check_replicasets
}


#### MAIN ####
setup $@
User_Authentication_Check
Nodes_Check
Applications_Check

