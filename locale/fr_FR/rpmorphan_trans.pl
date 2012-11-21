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
rpmorphan vous aide a supprimer les packages inutiles :
il affiche les packages orphelins (ceux dont aucun autre package ne dépends)

les bouttons disponibles sont :
-------------------------------
remove : pour lancer la suppression du/des packages selectionnes 
info   : affiche les informations sur le package courant
select all : selectionne tous les packages (dangereux)
unselect all : deselectionne tous les packages
log    : affiche la log (liste des packages supprimes)
help   : affiche cette aide
quit   : fin du programme

utilisation de la souris :
--------------------------
- click gauche pour selectionner/deselectionner un package
- click droit pour afficher les informations sur le package (info)

raccourcis clavier :
--------------------
x/r 	: supprime le package
i 	: affiche les infos du package
S 	: affiche le sommaire du package dans un popup
s 	: selectionne tous les packages 
u 	: deselectionne tous les packages
l 	: affiche la log 
h 	: aide
q 	: quit

informations de bas de page
---------------------------
total 	: nombre de packages pris en compte 
( filtrage par les options guess et les listes d'exclusions)
orphans : nombre de packages "orphelins"
selected : nombre de packages selectionnes

notes
-----
Ce programme est libre, vous pouvez le redistribuer et/ou le modifier selon les 
termes de la Licence Publique Générale GNU publiée par la Free Software Foundation 
(version 2 ou bien toute autre version ultérieure choisie par vous).

Ce programme est distribué car potentiellement utile, mais SANS AUCUNE GARANTIE, 
ni explicite ni implicite, y compris les garanties de commercialisation ou d'adaptation 
dans un but spécifique. Reportez-vous à la Licence Publique Générale GNU pour plus de détails.

website
-------
http://rpmorphan.sourceforge.net
EOF

###############################################################################
1;
