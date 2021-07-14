#!/bin/sh

#
# This script outputs OS information (OS name, version supportability, etc.)
#
# Inputs: 1) Path containing features files
#	  2) susedata path
#	  3) short-form output file (optional)
#
# Output: Info messages written to stdout
#	  os, os-support, os-result name-value pairs written to output file
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path susedata-path [output-file]"
}

# arguments
while getopts 'hd' OPTION; do
        case $OPTION in
                h)
                        usage 
                        exit 0
                        ;;
                d)
                        DEBUG=1
                        ;;
        esac
done
shift $((OPTIND - 1))
if [ -z "$2" ]; then
        usage >&2
	exit 1
else
        featuresPath="$1"
	susedataPath="$2"
fi
if [ ! -z "$3" ]; then
	outFile="$3"
fi

if [ ! -d "$featuresPath" ] || [ ! -d "$susedataPath" ] || [ $outFile ] && [ ! -f "$outFile" ]; then
	echo "$0: features path $featuresPath, susedata path $susedataPath, or output file $outFile does not exist, exiting..." >&2
	[ $outFile ] && echo "os: error" >> $outFile
	[ $outFile ] && echo "os-support: error" >> $outFile
	[ $outFile ] && echo "os-result: 0" >> $outFile
	exit 1
fi

# config file
curPath=`dirname "$(realpath "$0")"`
confFile="/usr/etc/sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
confFile="/etc/sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
confFile="$curPath/../sca-L0.conf"
[ -r "$confFile" ] && source ${confFile}
if [ -z "$SCA_HOME" ]; then
        echo "No sca-L0.conf file info; exiting..." >&2
	[ $outFile ] && echo "os: error" >> $outFile
	[ $outFile ] && echo "os-support: error" >> $outFile
	[ $outFile ] && echo "os-result: 0"
	exit 1
fi

# intro
echo ">>> Checking OS version and support status..."

# os
os=`cat "$featuresPath"/os.tmp`
[ $DEBUG ] && echo "*** DEBUG: $0: os: $os" >&2
if [ -z "$os" ]; then
	echo "        Error retrieving OS info"
	[ $outFile ] && echo "os: error" >> $outFile
	[ $outFile ] && echo "os-support: error" >> $outFile
	[ $outFile ] && echo "os-result: 0"
	exit 1
fi
osName=`echo $os | cut -d'_' -f1 | tr '[:lower:]' '[:upper:]'`
osVer=`echo $os | cut -d'_' -f2`
osArch=`echo $os | cut -d'_' -f1,2 --complement`
case $os in
	caasp*)
		osName="CaaSP"
		osVer=`echo $os | cut -d'_' -f2`
		;;
	opensuse-leap*)
		osName="openSUSE Leap"
		osVer=`echo $os | cut -d'_' -f2`
		;;
	opensuse-tumbleweed*)
		osName="openSUSE Tumbleweed"
		osVer=`echo $os | cut -d'_' -f2`
		;;
	sle*)
		osName=`echo $os | cut -d'_' -f1 | tr '[:lower:]' '[:upper:]'`
		osVer=`echo $osVer | sed 's/\./ SP/'`
		;;
	suse-microos*)
		osName="SLE Micro"
		osVer=`echo $os | cut -d'_' -f2`
		;;
	*)
		;;
esac
osArch=`echo $os | cut -d'_' -f1,2 --complement`
echo "        OS: $osName $osVer $osArch"
[ $outFile ] && echo "os: $os" >> $outFile

# support status
lifecycleInfo=`grep "$os" $susedataPath/lifecycles.csv`
[ $DEBUG ] && echo "*** DEBUG: $0: lifecycleInfo: $lifecycleInfo" >&2
endLtss=`echo $lifecycleInfo | grep "$os" | cut -d',' -f4`
endGeneral=`echo $lifecycleInfo | grep "$os" | cut -d',' -f3`
[ $DEBUG ] && echo "*** DEBUG: $0: endLtss: $endLtss, endGeneral: $endGeneral" >&2
if [ -z "$endLtss" ] || [ -z "$endGeneral" ]; then
        echo "        No lifecycle data for $osName $osVer $osArch"
        [ $outFile ] && echo "os-support: no-info" >> $outFile
        [ $outFile ] && echo "os-result: 0" >> $outFile
        exit 1
fi
curDate=`date +%Y%m%d`
if (( curDate > endLtss )); then
	echo "        Support status: Custom support contract required"
	[ $outFile ] && echo "os-support: out-of-support" >> $outFile
	osResult="-1"
elif (( curDate > endGeneral )); then
	echo "        Support status: LTSS support contract required"
	[ $outFile ] && echo "os-support: ltss" >> $outFile
	osResult="0"
else
	echo "        Support status: Supported"
	[ $outFile ] && echo "os-support: supported" >> $outFile
	osResult="1"
fi
[ $outFile ] && echo "os-result: $osResult" >> $outFile
exit 0
