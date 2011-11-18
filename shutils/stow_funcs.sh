#-
# Copyright (c) 2008-2011 Juan Romero Pardines.
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

stow_pkg_handler()
{
	local action="$1" subpkg spkgrev

	for subpkg in ${subpackages}; do
		if [ -n "$revision" ]; then
			spkgrev="${subpkg}-${version}_${revision}"
		else
			spkgrev="${subpkg}-${version}"
		fi
		if [ "$action" = "stow" ]; then
			check_installed_pkg ${spkgrev}
			[ $? -eq 0 ] && continue
		fi
		if [ ! -f $XBPS_SRCPKGDIR/${sourcepkg}/${subpkg}.template ]; then
			msg_error "Cannot find $subpkg subpkg build template!\n"
		fi
		unset revision pre_install pre_remove post_install \
			post_remove post_stow
		. $XBPS_SRCPKGDIR/${sourcepkg}/${subpkg}.template
		pkgname=${subpkg}
		set_tmpl_common_vars
		if [ "$action" = "stow" ]; then
			stow_pkg_real || return $?
		else
			unstow_pkg_real || return $?
		fi
		setup_tmpl ${sourcepkg}
	done

	if [ "$action" = "stow" ]; then
		stow_pkg_real
	else
		unstow_pkg_real
	fi
	return $?
}

#
# Stow a package, i.e copy files from destdir into masterdir
# and register pkg into the package database.
#
stow_pkg_real()
{
	local i lfile lver regpkgdb_flags

	[ -z "$pkgname" ] && return 2

	if [ $(id -u) -ne 0 ] && [ ! -w $XBPS_MASTERDIR ]; then
		msg_error "cannot stow $pkgname! (permission denied)\n"
	fi

	if [ -n "$build_style" -a "$build_style" = "meta-template" ]; then
		[ ! -d ${DESTDIR} ] && mkdir -p ${DESTDIR}
	fi

	[ -n "$stow_flag" ] && setup_tmpl $pkgname

	cd ${DESTDIR} || return 1

	if [ -n "$revision" ]; then
		lver="${version}_${revision}"
	else
		lver="${version}"
	fi
	msg_normal "$pkgver: stowning files into masterdir, please wait...\n"

	# Copy files into masterdir.
	for i in $(find -print); do
		lfile="$(echo $i|sed -e 's|^\./||')"
		# Skip pkg metadata
		if [ "$lfile" = "INSTALL" -o "$lfile" = "REMOVE" -o \
		     "$lfile" = "files.plist" -o "$lfile" = "props.plist" ]; then
		     continue
		# Skip files that are already in masterdir.
		elif [ -f "$XBPS_MASTERDIR/$lfile" ]; then
			echo "   Skipping $lfile file, already exists!"
			continue
		elif [ -h "$XBPS_MASTERDIR/$lfile" ]; then
			echo "   Skipping $lfile link, already exists!"
			continue
		elif [ -d "$XBPS_MASTERDIR/$lfile" ]; then
			continue
		fi
		if [ -f "$i" -o -h "$i" ]; then
			# Always copy the pkg metadata flist file.
			if [ "$(basename $i)" = "flist" ]; then
				cp -dp $i $XBPS_MASTERDIR/$lfile
				continue
			fi
			if [ -n "$IN_CHROOT" -a -n "$stow_copy_files" ]; then
				# Templates that set stow_copy_files require
				# some files to be copied, rather than symlinked.
				local found
				for j in ${stow_copy_files}; do
					if [ "/$lfile" = "${j}" ]; then
						found=1
						break
					fi
				done
				if [ -n "$found" ]; then
					cp -dp $i $XBPS_MASTERDIR/$lfile
					unset found
					continue
				fi
			fi
			if [ -n "$IN_CHROOT" -a -n "$stow_copy" -o -z "$IN_CHROOT" ]; then
				# In the no-chroot case and templates that
				# set $stow_copy, we can't stow with symlinks.
				# Just copy them.
				cp -dp $i $XBPS_MASTERDIR/$lfile
			else
				# Always use symlinks in the chroot with pkgs
				# that don't have $stow_copy set, they can have
				# full path.
				ln -sf $DESTDIR/$lfile $XBPS_MASTERDIR/$lfile
			fi
		elif [ -d "$i" ]; then
			mkdir -p $XBPS_MASTERDIR/$lfile
		fi
	done

	#
	# Register pkg in plist file.
	#
	$XBPS_PKGDB_CMD register $pkgname $lver "$short_desc" || return $?
	run_func post_stow
	return 0
}

#
# Unstow a package, i.e remove its files from masterdir and
# unregister pkg from package database.
#
unstow_pkg_real()
{
	local f ver

	[ -z $pkgname ] && return 1

	if [ $(id -u) -ne 0 ] && \
	   [ ! -w $XBPS_MASTERDIR ]; then
		msg_error "cannot unstow $pkgname! (permission denied)\n"
	fi

	ver=$($XBPS_PKGDB_CMD version $pkgname)
	if [ -z "$ver" ]; then
		msg_warn "'${pkgname}' not installed in masterdir!\n"
		return 1
	fi

	if [ "$build_style" = "meta-template" ]; then
		# If it's a metapkg, do nothing.
		:
	elif [ ! -f ${XBPS_PKGMETADIR}/${pkgname}/flist ]; then
		msg_warn "${pkgname}-${ver}: wasn't installed from source!\n"
		return 1
	elif [ ! -w ${XBPS_PKGMETADIR}/${pkgname}/flist ]; then
		msg_error "${pkgname}-${ver}: cannot be removed (permission denied).\n"
	elif [ -s ${XBPS_PKGMETADIR}/${pkgname}/flist ]; then
		msg_normal "${pkgname}-${ver}: removing files from masterdir...\n"
		run_func pre_remove
		# Remove installed files.
		for f in $(cat ${XBPS_PKGMETADIR}/${pkgname}/flist); do
			if [ -f $XBPS_MASTERDIR/$f -o -h $XBPS_MASTERDIR/$f ]; then
				rm -f $XBPS_MASTERDIR/$f >/dev/null 2>&1
				if [ $? -eq 0 ]; then
					echo "Removing file: $f"
				fi
			elif  [ -d $XBPS_MASTERDIR/$f ]; then
				rmdir $XBPS_MASTERDIR/$f >/dev/null 2>&1
				if [ $? -eq 0 ]; then
					echo "Removing directory: $f"
				fi
			fi
		done
	fi

	run_func post_remove
	# Remove metadata dir.
	[ -d $XBPS_PKGMETADIR/$pkgname ] && rm -rf $XBPS_PKGMETADIR/$pkgname

	# Unregister pkg from plist file.
	$XBPS_PKGDB_CMD unregister $pkgname $ver
	return $?
}
