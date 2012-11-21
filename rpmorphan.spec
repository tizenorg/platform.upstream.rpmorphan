%global _binary_filedigest_algorithm 1
%global _source_filedigest_algorithm 1

%define VERSION 1.11
Summary: 	List packages that have no dependencies (like deborphan)
# The Summary: line should be expanded to about here -----^
Summary(fr): 	Liste les packages rpm orphelins (sans dependances)
Name: 		rpmorphan
Version: 	%{VERSION}
Release: 	1
Group:		Applications/System
#Group(fr): (translated group goes here)
License:	GPLv2+

BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u})
BuildArch:	noarch

URL: 	http://rpmorphan.sourceforge.net
Source: http://downloads.sourceforge.net/%{name}/%{name}-%{version}.tar.gz
# Following are optional fields
Packager: Eric Gerbier <gerbier@users.sourceforge.net>
#Distribution: Red Hat Contrib-Net
#Patch: src-%{version}.patch
#Prefix: /usr

Requires:	perl
Requires:	rpm
Requires:	logrotate
# rpmorphan can also use tk or curses but it is optionnal
# so this are not required but recommanded (when rpm allow this feature)
#Recommanded:	perl-Tk
#Recommanded:	perl-Curses-UI
# to speed up rpm query, use RPM2.pm perl package
#Recommanded:	perl-RPM2

#Obsoletes: 
#BuildRequires: 

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

notes :

For all users :
---------------
[1] this rpm package will make rpmorphan work in command line mode.
If you want to use a graphical interface, you will need to install extra 
rpm packages : perl-Tk or perl-Curses-UI.

For Fedora users : 
------------------
[2] Note that orphan is used in the sense of Debian's deborphan, and
is NOT the same as Fedora orphaned packages which are packages that
have no current maintainer.

[3] Yum offers a program called 'package-cleanup' which,
called with the '--leaves' option, can show quickly a list of
unused library packages. Rpmorphan is an extended version with
filters, gui, etc ...

[4] rpmorphan can be speed up by installing the perl-RPM2 rpm package

For Mandriva users :
--------------------
[5] the 'urpme --auto-orphans' command show quickly a a list of
unused library packages. Rpmorphan is an extended version with
filters, gui, etc ...

%description -l fr
Le  logiciel  rpmorphan  liste  les  packages  rpm  qui  n'ont plus de
dépendances avec les autres paquets installés sur votre système.
C'est un clone du logiciel deborphan de debian pour les packages rpm.

Il peut vous aider pour supprimer les packages inutilisés, par exemple :
* après une montée de version système
* lors de la suppression de logiciels après des tests

plusieurs outils sont également fournis :
* rpmusage : donne la date de la dernière utilisation d'un package
* rpmdep   : fournit l'ensemble des dependances (recursive) d'un package
* rpmduplicates : cherche les packages qui ont plusieurs versions installées
* rpmextra : cherche les packages installés hors distribution

notes :
Pour tous les utilisateurs
--------------------------
[1] ce package rpm permet de faire fonctionner rpmorphan en mode
ligne de commande. Si vous voulez profiter d'une interface graphique,
vous devez installer des packages rpm suplementaires : perl-Tk ou perl-Curses-UI

Pour les utilisateurs de Fedora :
---------------------------------
[2] la notion d'orphelin est à prendre au sens du logiciel debian deborphan, et
non pas au sens général de Fedora (packages sans mainteneur).

[3] Yum contient le programme 'package-cleanup', qui appelé avec l'option --leaves, 
permet d'afficher rapidement les librairies inutilisées. Rpmorphan est une version 
étendue, avec notamment les filtres, l'interface graphique.

[4] rpmorphan peut être accéléré en installant le package rpm perl-RPM2

Pour les utilisateurs de Mandriva
---------------------------------
[5] la commande 'urpme --auto-orphans' permet d'afficher rapidement les librairies inutilisées.
Rpmorphan est une version étendue, avec notamment les filtres, l'interface graphique.

%prep
%setup -q
#%patch

%build
# dummy : nothing to build
make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT install

%clean
[ "$RPM_BUILD_ROOT" != "/" ] && rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc rpmorphan.lsm Authors COPYING Changelog NEWS Todo Readme Readme.fr rpmorphanrc.sample
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

