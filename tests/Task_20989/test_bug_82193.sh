#!/bin/sh

script_name=`basename $0`
passed="yes"

# Make sure all the needed Variables are present and all the Argus-components are up and running
source $FRAMEWORK/set_homes.sh
source $FRAMEWORK/start_services.sh

#########################################################
# Now everything is set up and we can start the test
echo `date`
echo "---Test: Pap-admin aace CN=.../... causes Pap-crash at restart---"

echo "1) test if Pap restart after a kerberized DN was added as acl:"

FAKE_KERB_DN="CN=host/argus.example.ch,C=CH"
$T_PAP_HOME/bin/pap-admin aace $FAKE_KERB_DN ALL
if [ $? -ne 0 ]; then
        passed="no";
	echo "faild to add a kerberized DN to pap"
else
	echo "added a kerberized DN to pap"
fi

sleep 10
/etc/rc.d/init.d/$T_PAP_CTRL restart;
echo "Pap-restarted ..."
sleep 10;

$T_PAP_HOME/bin/pap-admin lp > /dev/null
if [ $? -ne 0 ]; then
	passed="no";
  	echo "PAP crashed"
else
	echo "Succesfull"
	$T_PAP_HOME/bin/pap-admin race $FAKE_KERB_DN
fi 
echo "-------------------------------"
#########################################################


#########################################################
# give out wether the test has been passed
if [ $passed == "no" ]; then
	echo "---Test: Pap-admin aace CN=.../... causes Pap-crash at restart---TEST FAILED"
	echo `date`
	exit 1
else
	echo "---Test: Pap-admin aace CN=.../... causes Pap-crash at restart---TEST PASSED"
	echo `date`
	exit 0
fi
