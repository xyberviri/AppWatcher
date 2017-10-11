#!/bin/bash
varDestinationEmail=DESTINATION@EMAIL.COM
varEtcFolder=/etc/appwatcher
varCurrentList=${varEtcFolder}/packages.lst
varLatestList=${varEtcFolder}/latest.lst
varReportFile=/tmp/${RANDOM}.appwatcher
SERVER="`hostname`";

function sendReport {
if [ ${#varPackagesAdded[@]} -gt 0 ] || [ ${#varPackagesRemoved[@]} -gt 0 ]; then
	echo "Sending report to $varDestinationEmail"
	mail -s "New software report for $SERVER" $varDestinationEmail < $varReportFile
else
	echo "No new software found"
fi
}

function getAdded {
diff --unchanged-line-format= --old-line-format= --new-line-format="%L" $varCurrentList $varLatestList| cut -d$'\t' -f1
}

function getRemoved {
diff --unchanged-line-format= --old-line-format="%L" --new-line-format= $varCurrentList $varLatestList| cut -d$'\t' -f1
}

function getPkgHistory {
grep "$1" /var/log/dpkg.log|awk '{print $4" on " $1 $2}' | sed -e '$!d;s/not-installed/removed/;s/^/#/'
}

function checkSetup {
[ ! -d $varEtcFolder ] && mkdir -p $varEtcFolder
[ ! -f $varCurrentList ] && $( getPackageList > $varCurrentList )
$( getPackageList > $varLatestList )
}

function getPackageList {
dpkg --get-selections
}

function buildReport {
echo "New software report for $SERVER"
echo $(date +"%D:%T")
echo "${#varPackagesAdded[@]} packages installed"
[ ${#varPackagesAdded[@]} -gt 0 ] && echo "Package List:"
	for package in "${varPackagesAdded[@]}"; do
	echo $package
	getPkgHistory $package
	done
echo "${#varPackagesRemoved[@]} packages removed"
[ ${#varPackagesRemoved[@]} -gt 0 ] && echo "Package List:"
	for package in "${varPackagesRemoved[@]}"; do
	echo $package
	getPkgHistory $package
	done
}

checkSetup
varPackagesAdded=($(getAdded))
varPackagesRemoved=($(getRemoved))
buildReport > $varReportFile
cat $varReportFile
sendReport
$( getPackageList > $varCurrentList )
echo "Done"