%changelog
* Thu Aug 03 2012 Eric Gerbier <gerbier@users.sourceforge.net> 1.11
- add suggests option
- add /etc/rpmorphanrc
- fix bug with space in filenames
- add env RPMORPHAN_METHOD for debugging

* Thu Jul 8 2011 Eric Gerbier <gerbier@users.sourceforge.net> 1.10
- bugfix eval for Curses (mandriva)
- fix bad version display
- clean all scripts
- reduce size/duplicated code in rpmorphan/rpmusage
- reduce menu length in curses gui (< 72)
- display package summary in a popup on S key

* Mon Mar 21 2011 Eric Gerbier <gerbier@users.sourceforge.net> 1.9
- fix perlcritic warnings
- add grpmorphan as link to rpmorphan -gui
- add rpmextra tool

* Fri Apr 30 2010 <gerbier@users.sourceforge.net> 1.8-1
- fix bug on rpmdep ( missing installtime in urpm mode)
- add help translation (gui)

* Mon Mar 1 2010 <gerbier@users.sourceforge.net> 1.7-1
- Curses is no more an rpm dependency
- add reload button

* Thu Jan 14 2010 <gerbier@users.sourceforge.net> 1.6-1
- curses window size is now variable to use full available size
- split core and gui code (new rpmorphan-curses-lib.pl rpmorphan-tk-lib.pl)

* Thu Nov 20 2009 <gerbier@users.sourceforge.net> 1.5-1
- add logrotate config
- remove all matching packages (same name)
- fix a bug on curses interface
- merge spec file with fedora one
- add info for fedora/mandriva users in package description
- french description is now in utf-8

* Tue Mar 31 2009 Richard W.M. Jones <rjones@redhat.com> - 1.4-5
- Clarify the documentation, usage of 'orphan' and other terminology.

* Wed Mar 25 2009 Richard W.M. Jones <rjones@redhat.com> - 1.4-4
- Combine all %%doc lines into one.
- Remove Makefile from %%doc section.

* Mon Jan 05 2009 <gerbier@users.sourceforge.net> 1.4-1
- improve diagnostic if "rpm -e" return some comments

* Mon Oct 19 2008 <gerbier@users.sourceforge.net> 1.3-1
- fix a bug if exclude are set in config file (thanks Szymon Siwek)
- display number of deleted file

* Mon Apr 7 2008 <gerbier@users.sourceforge.net> 1.2-1
- write log to /var/log/rpmorphan.log
- add rpmdep.pl tool
- add rpmduplicate.pl tool

* Thu Nov 22 2007 <gerbier@users.sourceforge.net> 1.1-1
- (rpmorphan) add a default target : guess-lib
- (rpmorphan) test rpm delete
- fix warnings from perlcritic tool
- (rpmorphan) split too complex code (add read_one_rc, init_cache)
- (rpmorphan) add keep-file option, which allow to cutomize the keep file
- add rpmorphan-lib.pl to store common code for rpmorphan, rpmusage
- (rpmusage) add a default target : all
- use rpmlint to build a better rpm package

* Wed Apr 27 2007 <gerbier@users.sourceforge.net> 1.0
- fix bug with tk : core dump because update call before mainloop
- add w_ prefix for widgets variables
- add dry-run (simulation) mode
- (gui) add 3 counters : packages, orphans, selected
- (gui) display_status call debug sub
- new Liste_pac global variable
- (gui) change curses geometry to work on console
- (gui) recursive analysis
- improve virtuals : now check if how many package provide this one

* Wed Mar 29 2007 <gerbier@users.sourceforge.net> 0.9
- add curses interface
- test for root access before removing packages
- add optionnal configuration file
- recode debugging system
- apply conway coding rules
- add tk_get_current_elem sub
- add get_from_command_line sub
- add status widget
* Tue Mar 06 2007 <gerbier@users.sourceforge.net> 0.8
- add simple graphical user iinterface (optionnal)
- remove global variable opt_verbose
- split code in functions : access_time_filter, read_rpm_data, search_orphans
* Tue Feb 28 2007  <gerbier@users.sourceforge.net> 0.4
- add optionnal cache
* Tue Feb 03 2007  <gerbier@users.sourceforge.net> 0.3
- add rpmusage tool
- add a link from rpmorphan.pl to rpmorphan
* Tue Jan 30 2007  <gerbier@users.sourceforge.net> 0.2
- add permanent exclude list
* Tue Jan 23 2007  <gerbier@users.sourceforge.net> 0.1
- Initial spec file 
