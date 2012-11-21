#!/usr/bin/perl 
###############################################################################
#   rpmextra.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmorphan-1.11 | rpmextra.pl | Mon Jul 4 12:49:43 2011 +0000 | gerbier  $
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
# this program search extra packages
# same as : yum list extra
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
# is to be defined because rpmorphan-lib need it
sub display_status($) {
	debug( shift @_ );
	return;
}
##########################################################
# search for a command in PATH variable
sub search_in_path($) {
	my $prog = shift @_;

	foreach ( split /:/, $ENV{'PATH'} ) {
		if ( -x "$_/$prog" ) {
			return "$_/$prog";
		}
	}
	return;
}
##########################################################
# get list of installed packages
sub get_installed_rpm() {

	debug('get list of installed packages');
	## no critic (ProhibitBacktickOperators)
	my @list = `/bin/rpm -qa`;
	chomp @list;
	my @sorted_list = sort @list;
	return @sorted_list;
}
#########################################################
# for distribution using package-cleanup
# ex : redhat/centos
sub get_extra_cleanup($) {
	my $cleanup_path = shift @_;    # path to package-cleanup

	debug('using package-cleanup');

	my $cmd = "$cleanup_path -q --orphans";

	# output look like :
	# kernel-2.6.35.12-90.fc14.i686
	# rpmorphan-1.8-1.noarch

	my %hash;
	## no critic (ProhibitTwoArgOpen)
	if ( open my $fh, "$cmd |" ) {
		my $nr = 0;
		while ( my $line = <$fh> ) {
			chomp $line;

			# skip first lines
			if ( $nr > 1 ) {
				$hash{$line} = 1;
			}
			$nr++;
		}
		close $fh or warning("problem on close $cmd : $ERRNO");
	}
	else {
		warning("can not read $cmd output");
		exit;
	}

	foreach my $pac ( sort keys %hash ) {
		print "$pac\n";
	}
	return;
}
#########################################################
# for distribution using yum
# ex : redhat/centos/fedora
sub get_extra_yum($) {
	my $yum_path = shift @_;    # path to yum

	debug('using yum');
	my $cmd = "$yum_path -q list extras 2>/dev/null";

	# output look like :
	# zynaddsubfx.x86_64    2.4.0-2.fc12    fedora
	# zynjacku.x86_64       5-4.fc12        updates

	my %hash;
	## no critic (ProhibitTwoArgOpen)
	if ( open my $fh, "$cmd |" ) {
		my $nr = 0;
		while ( my $line = <$fh> ) {
			chomp $line;

			if ( $nr > 0 ) {

			   # line follow the format : name version repository
			   # but if version is too long, line may be splitted in 2 lines !!!
				## no critic (ProhibitEmptyQuotes)
				my ( $name, $version, undef ) = split ' ', $line;
				if ( !$version ) {
					print "problem line $line\n";
				}
				else {
					$name =~ s/\..*//;    # remove arch
					$name .= $version;    # add version
					$hash{$name} = 1;
				}
			}
			$nr++;
		}
		close $fh or warning("problem on close $cmd : $ERRNO");
	}
	else {
		warning("can not read $cmd output");
		exit;
	}

	foreach my $pac ( sort keys %hash ) {
		print "$pac\n";
	}
	return;
}
#########################################################
# for distribution using urpmq
# ex : Mandriva
sub get_extra_urpmq($) {
	my $urpmq_path = shift @_;    # path to urpmq

	# maybe use urpm perl module ?
	debug('using urpmq');
	my $cmd = "$urpmq_path --list -r";

	# output look like :
	# zziplib0-devel-0.13.58-1mdv2010.1
	# zzuf-0.13-1mdv2010.1

	# get list of all available packages
	my %available;
	debug('get list of packages in repository');
	## no critic (ProhibitTwoArgOpen)
	if ( open my $fh, "$cmd |" ) {
		while ( my $line = <$fh> ) {
			chomp $line;
			$available{$line} = 1;
		}
		close $fh or warning("problem on close $cmd : $ERRNO");
	}
	else {
		warning("can not read $cmd output");
		exit;
	}

	my @installed = get_installed_rpm();

	foreach my $pac (@installed) {
		if ( !exists $available{$pac} ) {
			print "$pac\n";
		}
	}
	return;
}
#########################################################
# for distribution using zypper
# ex : Suse
sub get_extra_zypper($) {
	my $zypper_path = shift @_;

	debug('using zypper');

	my $cmd = "$zypper_path pa";

	# output look like :
	# i | openSUSE-11.4 OSS   | ConsoleKit       | 0.4.3-6.1 | i586
	#   | openSUSE-11.4 OSS   | ConsoleKit-devel | 0.4.3-6.1 | i586

	# get list of all available packages
	debug('get list of packages in repository');
	my %available;
	## no critic (ProhibitTwoArgOpen)
	if ( open my $fh, "$cmd |" ) {
		while ( my $line = <$fh> ) {
			chomp $line;
			next unless ( $line =~ m/\|/ );    # skip first lines
			$line =~ s/\s+//g;                 # remove spaces

			my @tab = split /\|/, $line;
			## no critic(ProhibitMagicNumbers)
			my $pac = $tab[2] . q{-} . $tab[3] . q{.} . $tab[4];
			$available{$pac} = 1;
		}
		close $fh or warning("problem on close $cmd : $ERRNO");
	}
	else {
		warning("can not read $cmd output");
		exit;
	}

	my @installed = get_installed_rpm();

	foreach my $pac (@installed) {
		if ( !exists $available{$pac} ) {
			print "$pac\n";
		}
	}

	return;
}
#########################################################
#
#	main
#
#########################################################
my $version = '0.2';

