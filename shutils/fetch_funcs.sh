# -*-* shell *-*-
#
# Verifies that file's checksum downloaded matches what it's specified
# in template file.
#
verify_sha256_cksum() {
	local file="$1" origsum="$2" distfile="$3"

	[ -z "$file" -o -z "$cksum" ] && return 1

	msg_normal "$pkgver: verifying checksum for distfile '$file'... "
	filesum=$(${XBPS_DIGEST_CMD} $distfile)
	if [ "$origsum" != "$filesum" ]; then
		echo
		msg_error "SHA256 mismatch for '$file:'\n$filesum\n"
	fi
	msg_normal_append "OK.\n"
}

#
# Downloads the distfiles and verifies checksum for all them.
#
fetch_distfiles() {
	local pkg="$1" upcksum="$2" dfiles= localurl= dfcount=0 ckcount=0 f
	local srcdir= distfile= curfile=

	[ -z $pkgname ] && return 1
	#
	# There's nothing of interest if we are a meta template.
	#
	[ -n "$build_style" -a "$build_style" = "meta-template" ] && return 0

	[ -f "$XBPS_FETCH_DONE" ] && return 0

	#
	# If nofetch is set in a build template, skip this phase
	# entirely and run the do_fetch() function.
	#
	if [ -n "$nofetch" ]; then
		cd ${XBPS_BUILDDIR}
		[ -n "$build_wrksrc" ] && mkdir -p "$wrksrc"
		if declare -f do_fetch >/dev/null; then
			run_func do_fetch
			touch -f $XBPS_FETCH_DONE
		fi
		return 0
	fi

	if [ -n "$create_srcdir" ]; then
		srcdir="$XBPS_SRCDISTDIR/$pkgname-$version"
	else
		srcdir="$XBPS_SRCDISTDIR"
	fi
	[ ! -d "$srcdir" ] && mkdir -p "$srcdir"

	cd $srcdir || return 1
	for f in ${distfiles}; do
		curfile=$(basename $f)
		distfile="$srcdir/$curfile"
		if [ -f "$distfile" ]; then
			for i in ${checksum}; do
				if [ $dfcount -eq $ckcount -a -n $i ]; then
					cksum=$i
					found=yes
					break
				fi

				ckcount=$(($ckcount + 1))
			done

			if [ -z $found ]; then
				msg_error "$pkgver: cannot find checksum for $curfile.\n"
			fi

			verify_sha256_cksum $curfile $cksum $distfile
			if [ $? -eq 0 ]; then
				unset cksum found
				ckcount=0
				dfcount=$(($dfcount + 1))
				continue
			fi
		fi

		msg_normal "$pkgver: fetching distfile '$curfile'...\n"

		if [ -n "$distfiles" ]; then
			localurl="$f"
		else
			localurl="$url/$curfile"
		fi

		$XBPS_FETCH_CMD $localurl
		if [ $? -ne 0 ]; then
			unset localurl
			if [ ! -f $distfile ]; then
				msg_error "$pkgver: couldn't fetch $curfile.\n"
			else
				msg_error "$pkgver: there was an error fetching $curfile.\n"
			fi
		else
			unset localurl
			#
			# XXX duplicate code.
			#
			for i in ${checksum}; do
				if [ $dfcount -eq $ckcount -a -n $i ]; then
					cksum=$i
					found=yes
					break
				fi

				ckcount=$(($ckcount + 1))
			done

			if [ -z $found ]; then
				msg_error "$pkgver: cannot find checksum for $curfile.\n"
			fi

			verify_sha256_cksum $curfile $cksum $distfile
			if [ $? -eq 0 ]; then
				unset cksum found
				ckcount=0
			fi
		fi

		dfcount=$(($dfcount + 1))
	done

	unset cksum found
}
