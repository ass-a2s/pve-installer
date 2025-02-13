include /usr/share/dpkg/pkg-info.mk

PVE_DEB=pve-installer_${DEB_VERSION_UPSTREAM_REVISION}_all.deb
PMG_DEB=pmg-installer_${DEB_VERSION_UPSTREAM_REVISION}_all.deb
PBS_DEB=pbs-installer_${DEB_VERSION_UPSTREAM_REVISION}_all.deb

DEBS = ${PVE_DEB} ${PMG_DEB} ${PBS_DEB}

INSTALLER_SOURCES=		\
	unconfigured.sh 	\
	fake-start-stop-daemon	\
	policy-disable-rc.d	\
	interfaces		\
	pmg-banner.png		\
	pve-banner.png		\
	pbs-banner.png		\
	checktime		\
	xinitrc			\
	spice-vdagent.sh	\
	Xdefaults		\
	country.dat		\
	proxinstall

HTML_SOURCES=$(wildcard html/*.htm)
HTML_COMMON_SOURCES=$(wildcard html-common/*.htm) $(wildcard html-common/*.css) $(wildcard html-common/*.png)

all: ${INSTALLER_SOURCES} ${HTML_COMMON_SOURCES} ${HTML_SOURCES}

country.dat: country.pl
	./country.pl > country.dat

deb: ${DEBS}
${DEBS}: ${INSTALLER_SOURCES} ${HTML_COMMON_SOURCES} ${HTML_SOURCES}
	rsync --exclude='test*.img' -a * build
	cd build; dpkg-buildpackage -b -us -uc
	lintian -X man ${PVE_DEB}
	lintian -X man ${PMG_DEB}
	lintian -X man ${PBS_DEB}

.phony: install
install: ${INSTALLER_SOURCES} ${HTML_COMMON_SOURCES} ${HTML_SOURCES}
	make -C html-common install
	install -D -m 644 interfaces ${DESTDIR}/etc/network/interfaces
	install -D -m 755 fake-start-stop-daemon ${DESTDIR}/var/lib/pve-installer/fake-start-stop-daemon
	install -D -m 755 policy-disable-rc.d ${DESTDIR}/var/lib/pve-installer/policy-disable-rc.d
	install -D -m 644 country.dat ${DESTDIR}/var/lib/pve-installer/country.dat
	install -D -m 755 unconfigured.sh ${DESTDIR}/sbin/unconfigured.sh
	install -D -m 755 proxinstall ${DESTDIR}/usr/bin/proxinstall
	install -D -m 755 checktime ${DESTDIR}/usr/bin/checktime
	install -D -m 644 xinitrc ${DESTDIR}/.xinitrc
	install -D -m 755 spice-vdagent.sh ${DESTDIR}/.spice-vdagent.sh
	install -D -m 644 Xdefaults ${DESTDIR}/.Xdefaults

pmg-banner.png: pmg-banner.svg
	rsvg-convert -o $@ $<

pve-banner.png: pve-banner.svg
	rsvg-convert -o $@ $<

pbs-banner.png: pbs-banner.svg
	rsvg-convert -o $@ $<

.phony: upload-pmg
upload-pmg: ${PMG_DEB}
	tar cf - ${PMG_DEB} | ssh -X repoman@repo.proxmox.com -- upload --product pmg --dist stretch

.phony: upload-pve
upload-pve: ${PVE_DEB}
	tar cf - ${PVE_DEB} | ssh -X repoman@repo.proxmox.com -- upload --product pve --dist buster

%.img:
	truncate -s 2G $@

check-pve: ${PVE_DEB} test.img
	umount -Rd testdir || true
	rm -rf testdir
	dpkg -X ${PVE_DEB} testdir
	G_SLICE=always-malloc perl -I testdir/usr/share/perl5 testdir/usr/bin/proxinstall -t test.img

check-pve-multidisks: ${PVE_DEB} test.img test2.img test3.img test4.img
	umount -Rd testdir || true
	rm -rf testdir
	dpkg -X ${PVE_DEB} testdir
	G_SLICE=always-malloc perl -I testdir/usr/share/perl5 testdir/usr/bin/proxinstall -t test.img,test2.img,test3.img,test4.img

check-pmg: ${PMG_DEB} test.img
	umount -Rd testdir || true
	rm -rf testdir
	dpkg -X ${PMG_DEB} testdir
	G_SLICE=always-malloc perl -I testdir/usr/share/perl5 testdir/usr/bin/proxinstall -t test.img

check-pbs: ${PBS_DEB} test.img
	umount -Rd testdir || true
	rm -rf testdir
	dpkg -X ${PBS_DEB} testdir
	G_SLICE=always-malloc perl -I testdir/usr/share/perl5 testdir/usr/bin/proxinstall -t test.img


.phony: clean
clean:
	umount -Rd testdir || true
	make -C html-common clean
	rm -rf *~ *.deb target build packages packages.tmp testdir test*.img pve-final.pkglist *.buildinfo *.changes country.dat final.pkglist
	find . -name '*~' -exec rm {} ';'
