#!/bin/sh

script_name=`basename $0`
passed="yes"

# Make sure all the needed Variables are present and all the Argus-components are up and running
source $FRAMEWORK/set_homes.sh
source $FRAMEWORK/start_services.sh


#########################################################
# Prepare the environment (conf-files, e.t.c) for the TEST
#

if [ ! -d /etc/vomses ]; then
	mkdir -p /etc/vomses
	if [ ! -f /etc/vomses/${VO} ]; then
		echo ${VOMSES_STRING} > /etc/vomses/${VO}
	fi
fi

USERPROXY=/tmp/x509up_u0
rm $USERPROXY

if [ ! -f $USERPROXY ]; then
	voms-proxy-init -voms "${VO}" \
	-cert $USERCERT \
	-key $USERKEY \
	-pwstdin < "${USERPWD_FILE}"
	voms-proxy-info -fqan
fi



# Copy the files:
source_dir=/etc/grid-security
target_file=grid-mapfile
touch ${source_dir}/${target_file}

target_file=groupmapfile
touch ${source_dir}/${target_file}

target_file_dir=gridmapdir
mkdir -p ${source_dir}/${target_file_dir}
rm -rf ${source_dir}/${target_file_dir}/*

# Now enter the userids etc
# /etc/grid-security/grid-mapfile
# “/${VO}” .${VO}
# <DN> <user id>
target_file=/etc/grid-security/grid-mapfile
echo "\"${VO_PRIMARY_GROUP}\"" ".${VO}" > ${target_file}
echo "\"${VO_PRIMARY_GROUP}/Role=NULL/Capability=NULL\"" ".${VO}" > ${target_file}
echo ${target_file};cat ${target_file}

target_file=/etc/grid-security/groupmapfile
GROUP1="group"
GROUP2="group2"
echo "\"${VO_PRIMARY_GROUP}\"" $GROUP1 > ${target_file}
echo "\"${VO_PRIMARY_GROUP}/Role=NULL/Capability=NULL\"" $GROUP1 > ${target_file}
echo "\"${VO_SECONDARY_GROUP}/Role=NULL/Capability=NULL\"" $GROUP2 >> ${target_file}
echo ${target_file};cat ${target_file}

# make sure that there is a reference to the glite pool-accounts in the gridmapdir
touch "/etc/grid-security/gridmapdir/${VO}001"
touch "/etc/grid-security/gridmapdir/${VO}002"


#########################################################


#########################################################
# Now probably let's start the services.
function pep_start {
	$T_PEP_CTRL status > /dev/null
	if [ $? -ne 0 ]; then
		echo "PEPd is not running. Starting one."
  		$T_PEP_CTRL start
  		sleep 10
	else
  		echo "${script_name}: Stopping PEPd."
  		$T_PEP_CTRL stop > /dev/null
  		sleep 5
  		echo "${script_name}: Starting PEPd."
  		$T_PEP_CTRL start > /dev/null
  		sleep 15
	fi
}
pep_start

function pdp_start {
	$T_PDP_CTRL status > /dev/null
	if [ $? -ne 0 ]; then
		echo "PDP is not running. Starting one."
		$T_PDP_CTRL start
  		sleep 10
	fi
}
pdp_start

function pap_start {
	$T_PAP_CTRL status | grep -q 'PAP running'
	if [ $? -ne 0 ]; then
  		echo "PAP is not running"
  		$T_PAP_CTRL start;
  		sleep 10;
	fi 
}
pap_start
#########################################################


#########################################################
# Get my cert DN for usage later
#
# Here’s the string format
# subject= /C=CH/O=CERN/OU=GD/CN=Test user 1
# so should match the first “subject= “ and keep the rest
# of the string
obligation_dn=`openssl x509 -in $USERCERT -subject -noout -nameopt RFC2253 | sed 's/subject= //'`
echo subject string="$obligation_dn"
#########################################################


#########################################################
# Now its time to define a policy and add it with pap-admin
RESOURCE=test_resource
ACTION=ANY
RULE=permit
OBLIGATION="http://glite.org/xacml/obligation/local-environment-map"

$T_PAP_HOME/bin/pap-admin ap $RULE subject="${obligation_dn}" \
			 --resource $RESOURCE \
             --action $ACTION \
             --obligation $OBLIGATION 
             
sleep 5;

$T_PEP_CTRL clearcache
$T_PDP_CTRL reloadpolicy #without this, the policy wouldn't be visible for ~5min.
#########################################################


#########################################################
# Now everything is set up and we can start the test
echo `date`
echo "---Test: new pepd-flag encode or not secondary groups in leases---"

echo "1) test if pepd is writing the secondary group into the lease:"

target_file=$T_PEP_HOME/conf/pepd.ini
NEW_FLAG=useSecondaryGroupNamesForMapping
cp ${target_file} /tmp/pepd.ini
echo "$NEW_FLAG = true" >> ${target_file}

pep_start

pepcli --pepd https://`hostname`:8154/authz \
       -c /tmp/x509up_u0 \
       --capath /etc/grid-security/certificates/ \
       --key $USERKEY \
       --cert $USERCERT \
       --resource $RESOURCE \
       --keypasswd "$USERPWD" \
       --action $ACTION > /dev/null
       
target_file=$T_PEP_HOME/conf/pepd.ini
NEW_FLAG=useSecondaryGroupNamesForMapping
cp /tmp/pepd.ini ${target_file}
echo "$NEW_FLAG = false" >> ${target_file}

pep_start

pepcli --pepd https://`hostname`:8154/authz \
       -c /tmp/x509up_u0 \
       --capath /etc/grid-security/certificates/ \
       --key $USERKEY \
       --cert $USERCERT \
       --resource $RESOURCE \
       --keypasswd "$USERPWD" \
       --action $ACTION > /dev/null
       
mv /tmp/pepd.ini ${target_file}
pep_start

LEASES_NUM=`ls /etc/grid-security/gridmapdir | wc -l`

# why 4? -> ${VO}001, ${VO}002, one lease with and one without the secondary group!
if [ $LEASES_NUM -ne 4 ]; then
	passed="no";
fi

echo "-------------------------------"
#########################################################


#########################################################
# give out wether the test has been passed
if [ $passed == "no" ]; then
	echo "---Test: new pepd-flag encode or not secondary groups in leases TEST FAILED--"
	echo `date`
	exit 1
else
	echo "---Test: new pepd-flag encode or not secondary groups in leases TEST PASS---"
	echo `date`
	exit 0
fi
