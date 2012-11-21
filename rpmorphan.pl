#!/usr/bin/perl 
###############################################################################
#   rpmorphan.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmorphan-1.11 | rpmorphan.pl | Wed Aug 1 20:47:14 2012 +0200 | Eric Gerbier  $
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
###############################################################################
use strict;
use warnings;

use English '-no_match_vars';

use Getopt::Long;    # arg analysis
use Pod::Usage;      # man page
use POSIX qw(strftime);
use Data::Dumper;    # debug

# library
use File::Basename;
my $dirname  = dirname($PROGRAM_NAME);
my $basename = basename($PROGRAM_NAME);
require $dirname . '/rpmorphan-lib.pl'
  or die "problem to load rpmorphan-lib: $ERRNO\n";

# translations
##############
use lib q{.};                    # for tests
use lib '/usr/lib/rpmorphan';    # for prod
my $lang = $ENV{'LANG'};
my $locale_dir;
if ( $lang =~ m/fr_FR/ ) {
	$locale_dir = 'locale/fr_FR/rpmorphan_trans.pl';
}
else {
	$locale_dir = 'locale/en/rpmorphan_trans.pl';
}
## no critic(RequireCheckingReturnValueOfEval)
eval { require $locale_dir; };
if ($EVAL_ERROR) {
	warning("can not load translation file $locale_dir");
	exit;
}

###############################################################################
# global variables
###############################################################################
## no critic(Capitalization)
## no critic(ProhibitPackageVars)

# translations
use vars qw( %TRANS );

# main widget (used for mainloop in curse mode)
use vars qw( $Main_ui);

# widget list of packages for gui
use vars qw( $W_list );

# to know if we are or not in mainloop
use vars qw( $Inloop );
$Inloop = 0;

# command line option for access_time test
my $Opt_access_time;

# options (for load_data, from tk and curses)
my %Opt;

# command line option for dry-run (simulation mode)
use vars qw( $Opt_dry_run );

# hash structures to be filled with rpm query
my %Provides;
my %Depends;
my %Requires;
my %Install_time;
my %Files;
my %Virtual;

# list of filtered packages
use vars qw( @Liste_pac );
## use critic
## no critic(RequireCheckingReturnValueOfEval)

