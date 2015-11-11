#!/bin/bash

script_name=`basename $0`
failed="no"
policyfile=policyfile.txt

# Make sure all the needed Variables are present and all the Argus-components are up and running
source $FRAMEWORK/set_homes.sh
source $FRAMEWORK/start_services.sh

export GRID_MAPFILE_VO_MAP="no"
export GRID_MAPFILE_DN_MAP="yes"
export GROUP_MAPFILE_VO_MAP="no"
export GROUP_MAPFILE_DN_MAP="yes"

export PEPENV_preferDNForLoginName="preferDNForLoginName = true"
export PEPENV_preferDNForPrimaryGroupName="preferDNForPrimaryGroupName = true"
export PEPENV_noPrimaryGroupNameIsError="noPrimaryGroupNameIsError = true"

# Set up the environment for the use of pepcli
source $FRAMEWORK/pepcli-env.sh

echo "Running: ${script_name}"
echo `date`

###############################################################

$PEPCLI -p https://`hostname`:8154/authz \
       --capath /etc/grid-security/certificates/ \
       --key $USERKEY \
       --cert $USERCERT \
       -k $USERCERT \
       -r "resource_1" \
       -a "testwerfer" \
       -f "/${VO}" > $LOGSLOCATION/${script_name}.out
result=$?

if [ $result -eq 0 ]
then

    echo "$LOGSLOCATION/${script_name}.out"
    cat $LOGSLOCATION/${script_name}.out

    grep -q resource_1 $LOGSLOCATION/${script_name}.out;
    if [ $? -ne 0 ]
    then
        echo "${script_name}: Did not find expected resource: $RESOURCE"
        failed="yes"
    fi
    RULE=permit
    grep -qi $RULE $LOGSLOCATION/${script_name}.out;
    if [ $? -ne 0 ]
    then
	echo "${script_name}: Did not find expected rule: $RULE"
	failed="yes"
    fi

    declare groups;

    foo=`grep Username: $LOGSLOCATION/${script_name}.out`
    IFS=" "
    groups=( $foo )
    if [ ! -z ${groups[1]} ]
    then
        sleep 0;
    else
	echo "${script_name}: No user account mapped."
        failed="yes"
    fi
    foo=`grep Group: $LOGSLOCATION/${script_name}.out`
    IFS=" "
    groups=( $foo )
    prim_group=${groups[1]}
    if [ ! -z ${prim_group} ]
    then
        sleep 0;
    else
        echo "${script_name}: No user group mapped."
        failed="yes"
    fi
    foo=`grep "Secondary Groups:" $LOGSLOCATION/${script_name}.out`
    IFS=" "
    groups=( $foo )
    sec_group=${groups[2]}
    if [ ! -z ${sec_group} -a ${sec_group} = ${prim_group} ]
    then
        sleep 0;
    else
        echo "${script_name}: No user secondary group mapped."
        failed="yes"
    fi
else
    failed="yes"
fi

###############################################################
#
# clean up...
#
# Make sure to return the files
#
# Copy the files:
# /etc/grid-security/grid-mapfile
# /etc/grid-security/groupmapfile
# /etc/grid-security/voms-grid-mapfile

source_dir="/tmp/"
target_dir="/etc/grid-security"
target_file="grid-mapfile"
cp ${source_dir}/${target_file}.${script_name} ${target_dir}/${target_file}
target_file="voms-grid-mapfile"
cp ${source_dir}/${target_file}.${script_name} ${target_dir}/${target_file}
target_file="groupmapfile"
cp ${source_dir}/${target_file}.${script_name} ${target_dir}/${target_file}

cp $SCRIPTBACKUPLOCATION/$T_PEP_INI $T_PEP_CONF/$T_PEP_INI

if [ $failed == "yes" ]; then
  echo "---${script_name}: TEST FAILED---"
  echo `date`
  exit 1
else 
  echo "---${script_name}: TEST PASSED---"
  echo `date`
  exit 0
fi

