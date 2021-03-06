#!/bin/bash
#
# Passed arguments:
# 	$1 - pkgname [REQUIRED]
#	$2 - path to local repository [REQUIRED]
# 	$3 - cross-target [OPTIONAL]

if [ $# -lt 2 -o $# -gt 3 ]; then
	echo "$(basename $0): invalid number of arguments: pkgname repository [cross-target]"
	exit 1
fi

PKGNAME="$1"
XBPS_REPOSITORY="$2"
XBPS_CROSS_BUILD="$3"

. $XBPS_SHUTILSDIR/common.sh

for f in $XBPS_COMMONDIR/helpers/*.sh; do
	source_file $f
done

setup_pkg "$PKGNAME" $XBPS_CROSS_BUILD

for f in $XBPS_COMMONDIR/environment/pkg/*.sh; do
	set -a; source_file $f; set +a
done

if [ "$sourcepkg" != "$PKGNAME" ]; then
	reset_subpkg_vars
	${PKGNAME}_package
	pkgname=$PKGNAME
fi

if [ -s $XBPS_MASTERDIR/.xbps_chroot_init ]; then
	export XBPS_ARCH=$(cat $XBPS_MASTERDIR/.xbps_chroot_init)
fi

run_pkg_hooks pre-pkg
run_pkg_hooks post-pkg

exit 0