# the code should use no "print" calls
# but instead debug, warning, info calls
##########################################################
# for debuging
# dump internal structures
sub dump_struct() {
	print Dumper( 'depends',  \%Depends );
	print Dumper( 'virtuals', \%Virtual );

	display_status('dump done');
	return;
}
#########################################################
{

	# for gui, we will have to call this sub after each delete
	# as it is very expensive (file access)
	# we will use a cache
	#
	my %access_time;

# this is a filter : we will test if any file was accessed since $access_time days
# be careful : this code can be very slow
	sub access_time_filter($$$$) {
		my $name        = shift @_;    # package name
		my $rh_files    = shift @_;    # general hash of package files
		my $access_time = shift @_;    # option access-time
		my $now         = shift @_;    # current time

		my $ret;
		if ($access_time) {

			my $age;

			# test for cache
			if ( exists $access_time{$name} ) {

				# get from cache
				$age = $access_time{$name};
			}
			else {

				# not in cache : get it from file system
				my ( $last_time, $file ) =
				  get_last_access( $rh_files->{$name} );
				$age = diff_date( $now, $last_time );
				debug("last access on $file is $age days old");
				$access_time{$name} = $age;
			}

			if ( $age > $access_time ) {
				debug("keep package $name : old access ($age days)");
				$ret = 1;
			}
			else {
				debug("skip package $name : too recent access ($age days)");
				$ret = 0;
			}
		}
		else {

			# no filter
			$ret = 1;
		}
		return $ret;
	}
}
#########################################################
# load_data is called from tk and curses lib (callback)
sub load_data($) {
	my $opt_gui = shift @_;    # true if use a gui
	                           # also use %Opt gloval var

	# phase 1 : get data and build structures
	read_rpm_data( \%Opt, \%Provides, \%Install_time, \%Files, \%Depends,
		\%Virtual, \%Requires );

# phase 2 : guess filter
# if a package is set, it will be first used, then it will use in order -all, then (guess*)
# (see filter sub)
	display_status('2 : guess filter');
	my @opt_package = @{ $Opt{'package'} };
	if (@opt_package) {
		@Liste_pac = @opt_package;
	}
	else {
		@Liste_pac = rpmfilter( \%Opt, \%Provides );
	}

	# needed by access-time and install-time options
	my $now = time;

	# phase 3 : excluded and install-time filter
	display_status('3 : excluded and install-time');
	my $opt_install_time = ${ $Opt{'install-time'} };
	my $excluded         = $Opt{'excluded'};
	my @liste_pac2;
  PACKAGE: foreach my $pac (@Liste_pac) {
		if ( exists $excluded->{$pac} ) {
			display_status("skip $pac : excluded");
			next PACKAGE;
		}

		if ($opt_install_time) {
			my $diff = diff_date( $now, $Install_time{$pac} );
			if ( $opt_install_time > 0 ) {
				if ( $diff < $opt_install_time ) {
					display_status(
						"skip $pac : too recent install ($diff days)");
					next PACKAGE;
				}
			}
			elsif ( $diff > -$opt_install_time ) {
				display_status("skip $pac : too old install ($diff days)");
				next PACKAGE;
			}
		}
		push @liste_pac2, $pac;
	}

	# note : access-time filter is a very slow method
	# so we apply this filter after dependencies research
	#  see below access_time_filter call

	# we want the result sorted in alphabetic order
	@Liste_pac = sort @liste_pac2;
	display_total();

	# phase 4 : solve dependencies
	my @orphans =
	  search_orphans( \%Provides, \%Files, \%Depends, \%Virtual, $now,
		\@Liste_pac, $Opt_access_time );

	# display
	if ($opt_gui) {
		insert_gui_orphans(@orphans);
	}
	else {

		# just display @orphans
		my $txt = join "\n", @orphans;
		info($txt);
	}

	display_status('ready');
	return;
}
#########################################################
# return true is $name is an orphan
sub solve($$$$) {
	my $name        = shift @_;    # package name
	my $rh_provides = shift @_;    # general provide hash
	my $rh_depends  = shift @_;    # general dependencies hash
	my $rh_virtual  = shift @_;    # virtual package hash

	debug("(solve) : $name");

	my $flag_orphan = 1;
  PROVIDE: foreach my $prov ( @{ $rh_provides->{$name} } ) {

   # dependencies can be to "virtual" object : smtpdaemon, webclient, bootloader
   # for example, try "rpm -q --whatprovides webclient"
   # you will get many packages : elinks,kdebase-common,mozilla,wget,lynx ...

		# with this new algo, let's see an example
		# lilo and grub provide 'bootloader' virtual, which is necessary
		# If the 2 are installed, they will be shown all 2 as orphans
		# but if you remove one of them, the other is now longer orphan
		if ( exists $rh_virtual->{$prov} ) {

			# this feature is a virtual
			my @virtuals   = sort keys %{ $rh_virtual->{$prov} };
			my $nb_virtual = scalar @virtuals;
			if ( $nb_virtual == 1 ) {

				# name provide a virtual and is the only one
				# so it act as a real dependency
				$flag_orphan = 0;
				debug("$name is required by virtual @virtuals ($prov)");
				last PROVIDE;
			}
			else {

				# name provide virtual but is not the only one
				# we consider it an orphan
				debug("$name : skip virtual $prov (@virtuals)");
				next PROVIDE;
			}
		}

		if ( exists $rh_depends->{$prov} ) {

			# some packages depends from $prov ...
			$flag_orphan = 0;

			# only in verbose mode
			if ( is_verbose( \%Opt ) ) {
				my @depends = sort keys %{ $rh_depends->{$prov} };
				debug("$name is required by @depends ($prov)");
			}
			last PROVIDE;
		}
	}
	return $flag_orphan;
}
#########################################################
# use the slow "rpm -e --test" command
# but is quicker if used only on 1 package (no analysis)
# return true if is an orphan
sub quicksolve($) {
	my $name = shift @_;    # package name

	debug("(quicksolve) : $name");

	my $cmd = 'rpm -e --test ';

	## no critic ( ProhibitBacktickOperators );
	my @depends = `$cmd $name 2>&1`;
	## use critic;
	my $ret;
	## no critic (ProhibitMagicNumbers)
	if ( $#depends == -1 ) {

		# empty output : ok
		#info($name);
		$ret = 1;
	}
	else {
		$ret = 0;
		debug("$name is required by @depends");
	}
	return $ret;
}
##########################################################
sub quick_run($$) {
	my $rh_opt      = shift @_;
	my $rh_excluded = shift @_;

	debug('quick_run');

	#allow comma separated options on tags option
	my @opt_package = get_from_command_line( @{ $rh_opt->{'package'} } );
	$rh_opt->{'package'} = \@opt_package;

	if ( !is_set( $rh_opt, 'fullalgo' ) ) {
		## no critic (ProhibitMagicNumbers)
		my $max_packages = 5;
		if ( $#opt_package <= $max_packages ) {

			# use  quicksolve
		  PAC: foreach my $pac (@opt_package) {
				if ( exists $rh_excluded->{$pac} ) {
					debug("skip $pac : excluded");
					next PAC;
				}
				info($pac) if ( quicksolve($pac) );
			}
			exit;
		}
		else {
			debug('too much package for quicksolve algo');
		}
	}
	else {
		debug('full algo required');
	}
	return;
}
##########################################################
# resolv dependencies for all packages in ra_liste_pac
sub search_orphans($$$$$$$) {
	my $rh_provides     = shift @_;
	my $rh_files        = shift @_;
	my $rh_depends      = shift @_;
	my $rh_virtual      = shift @_;
	my $now             = shift @_;
	my $ra_liste_pac    = shift @_;    # list of all packages
	my $opt_access_time = shift @_;

	display_status('4 : solve');
	my @orphans;
	foreach my $pac ( @{$ra_liste_pac} ) {
		if (    solve( $pac, $rh_provides, $rh_depends, $rh_virtual, )
			and access_time_filter( $pac, $rh_files, $opt_access_time, $now ) )
		{
			push @orphans, $pac;
		}
	}
	return @orphans;
}
#########################################################
# remove entries from lists for a package
sub remove_a_package($) {
	my $pacname = shift @_;

	# first remove dependencies
  PROVIDE: foreach my $req ( @{ $Requires{$pacname} } ) {

		delete $Depends{$req}{$pacname};
		debug("delete Depends { $req } {$pacname}");

		# suppress entry if empty
		my $keys = scalar keys %{ $Depends{$req} };
		if ( !$keys ) {
			delete $Depends{$req};
			debug("delete empty Depends { $req }");
		}
	}

	# remove virtuals
  VIRT: foreach my $prov ( @{ $Provides{$pacname} } ) {
		if ( exists $Virtual{$prov} ) {
			delete $Virtual{$prov}{$pacname};
			debug("delete Virtual { $prov }{ $pacname }");

			# suppress entry if empty
			my $keys = scalar keys %{ $Virtual{$prov} };
			if ( !$keys ) {
				delete $Virtual{$prov};
				debug("delete empty Virtual { $prov }");
			}
		}
	}

	# then delete all entries
	delete $Provides{$pacname};
	delete $Files{$pacname};
	delete $Install_time{$pacname};
	delete $Requires{$pacname};

	return;
}
#########################################################
sub is_installed($) {
	my $pac = shift @_;

	# rpm -q return 0 is package exists, 1 if not
	system "rpm -q $pac >/dev/null 2>/dev/null";
	## no critic (ProhibitMagicNumbers)
	# cf perldoc -f system
	my $code = $CHILD_ERROR >> 8;

	return !$code;
}
#########################################################
# a generic program to be called by curses or tk sub
sub remove_packages($$) {
	my $ra_sel  = shift @_;    # list of select packages
	my $ra_list = shift @_;    # list of all orphans packages

	display_status('remove packages');
	my @deleted_packages;

	my $total = scalar @{$ra_sel};
	my $i     = 0;

	# remove package
  SELECT: foreach my $pac ( @{$ra_sel} ) {
		if ( !$Opt_dry_run ) {
			$i++;

			# not in dry mode : apply change

			# rpm delete
			# caution : it's suppose the shell used is bourne compatible
			my $cmd = "rpm -e --allmatches $pac 2>&1";

			# comment below to test without any real suppress
			## no critic ( ProhibitBacktickOperators );
			my $output = `$cmd`;
			## use critic;

			#print "@output\n";

			# there is some case where a delete may not work : virtuals
			# for example if you have lilo and grub installed, all 2
			# will be shown as orphans, but you will be able to delete only
			# the first one ...

			# we can not rely on return code : it seems to be allways 1
			# but a successful delete does not provide any output
			if ($output) {

				# to be sure : the only way is to test it
				if ( is_installed($pac) ) {

					write_log($output);
					display_status("problem to delete $pac (see log)");
					sleep 1;

					next SELECT;
				}
				else {

					# reports
					write_log("$i/$total $pac deleted with output : $output");
					push @deleted_packages, $pac;
				}
			}
			else {

				# reports
				write_log("$i/$total $pac deleted");
				push @deleted_packages, $pac;
			}
		}

		# update internal lists
		remove_a_package($pac);
	}

	# build a new list of all packages without the removed ones
	my @new_list;
  LISTE: foreach my $l (@Liste_pac) {
		foreach my $pac (@deleted_packages) {
			next LISTE if ( $pac eq $l );
		}
		push @new_list, $l;
	}
	@Liste_pac = @new_list;
	display_total();

	# compute new dependencies
	my $now = time;
	my @orphans =
	  search_orphans( \%Provides, \%Files, \%Depends, \%Virtual, $now,
		\@new_list, $Opt_access_time );

	# display
	insert_gui_orphans(@orphans);

	#build_summary(@new_list);

	display_status('end of cleaning');
	return;
}
#########################################################
# used to build windows's title
sub build_title() {

	my $title = 'rpmorphan version ' . get_version();
	$title .= ' (dry-run)' if $Opt_dry_run;
	return $title;
}
#########################################################
# 		keep
#
# a way to keep a list of exclusions
#########################################################
# list content of keep file
sub list_keep($$) {
	my $keep_file = shift @_;
	my $display   = shift @_;    # display or not ?

	my @list;
	if ( open my $fh, '<', $keep_file ) {
		@list = <$fh>;
		chomp @list;
		close $fh or warning("problem to close keep file : $ERRNO");

		info("@list") if ($display);
	}
	else {
		warning("can not read keep file $keep_file : $ERRNO");
	}
	return @list;
}
#########################################################
# empty keep file
sub zero_keep($) {
	my $keep_file = shift @_;

	if ( open my $fh, '>', $keep_file ) {
		close $fh or warning("problem to close keep file : $ERRNO");
	}
	else {
		warning("can not empty keep file $keep_file : $ERRNO");
	}
	return;
}
#########################################################
# add packages names to keep file
sub add_keep($$$) {
	my $keep_file   = shift @_;
	my $ra_list     = shift @_;
	my $flag_append = shift @_;    # true if append, else rewrite

	my @new_list;
	my $mode;
	if ($flag_append) {
		$mode = '>>';

		# read current list
		my @old_list = list_keep( $keep_file, 0 );

		# check for duplicates and merge
	  LOOP: foreach my $add ( @{$ra_list} ) {
			foreach my $elem (@old_list) {
				if ( $elem eq $add ) {
					debug("skip add duplicate $add");
					next LOOP;
				}
			}
			push @new_list, $add;
			debug("add keep $add");
		}
	}
	else {
		$mode     = '>';
		@new_list = @{$ra_list};
	}

	if ( open my $fh, $mode, $keep_file ) {
		foreach my $elem (@new_list) {
			print {$fh} $elem . "\n";
		}
		close $fh or warning("problem to close keep file : $ERRNO");
	}
	else {
		warning("can not write to keep file $keep_file : $ERRNO");
	}
	return;
}
#########################################################
# remove packages names from keep file
sub del_keep($$) {
	my $keep_file = shift @_;
	my $ra_list   = shift @_;

	# read current list
	my @old_list = list_keep( $keep_file, 0 );

	# remove entries
	my @new_list;
  LOOP: foreach my $elem (@old_list) {
		foreach my $del ( @{$ra_list} ) {
			if ( $elem eq $del ) {
				debug("del keep $del");
				next LOOP;
			}
		}
		push @new_list, $elem;
	}

	# rewrite keep file
	add_keep( $keep_file, \@new_list, 0 );
	return;
}
################################################################
sub write_log_file($) {
	my $text = shift @_;

	my $logfile = '/var/log/rpmorphan.log';

	if ( open my $fh, '>>', $logfile ) {
		my @date = gmtime;
		print {$fh} strftime( '%Y/%m/%d %H:%M:%S ', @date ) . $text . "\n";

		close $fh or warning("can not close $logfile : $ERRNO");
	}
	else {
		display_status("can not write to $logfile : $ERRNO");
	}
	return;
}
################################################################
{

	# store the current session log
	# just to avoid a global var
	my @log;

	sub write_log {
		push @log, @_;
		my $text = shift @_;
		display_status($text);
		write_log_file($text);
		return;
	}

	sub get_log() {
		return @log;
	}
}
#########################################################
# check if tk is available
sub test_tk_gui() {

	debug('test_tk_gui');
	eval {
		require Tk;
		require Tk::Balloon;
		require Tk::Dialog;
		require Tk::Frame;
		require Tk::Label;
		require Tk::Listbox;
		require Tk::Message;
		require Tk::ROText;
	};
	if ($EVAL_ERROR) {
		warning('can not find Tk perl module');
		return 0;
	}
	else {
		debug('Tk ok');
		import Tk;
		import Tk::Balloon;
		import Tk::Dialog;
		import Tk::Frame;
		import Tk::Label;
		import Tk::Listbox;
		import Tk::Message;
		import Tk::ROText;

		# should be ok
		require $dirname . '/rpmorphan-tk-lib.pl'
		  or die "problem to load rpmorphan-tk-lib: $ERRNO\n";
		build_tk_gui();
		return 'tk';
	}
}

