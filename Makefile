# $Id: rpmorphan-1.11 | Makefile | Wed Aug 1 14:09:35 2012 +0200 | Eric Gerbier  $
# recommanded by debian install guide
DESTDIR=

PACKAGE=rpmorphan

SHELL = /bin/sh
VERSION=$(shell grep Version rpmorphan.lsm | awk '{print $$2}')

BINDIR = $(DESTDIR)/usr/bin
LOGETC = $(DESTDIR)/etc/
LOGROT = $(LOGETC)/logrotate.d/
MANDIR = $(DESTDIR)/usr/share/man
MAN1DIR = $(MANDIR)/man1
# on some distribution it is $(PACKAGE)-$(VERSION) (fedora), on others $(PACKAGE) (mandriva)
# we force it with a define in rpm target to be able to build on any host the same way
DOCDIR=$(DESTDIR)/usr/share/doc/$(PACKAGE)-$(VERSION)
# for keep file 
DATADIR=$(DESTDIR)/var/lib/rpmorphan
# locales
TARGET_LOCALE=$(DESTDIR)/usr/lib/rpmorphan/locale

# log
LOGDIR=$(DESTDIR)/var/log
LOGFILE=rpmorphan.log

DOC = Authors Changelog COPYING NEWS Todo $(PACKAGE).lsm $(PACKAGE).spec Makefile Readme Readme.fr rpmorphanrc.sample
DATA = keep
CONF = rpmorphan.logrotate

# others programs
PROG2=rpmusage rpmdep rpmduplicates rpmextra
LIB=$(PACKAGE)-lib rpmorphan-curses-lib rpmorphan-tk-lib

PROGS =  $(PACKAGE) $(PROG2)
MANPAGES1 := $(addsuffix .1, $(PROGS))
HTMLPAGES := $(addsuffix .1.html, $(PROGS))
SCRIPTS := $(addsuffix .pl, $(PROGS) $(LIB) )

# file with keyword
KEYWORD_FILES = $(SCRIPTS) Makefile Readme Readme.fr rpmorphanrc.sample

# translations
LANGS := en fr_FR
LOCALE_BASE := rpmorphan_trans.pl
LOCALES := $(foreach lang,$(LANGS),$(addprefix locale/$(lang)/,$(LOCALE_BASE)))

# convert pod to other doc format
%.1 : %.pl
	pod2man $^ > $@

%.1.html : %.pl
	pod2html --header $^ | sed -f html.sed > $@
	tidy -m -i -asxhtml -utf8 --doctype strict $@ || echo "tidy"

# loop to check all perl scripts
define check_perl_script
	for fic in $(SCRIPTS);do	\
		perl -cw $$fic || exit;		\
		perlcritic --verbose 10 -3 $$fic || exit;	\
	done;
endef

# loop to make links on all programs
define make_links
	for fic in $(PROGS);do        \
		cd $(BINDIR) && ln -s $$fic.pl $$fic;	\
	done;
endef

# loop to install all locales
define install_locales
	for lang in $(LANGS); do			\
		d=$(TARGET_LOCALE)/$$lang;		\
		mkdir --parents $$d;			\
		(cd locale/$$lang && install --mode=644 $(LOCALE_BASE) $$d);	\
	done
endef

# default
help :
	@echo "available target are :"
	@echo "make all : same as make install"
	@echo "make help : this help"
	@echo "make install : install software"
	@echo "make installdoc : install software documentation"
	@echo "make uninstall : remove software"
	@echo "make uninstalldoc : remove software documentation"
	@echo "### for project packagers only ###########"
	@echo "make alldist : build all packages"
	@echo "make check : check perl syntaxe"
	@echo "make clean : remove temporary files"
	@echo "make dist : build a tar.gz package"
	@echo "make html : build html doc from pod"
	@echo "make man : build man page from pod"
	@echo "make rpm : build an rpm package"

all: install

# install perl scripts
install : $(DOC) $(MANPAGES1) $(SCRIPTS)
	mkdir -p              $(BINDIR)
	install -m 755 $(SCRIPTS) $(BINDIR)
	$(make_links)
	cd $(BINDIR) && ln -s rpmorphan grpmorphan
	mkdir -p                $(MAN1DIR)
	install -m 644 ${MANPAGES1} $(MAN1DIR)
	mkdir -p                $(DATADIR)
	install -m 644 ${DATA}	$(DATADIR)
	mkdir -p $(TARGET_LOCALE)
	$(install_locales)
	mkdir -p                $(LOGDIR)
	touch	$(LOGDIR)/${LOGFILE}
	chmod 640 $(LOGDIR)/${LOGFILE}
	mkdir -p		$(LOGROT)
	install -m 644 ${CONF} $(LOGROT)/rpmorphan
	install -m 644 rpmorphanrc.sample $(LOGETC)/rpmorphanrc

# install doc
installdoc : $(DOC)
	mkdir -p                $(DOCDIR)
	install -m 644 ${DOC}	$(DOCDIR)

uninstall :
	cd $(BINDIR) && rm $(SCRIPTS) $(PROGS)
	cd $(MAN1DIR) && rm ${MANPAGES1}
	rm -rf $(DATADIR)
	rm -f $(LOGROT)/rpmorphan
	rm -f $(LOGETC)/rpmorphanrc

uninstalldoc :
	rm -rf $(DOCDIR)

################################################################################
# targets for project packagers
################################################################################

# build all packages
alldist : check dist rpm html

# check perl script syntax
check : $(SCRIPTS)
	$(check_perl_script)

# build man pages
man : $(MANPAGES1)

# build tar.gz package
dist : $(DOC) man $(SCRIPTS) expand
	mkdir $(PACKAGE)-$(VERSION)
	cp -a ${CONF} $(DATA) locale $(DOC) $(MANPAGES1) $(SCRIPTS) $(PACKAGE)-$(VERSION)
	tar cvfz $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)
	~/bin/gensign.sh $(PACKAGE)-$(VERSION).tar.gz

# build rpm package
rpm : dist
	rpmbuild -ta --sign --define '_docdir_fmt %%{NAME}-%%{VERSION}' $(PACKAGE)-$(VERSION).tar.gz

# clean temp files
clean : unexpand
	rm -f $(MANPAGES1)
	rm -f $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION).tar.gz.sig
	rm -f pod2*
	rm -f *.html

# build man page in html for web site
html : $(HTMLPAGES)
	mv *.html ../web

# expand svn keywords just for publish
expand: $(KEYWORD_FILES)
	git tag -f "$(PACKAGE)-$(VERSION)"
	git-svn-keyword-expand $(KEYWORD_FILES)

# remove svn keywords to keep repository clean
unexpand: $(KEYWORD_FILES)
	git-svn-keyword-unexpand $(KEYWORD_FILES)
