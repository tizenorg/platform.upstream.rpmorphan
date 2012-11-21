#!/usr/bin/perl 
###############################################################################
#   rpmorphan-curses-lib.pl
#
#    Copyright (C) 2006 by Eric Gerbier
#    Bug reports to: gerbier@users.sourceforge.net
#    $Id: rpmorphan-1.11 | rpmorphan-curses-lib.pl | Wed Jul 6 13:59:20 2011 +0000 | gerbier  $
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
# curses gui code
###############################################################################
use strict;
use warnings;

use English '-no_match_vars';

## no critic(ProhibitPackageVars)
use vars
  qw( $W_list $Opt_dry_run @Liste_pac $Main_ui &display_total &insert_gui_orphans );
## use critic

#use Curses;    # for KEY_ENTER
## no critic(RequireCheckingReturnValueOfEval)
eval { require Curses; };
if ($EVAL_ERROR) {
	die "can not find Curses package : $EVAL_ERROR\n";
}
else {
	import Curses;
}
## use critic

#### global variable
my $flag_info = 0;    # flag for info window (avoid several calls)

#########################################################
# select all
sub curses_select_callback($) {
	my $widget = shift;

	my $container = $widget->parent();
	my $listbox   = $container->getobj('list_id');

	my $pac_list = $W_list->values();
	my @pac2     = @{$pac_list};
	my @sel      = ( 0 .. $#pac2 );
	$listbox->set_selection(@sel);

	# update
	$listbox->draw();
	return;
}
#########################################################
# unselect all
sub curses_unselect_callback($) {
	my $widget = shift;

	my $container = $widget->parent();
	my $listbox   = $container->getobj('list_id');

	$listbox->clear_selection();

	# update
	$listbox->draw();
	return;
}
#########################################################
# remove selected items
sub curses_remove_callback($) {
	my $widget = shift;

	my $container = $widget->parent();
	my $listbox   = $container->getobj('list_id');
	my @sel       = $listbox->get();                 # selected items

	my $old_pac_list = $W_list->values();

	# a confirm dialog box
	my $yes = $Main_ui->dialog(
		-message => "confirm remove @sel ?",
		-buttons => [ 'yes', 'no' ],
		-values  => [ 1, 0 ],
		-title   => 'Confirm',
	);

	if ($yes) {
		remove_packages( \@sel, $old_pac_list );
	}

	# update
	$listbox->draw();

	return;
}
#########################################################
# display help window
sub curses_help_callback($;) {
	my $this = shift @_;

	my $text = get_help_text();
	$this->root()->dialog(
		-message => $text,
		-buttons => ['ok'],
		-title   => 'help',
	);
	return;
}
#########################################################
sub curses_log_callback($;) {
	my $this = shift @_;

	my @l = get_log();

	@l = ('empty') if ( !@l );
	my $l = join "\n", @l;

	$this->root()->dialog(
		-message => $l,
		-buttons => ['ok'],
		-title   => 'log',
	);
	return;
}
#########################################################
# display rpm summary on the current item
sub curses_summary_callback($) {
	my $widget = shift;

	my $listbox = $widget->parent()->getobj('list_id');
	my $current = $listbox->get_active_value();

	curses_popup( get_package_summary($current) );
	return;
}
#########################################################
# display rpm info on the current item
sub curses_info_callback($) {
	my $widget = shift;

	# a flag to avoid a fatal error
	# only allow one call
	if ($flag_info) {
		return;
	}
	else {
		$flag_info++;
	}

	my $listbox = $widget->parent()->getobj('list_id');
	my $current = $listbox->get_active_value();

	my $txt;
	if ( defined $current ) {
		my @res = get_package_info($current);
		$txt = join "\n", @res;
	}
	else {
		$txt = 'you should select a package';
	}

	# old version
	# but the scrollbar does not work (not focusable)
	#	my $dialog = $listbox->root()->dialog(
	#		-message    => $txt,
	#		-buttons    => ['ok'],
	#		-title      => 'info',
	#		-vscrollbar => 'left',
	#	);

	# new version with TextViewer
	my $win = $listbox->parent();
	my $textviewer =
	  $win->add( 'mytextviewer_id', 'TextViewer', -text => $txt, );

	# any key will quit
	$win->set_binding( \&curses_exit_text_callback, KEY_ENTER() );
	$textviewer->focus();
	return;
}
#########################################################
# called from reload button
sub curses_load_callback($) {
	my $widget = shift;

	load_data(1);
	return;
}
#########################################################
sub curses_exit_text_callback() {

	$flag_info--;
	my $win = $Main_ui->getobj('win1_id');
	$win->delete('mytextviewer_id');
	$win->draw();
	return;
}
#########################################################
#sub curses_redraw_all() {
#
#	#while (my ($id, $object) = each %{$Main_ui->{-id2object}}) {
#		#curses_popup($id);
#		#$object->draw();
#	#}
#	my $win = $Main_ui->getobj('win1_id');
#	$Main_ui->draw();
#	$win->draw();
#	foreach my $id ('buttons_id', 'list_id', 'total_id', 'total_var_id','selected_id') {
#		my $obj = $win->getobj($id);
#		if ($obj ) {
#			curses_popup("draw $id");
#			$obj->draw();
#		}
#	}
#
#	return;
#}
#########################################################
# is called when an item is selected/unselected
# and change a counter
sub curses_list_callback() {
	my $widget  = shift;
	my $listbox = $widget->parent()->getobj('list_id');
	my @sel     = $listbox->get();                        # selected items

	my $nb       = scalar @sel;
	my $selected = $widget->parent()->getobj('selected_val_id');
	$selected->text($nb);
	$selected->draw();

	return;
}
#########################################################
# quit gui
sub curses_quit_callback($;) {
	my $this = shift @_;
	exit;
}
#########################################################
# display messages as a quick popup
# to be used as debuging tool for example
sub curses_popup($) {
	my $message = shift @_;

	$Main_ui->status($message);
	sleep 1;
	$Main_ui->nostatus();

	return;
}

#########################################################
sub build_curses_gui() {

	# Create the root object.
	$Main_ui = Curses::UI->new(
		-clear_on_exit => 0,
		-debug         => 0,
	);

	# add a window
	my $win1 = $Main_ui->add(
		'win1_id',
		'Window',
		-title          => build_title(),
		-titlefullwidth => 1,
		-border         => 1,
	);
	my $height = $win1->height();

	# debug
	#print "windows height : $height, width : " . $win1->width() . "\n";

	## no critic (ProhibitMagicNumbers)
	my $margin =
	  5;    # 1 for top menu, 2 for status/selected and 2 for     borders
	## use critic
	my $min_height = 2 * $margin;
	if ( $height < $min_height ) {
		die "the window is too small ($height)\n";
	}

	my @buttons;
	if ( is_remove_allowed($Opt_dry_run) ) {

		# I do not know how to disable the button,
		# so I only add it in this mode
		push @buttons,
		  (
			{
				-label   => 'Remove ',
				-onpress => \&curses_remove_callback,
			},
		  );

		# Bind <x> and <r> for remove
		$Main_ui->set_binding( sub { curses_remove_callback($W_list) }, 'x' );
		$Main_ui->set_binding( sub { curses_remove_callback($W_list) }, 'r' );

	}
	push @buttons,
	  (
		{
			-label   => 'Info ',
			-onpress => \&curses_info_callback,
		},
		{
			-label   => 'Select_all ',
			-onpress => \&curses_select_callback,
		},
		{
			-label   => 'Unselect_all ',
			-onpress => \&curses_unselect_callback,
		},
		{
			-label   => 'Log ',
			-onpress => \&curses_log_callback,
		},
		{
			-label   => 'reLoad ',
			-onpress => \&curses_load_callback,
		},
		{
			-label   => 'Help ',
			-onpress => \&curses_help_callback,
		},
		{
			-label   => 'Quit',
			-onpress => \&curses_quit_callback,
		},
	  );

	$win1->add(
		'buttons_id',
		'Buttonbox',
		-y       => 0,
		-buttons => \@buttons,
	);

	# listbox
	my $list_height = $height - $margin;
	$W_list = $win1->add(
		'list_id', 'Listbox',
		-y           => 1,
		-width       => 60,
		-height      => $list_height,
		-border      => 1,
		-vscrollbar  => 1,
		-multi       => 1,
		-onselchange => \&curses_list_callback,
	);

	my $empty = q{};

	# total
	$win1->add(
		'total_id',
		'Label',
		-text => 'total',
		-x    => 1,
		-y    => $list_height + 1,
	);
	my $w_total = $win1->add(
		'total_val_id',
		'TextViewer',
		-text   => $empty,
		-height => 1,
		-width  => 5,
		-x      => 7,
		-y      => $list_height + 1,
	);

	# orphans
	$win1->add(
		'orphans_id',
		'Label',
		-text => 'orphans',
		-x    => 12,
		-y    => $list_height + 1,
	);
	my $w_orphans = $win1->add(
		'orphans_val_id',
		'TextViewer',
		-text   => $empty,
		-height => 1,
		-width  => 5,
		-x      => 20,
		-y      => $list_height + 1,
	);

	# selected
	$win1->add(
		'selected_id',
		'Label',
		-text => 'selected',
		-x    => 25,
		-y    => $list_height + 1,
	);
	my $w_selected = $win1->add(
		'selected_val_id',
		'TextViewer',
		-text   => $empty,
		-height => 1,
		-width  => 4,
		-x      => 35,
		-y      => $list_height + 1,
	);

	# status
	$win1->add(
		'status_id',
		'Label',
		-text => 'status:',
		-x    => 1,
		-y    => $list_height + 2,
	);
	my $w_status = $win1->add(
		'status_val_id',
		'TextViewer',
		-text   => $empty,
		-height => 1,
		-width  => 50,
		-x      => 9,
		-y      => $list_height + 2,
	);

	# begin on list
	$W_list->focus();

	# Bind <i> for info
	$Main_ui->set_binding( sub { curses_info_callback($W_list) }, 'i' );

	# S for summary
	$Main_ui->set_binding( sub { curses_summary_callback($W_list) }, 'S' );

	# Bind <s> for select
	$Main_ui->set_binding( sub { curses_select_callback($W_list) }, 's' );

	# Bind <u> for unselect
	$Main_ui->set_binding( sub { curses_unselect_callback($W_list) }, 'u' );

	# Bind <l> for log
	$Main_ui->set_binding( sub { curses_log_callback($W_list) }, 'l' );

	# Bind <h> for help
	$Main_ui->set_binding( sub { curses_help_callback($W_list) }, 'h' );

	# Bind <L> for reload
	$Main_ui->set_binding( sub { curses_load_callback($W_list) }, 'L' );

	# Bind <q> to quit.
	$Main_ui->set_binding( sub { exit }, 'q' );

	# for debuging
	#$Main_ui->set_binding( sub { dump_struct() }, 'd' );

	# common gui subroutines with different coding
	##############################################
	*insert_gui_orphans = sub {
		$W_list->values(@_);
		$W_list->draw();

		# display orphans total
		my $nb = scalar @_;
		$w_orphans->text($nb);
		$w_orphans->draw();

		# reset selected
		$w_selected->text(0);
		$w_selected->draw();
	};

	*display_status = sub {
		my $text = shift @_;
		debug($text);

		$w_status->text($text);
		$w_status->draw();
	};

	*display_total = sub {

		# display orphans total
		my $nb = scalar @Liste_pac;
		$w_total->text($nb);
		$w_total->draw();
	};

	return;
}
#########################################################
1;