#########################################################
# check if curses is available
sub test_curses_gui() {

	debug('test_curses_gui');
	eval { require Curses::UI; };
	if ($EVAL_ERROR) {
		warning('can not find Curses::UI perl module');
		return 0;
	}
	else {
		debug('curses ok');
		import Curses::UI;

		# should be ok
		require $dirname . '/rpmorphan-curses-lib.pl'
		  or die "problem to load rpmorphan-curses-lib: $ERRNO\n";
		build_curses_gui();
		return 'curses';
	}
}
#########################################################
#		general gui
#########################################################
sub test_gui() {
	return ( test_tk_gui() or test_curses_gui() );
}
#########################################################
sub get_help_text() {

	my $baratin = $TRANS{'help'};
	return $baratin;
}
#########################################################
#	version
#########################################################
{
	my $version = '1.10';

	sub get_version() {
		return $version;
	}
}

#########################################################
#
#	main
#
#########################################################
my $opt_verbose = 0;    # default value
init_debug($opt_verbose);

my $opt_help;
my $opt_man;
my $opt_version;
my $opt_fullalgo;
my $opt_use_cache;
my $opt_clear_cache;
my $opt_suggests;
my $opt_gui;
my $opt_tk;
my $opt_curses;

my $opt_all;

my $opt_guess_perl;
my $opt_guess_python;
my $opt_guess_pike;
my $opt_guess_ruby;
my $opt_guess_common;
my $opt_guess_data;
my $opt_guess_doc;
my $opt_guess_dev;
my $opt_guess_lib;
my $opt_guess_all;
my $opt_guess_custom;

