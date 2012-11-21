#!/usr/bin/perl 
###############################################################################
#   rpmusage.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmorphan-1.11 | rpmusage.pl | Tue Jul 5 11:28:04 2011 +0000 | gerbier  $
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
use Data::Dumper;    # debug

# library
use File::Basename;
my $dirname = dirname($PROGRAM_NAME);
require $dirname . '/rpmorphan-lib.pl'
  or die "problem to load rpmorphan-lib: $ERRNO\n";

# the code should use no "print" calls
# but instead debug, warning, info calls
#########################################################
sub solve($$$$) {
	my $name        = shift @_;    # package name
	my $rh_files    = shift @_;    # general hash of package files
	my $access_time = shift @_;    # option access-time
	my $now         = shift @_;    # current time

	debug("solve $name");

	my ( $last_time, $file ) = get_last_access( $rh_files->{$name} );
	if ( !$file ) {
		debug("skip $name : no files");

		# can not give a time access : no files !
		return;
	}
	my $diff = diff_date( $now, $last_time );
	if ($access_time) {
		if ( $diff > $access_time ) {
			info("$name $diff on $file");
		}
		else {
			debug("skip package $name : too recent access ($diff days)");
		}
	}
	else {
		info("$name $diff on $file");
	}

	return;
}
#########################################################
sub quicksolve($$$) {
	my $name        = shift @_;    # package name
	my $access_time = shift @_;    # option access-time
	my $now         = shift @_;    # current time

	debug("(quicksolve) : $name");

	my $cmd = 'rpm -ql ';

	## no critic (ProhibitBacktickOperators);
	my @files = `$cmd $name`;
	## use critic;
	chomp @files;

	# change structure to call generic call
	my %files;
	push @{ $files{$name} }, @files;

	solve( $name, \%files, $access_time, $now );
	return;
}
##########################################################
# read all rpm database is long,
# for a small number of packages, it is faster to use
# another algo
sub quick_run($$$) {
	my $rh_opt      = shift @_;
	my $rh_excluded = shift @_;
	my $access_time = shift @_;

	debug('quick_run');

	#allow comma separated options on tags option
	my @opt_package = get_from_command_line( @{ $rh_opt->{'package'} } );
	$rh_opt->{'package'} = \@opt_package;

	if ( !is_set( $rh_opt, 'fullalgo' ) ) {
		## no critic (ProhibitMagicNumbers)
		my $max_packages = 5;
		if ( $#opt_package <= $max_packages ) {

			# use  quicksolve
			my $now = time;
		  PAC: foreach my $pac (@opt_package) {
				if ( exists $rh_excluded->{$pac} ) {
					debug("skip $pac : excluded");
					next PAC;
				}
				quicksolve( $pac, $access_time, $now );
			}
			exit;
		}
		else {
			debug('too much package for quicksolve algo');
		}
	}
	else {
		debug('full algo option');
	}
	return;
}
##########################################################
# is to be defined because rpmorphan-lib need it
sub display_status($) {
	debug( shift @_ );
	return;
}
#########################################################
#
#	main
#
#########################################################
my $version = '0.5';

my $opt_verbose = 0;
my $opt_help;
my $opt_man;
my $opt_version;
my $opt_fullalgo;
my $opt_use_cache;
my $opt_clear_cache;

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
my $opt_access_time;

my %opt = (
	'help'         => \$opt_help,
	'man'          => \$opt_man,
	'verbose'      => \$opt_verbose,
	'version'      => \$opt_version,
	'fullalgo'     => \$opt_fullalgo,
	'all'          => \$opt_all,
	'guess-perl'   => \$opt_guess_perl,
	'guess-python' => \$opt_guess_python,
	'guess-pike'   => \$opt_guess_pike,
	'guess-ruby'   => \$opt_guess_ruby,
	'guess-common' => \$opt_guess_common,
	'guess-data'   => \$opt_guess_data,
	'guess-doc'    => \$opt_guess_doc,
	'guess-dev'    => \$opt_guess_dev,
	'guess-lib'    => \$opt_guess_lib,
	'guess-all'    => \$opt_guess_all,
	'guess-custom' => \$opt_guess_custom,
	'package'      => \@opt_package,
	'exclude'      => \@opt_exclude,
	'install-time' => \$opt_install_time,
	'access-time'  => \$opt_access_time,
	'use-cache'    => \$opt_use_cache,
	'clear-cache'  => \$opt_clear_cache,
);

Getopt::Long::Configure('no_ignore_case');
GetOptions(
	\%opt,            'help|?',         'man',         'verbose',
	'fullalgo!',      'version|V',      'all!',        'guess-perl!',
	'guess-python!',  'guess-pike!',    'guess-ruby!', 'guess-common!',
	'guess-data!',    'guess-doc!',     'guess-dev!',  'guess-lib!',
	'guess-all!',     'guess-custom=s', 'package=s',   'exclude=s',
	'install-time=i', 'access-time=i',  'use-cache!',  'clear-cache'
) or pod2usage(2);

init_debug($opt_verbose);

if ($opt_help) {
	pod2usage(1);
}
elsif ($opt_man) {
	pod2usage( -verbose => 2 );
}
elsif ($opt_version) {
	print_version($version);
	exit;
}

ana_guess( \%opt );

