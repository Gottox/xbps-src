#-
# Copyright (c) 2008-2012 Juan Romero Pardines.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#-

make_binpkg() {
	local subpkg=

	[ -z "$pkgname" ] && return 1

	for subpkg in ${subpackages}; do
		unset noarch nonfree
		. $XBPS_SRCPKGDIR/$pkgname/$subpkg.template
		pkgname=${subpkg}
		set_tmpl_common_vars
		make_binpkg_real
		setup_tmpl ${sourcepkg}
	done

	[ -n "${subpackages}" ] && set_tmpl_common_vars
	make_binpkg_real
	return $?
}

binpkg_cleanup() {
	local pkgdir="$1" binpkg="$2"

	[ -z "$pkgdir" -o -z "$binpkg" ] && return 1
	msg_red "$pkgver: Interrupted! removing $binpkg file!\n"
	rm -f $pkgdir/$binpkg
	exit 1
}

#
# This function builds a binary package from an installed xbps
# package in destdir.
#
make_binpkg_real() {
	local mfiles= binpkg= pkgdir= arch= dirs= _dirs= d= clevel=

	if [ ! -d "${DESTDIR}" ]; then
		msg_warn "$pkgver: cannot find destdir... skipping!\n"
		return 0
	fi
	cd ${DESTDIR}

	if [ -n "$noarch" ]; then
		arch=noarch
	else
		arch=$XBPS_MACHINE
	fi
	binpkg=$pkgver.$arch.xbps
	if [ -n "$nonfree" ]; then
		pkgdir=$XBPS_PACKAGESDIR/nonfree/$arch
	else
		pkgdir=$XBPS_PACKAGESDIR/$arch
	fi
	#
	# Don't overwrite existing binpkgs by default, skip them.
	#
	if [ -f $pkgdir/$binpkg ]; then
		msg_normal "$pkgver: skipping existing $binpkg pkg...\n"
		return 6 # EEXIST
	fi

	#
	# Make sure that INSTALL is the first file on the archive,
	# this is to ensure that it's run before any other file is
	# unpacked.
	#
	if [ -x ./INSTALL -a -x ./REMOVE ]; then
		mfiles="./INSTALL ./REMOVE"
	elif [ -x ./INSTALL ]; then
		mfiles="./INSTALL"
	elif [ -x ./REMOVE ]; then
		mfiles="./REMOVE"
	fi
	mfiles="$mfiles ./files.plist ./props.plist"
	_dirs=$(find . -maxdepth 1 -type d -o -type l)
	for d in ${_dirs}; do
		[ "$d" = "." ] && continue
		dirs="$d $dirs"
	done

	[ -n "$XBPS_COMPRESS_LEVEL" ] && clevel="-$XBPS_COMPRESS_LEVEL"
	[ ! -d $pkgdir ] && mkdir -p $pkgdir

	# Remove binpkg if interrupted...
	trap "binpkg_cleanup $pkgdir $binpkg" INT
	msg_normal "Building $binpkg... "
	${FAKEROOT_CMD} tar --exclude "var/db/xbps/metadata/*/flist" \
		-cpf - ${mfiles} ${dirs} |			\
		$XBPS_COMPRESS_CMD ${clevel} -qf > $pkgdir/$binpkg
	rval=$?
	trap - INT

	if [ $rval -eq 0 ]; then
		msg_normal_append "done.\n"
	else
		rm -f $pkgdir/$binpkg
		msg_normal_append "failed!\n"
	fi

	return $rval
}
