#!/usr/bin/perl 
###############################################################################
#   rpmorphan-tk-lib.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmorphan-1.11 | rpmorphan-tk-lib.pl | Wed Jul 6 14:15:24 2011 +0000 | gerbier  $
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
# this file contains all tk code for rpmorphan gui
###############################################################################

use strict;
use warnings;

use English '-no_match_vars';

## no critic(ProhibitPackageVars)
use vars
  qw( $W_list $Opt_dry_run $Inloop @Liste_pac &display_total &insert_gui_orphans );
## use critic

################################################################
# select all
sub tk_select_callback() {

	$W_list->selectionSet( 0, 'end' );
	return;
}
################################################################
# unselect all
sub tk_unselect_callback() {

	$W_list->selectionClear( 0, 'end' );
	return;
}
#########################################################
# change cursor to watch
sub tk_cursor2watch() {

	my $cursor = $W_list->cget('-cursor');
	$W_list->configure( -cursor => 'watch' );
	$W_list->update();

	return $cursor;
}
#########################################################
# restore cursor
sub tk_cursor2normal($) {
	my $cursor = shift @_;    # saved cursor

	# restore pointer
	$W_list->configure( -cursor => $cursor );
	$W_list->update();
	return;
}
#########################################################
# remove selected packages
sub tk_remove_callback($) {
	my $main = shift @_;      # parent widget

	# change pointer
	my $cursor = tk_cursor2watch();

	# get full list
	my @liste = $W_list->get( 0, 'end' );

	# get selected items
	my @sel = $W_list->curselection();

	#transform index into names
	my @selnames = map { $liste[$_] } @sel;

	# confirm dialog
	my $answer = tk_dialog( $main, 'confirm', "confirm remove @selnames ?" );

	if ( $answer =~ m/Yes/ ) {

		remove_packages( \@selnames, \@liste );
	}

	# restore pointer
	tk_cursor2normal($cursor);
	return;
}
#########################################################
# general text display in a new text window
# is used by all help buttons
sub tk_display_message($$@) {
	my $main    = shift @_;    # parent widget
	my $title   = shift @_;    # window title
	my @baratin = @_;          # text to display

	my $top = $main->Toplevel( -title => $title );
	$top->Button( -text => 'quit', -command => [ $top => 'destroy' ] )->pack();
	my $text = $top->Scrolled(
		'ROText',
		-scrollbars => 'e',
		-height     => 25,
		-width      => 128,
		-wrap       => 'word'
	)->pack( -side => 'left', -expand => 1, -fill => 'both' );
	$top->bind( '<Key-q>', [ $top => 'destroy' ] );

	$text->insert( 'end', @baratin );
	$text->see('1.0');
	return;
}

