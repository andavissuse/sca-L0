#!/bin/sh

#
# This script outputs information about commands that generated errors or warnings.
#
# Inputs: 1) path containing features files
#	  2) susedata path
#	  3) message type (warning or error)
#	  4) short-form output file (optional)
#
# Output: Info messages written to stdout (and output file if specified)
#
# Return Value:  1 if no warnings exist
#		 0
#		-1 if warnings exist
#		 2 for usage
#		-2 for error
#

# functions
function usage() {
	echo "Usage: `basename $0` [-h (usage)] [-d(ebug)] features-path susedata-path message-type [output-file]"
	exit 2
}

function exitError() {
	echo "$1"
        exit -2
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
if [ ! "$3" ]; then
        usage
else
        featuresPath="$1"
	susedataPath="$2"
	msgType="$3"
fi
if [ ! -z "$4" ]; then
	outFile="$4"
fi
[ $DEBUG ] && echo "*** DEBUG: $0: featuresPath: $featuresPath, susedataPath: $susedataPath, msgType: $msgType, outFile: $outFile" >&2

if [ ! -d "$featuresPath" ]; then
	exitError "Features path $featuresPath does not exist, exiting..."
fi
if [ ! -d "$susedataPath" ]; then
	exitError "Susedata path $susedataPath does not exist, exiting..."
fi
if [ "$msgType" != "error" ] && [ "$msgType" != "warning" ]; then
	exitError "$msgType is not error or warning, exiting..."
fi
if [ $outFile ] && [ ! -f "$outFile" ]; then
	exitError "Output file $outFile does not exist, exiting..."
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
        exitError "No sca-L0.conf file info; exiting..."
fi

msgCmdsResult=0
echo ">>> Checking $msgType message commands..."
[ $DEBUG ] && echo "*** DEBUG: $0: msgType: $msgType"
if [ "$msgType" = "error" ]; then
	msgDataTypes="$SCA_ERR_CMDS_DATATYPES"
fi
if [ "$msgType" = "warning" ]; then
	msgDataTypes="$SCA_WARN_CMDS_DATATYPES"
fi
[ $DEBUG ] && echo "*** DEBUG: $0: msgDataTypes: $msgDataTypes"
rm $featuresPath/msgs.tmp $featuresPath/smsgs.tmp 2>/dev/null
for dataType in $msgDataTypes; do
	cat $featuresPath/"$dataType".tmp >> $featuresPath/msgs.tmp
done
if [ ! -s "$featuresPath/msgs.tmp" ]; then
	echo "        No $msgType messages in supportconfig messages.txt file"
	[ $outFile ] && echo "$msgType-cmds: none" >> $outFile
	msgCmdsResult=1
else
	[ $DEBUG ] && echo "*** DEBUG: $0: $featuresPath/msgs.tmp:"
	[ $DEBUG ] && cat $featuresPath/msgs.tmp
	cat $featuresPath/msgs.tmp | sort -u > $featuresPath/smsgs.tmp
	[ $DEBUG ] && echo "*** DEBUG: $0: $featuresPath/smsgs.tmp:"
	[ $DEBUG ] && cat $featuresPath/smsgs.tmp
	cmds=""
	while IFS= read -r cmd; do
		cmds="$cmds $cmd"
	done < $featuresPath/smsgs.tmp
	cmds=`echo $cmds | sed "s/^ //"`
	[ $DEBUG ] && echo "*** DEBUG: $0: cmds: $cmds"
	[ $outFile ] && echo "$msgType-cmds: $cmds" >> $outFile
	os=`cat $featuresPath/os.tmp`
        osEquiv=`"$SCA_BIN_PATH"/os-equiv.sh "$os"`
        [ $DEBUG ] && echo "*** DEBUG: $0: osEquiv: $osEquiv" >&2
        if [ ! -z "$osEquiv" ]; then
                os="$osEquiv"
        fi
	osId=`echo $os | cut -d'_' -f1`
	osVerId=`echo $os | cut -d'_' -f2`
	osArch=`echo $os | cut -d'_' -f1,2 --complement`
	for cmd in $cmds; do
		echo "        $msgType message generated by: $cmd"
		if echo $cmd | grep -q "^kernel"; then
			kern=`cat $featuresPath/kernel.tmp`
        		kVer=`echo $kern | sed 's/-[a-z]*$//'`
        		flavor=`echo $kern | sed "s/$kVer-//"`
			cmdPkgNames="kernel-$flavor"
		else
			sleCmdPkgNames=`grep "/$cmd " $susedataPath/rpmfiles-$os.txt | cut -d" " -f2 | sort -u | tr '\n' ' '`
			[ $DEBUG ] && echo "*** DEBUG: $0: sleCmdPkgNames: $sleCmdPkgNames"
			scCmdPkgNames=""
			for sleCmdPkgName in $sleCmdPkgNames; do
				if scCmdPkgName=`grep "^$sleCmdPkgName " $featuresPath/rpm.txt | cut -d" " -f1`; then
					scCmdPkgNames="$scCmdPkgNames $scCmdPkgName"
				fi
			done
			[ $DEBUG ] && echo "*** DEBUG: $0: scCmdPkgNames: $scCmdPkgNames"
			cmdPkgNames=""
			for i in $scCmdPkgNames; do
				if echo $i | grep -q "$cmd"; then
					if [ "$i" = "$cmd" ]; then
						cmdPkgNames="$i"
						break
					else
						cmdPkgNames="$cmdPkgNames $i"
					fi
				fi
			done
			if [ -z "$cmdPkgNames" ]; then
				cmdPkgNames="$scCmdPkgNames"
			fi
		fi
		[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgNames: $cmdPkgNames"
		if [ -z "$cmdPkgNames" ]; then
			echo "            No package info for $cmd"
			[ $outFile ] && echo "$msgType-cmds-pkgs-$cmd: no-info" >> $outFile
		else
			cmdPkgs=""
			for cmdPkgName in $cmdPkgNames; do
				[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgName: $cmdPkgName"
				if [ "$cmdPkgName" = "kernel-$flavor" ]; then
					cmdPkgVer="$kVer"
				else
					cmdPkgVer=`grep "^$cmdPkgName " $featuresPath/rpm.txt | rev | cut -d" " -f1 | rev`
				fi
				cmdPkgs="$cmdPkgs $cmdPkgName-$cmdPkgVer"
			done
			cmdPkgs=`echo $cmdPkgs | sed "s/^ //"`
			[ $outFile ] && echo "$msgType-cmds-pkgs-$cmd: $cmdPkgs" >> $outFile
			for cmdPkg in $cmdPkgs; do
				[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkg: $cmdPkg"
				echo "            $cmd package: $cmdPkg"
				cmdPkgName=`echo $cmdPkg | rev | cut -d"-" -f1,2 --complement | rev`
				cmdPkgVer=`echo $cmdPkg | rev | cut -d"-" -f1,2 | rev`
				[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgName: $cmdPkgName, cmdPkgVer: $cmdPkgVer"
				cmdPkgCur=`grep "^$cmdPkgName-[0-9]" $susedataPath/rpms-$os.txt | tail -1 | sed "s/\.rpm$//" | sed "s/\.noarch$//" | sed "s/\.${arch}$//"`
				cmdPkgCurVer=`echo $cmdPkgCur | sed "s/${cmdPkgName}-//"`
				[ $DEBUG ] && echo "*** DEBUG: $0: cmdPkgCur: $cmdPkgCur, cmdPkgCurVer: $cmdPkgCurVer"
				if [ -z "$cmdPkgCurVer" ]; then
					echo "                No current version info for $cmdPkgName"
					[ $outFile ] && echo "$msgType-cmds-pkg-status-$cmdPkg: no-info" >> $outFile
				elif ! echo "$cmdPkgCur" | grep -q "$cmdPkgVer"; then
					echo "                $cmdPkgName-$cmdPkgVer package status: downlevel (current version: $cmdPkgCur)"
					[ $outFile ] && echo "$msgType-cmds-pkg-status-$cmdPkg: downlevel" >> $outFile
				else
					echo "                $cmdPkgName-$cmdPkgVer package status: current"
					[ $outFile ] && echo "$msgType-cmds-pkg-status-$cmdPkg: current" >> $outFile
				fi
			done
		fi
	done < $featuresPath/smsgs.tmp
	msgCmdsResult=0
fi

[ $outFile ] && echo "$msgType-cmds-result: $msgCmdsResult" >> "$outFile"
exit 0