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

#
# Shows info about a template.
#
show_tmpl() {
	local i=

	echo "pkgname:	$pkgname"
	echo "version:	$version"
	echo "revision:	$revision"
	for i in ${distfiles}; do
		[ -n "$i" ] && echo "distfiles:	$i"
	done
	for i in ${checksum}; do
		[ -n "$i" ] && echo "checksum:	$i"
	done
	[ -n "$noarch" ] && echo "noarch:		yes"
	echo "maintainer:	$maintainer"
	[ -n "$homepage" ] && echo "Upstream URL:	$homepage"
	[ -n "$license" ] && echo "License(s):	$license"
	[ -n "$build_style" ] && echo "build_style:	$build_style"
	for i in ${configure_args}; do
		[ -n "$i" ] && echo "configure_args:	$i"
	done
	echo "short_desc:	$short_desc"
	for i in ${subpackages}; do
		[ -n "$i" ] && echo "subpackages:	$i"
	done
	for i in ${conf_files}; do
		[ -n "$i" ] && echo "conf_files:	$i"
	done
	for i in ${replaces}; do
		[ -n "$i" ] && echo "replaces:	$i"
	done
	for i in ${conflicts}; do
		[ -n "$i" ] && echo "conflicts:	$i"
	done
	echo "long_desc: $long_desc"
}

show_tmpl_deps() {
	[ -f "${DESTDIR}/rdeps" ] && cat ${DESTDIR}/rdeps
}

show_tmpl_build_deps() {
	local f=

	# build time deps
	for f in ${build_depends}; do
		echo "$f"
	done
}
