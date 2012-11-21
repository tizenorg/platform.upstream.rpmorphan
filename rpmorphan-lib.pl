#!/usr/bin/perl 
###############################################################################
#   rpmorphan-lib.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmorphan-1.11 | rpmorphan-lib.pl | Wed Aug 1 09:36:43 2012 +0200 | Eric Gerbier  $
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

use Data::Dumper;    # debug
use File::stat;      # get_last_access

## no critic (RequireCheckingReturnValueOfEval)

# the code should use no "print" calls
# but use instead debug, warning, info calls
###############################################################################
sub nodebug {
	return;
}
###############################################################################
sub backend_debug {
	my $text = $_[0];
	print "debug $text\n";
	return;
}
###############################################################################
# change debug subroutine
# this way seems better than previous one as
# - it does not need any "global" verbose variable
# - it suppress any verbose test (quicker)
sub init_debug($) {
	my $verbose = shift @_;

	# to avoid error messages
	## no critic ( NoWarnings );
	no warnings 'redefine';
	## use critic;

	if ($verbose) {
		*debug = \&backend_debug;
	}
	else {
		*debug = \&nodebug;
	}

	use warnings 'all';
	return;
}
###############################################################################
# used to print warning messages
sub warning($) {
	my $text = shift @_;
	warn "WARNING $text\n";
	return;
}
###############################################################################
# used to print normal messages
sub info($) {
	my $text = shift @_;
	print "$text\n";
	return;
}
###############################################################################
sub print_version($) {
	my $version = shift @_;
	info("$PROGRAM_NAME version $version");
	return;
}
#########################################################
# used to check on option
sub is_set($$) {
	my $rh_opt = shift @_;    # hash of program arguments
	my $key    = shift @_;    # name of desired option

	#debug("is_set $key");
	my $r_value = $rh_opt->{$key};
	return ${$r_value};
}
#########################################################
sub is_verbose($) {
	my $rh_opt = shift @_;    # hash of program arguments

	return is_set( $rh_opt, 'verbose' );
}
#########################################################
# apply a filter on package list according program options
sub rpmfilter($$) {
	my $rh_opt      = shift @_;
	my $rh_list_pac = shift @_;

	display_status('apply filters');

	# we just want the list of keys
	my @list = keys %{$rh_list_pac};

	if ( is_set( $rh_opt, 'all' ) ) {
		debug('all');
		return @list;
	}
	else {
		debug('guess');

		my @filtered_list;
		if ( is_set( $rh_opt, 'guess-perl' ) ) {
			debug('guess-perl');
			my @res = grep { /^perl/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-python' ) ) {
			my @res = grep { /^python/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-pike' ) ) {
			my @res = grep { /^pike/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-ruby' ) ) {
			my @res = grep { /^ruby/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-common' ) ) {
			my @res = grep { /-common$/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-data' ) ) {
			my @res = grep { /-data$/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-doc' ) ) {
			my @res = grep { /-doc$/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-dev' ) ) {
			my @res = grep { /-devel$/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-lib' ) ) {
			my @res = grep { /^lib/ } @list;
			push @filtered_list, @res;
		}
		if ( is_set( $rh_opt, 'guess-custom' ) ) {
			my $regex = ${ $rh_opt->{'guess-custom'} };
			my @res = grep { /$regex/ } @list;
			push @filtered_list, @res;
		}
		return @filtered_list;
	}
}
#########################################################
# difference between 2 date in unix format
# return in days
sub diff_date($$) {
	my $now  = shift @_;    # current
	my $time = shift @_;    #

	# convert from seconds to days
	## no critic(ProhibitParensWithBuiltins,ProhibitMagicNumbers)
	return int( ( $now - $time ) / 86_400 );
}
#########################################################
# return the date (unix format) of last access on a package
# (scan all inodes for atime) and the name of the file
sub get_last_access($) {
	my $ra_files = shift @_;    # array of file names

	my $last_date = 0;          # means a very old date for linux : 1970
	my $last_file = q{};
  FILE: foreach my $file ( @{$ra_files} ) {
		next FILE unless ( -e $file );
		my $stat  = stat $file;
		my $atime = $stat->atime();

		if ( $atime > $last_date ) {
			$last_date = $atime;
			$last_file = $file;
		}
	}
	return ( $last_date, $last_file );
}
#########################################################
# depending the cache option, return a command to execute
# - as an rpm query (piped)
# - as a cache file to open
sub init_cache($) {
	my $rh_opt = shift @_;    # hash of program arguments

	# the main idea is to reduce the number of call to rpm in order to gain time
	# the ';' separator is used to separate fields
	# the ',' separator is used to separate data in fields arrays

	# note : we do not ask for PROVIDEFLAGS PROVIDEVERSION
	# REQUIREFLAGS REQUIREVERSION

	my $suggests = ( is_set( $rh_opt, 'suggests' ) ) ? '[%{SUGGESTS},]' : q{};

	my $rpm_cmd =
"rpm -qa --queryformat '%{NAME};[%{REQUIRENAME},]$suggests;[%{PROVIDES},];[%{FILENAMES},];%{INSTALLTIME}\n' 2>/dev/null";
	my $cache_file = '/tmp/rpmorphan.cache';
	my $fh_cache;
	my $cmd;

	if ( is_set( $rh_opt, 'clear-cache' ) ) {
		unlink $cache_file if ( -f $cache_file );
	}

	if ( is_set( $rh_opt, 'use-cache' ) ) {
		if ( -f $cache_file ) {

			# cache exists : use it
			$cmd = $cache_file;
			display_status("use cache file $cache_file");
		}
		else {

			# use rpm command
			$cmd = "$rpm_cmd |";

			# and create cache file
			## no critic (RequireBriefOpen)
			if ( open $fh_cache, '>', $cache_file ) {
				display_status("create cache file $cache_file");
			}
			else {
				warning("can not create cache file $cache_file : $ERRNO");
			}
		}
	}
	else {

		# output may be long, so we use a pipe to avoid to store a big array
		$cmd = "$rpm_cmd |";
		display_status('read rpm data');

		unlink $cache_file if ( -f $cache_file );
	}

	return ( $cmd, $fh_cache );
}
#########################################################
## no critic (ProhibitManyArgs)
sub analyse_rpm_info($$$$$$$$$$) {
	my $name        = shift @_;    # current package name
	my $ra_prov     = shift @_;    # data from database on name
	my $ra_req      = shift @_;    # idem
	my $ra_files    = shift @_;    # idem
	my $rh_objects  = shift @_;
	my $rh_provides = shift @_;
	my $rh_files    = shift @_;
	my $rh_depends  = shift @_;
	my $rh_virtual  = shift @_;
	my $rh_requires = shift @_;

	## use critic;

	# we do not use version in keys
	# so we only keep the last seen data for a package name
	if ( exists $rh_provides->{$name} ) {
		debug("duplicate package $name");
	}

  VIRTUAL: foreach my $p ( @{$ra_prov}, @{$ra_files} ) {

		# do not add files
		#next VIRTUAL if ( $p =~ m!^/! );

		#  some bad package may provide more than on time the same object
		if (   ( exists $rh_objects->{$p} )
			&& ( $rh_objects->{$p} ne $name ) )
		{

			# method 1 (old)
			# we do not use who provide this virtual for now
			#$rh_virtual->{$p} = 1;

			# method 2 (current)
			# to improve the code, we can use virtual as a counter
			# ( as a garbage collector )
			# so we can remove all providing except the last one
			if ( !exists $rh_virtual->{$p} ) {

				# add previous data
				$rh_virtual->{$p}{ $rh_objects->{$p} } = 1;
			}

			# add new virtual
			$rh_virtual->{$p}{$name} = 1;
		}
		else {

			# keep memory of seen "provided"
			$rh_objects->{$p} = $name;
		}
	}

	# $name package provide @prov
	# file are also included in "provide"
	push @{ $rh_provides->{$name} }, @{$ra_prov}, @{$ra_files};

	# list are necessary for access-time option
	push @{ $rh_files->{$name} }, @{$ra_files};

	# this will be helpfull when recursive remove package
	push @{ $rh_requires->{$name} }, @{$ra_req};

	# build a hash for dependencies
	foreach my $require ( @{$ra_req} ) {

		# we have to suppress auto-depends (ex : ark package)
		my $flag_auto = 0;
	  PROVIDE: foreach my $p ( @{$ra_prov} ) {
			if ( $require eq $p ) {
				$flag_auto = 1;

				#debug("skip auto-depency on $name");
				last PROVIDE;
			}
		}

	   # $name depends from $require
	   # exemple : depends { 'afick' } { afick-gui } = 1
	   # push @{ $rh_depends->{$require} }, $name unless $flag_auto;
	   # we use a hash to help when we have to delete data (on recursive remove)
		$rh_depends->{$require}{$name} = 1 unless $flag_auto;
	}
	return;
}
#########################################################
# read rpm information about all installed packages
# can be from database, or from rpmorphan cache
sub read_rpm_data_base($$$$$$$) {
	my $rh_opt          = shift @_;    # hash of program arguments
	my $rh_provides     = shift @_;
	my $rh_install_time = shift @_;
	my $rh_files        = shift @_;
	my $rh_depends      = shift @_;
	my $rh_virtual      = shift @_;
	my $rh_requires     = shift @_;

	display_status('read rpm data using base RPM');
	my ( $cmd, $fh_cache ) = init_cache($rh_opt);

	# because we can open a pipe or a cache, it is not possible to use
	# the 3 arg form of open
	## no critic (ProhibitTwoArgOpen,RequireBriefOpen);
	my $fh;
	if ( !open $fh, $cmd ) {

		# no critic;
		die "can not open $cmd : $ERRNO\n";
		## use critic
	}
	debug('1 : analysis');
	my %objects;
	while (<$fh>) {

		# write cache
		print {$fh_cache} $_ if ($fh_cache);

		my ( $name, $req, $prov, $files, $install_time ) = split /;/, $_;

		# install time are necessary for install-time option
		$rh_install_time->{$name} = $install_time;

		# see rpm query format in init_cache
		my $delim = q{,};
		my @prov  = split /$delim/, $prov;
		my @req   = split /$delim/, $req;
		my @files = split /$delim/, $files;

		analyse_rpm_info(
			$name,       \@prov,       \@req,     \@files,
			\%objects,   $rh_provides, $rh_files, $rh_depends,
			$rh_virtual, $rh_requires
		);

	}
	close $fh or warning("problem to close rpm command : $ERRNO");

	# close cache if necessary
	if ($fh_cache) {
		close $fh_cache or warning("problem to close cache file : $ERRNO");
	}
	return;
}
#########################################################
# read database info by use of RPM2 module
sub read_rpm_data_rpm2($$$$$$$) {
	my $rh_opt          = shift @_;    # hash of program arguments
	my $rh_provides     = shift @_;
	my $rh_install_time = shift @_;
	my $rh_files        = shift @_;
	my $rh_depends      = shift @_;
	my $rh_virtual      = shift @_;
	my $rh_requires     = shift @_;

	# cache ?
	# acces to data by rpm2 should be fast,
	# so do not need cache
	# and init_cache works with a command to exec
	# not with a perl module

	display_status('read rpm data using RPM2');
	import RPM2;
	my $db = RPM2->open_rpm_db();

	my $flag_suggests = is_set( $rh_opt, 'suggests' );

	debug('1 : analysis');
	my %objects;

	my $i = $db->find_all_iter();
	while ( my $pkg = $i->next ) {

		my $name         = $pkg->name;
		my $install_time = $pkg->installtime;
		$rh_install_time->{$name} = $install_time;

		my @req   = $pkg->requires;
		my @prov  = $pkg->provides;
		my @files = $pkg->files;

		if ($flag_suggests) {
			my @suggests = $pkg->tag('SUGGESTS');

			#debug("suggests for $name : " . join ' ', @suggests);
			push @req, @suggests;
		}

		analyse_rpm_info(
			$name,       \@prov,       \@req,     \@files,
			\%objects,   $rh_provides, $rh_files, $rh_depends,
			$rh_virtual, $rh_requires
		);
	}
	return;
}
#########################################################
# URPM return dependencies as perl[ = 5.8]
# we have to suppress the version and only keep the package
sub clean_rel($) {
	my $ra = shift @_;

	foreach my $elem ( @{$ra} ) {
		$elem =~ s/\[.*\]//;
	}
	return;
}
#########################################################
# read database info by use of URPM module
sub read_rpm_data_urpm($$$$$$$) {
	my $rh_opt          = shift @_;    # hash of program arguments
	my $rh_provides     = shift @_;
	my $rh_install_time = shift @_;
	my $rh_files        = shift @_;
	my $rh_depends      = shift @_;
	my $rh_virtual      = shift @_;
	my $rh_requires     = shift @_;

	# cache ?
	# acces to data by rpm2 should be fast,
	# so do not need cache
	# and init_cache works with a command to exec
	# not with a perl module

	display_status('read rpm data using URPM');
	import URPM;
	my $db = URPM::DB::open();
	debug('1 : analysis');

	my $flag_suggests = is_set( $rh_opt, 'suggests' );

	my %objects;
	$db->traverse(
		sub {
			my ($package) = @_;          # this is a URPM::Package object
			my $name = $package->name;
			my $installtime = $package->queryformat('%{INSTALLTIME}');
			$rh_install_time->{$name} = $installtime;
			my @req = $package->requires();
			clean_rel( \@req );
			my @prov = $package->provides();
			clean_rel( \@prov );
			my @files = $package->files();

			if ($flag_suggests) {
				my $suggests = $package->queryformat('[%{SUGGESTS},]');
				my @suggests = split /,/, $suggests;

				#debug("suggests for $name : " . join ' ', @suggests);
				clean_rel( \@suggests );
				push @req, @suggests;
			}

			analyse_rpm_info(
				$name,       \@prov,       \@req,     \@files,
				\%objects,   $rh_provides, $rh_files, $rh_depends,
				$rh_virtual, $rh_requires
			);
		}
	);

	return;
}
#########################################################
sub read_rpm_data($$$$$$$) {
	my $rh_opt          = shift @_;    # hash of program arguments
	my $rh_provides     = shift @_;
	my $rh_install_time = shift @_;
	my $rh_files        = shift @_;
	my $rh_depends      = shift @_;
	my $rh_virtual      = shift @_;
	my $rh_requires     = shift @_;

	# empty all structures
	%{$rh_provides}     = ();
	%{$rh_install_time} = ();
	%{$rh_files}        = ();
	%{$rh_depends}      = ();
	%{$rh_virtual}      = ();
	%{$rh_requires}     = ();

	my %code = (
		'URPM'  => \&read_rpm_data_urpm,
		'RPM2'  => \&read_rpm_data_rpm2,
		'basic' => \&read_rpm_data_base,
	);
	my @def_list = ( 'URPM', 'RPM2', 'basic' );
	my @list;
	if ( exists $ENV{'RPMORPHAN_METHOD'} ) {
		my $method = $ENV{'RPMORPHAN_METHOD'};

		# should be 'URPM', 'RPM2' or 'basic'
		if ( exists $code{$method} ) {
			push @list, $method;

			# for security : basic will allways work
			push @list, 'basic';
		}
		else {
			warning("unknown method $method, use default");
			@list = @def_list;
		}
	}
	else {

		# default list (ordered) of perl packages to test
		@list = @def_list;
	}
	my $ok = 0;
	foreach my $method (@list) {
		debug("try $method");
		eval { require $method . '.pm'; };
		if ($EVAL_ERROR) {
			debug("can not use $method");
		}
		else {
			$ok              = 1;
			*read_rpm_data_m = $code{$method};
			read_rpm_data_m( $rh_opt, $rh_provides, $rh_install_time, $rh_files,
				$rh_depends, $rh_virtual, $rh_requires );
			last;
		}
	}
	if ( !$ok ) {

		# if nothing is working, use default basic method
		read_rpm_data_base( $rh_opt, $rh_provides, $rh_install_time, $rh_files,
			$rh_depends, $rh_virtual, $rh_requires );
	}
	return;
}
## use critic
#########################################################
sub read_one_rc($$$) {
	my $rh_list = shift @_;    # list of available parameters
	my $fh_rc   = shift @_;
	my $rcfile  = shift @_;

	# perl cookbook, 8.16
	my $line = 1;
  RC: while (<$fh_rc>) {
		chomp;
		s/#.*//;               # comments
		s/^\s+//;              # skip spaces
		s/\s+$//;
		next RC unless length;
		my ( $key, $value ) = split /\s*=\s*/, $_, 2;
		if ( defined $key ) {
			if ( exists $rh_list->{$key} ) {

				# the last line wins
				if ( ref( $rh_list->{$key} ) eq 'ARRAY' ) {
					@{ $rh_list->{$key} } = get_from_command_line($value);
				}
				else {
					${ $rh_list->{$key} } = $value;
				}

				# special case : verbose will modify immediately behavior
				init_debug($value) if ( $key eq 'verbose' );

				debug(
"rcfile ($rcfile) : found $key parameter with value : $value"
				);
			}
			else {
				warning("bad $key parameter in line $line in $rcfile file");
			}
		}
		else {
			warning("bad line $line in $rcfile file");
		}
		$line++;
	}

	return;
}
#########################################################
# read all existing rc file from general to local :
# host, home, local directory
sub readrc($) {

	my $rh_list = shift @_;    # list of available parameters

	# can use local rc file, home rc file, host rc file
	my @list_rc =
	  ( '/etc/rpmorphanrc', $ENV{HOME} . '/.rpmorphanrc', '.rpmorphanrc', );

	foreach my $rcfile (@list_rc) {

		if ( -f $rcfile ) {
			debug("read rc from $rcfile");
			if ( open my $fh_rc, '<', $rcfile ) {
				read_one_rc( $rh_list, $fh_rc, $rcfile );
				close $fh_rc
				  or warning("problem to close rc file $rcfile :$ERRNO");
			}
			else {
				warning("can not open rcfile $rcfile : $ERRNO");
			}
		}
		else {
			debug("no rcfile $rcfile found");
		}
	}
	return;
}
#########################################################
# because arg can be given in one or several options :
# --add toto1 --add toto2
# --add toto1,toto2
sub get_from_command_line(@) {
	my @arg = @_;

	my $comma = q{,};
	## no critic (ProhibitParensWithBuiltins);
	return split /$comma/, join( $comma, @arg );
	## use critic;
}
#########################################################
sub is_remove_allowed($) {
	my $opt_dry_run = shift @_;

	return ( ( $EFFECTIVE_USER_ID == 0 ) && ( !$opt_dry_run ) );
}
#########################################################
# analyse command line options for guess
sub ana_guess($) {
	my $rh_opt = shift @_;

	debug('ana_guess');

	my $true = 1;

	# guess-all force all others
	if ( is_set( $rh_opt, 'guess-all' ) ) {
		$rh_opt->{'guess-perl'}   = \$true;
		$rh_opt->{'guess-python'} = \$true;
		$rh_opt->{'guess-pike'}   = \$true;
		$rh_opt->{'guess-ruby'}   = \$true;
		$rh_opt->{'guess-common'} = \$true;
		$rh_opt->{'guess-data'}   = \$true;
		$rh_opt->{'guess-doc'}    = \$true;
		$rh_opt->{'guess-dev'}    = \$true;
		$rh_opt->{'guess-lib'}    = \$true;
	}

	my $is_guess =
	     is_set( $rh_opt, 'guess-perl' )
	  || is_set( $rh_opt, 'guess-python' )
	  || is_set( $rh_opt, 'guess-pike' )
	  || is_set( $rh_opt, 'guess-ruby' )
	  || is_set( $rh_opt, 'guess-common' )
	  || is_set( $rh_opt, 'guess-data' )
	  || is_set( $rh_opt, 'guess-doc' )
	  || is_set( $rh_opt, 'guess-dev' )
	  || is_set( $rh_opt, 'guess-lib' )
	  || is_set( $rh_opt, 'guess-custom' );

	# test if a target is set
	if (   ( !@{ $rh_opt->{'package'} } )
		&& ( !is_set( $rh_opt, 'all' ) )
		&& ( !$is_guess ) )
	{

		# default behavior if no targets selected
		debug('set target to guess-lib (default)');
		$rh_opt->{'guess-lib'} = \$true;
	}
	return;
}
#########################################################
# parse command line exclude option
sub build_excluded($$) {
	my $rh_opt      = shift @_;
	my $rh_excluded = shift @_;

	debug('build_excluded');
	if ( $rh_opt->{'exclude'} ) {

		# allow comma separated options on tags option
		# and build a hash for faster access
		my @liste_ex = get_from_command_line( @{ $rh_opt->{'exclude'} } );
		foreach my $ex (@liste_ex) {
			$rh_excluded->{$ex} = 1;
			debug("build_excluded : exclude $ex");
		}
	}

   # to be passed to load_data;
   # be carefull : we use here a new key : excluded , not exclude (command line)
	$rh_opt->{'excluded'} = $rh_excluded;
	return;
}
#########################################################
sub get_package_info($) {
	my $pac = shift @_;

	my $cmd = "rpm -qil $pac";
	## no critic ( ProhibitBacktickOperators );
	my @res = `$cmd`;
	## use critic
	chomp @res;

	return @res;
}
#########################################################
sub get_package_summary($) {
	my $pac = shift @_;

	my $cmd = "rpm -q --queryformat '%{SUMMARY}' $pac";
	## no critic ( ProhibitBacktickOperators );
	my $res = `$cmd`;
	## use critic

	return $res;
}
#########################################################
# return true is rpm allow SUGGEST tags
sub is_suggests() {

	my $cmd = 'rpm -q --querytags ';
	## no critic ( ProhibitBacktickOperators );
	my @res = `$cmd`;
	## use critic
	foreach my $tag (@res) {
		chomp $tag;
		if ( $tag =~ m/^SUGGESTS/ ) {
			return 1;
		}
	}
	return 0;
}
#########################################################

1;
