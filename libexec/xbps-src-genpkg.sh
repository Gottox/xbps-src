#!/bin/bash
#
# Passed arguments:
# 	$1 - pkgname [REQUIRED]
# 	$2 - cross-target [OPTIONAL]
#	$3 - alternative local repository [OPTIONAL]

register_pkg() {
	local rval= _pkgdir="$1" _binpkg="$2" _force="$3"

	if [ -n "$XBPS_CROSS_BUILD" ]; then
		$XBPS_RINDEX_XCMD ${_force:+-f} -a ${_pkgdir}/${_binpkg}
	else
		$XBPS_RINDEX_CMD ${_force:+-f} -a ${_pkgdir}/${_binpkg}
	fi
	rval=$?

	return $rval
}

#
# This function builds a binary package from an installed xbps
# package in destdir.
#
genbinpkg() {
	local binpkg= pkgdir= arch= _deps= f=

	if [ ! -d "${PKGDESTDIR}" ]; then
		msg_warn "$pkgver: cannot find pkg destdir... skipping!\n"
		return 0
	fi

	if [ -n "$noarch" ]; then
		arch=noarch
	elif [ -n "$XBPS_TARGET_MACHINE" ]; then
		arch=$XBPS_TARGET_MACHINE
	else
		arch=$XBPS_MACHINE
	fi
	if [ -z "$noarch" -a -n "$XBPS_ARCH" -a "$XBPS_ARCH" != "$XBPS_TARGET_MACHINE" ]; then
		arch=${XBPS_ARCH}
	fi
	binpkg=$pkgver.$arch.xbps
	if [ -n "$XBPS_ALT_REPOSITORY" ]; then
		pkgdir=$XBPS_PACKAGESDIR/$XBPS_ALT_REPOSITORY
	else
		pkgdir=$XBPS_PACKAGESDIR
	fi
	if [ -n "$nonfree" ]; then
		pkgdir=$pkgdir/nonfree
	fi

	[ ! -d $pkgdir ] && mkdir -p $pkgdir

	while [ -f $pkgdir/${binpkg}.lock ]; do
		msg_warn "$pkgver: binpkg is being created, waiting for 1s...\n"
		sleep 1
	done

	# Don't overwrite existing binpkgs by default, skip them.
	if [ -f $pkgdir/$binpkg -a -z "$XBPS_BUILD_FORCEMODE" ]; then
		msg_normal "$pkgver: skipping existing $binpkg pkg...\n"
		register_pkg "$pkgdir" "$binpkg"
		return $?
	fi

	touch -f $pkgdir/${binpkg}.lock

	if [ ! -d $pkgdir ]; then
		mkdir -p $pkgdir
	fi
	cd $pkgdir

	if [ -n "$preserve" ]; then
		_preserve="-p"
	fi
	if [ -s ${PKGDESTDIR}/rdeps ]; then
		_deps="$(cat ${PKGDESTDIR}/rdeps)"
	fi
	if [ -s ${PKGDESTDIR}/shlib-provides ]; then
		_shprovides="$(cat ${PKGDESTDIR}/shlib-provides)"
	fi
	if [ -s ${PKGDESTDIR}/shlib-requires ]; then
		_shrequires="$(cat ${PKGDESTDIR}/shlib-requires)"
	fi

	if [ -n "$provides" ]; then
		local _provides=
		for f in ${provides}; do
			_provides="${_provides} ${f}"
		done
	fi
	if [ -n "$conflicts" ]; then
		local _conflicts=
		for f in ${conflicts}; do
			_conflicts="${_conflicts} ${f}"
		done
	fi
	if [ -n "$replaces" ]; then
		local _replaces=
		for f in ${replaces}; do
			_replaces="${_replaces} ${f}"
		done
	fi
	if [ -n "$mutable_files" ]; then
		local _mutable_files=
		for f in ${mutable_files}; do
			_mutable_files="${_mutable_files} ${f}"
		done
	fi
	if [ -n "$conf_files" ]; then
		local _conf_files=
		for f in ${conf_files}; do
			_conf_files="${_conf_files} ${f}"
		done
	fi

	msg_normal "$pkgver: building $binpkg ...\n"

	#
	# Create the XBPS binary package.
	#
	xbps-create \
		--architecture ${arch} \
		--provides "${_provides}" \
		--conflicts "${_conflicts}" \
		--replaces "${_replaces}" \
		--mutable-files "${_mutable_files}" \
		--dependencies "${_deps}" \
		--config-files "${_conf_files}" \
		--homepage "${homepage}" \
		--license "${license}" \
		--maintainer "${maintainer}" \
		--long-desc "${long_desc}" --desc "${short_desc}" \
		--built-with "xbps-src-${XBPS_SRC_VERSION}" \
		--build-options "${PKG_BUILD_OPTIONS}" \
		--pkgver "${pkgver}" --quiet \
		--source-revisions "$(cat ${PKG_GITREVS_FILE:-/dev/null} 2>/dev/null)" \
		--shlib-provides "${_shprovides}" \
		--shlib-requires "${_shrequires}" \
		${_preserve} ${_sourcerevs} ${PKGDESTDIR}
	rval=$?

	rm -f $pkgdir/${binpkg}.lock

	if [ $rval -eq 0 ]; then
		register_pkg "$pkgdir" "$binpkg" $XBPS_BUILD_FORCEMODE
		rval=$?
	else
		rm -f $pkgdir/$binpkg
		msg_error "Failed to build binary package: $binpkg!\n"
	fi

	return $rval
}

if [ $# -lt 1 -o $# -gt 3 ]; then
	echo "$(basename $0): invalid number of arguments: pkgname [cross-target] [altrepo]"
	exit 1
fi

PKGNAME="$1"
XBPS_CROSS_BUILD="$2"
XBPS_ALT_REPOSITORY="$3"

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

genbinpkg
rval=$?

# Generate -dbg pkg automagically.
if [ -d "$XBPS_DESTDIR/$XBPS_CROSS_TRIPLET/${PKGNAME}-dbg-${version}" ]; then
	reset_subpkg_vars
	pkgname="${PKGNAME}-dbg"
	pkgver="${PKGNAME}-dbg-${version}_${revision}"
	short_desc="${short_desc} (debug files)"
	PKGDESTDIR="$XBPS_DESTDIR/$XBPS_CROSS_TRIPLET/${PKGNAME}-dbg-${version}"
	genbinpkg
fi

exit $rval