my @opt_package;
my @opt_exclude;
my $opt_install_time;

my $opt_keep_file;
my $opt_list_keep;
my $opt_zero_keep;
my @opt_add_keep;
my @opt_del_keep;

%Opt = (
	'help'         => \$opt_help,            # help
	'man'          => \$opt_man,             # full help
	'verbose'      => \$opt_verbose,         # debug
	'dry-run'      => \$Opt_dry_run,         #
	'version'      => \$opt_version,
	'fullalgo'     => \$opt_fullalgo,
	'all'          => \$opt_all,             # all packages
	'guess-perl'   => \$opt_guess_perl,      # perl packages
	'guess-python' => \$opt_guess_python,    # python packages
	'guess-pike'   => \$opt_guess_pike,
	'guess-ruby'   => \$opt_guess_ruby,
	'guess-common' => \$opt_guess_common,
	'guess-data'   => \$opt_guess_data,
	'guess-doc'    => \$opt_guess_doc,
	'guess-dev'    => \$opt_guess_dev,
	'guess-lib'    => \$opt_guess_lib,
	'guess-all'    => \$opt_guess_all,       # all guess packages
	'guess-custom' => \$opt_guess_custom,
	'package'      => \@opt_package,
	'exclude'      => \@opt_exclude,
	'suggests'     => \$opt_suggests,
	'install-time' => \$opt_install_time,
	'access-time'  => \$Opt_access_time,
	'add-keep'     => \@opt_add_keep,
	'del-keep'     => \@opt_del_keep,
	'list-keep'    => \$opt_list_keep,
	'zero-keep'    => \$opt_zero_keep,
	'keep-file'    => \$opt_keep_file,
	'use-cache'    => \$opt_use_cache,
	'clear-cache'  => \$opt_clear_cache,
	'gui'          => \$opt_gui,
	'tk'           => \$opt_tk,
	'curses'       => \$opt_curses,
);

