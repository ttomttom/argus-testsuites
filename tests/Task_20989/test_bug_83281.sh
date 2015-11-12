#!/bin/sh

script_name=`basename $0`
passed="yes"

# Make sure all the needed Variables are present and all the Argus-components are up and running
source $FRAMEWORK/set_homes.sh
source $FRAMEWORK/start_services.sh

#########################################################

export GRID_MAPFILE_VO_MAP="yes"
export GRID_MAPFILE_DN_MAP="no"
export GROUP_MAPFILE_VO_MAP="yes"
export GROUP_MAPFILE_DN_MAP="no"

export PEPENV_preferDNForLoginName="preferDNForLoginName = true"
export PEPENV_preferDNForPrimaryGroupName="preferDNForPrimaryGroupName = true"
export PEPENV_noPrimaryGroupNameIsError="noPrimaryGroupNameIsError = true"

# Set up the environment for the use of pepcli
source $FRAMEWORK/pepcli-env.sh

#########################################################
# Now everything is set up and we can start the test
echo `date`
echo "---Test: Argus renews timestamp of leases---"

echo "1) test if timestamp of lease in gridmapdir is altered:"

pepcli --pepd https://`hostname`:8154/authz \
       -c /tmp/x509up_u0 \
       --capath /etc/grid-security/certificates/ \
       --key $USERKEY \
       --cert $USERCERT \
       --resource $RESOURCE \
       --keypasswd "$USERPWD" \
       --action $ACTION > /tmp/${script_name}.out
result=$?

echo "---------------------------------------"
cat /tmp/${script_name}.out
echo "---------------------------------------"

if [ $result -ne 0 ]; then
	echo "${script_name}: pepcli failed!"
	passed="no"
fi

LEASE_FILE=`ls /etc/grid-security/gridmapdir | grep %`
TIMESTAMP=`date -r /etc/grid-security/gridmapdir/$LEASE_FILE +%s`
echo `date -r /etc/grid-security/gridmapdir/$LEASE_FILE`

sleep 5

pepcli --pepd https://`hostname`:8154/authz \
       -c /tmp/x509up_u0 \
       --capath /etc/grid-security/certificates/ \
       --key $USERKEY \
       --cert $USERCERT \
       --resource $RESOURCE \
       --keypasswd "$USERPWD" \
       --action $ACTION > /tmp/${script_name}.out
result=$?

echo "---------------------------------------"
cat /tmp/${script_name}.out
echo "---------------------------------------"

if [ $result -ne 0 ]; then
        echo "${script_name}: pepcli failed!"
        passed="no"
fi

NEW_TIMESTAMP=`date -r /etc/grid-security/gridmapdir/$LEASE_FILE +%s`
echo `date -r /etc/grid-security/gridmapdir/$LEASE_FILE`

if [ $TIMESTAMP -ne $NEW_TIMESTAMP ]; then
	echo "Timestamp has indeed been altered"
else
	passed="no";
	echo "Timestamp has not been altered"
fi

echo "-------------------------------"
#########################################################
#
# clean up...
#
# Make sure to return the files
#
# Copy the files:
# /etc/grid-security/grid-mapfile
# /etc/grid-security/groupmapfile
# /etc/grid-security/voms-grid-mapfile

source_dir="/tmp"
target_dir="/etc/grid-security"
target_file="grid-mapfile"
mv ${source_dir}/${target_file}.${script_name} ${target_dir}/${target_file}
target_file="voms-grid-mapfile"
mv ${source_dir}/${target_file}.${script_name} ${target_dir}/${target_file}
target_file="groupmapfile"
mv ${source_dir}/${target_file}.${script_name} ${target_dir}/${target_file}

cp $SCRIPTBACKUPLOCATION/$T_PEP_INI $T_PEP_CONF/$T_PEP_INI

rm -f "${source_dir}/${script_name}.out"

#########################################################
# give out wether the test has been passed
if [ $passed == "no" ]; then
	echo "---Test: Argus renews timestamp of leases TEST FAILED---"
	echo `date`
	exit 1
else
	echo "---Test: Argus renews timestamp of leases TEST PASSED---"
	echo `date`
	exit 0
fi