my $opt_help;
my $opt_man;
my $opt_version;
my $opt_verbose;

my %opt = (
	'help'      => \$opt_help,
	'man'       => \$opt_man,
	'verbose'   => \$opt_verbose,
	'version|V' => \$opt_version,
);

Getopt::Long::Configure('no_ignore_case');
GetOptions( \%opt, 'help|?', 'man', 'verbose', 'version|V', )
  or pod2usage(2);

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

my $yum_util_path = search_in_path('package-cleanup');
my $yum_path      = search_in_path('yum');
my $urpmq_path    = search_in_path('urpmq');
my $zypper_path   = search_in_path('zypper');

## no critic (ProhibitCascadingIfElse)
if ($yum_util_path) {
	get_extra_cleanup($yum_util_path);
}
elsif ($yum_path) {
	get_extra_yum($yum_path);
}
elsif ($urpmq_path) {
	get_extra_urpmq($urpmq_path);
}
elsif ($zypper_path) {
	get_extra_zypper($zypper_path);
}
else {
	warning('unknown package tool');
}
## use critic

exit;
__END__

=head1 NAME

rpmextra - display extra packages  : not from distribution repositories

=head1 DESCRIPTION

rpmextra search for extra packages : 
packages installed on the system that are not available
in any repository listed in the config file

this packages are often installed manually and are not
updated as others packages by distribution tools

=head1 SYNOPSIS

rpmextra [options] 

options:

   -help                brief help message
   -man                 full documentation
   -V, --version        print version
   -verbose             verbose

=head1 REQUIRED ARGUMENTS

none

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

=back

=head1 USAGE

rpmextra

=head1 DIAGNOSTICS

the verbose mode allow to see which
functions are used

=head1 EXIT STATUS

O if all is ok

>=1 if a problem

=head1 CONFIGURATION

nothing

=head1 DEPENDENCIES

rpmextra depends upon rpm package managers.
it can use yum (Redhat), urpmi (Mandriva), zypper (Suse) tools

=head1 INCOMPATIBILITIES

not known

=head1 BUGS AND LIMITATIONS

the program does not work well on program installed
with several versions

=head1 NOTES

this program can be used as "normal" user

=head1 SEE ALSO

=for man
\fIrpm\fR\|(1) for rpm call
.PP
\fIrpmorphan\fR\|(1)
.PP
\fIrpmusage\fR\|(1)
.PP
\fIrpmduplicates\fR\|(1)
.PP
\fIrpmdep\fR\|(1)

=for html
<a href="rpmorphan.1.html">rpmorphan(1)</a><br />
<a href="rpmusage.1.html">rpmusage(1)</a><br />
<a href="rpmduplicates.1.html">rpmduplicates(1)</a><br />
<a href="rpmdep.1.html">rpmdep(1)</a><br />

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 by Eric Gerbier
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=head1 AUTHOR

Eric Gerbier

you can report any bug or suggest to gerbier@users.sourceforge.net

=cut