# call from this name force gui
if ( $basename =~ m/grpmorphan/ ) {
	$opt_gui = 1;
}

# first read config file
readrc( \%Opt );

# get arguments
Getopt::Long::Configure('no_ignore_case');
GetOptions(
	\%Opt,            'help|?',         'man',         'verbose!',
	'fullalgo!',      'version|V',      'all!',        'guess-perl!',
	'guess-python!',  'guess-pike!',    'guess-ruby!', 'guess-common!',
	'guess-data!',    'guess-doc!',     'guess-dev!',  'guess-lib!',
	'guess-all!',     'guess-custom=s', 'package=s',   'exclude=s',
	'install-time=i', 'access-time=i',  'list-keep',   'zero-keep',
	'add-keep=s',     'del-keep=s',     'use-cache!',  'clear-cache',
	'gui!',           'tk!',            'curses!',     'dry-run!',
	'suggests!',
) or pod2usage(2);

if ($opt_help) {
	pod2usage(1);
}
elsif ($opt_man) {
	pod2usage( -verbose => 2 );
}
elsif ($opt_version) {
	print_version( get_version() );
	exit;
}

# use command line argument
init_debug($opt_verbose);

# keep file management
# set default value
$opt_keep_file = $opt_keep_file || '/var/lib/rpmorphan/keep';
if ($opt_list_keep) {
	list_keep( $opt_keep_file, 1 );
	exit;
}
if ($opt_zero_keep) {
	zero_keep($opt_keep_file);
	exit;
}
if (@opt_add_keep) {
	my @liste_add = get_from_command_line(@opt_add_keep);
	add_keep( $opt_keep_file, \@liste_add, 1 );
	exit;
}
if (@opt_del_keep) {
	my @liste_del = get_from_command_line(@opt_del_keep);
	del_keep( $opt_keep_file, \@liste_del );
	exit;
}

