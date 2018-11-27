#!/bin/bash
# 
# A sample script for starting SIP.  
# You probably want to specify new log destinations.
#
# Takes 3 optional arguments:
# ~ SIPconfig.xml file to use
# ~ file for STDOUT, default ~/sip.out
# ~ file for STDERR, default ~/sip.err
#
# The STDOUT and STDERR files are only for the SIPServer process itself.
# Actual SIP communication and transaction logs are handled by Syslog.
#
# Examples:
#   sip_run.sh /path/to/SIPconfig.xml
#   sip_run.sh ~/my_sip/SIPconfig.xml sip_out.log sip_err.log


## for x in HOME PERL5LIB; do
## 	echo $x=${!x}
## 	if [ -z ${!x} ] ; then 
## 		echo ERROR: $x not defined;
## 		exit 1;
## 	fi;
## done;
## unset x;
# cd $PERL5LIB/C4/SIP;
echo;
echo Running from `pwd`;

sipserver='./SIPServer.pm';
sipconfig=${1:-`pwd`/SIPconfig.xml};
## outfile=${2:-$HOME/sip.out};
## errfile=${3:-$HOME/sip.err};

outfile=${2:-/opt/invenio/var/log/sip/sip.out};
errfile=${3:-/opt/invenio/var/log/sip/sip.err};

mkdir -p /opt/invenio/var/log/sip

if [ ! -r $sipconfig ] ; then
    echo "ERROR: Required SIP Configuration file not found at '$sipconfig'" >&2;
    exit 1;
fi
if [ ! -r $sipserver ] ; then
    echo "ERROR: Target SIPServer not found at '$sipserver'" >&2;
    exit 1;
fi
echo "Calling (backgrounded):";
echo "perl -I./ $sipserver $sipconfig >>$outfile 2>>$errfile";
perl -I./ $sipserver $sipconfig >>$outfile 2>>$errfile &
