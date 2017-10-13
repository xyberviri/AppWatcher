#!/bin/bash
varDestinationEmail=DESTINATION@EMAIL.COM
varEtcFolder=/etc/appwatcher
varCurrentList=${varEtcFolder}/packages.lst
varLatestList=${varEtcFolder}/latest.lst
varReportFile=/tmp/${RANDOM}.appwatcher
SERVER="`hostname`";

function log {
  echo "$@"
  logger -p user.notice -t "appwatcher[$$]" "$@"
}
function logSilent {
  logger -p user.notice -t "appwatcher[$$]" "$@"
}

function sendReport {
if [ ${#varPackagesAdded[@]} -gt 0 ] || [ ${#varPackagesRemoved[@]} -gt 0 ]; then
	log "Software change found sending report to $varDestinationEmail"
	mail -s "Software change report for $SERVER" $varDestinationEmail < $varReportFile
else
	log "No software changes found"
fi
}

function getAdded {
diff --unchanged-line-format= --old-line-format= --new-line-format="%L" $varCurrentList $varLatestList| cut -d$'\t' -f1
}

function getRemoved {
diff --unchanged-line-format= --old-line-format="%L" --new-line-format= $varCurrentList $varLatestList| cut -d$'\t' -f1
}

function getPkgHistory {
grep "$1" /var/log/dpkg.log|awk '{print $5" "$4" on " $1 $2}' | sed -e '$!d;s/not-installed/removed/'
}

function getPkgStatus {
grep "$1" /var/log/dpkg.log |cut -d " " -f4 | sed -e '$!d'
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
log "${#varPackagesAdded[@]} new packages were found"
log "${#varPackagesRemoved[@]} packages were removed"

[ ${#varPackagesAdded[@]} -gt 0 ] && echo "The following NEW packages were found"
	for package in "${varPackagesAdded[@]}"; do
	echo $package
	logSilent "FOUND $package"
	getPkgHistory $package
	done

[ ${#varPackagesRemoved[@]} -gt 0 ] && echo "The following packages were removed"
	for package in "${varPackagesRemoved[@]}"; do
	echo $package
	logSilent "FOUND MISSING $package"
	getPkgHistory $package
	done
}

log "Checking for software changes"
checkSetup
varPackagesAdded=($(getAdded))
varPackagesRemoved=($(getRemoved))
buildReport > $varReportFile
cat $varReportFile
sendReport
$( getPackageList > $varCurrentList )
log "Check completed"