# disable suggests option if rpm does not provide it
if ($opt_suggests) {
	$opt_suggests = is_suggests();
}

ana_guess( \%Opt );

# excluded files
my %excluded;

# first : permanent "keep" file
my @list_keep = list_keep( $opt_keep_file, 0 );
foreach my $ex (@list_keep) {
	$excluded{$ex} = 1;
	debug("conf : permanent exclude $ex");
}

build_excluded( \%Opt, \%excluded );

# install-time and access-time options are only available with the full algo
if ( ($opt_install_time) or ($Opt_access_time) ) {
	debug('forced full algo');
	$opt_fullalgo = 1;
}

# if only few packages, the big algo is not necessary
# quicksolve algo will be faster
if (@opt_package) {

	quick_run( \%Opt, \%excluded );
}

# test for graphical interface
if ($opt_gui) {
	$opt_gui = test_gui();
}
elsif ($opt_tk) {
	$opt_gui = test_tk_gui();
}
elsif ($opt_curses) {
	$opt_gui = test_curses_gui();
}

if ( !$opt_gui ) {
	*display_status = \&debug;
	*display_total = sub { };
}

# load and compute
load_data($opt_gui);

# display
if ($opt_gui) {

	# this will allow status update
	$Inloop = 1;

	# loop events
	if ( $opt_gui eq 'curses' ) {
		$Main_ui->mainloop;
	}
	else {
		MainLoop();
	}
}

__END__

=head1 NAME

rpmorphan - find orphaned packages

=head1 DESCRIPTION

rpmorphan finds "orphaned" packages on your system. It determines which packages have no other 
packages depending on their installation, and shows you a list of these packages. 
It is clone of deborphan debian software for rpm packages.

It will try to help you to remove unused packages, for exemple :

- after a distribution upgrade

- when you want to suppress packages after some tests

=head1 SYNOPSIS

rpmorphan  [options] [targets]

or

grpmorphan  [options] [targets]

using grpmorphan is a short way to use "rpmorphan -gui"

options:

   -help                brief help message
   -man                 full documentation
   -V, --version        print version

   -verbose             verbose
   -dry-run             simulate package remove
   -fullalgo            force full algorythm
   -suggests            use suggested package as if required
   -use-cache           use cache to avoid rpm query
   -clear-cache         remove cache file
   -gui                 display the graphical interface
   -tk                  display the tk graphical interface
   -curses              display the curses graphical interface

   -exclude pac         exclude pac from results
   -install-time +/-d   apply on packages which are installed before (after) d days
   -access-time d       apply on packages which are not been accessed for d days (slow)