my %excluded;
build_excluded( \%opt, \%excluded );

# install-time and access-time options are only available with the full algo
if ( ($opt_install_time) or ($opt_access_time) ) {
	debug('forced full algo');
	$opt_fullalgo = 1;
}

# if only few packages, the big algo is not necessary
# quicksolve algo will be faster
if (@opt_package) {

	quick_run( \%opt, \%excluded, $opt_access_time );
}

# hash structures to be filled with rpm query
my %files;
my %install_time;

# not really used for new
my %provides;
my %depends;
my %virtual;
my %requires;

# phase 1 : get data and build structures
read_rpm_data( \%opt, \%provides, \%install_time, \%files, \%depends, \%virtual,
	\%requires );

# phase 2 : filter
# if a package is set, it will be first used, then it will use in order -all, then (guess*)
# (see filter sub)
debug('2 : filter');
my @liste_pac;
if (@opt_package) {
	@liste_pac = @opt_package;
}
else {
	@liste_pac = rpmfilter( \%opt, \%files );
}

# needed by access-time and install-time options
my $now = time;

# phase 3 : solve problem
debug('3 : solve');
PACKAGE: foreach my $pac (@liste_pac) {
	if ( exists $excluded{$pac} ) {
		debug("skip $pac : excluded");
		next PACKAGE;
	}

	if ($opt_install_time) {
		my $diff = diff_date( $now, $install_time{$pac} );
		if ( $opt_install_time > 0 ) {
			if ( $diff < $opt_install_time ) {
				debug("skip $pac : too recent install ($diff days)");
				next;
			}
		}
		elsif ( $diff > -$opt_install_time ) {
			debug("skip $pac : too old install ($diff days)");
			next;
		}
	}
	solve( $pac, \%files, $opt_access_time, $now );
}

__END__

=head1 NAME

rpmusage - display rpm packages last use

=head1 DESCRIPTION

rpmusage will display for each package, the last date it was used (in days). It can be used
to find unused packages. It use the atime field of all package's files to do this job.
Note : as it scan all files inodes, the run may be long ...

=head1 SYNOPSIS

rpmusage.pl  [options] [targets]

options:

   -help		brief help message
   -man			full documentation
   -V, --version	print version

   -verbose		verbose
   -fullalgo		force full algorythm
   -use-cache		use cache to avoid rpm query
   -clear-cache		remove cache file

   -exclude pac		exclude pac from results
   -install-time +/-d	apply on packages which are installed before (after) d days
   -access-time d	apply on packages which are not been accessed for d days (slow)

targets:

   -package pac		search last access on pac package
   -all			apply on all packages (this is the default)
   -guess-perl		apply on perl packages
   -guess-python	apply on python packages
   -guess-pike		apply on pike packages
   -guess-ruby		apply on ruby packages
   -guess-common	apply on common packages
   -guess-data		apply on data packages
   -guess-doc		apply on documentation packages
   -guess-dev		apply on development packages
   -guess-lib		apply on library packages
   -guess-all		apply all -guess-* options (perl, python ...)
   -guess-custom regex	apply the given regex to filter to package's names to filter the output

=head1 REQUIRED ARGUMENTS

it can be used without any argument, and then will apply on all packages

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

=item B<-use-cache>

the rpm query may be long (10 to 30 s). If you will run an rpmorphan tool
several time, this option will allow to gain a lot of time :
it save the rpm query on a file cache (first call), then
use this cache instead quering rpm (others calls).

=item B<-clear-cache>

to remove cache file. Can be used with -use-cache to write
a new cache.

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

for a small list of packages, rpmusage use a different quicker methode : rpm -e --test

this option can be used to force the use of the full algo

=item B<-package>

search if the given package(s) is(are) orphaned.
Can be used as '--package pac1 --package pac2'
or '--package "pac1, pac2"'

=item B<-all>

apply on all installed packages. The output should be interpreted.
For example lilo or grub are orphaned packages, but are necessary
to boot ...

the L<-install-time> and L<-access-time> options may be useful to filter the list

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

=back

=head1 USAGE

display all packages in access date order

rpmusage.pl  | sort -k 2 -n

only ask for perl packages

rpmusage.pl --guess-perl | sort -k 2 -n

to read the output :
"python-pexpect 97 on /usr/share/doc/python-pexpect"
means the package was last used 97 days ago and the more recently used file was the 
/usr/share/doc/python-pexpect file

=head1 FILES

/tmp/rpmorphan.cache : cache file to store rpm query. The cache
file is common to all rpmorphan tools

=head1 DEPENDENCIES

rpmusage uses only standard perl module.

but it needs the rpm command tool.

=head1 BUGS AND LIMITATIONS

the software can only work with one version of each software :
we only treat the first version seen

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

=head1 INCOMPATIBILITIES

not known

=head1 DIAGNOSTICS

to be written

=head1 NOTES

this program should be used as root superuser, because it needs to access
(in read mode) to all files

=head1 SEE ALSO

=for man
\fIrpm\fR\|(1) for rpm call
.PP
\fIrpmorphan\fR\|(1)
.PP
\fIrpmdep\fR\|(1)
.PP
\fIrpmduplicates\fR\|(1)
.PP
\fIrpmextra\fR\|(1)

=for html
<a href="rpmorphan.1.html">rpmorphan(1)</a><br />
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
