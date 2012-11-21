%global _binary_filedigest_algorithm 1
%global _source_filedigest_algorithm 1

Summary: 	List packages that have no dependencies (like deborphan)
Name: 		rpmorphan
Version:    1.11
Release: 	1
Group:		Applications/System
License:	GPLv2+

BuildArch:	noarch

URL: 	http://rpmorphan.sourceforge.net
Source: http://downloads.sourceforge.net/%{name}/%{name}-%{version}.tar.gz
Requires:	perl
Requires:	rpm

%description
rpmorphan finds "orphaned"[2,5] packages on your system. It determines
which packages have no other packages depending on their installation,
and shows you a list of these packages.  It intends to be clone of
deborphan Debian tools for rpm packages.

It will try to help you to remove unused packages, for example:
* after a distribution upgrade
* when you want to suppress packages after some tests

Several tools are also provided :
* rpmusage - display rpm packages last use date
* rpmdep - display the full dependency of an installed rpm package
* rpmduplicates - find packages with several version installed
* rpmextra - find installed packages not in distribution


%prep
%setup -q

%build
make %{?_smp_mflags}


%install
%make_install


%files
%defattr(-,root,root,-)
%doc COPYING
%{_bindir}/rpmorphan-lib.pl
%{_bindir}/rpmorphan-curses-lib.pl
%{_bindir}/rpmorphan-tk-lib.pl
%{_bindir}/rpmorphan.pl
%{_bindir}/rpmorphan
%{_bindir}/grpmorphan
%{_bindir}/rpmusage.pl
%{_bindir}/rpmusage
%{_bindir}/rpmdep.pl
%{_bindir}/rpmdep
%{_bindir}/rpmduplicates.pl
%{_bindir}/rpmduplicates
%{_bindir}/rpmextra.pl
%{_bindir}/rpmextra
%ghost /var/log/rpmorphan.log
%dir /var/lib/rpmorphan
%config(noreplace) %attr(644, root, root) /var/lib/rpmorphan/keep
%dir /usr/lib/rpmorphan
%dir /usr/lib/rpmorphan/locale
%dir /usr/lib/rpmorphan/locale/en
%attr(644, root, root) /usr/lib/rpmorphan/locale/en/rpmorphan_trans.pl
%dir /usr/lib/rpmorphan/locale/fr_FR
%attr(644, root, root) /usr/lib/rpmorphan/locale/fr_FR/rpmorphan_trans.pl
%config(noreplace) /etc/logrotate.d/rpmorphan
%config(noreplace) /etc/rpmorphanrc
%doc %{_mandir}/man1/rpmorphan.1*
%doc %{_mandir}/man1/rpmusage.1*
%doc %{_mandir}/man1/rpmdep.1*
%doc %{_mandir}/man1/rpmduplicates.1*
%doc %{_mandir}/man1/rpmextra.1*