targets:

   -package pac		search if pac is an orphan package
   -all        		apply on all packages
   -guess-perl		apply on perl packages
   -guess-python	apply on python packages
   -guess-pike		apply on pike packages
   -guess-ruby		apply on ruby packages
   -guess-common	apply on common packages
   -guess-data		apply on data packages
   -guess-doc		apply on documentation packages
   -guess-dev		apply on development packages
   -guess-lib		apply on library packages (this is the default target if none is specified)
   -guess-all		apply all -guess-* options (perl, python ...)
   -guess-custom regex	apply the given regex to filter to package's names to filter the output

keep file management

   -keep-file file	define the keep file to be used
   -list-keep 		list permanent exclude list
   -zero-keep 		empty permanent exclude list
   -add-keep pac	add pac package to permanent exclude list
   -del-keep pac	remove pac package from permanent exclude list

=head1 REQUIRED ARGUMENTS

you should provide at least one target. this can be 

=over 8

=item B<-all>

all the installed rpm package

=item B<-package>

one or several explicit package

=item B<-guess-*>

pre-selected packages groups

=item B<-guess-custom>

give a filter to select the packages you want study. you can use regular expressions.

=back

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Print the manual page and exits.

=item B<-version>

Print the program release and exit.

=item B<-verbose>

The program works and print debugging messages.

=item B<-dry-run>

this is a simulation mode : rpmorphan will show you what is
the result of package removing. The window's title is modified
to show this mode.

=item B<-use-cache>

the rpm query may be long (10 to 30 s). If you will run an rpmorphan tool
several time, this option will allow to gain a lot of time :
it save the rpm query on a file cache (first call), then
use this cache instead quering rpm (others calls).

=item B<-clear-cache>

to remove cache file. Can be used with -use-cache to write
a new cache.

=item B<-gui>

display a graphical interface which allow to show informations, remove packages
(an internal help is provided). This is currently the same as the -tk option

=item B<-tk>

display a tk graphical interface which allow to show informations, remove packages
(an internal help is provided). The Tk perl module is necessary to run the gui.

=item B<-curses>

display a curses graphical interface which allow to show informations, remove packages
(an internal help is provided). The Curses::UI perl module is necessary to run the gui.


=item B<-exclude>

this option will specify the packages to exclude from the output.
Can be used as '--exclude pac1 --exclude pac2'
or '--exclude "pac1, pac2"'

=item B<-install-time>

install-time is a filter on the period from the package installation date to now (in days).
if set positive, it only allow packages installed before x days.
if set negative, it only allow packages installed since x days.

=item B<-access-time>

access-time is designed to filter packages which have not been used since x days.

be careful : this option will slow the program

=item B<-fullalgo>

for a small list of packages, rpmorphan use a different quicker methode : rpm -e --test

this option can be used to force the use of the full algo

=item B<-suggests>

some rpm version offers a meta-data dependency call suggests : it is
for usefull but not necessary packages. if this option is set, the
suggested packages are used in rpmorphan as required packages.
The default value for this option is unset.

=item B<-package>

search if the given package(s) is(are) orphaned.
Can be used as '--package pac1 --package pac2'
or '--package "pac1, pac2"'

=item B<-all>

apply on all installed packages. The output should be interpreted.
For example lilo or grub are orphaned packages, but are necessary
to boot ...

the L</-install-time> and L</-access-time> options may be useful to filter the list

=item B<-guess-perl>

This option tries to find perl modules. It tries to match "^perl"

=item B<-guess-python>

This option tries to find python modules. It tries to match "^python"

=item B<-guess-pike>

This option tries to find pike modules. It tries to match "^pike"

=item B<-guess-ruby>

This option tries to find ruby modules. It tries to match "^ruby"

=item B<-guess-common>

This option tries to find common packages. It tries to match "-common$"

=item B<-guess-data>

This option tries to find data packages. It tries to match "-data$"

=item B<-guess-doc>

This option tries to find documentation packages. It tries to match "-doc$"

=item B<-guess-data>

This option tries to find data packages. It tries to match "-data$"

=item B<-guess-dev>

This option tries to find development packages. It tries to match "-devel$"

=item B<-guess-lib>

This option tries to find library packages. It tries to match "^lib"

=item B<-guess-all>

This is a short to tell : Try all of the above (perl, python ...)

=item B<-guess-custom>

this will allow you to specify your own filter. for exemple "^wh" 
will match whois, whatsnewfm ...

