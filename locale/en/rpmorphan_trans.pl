#!/usr/bin/perl 
###############################################################################
#   rpmorphan-curses-lib.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmorphan-curses-lib.pl 170 2010-01-14 12:13:48Z gerbier $
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

use vars qw( %TRANS );

$TRANS{'help'} = <<'EOF';
rpmorphan will help you to clean unused package
it will show you orphaned packages (without any rpm dependencies to them)

buttons are :
-------------
remove : remove selected package(s) 
info 	: show informations about current package
select all : select all packages (dangerous)
unselect all : unselect all packages
log    : display list of suppressed packages
help   : this help screen
quit   : exit rpmorphan

mouse use :
-----------
- left click to select/unselect a package
- right click to display rpm informations

hotkeys :
---------
x/r : remove package
i : show package information
S : show package summary in a popup
s : select all
u : unselect all
l : display log
h : help
q : quit

status window
-------------
total : total number of packages (filtered by guess filter and exclude list)
orphans : number of packages resolved as orphans
selected : number of selected orphans

notes
-----
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

website
-------
http://rpmorphan.sourceforge.net
EOF

###############################################################################
1;
