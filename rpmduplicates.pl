#!/usr/bin/perl
###############################################################################
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmorphan-1.11 | rpmduplicates.pl | Mon Jul 4 12:47:55 2011 +0000 | gerbier  $
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
# search for packages with several versions installed
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

# not very usefull, but warning, debug ...
require $dirname . '/rpmorphan-lib.pl'
  or die "problem to load rpmorphan-lib: $ERRNO\n";

my $VERSION = '0.2';

my $opt_help;
my $opt_man;
my $opt_version;
my $opt_verbose;

my %opt = (
	'help'    => \$opt_help,
	'man'     => \$opt_man,
	'verbose' => \$opt_verbose,
	'version' => \$opt_version,
);

Getopt::Long::Configure('no_ignore_case');
GetOptions( \%opt, 'help|?', 'man', 'verbose', 'version|V' )
  or pod2usage(2);

init_debug($opt_verbose);

if ($opt_help) {
	pod2usage(1);
}
elsif ($opt_man) {
	pod2usage( -verbose => 2 );
}
elsif ($opt_version) {
	print_version($VERSION);
	exit;
}

#  we cannot use common cache as duplicate package are not clean taken
#  by the common code
## no critic (RequireInterpolationOfMetachars)
my $cmd =
  'rpm -qa --queryformat "%{NAME} %{VERSION}-%{RELEASE} %{BUILDTIME}\n" ';
## use critic

my $fh;
## no critic (ProhibitTwoArgOpen,RequireBriefOpen)
if ( !open $fh, "$cmd |" ) {
	die "can not open $cmd : $ERRNO\n";
}
## use critic

my %h_ver;          # versions
my %h_buildtime;    # buildtime

my $nb    = 0;
my $SPACE = q{ };

while ( my $line = <$fh> ) {
	chomp $line;
	my ( $soft, $version, $build ) = split $SPACE, $line;

	next if ( $soft eq 'gpg-pubkey' );

	if ( exists $h_ver{$soft} ) {

		# we already have found a package with same name
		my $old_ver  = $h_ver{$soft};
		my $old_date = $h_buildtime{$soft};

		my $old;
		if ( $old_date < $build ) {

			# current package was build after the stored one
			# keep the latest
			$h_buildtime{$soft} = $build;

			# delete the older
			$old = $old_ver;
		}
		else {

			# current package was build before the stored one
			# delete the older
			$old = $version;
		}
		$old_date = localtime $old_date;
		$build    = localtime $build;
		print "duplicate $soft : $old_ver ($old_date) / $version ($build)\n";
		print "suggest : rpm -e $soft-$old\n";
		$nb++;
	}
	else {
		$h_ver{$soft}       = $version;
		$h_buildtime{$soft} = $build;
	}
}
close $fh or warning("can not close $cmd : $ERRNO");

if ( $nb == 0 ) {
	print "no duplicate found !\n";
}

exit $nb;
__END__

=head1 NAME

rpmduplicates - find program with several version installed

=head1 DESCRIPTION

sometimes, the upgrade of a system will install new packages, and "forget" to remove
the older version. Rpmorphan do not work with this kind of unused packages. Rpmduplicates 
is the answer. I recommend to run it after each distribution upgrade 
(for example from fedora core 7 to 8).

=head1 SYNOPSIS

rpmduplicates.pl  [options]

options:

   -help                brief help message
   -man                 full documentation
   -V, --version        print version

   -verbose             verbose

=head1 REQUIRED ARGUMENTS

nothing

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Print the full manual page and exits.

=item B<-version>

Print the program release and exit.

=item B<-verbose>

The program works and print debugging messages.

=back

=head1 USAGE

rpmduplicates.pl 

=head1 FILES

nothing

=head1 DIAGNOSTICS

it will show the duplicates with their version and build date

and suggest to remove the older one

example :

duplicate kernel-devel : 2.6.24.4-64.fc8 (Sat Mar 29 15:36:41 2008) / 2.6.24.3-50.fc8 (Thu Mar 20 20:43:47 2008)

suggest : rpm -e kernel-devel-2.6.24.3-50.fc8

=head1 EXIT STATUS

the number of duplicates packages found

=head1 CONFIGURATION

nothing

=head1 DEPENDENCIES

rpmorphan library

=head1 INCOMPATIBILITIES

not known

=head1 BUGS AND LIMITATIONS

not known

=head1 NOTES

this program can be used as "normal" user

the gpg-pubkey packages are excluded from the result

=head1 SEE ALSO

=for man
\fIrpm\fR\|(1) for rpm call
.PP
\fIrpmorphan\fR\|(1)
.PP
\fIrpmusage\fR\|(1)
.PP
\fIrpmdep\fR\|(1)
.PP
\fIrpmextra\fR\|(1)

=for html
<a href="rpmorphan.1.html">rpmorphan(1)</a><br />
<a href="rpmusage.1.html">rpmusage(1)</a><br />
<a href="rpmdep.1.html">rpmdep(1)</a><br />
<a href="rpmextra.1.html">rpmextra(1)</a><br />

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