=item B<-keep-file>

define the keep file to be used. If not set, the /var/lib/rpmorphan/keep will be used

=item B<-list-keep>

list the permanent list of excluded packages and exit.

=item B<-zero-keep>

empty the permanent list of excluded packages and exit.

=item B<-add-keep>

add package(s) to the permanent list of excluded packages and exit.

Can be used as '--add-keep pac1 --add-keep pac2'
or '--add-keep "pac1, pac2"'

=item B<-del-keep>

remove package(s) from the permanent list of excluded packages and exit.

Can be used as '--add-keep pac1 --add-keep pac2'
or '--add-keep "pac1, pac2"'

=back

=head1 USAGE

rpmorphan can be useful after a distribution upgrade, to remove packages forgotten
by the upgrade tool. It is interesting to use the options "-all -install-time +xx'.

If you want to remove some recent tested packages, my advice is "-all -install-time -xx'.

if you just want to clean your disk, use '-all -access-time xxx'

=head1 FILES

/var/lib/rpmorphan/keep : the permanent exclude list

/tmp/rpmorphan.cache : cache file to store rpm query. The cache
file is common to all rpmorphan tools

/var/log/rpmorphan.log : log of all deleted packages

=head1 CONFIGURATION

the program can read rcfile if some exists.
it will load in order 

/etc/rpmorphanrc

~/.rpmorphanrc

.rpmorphanrc

In this file, 

# are comments, 

and parameters are stored in the following format :
parameter = value

example :

all = 1

curses = 1

=head1 DEPENDENCIES

rpmorphan uses standard perl module in console mode.

If you want to use the Tk graphical interface, you should install the Tk module 
(perl-Tk rpm package).

If you want to use the curses interface, you should install the Curses::UI perl module 
( perl-Curses-UI rpm package).

If you want to speed up rpmorphan, you should install the RPM2 perl module ( perl-RPM2 rpm package).
On mandriva, the URPM perl module (dependency from urpmi) will be used instead.

=head1 EXAMPLES

=over 8

=item display orphaned libraries

rpmorphan 

=item display all orphaned packages in a curses interface

rpmorphan --all --curses

=item display orphaned packages, not used since one year 

rpmorphan --all -access-time +365

=item display all orphaned packages, installed in the last 10 days

rpmorphan --all -install-time -10

=item display all orphaned packages, installed one month ago (or more)

rpmorphan --all -install-time +30

=back

=head1 BUGS AND LIMITATIONS

Virtuals packages are not well (for now) taken in account. 
Let's see an example : lilo and grub provide 'bootloader' virtual, which is 
necessary for system boot.
if the 2 are installed, they will be shown all 2 as orphans (but you can not remove 
the 2).
If you remove one of them, the other is now longer shown as orphan.

the software can only work with one version of each software : 
we only treat the first version seen

=head1 INCOMPATIBILITIES

not known

=head1 DIAGNOSTICS

to be written

=head1 NOTES

this program can be used as "normal" user to show orphans,
but you need to run it as supersuser (root) to remove packages
or apply changes in the permanent exclude list

access-time and install-time options are "new" features, not available
in deborphan tool

For Fedora users :
Yum offers a program called 'package-cleanup' which,
called with the '--leaves' option, can show quickly a list of
unused library packages.

For Mandriva users :
the 'urpme --auto-orphans' command show quickly a a list of
unused library packages.

=head1 ENVIRONMENT

=over 8

=item RPMORPHAN_METHOD

for experts only : allow to force the method used to get rpm 
data. It can be set to URPM, RPM2 or 'basic' (for external rpm query)

=back

=head1 SEE ALSO

=for man
\fIrpm\fR\|(1) for rpm call
.PP
\fIrpmusage\fR\|(1)
.PP
\fIrpmdep\fR\|(1)
.PP
\fIrpmduplicates\fR\|(1)
.PP
\fIrpmextra\fR\|(1)

=for html
<a href="rpmusage.1.html">rpmusage(1)</a><br />
<a href="rpmdep.1.html">rpmdep(1)</a><br />
<a href="rpmduplicates.1.html">rpmduplicates(1)</a><br />
<a href="rpmextra.1.html">rpmextra(1)</a><br />

=head1 EXIT STATUS

should be allways 0

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006 by Eric Gerbier
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=head1 AUTHOR

Eric Gerbier

you can report any bug or suggest to gerbier@users.sourceforge.net

=cut