################################################################
# general dialog
sub tk_dialog($$$) {
	my $main    = shift @_;    # parent widget
	my $title   = shift @_;    # window title
	my $baratin = shift @_;    # text to display

	my $dialog = $main->Dialog(
		-text           => $baratin,
		-default_button => 'Yes',
		-buttons        => [qw/Yes No/]
	);
	my $answer = $dialog->Show();

	return $answer;
}
################################################################
# display help text
sub tk_help_callback($) {
	my $main = shift;    # parent widget

	my $baratin = get_help_text();

	tk_display_message( $main, 'help', $baratin );
	return;
}
################################################################
# display log file
sub tk_log_callback($) {
	my $main = shift;    # parent widget

	my @l = get_log();
	my $l = join "\n", @l;

	tk_display_message( $main, 'help', $l );
	return;
}
#########################################################
# return name of current package
sub tk_get_current_elem() {

	# get current position
	my $elem = $W_list->get('active');

	# this code will be used if we display more
	# than name on each line
	#	my $space = q{ };
	#	my @c = split /$space/, $elem;
	#	my $c = $c[0];
	#	return $c;

	return $elem;
}
#########################################################
# display package summary
sub tk_summary_callback($) {
	my $main = shift @_;    # parent widget

	my $c = tk_get_current_elem();
	if ($c) {
		tk_popup( $main, get_package_summary($c) );
	}
	else {
		print "no current element selected\n";
	}

	return;
}
################################################################
# display package info
sub tk_info_callback($) {
	my $main = shift @_;    # parent widget

	# get current position
	my $c = tk_get_current_elem();

	my @res = get_package_info($c);
	chomp @res;
	my $message = join "\n", @res;

	tk_display_message( $main, 'info', $message );
	return;
}
#########################################################
# for reload button
sub tk_load_callback($) {
	my $main = shift @_;    # parent widget

	load_data(1);

	return;
}
#########################################################
# is called when an item is selected/unselected
# and change a counter
sub tk_list_callback {
	my $widget   = shift @_;
	my $selected = shift @_;

	# get selected items
	my @sel = $W_list->curselection();

	my $nb = scalar @sel;

	$selected->delete( '1.0', 'end' );
	$selected->insert( '1.0', $nb );

	return;
}
#########################################################
# common sub for button and key
sub tk_quit($) {
	my $main = shift @_;
	$main->destroy();

	return;
}
#########################################################
sub tk_popup($$) {
	my $main    = shift @_;
	my $message = shift @_;

	my $top = $main->Toplevel();
	$top->title('popup');
	my $d = $top->Message( -text => $message );
	$d->pack();
	$d->focus();
	$top->update();

	# wait 1 second and destroy popup
	## no critic (ProhibitMagicNumbers)
	$main->after(1000);

	$top->destroy();

	return;
}
#########################################################
sub build_tk_gui() {

	my $main      = MainWindow->new( -title => build_title() );
	my $w_balloon = $main->Balloon();
	my $side      = 'top';

	# frame for buttons
	###################
	my $frame1 = $main->Frame();
	$frame1->pack( -side => 'top', -expand => 0, -fill => 'none' );

	# remove
	my $remove_button = $frame1->Button(
		-text    => 'Remove',
		-command => [ \&tk_remove_callback, $main ],
	);
	$remove_button->pack( -side => 'left' );
	$w_balloon->attach( $remove_button, -msg => 'remove selected packages' );
	if ( is_remove_allowed($Opt_dry_run) ) {

		$main->bind( '<Key-r>', [ \&tk_remove_callback, $main ] );
		$main->bind( '<Key-x>', [ \&tk_remove_callback, $main ] );
	}
	else {
		$remove_button->configure( -state => 'disabled' );
	}

	# info
	my $info_button = $frame1->Button(
		-text    => 'Info',
		-command => [ \&tk_info_callback, $main ],
	);
	$info_button->pack( -side => 'left' );
	$w_balloon->attach( $info_button, -msg => 'get info on current package' );
	$main->bind( '<Key-i>', [ \&tk_info_callback, $main ] );

	# select all
	my $select_button = $frame1->Button(
		-text    => 'Select all',
		-command => [ \&tk_select_callback ],
	);
	$select_button->pack( -side => 'left' );
	$w_balloon->attach( $select_button, -msg => 'select all packages' );
	$main->bind( '<Key-s>', [ \&tk_select_callback ] );

	# unselect all
	my $unselect_button = $frame1->Button(
		-text    => 'Unselect all',
		-command => [ \&tk_unselect_callback ],
	);
	$unselect_button->pack( -side => 'left' );
	$w_balloon->attach( $unselect_button, -msg => 'unselect all packages' );
	$main->bind( '<Key-u>', [ \&tk_unselect_callback ] );

	# log
	my $log_button = $frame1->Button(
		-text    => 'Log',
		-command => [ \&tk_log_callback, $main ],
	);
	$log_button->pack( -side => 'left' );
	$w_balloon->attach( $log_button, -msg => 'display log' );
	$main->bind( '<Key-l>', [ \&tk_log_callback, $main ] );

	# reload button
	my $reload_button = $frame1->Button(
		-text    => 'reLoad',
		-command => [ \&tk_load_callback, $main ]
	);
	$reload_button->pack( -side => 'left' );
	$w_balloon->attach( $reload_button, -msg => 'reload rpm database' );
	$main->bind( '<Key-L>', [ \&tk_load_callback, $main ] );

	# help
	my $help_button = $frame1->Button(
		-text    => 'Help',
		-command => [ \&tk_help_callback, $main ],
	);
	$help_button->pack( -side => 'left' );
	$w_balloon->attach( $help_button, -msg => 'help on rpmorphan interface' );
	$main->bind( '<Key-h>', [ \&tk_help_callback, $main ] );

	# quit
	my $exit_button =
	  $frame1->Button( -text => 'Quit', -command => [ \&tk_quit, $main ] );
	$exit_button->pack( -side => 'left' );
	$w_balloon->attach( $exit_button, -msg => 'quit the software' );
	$main->bind( '<Key-q>', [ \&tk_quit, $main ] );

	# frame for the list
	####################
	my $frame2 = $main->Frame();
	$frame2->pack( -side => $side, -expand => 1, -fill => 'both' );

	$W_list = $frame2->Scrolled(
		'Listbox',
		-scrollbars => 'e',
		-selectmode => 'multiple'
	)->pack( -side => $side, -expand => 1, -fill => 'both' );

	$w_balloon->attach( $W_list, -msg => 'list window' );

	# for summary
	$main->bind( '<Key-S>', [ \&tk_summary_callback, $main ] );

	# button 3 : full info
	$main->bind( '<Button-3>', [ \&tk_info_callback, $main ] );

	# frame for status
	###################
	my $frame3 = $main->Frame();
	$frame3->pack( -side => 'bottom', -expand => 0, -fill => 'none' );

	# number of packages
	$frame3->Label( -text => 'total' )->pack( -side => 'left' );
	my $w_total = $frame3->ROText( -width => 4, -height => 1 );
	$w_total->pack( -side => 'left', -expand => 0, );
	$w_balloon->attach( $w_total, -msg => 'number of packages' );

	# number of orphans
	$frame3->Label( -text => 'orphans' )->pack( -side => 'left' );
	my $w_orphans = $frame3->ROText( -width => 4, -height => 1 );
	$w_orphans->pack( -side => 'left', -expand => 0, );
	$w_balloon->attach( $w_orphans, -msg => 'number of orphans packages' );

	# number of selected
	$frame3->Label( -text => 'selected' )->pack( -side => 'left' );
	my $w_selected = $frame3->ROText( -width => 4, -height => 1 );
	$w_selected->pack( -side => 'left', -expand => 0, );
	$w_balloon->attach( $w_selected, -msg => 'number of selected orphans' );

	# to allow to show number of selected
	$W_list->bind( '<<ListboxSelect>>', [ \&tk_list_callback, $w_selected ] );

	# status
	$frame3->Label( -text => 'status' )->pack( -side => 'left' );
	my $w_status = $frame3->ROText( -width => 40, -height => 1 );
	$w_status->pack( -side => 'left', -expand => 1, -fill => 'both' );
	$w_balloon->attach( $w_status,
		-msg => 'display informations on internal state' );

	# for debuging
	$main->bind( '<Key-d>', [ \&dump_struct ] );

	# common gui subroutines with different coding
	##############################################
	# define insert_gui_orphans as a ref to anonymous sub
	*insert_gui_orphans = sub {
		$W_list->delete( 0, 'end' );
		$W_list->insert( 'end', @_ );

		my $nb = scalar @_;
		$w_orphans->delete( '1.0', 'end' );
		$w_orphans->insert( '1.0', $nb );

		# reset
		$w_selected->delete( '1.0', 'end' );
		$w_selected->insert( '1.0', 0 );
	};

	*display_status = sub {
		my $text = shift @_;

		debug($text);

		$w_status->delete( '1.0', 'end' );
		$w_status->insert( '1.0', $text );

		# an update before the mainloop call cause a core dump
		# so we have to test if we are before of after
		$w_status->update() if $Inloop;
	};

	*display_total = sub {

		# display orphans total
		my $nb = scalar @Liste_pac;
		$w_total->delete( '1.0', 'end' );
		$w_total->insert( '1.0', $nb );
	};
	return;
}

#########################################################
1;
