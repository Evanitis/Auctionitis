#!/perl/bin/perl -T
#
# Name:
#	onfocus.pl.
#
# Purpose:
#	Demonstrates various JavaScript event handlers, and also how they can be
#	combined with a style sheet to achieve certain effects.
#
# Author:
#	Ron Savage <ron@savage.net.au>
#
# Home:
#	http://savage.net.au/Perl-tutorials.html (tutorial # 39)
#
# Version:
#	1.00	5-May-2001
#	------------------
#	o Initial version
#
# Prerequisites:
#	CGI
#
# Licence:
#	Copyright (c) 2001 Ron Savage.
#	All Programs in this package are free software; you can redistribute
#	them and/or modify them under the same terms as Perl itself.
#	Perl's Artistic License is available at:
#	See licence.txt.
#
# Note:
#	o This script offers 3 submit buttons, each of which is programmed with
#		a different bit of JavaScript.
#	o When the mouse is moved over these buttons, the text on them changes color.
#		This effect is achieved using JavaScript event handlers and a style sheet.
#	o When any button is clicked, it submits the form and reruns this script,
#		which just updates the display of 2 hidden variables.
#		This effect is achieved using JavaScript event handlers.
#	o In some places I use the prefix 'javascript:', and in other places not.
#		It is always optional, AFAIK.

use integer;
use strict;
use warnings;

use CGI;

# -----------------------------------------------------------------------------

my($bg_color)	= '#80c0ff';
my($blue)		= '#0000ff';
my($form_name)	= 'formalware';
my($green)		= '#00ff00';
my($red)		= '#ff0000';
my($text_color)	= '#000080'; # Ie navy.

# -----------------------------------------------------------------------------

# This style sheet uses a global variable to set one attribute,
# but obviously, the sub css could take parameters so that
# different pages would have different appearences while all being
# based on the same style sheet.
# Also, this style sheet is quite limited, since only items of class
# 'submit' (see '.submit') are under its control.

sub css
{
	my($css) = <<CSS;
<style type = 'text/css'>
<!--
.submit
{
background:$bg_color;
border-top-width:1px;
border-bottom-width:1px;
border-left-width:1px;
border-right-width:1px;
color:$text_color;
font-family:Verdana, Helvetica, Arial, sans-serif;
font-size:8pt;
font-weight:bold;
width:auto;
}
// -->
</style>
CSS

	$css;

}	# End of css.

# -----------------------------------------------------------------------------

$ENV{'PATH'}	= '';
my($script)		= $0;
$script			=~ s/.+[\/\\]//;
my($q)			= CGI -> new();
my($url)		= $q -> url();

# $a and $b are the values displayed on the screen.
# $a_count and $b_count are the values used to set
# $a and $b when a button is clicked.
# All 4 are passed to each invocation of the script.
# $a_count and $b_count are incremented on each invocation,
# but $a and $b will lag behind by different amounts,
# depending on which combinations of buttons has been clicked.

my($a)			= $q -> param('a')			|| 0;
my($b)			= $q -> param('b')			|| 0;
my($a_count)	= $q -> param('a_count')	|| 0;
my($b_count)	= $q -> param('b_count')	|| 0;

$a_count++;
$b_count++;

my(@row);

# The onFocus event handler is used to:
#	- Set the form's action, although in this script nothing special
#		is done with this capability. It does mean, hoever, that you
#		can use this to run any script, not just the current one
#	- Set the values of one or more form elements.
# Together these show an event handler is not limited to a single statment.
# In complex cases, you'll need to use qq here, since the JavaScript code
# will contain both single and double quotes.
# Also, look closely at the first 2 onFocus handlers: They use different
# methods to transfer the value from $a_count to $a.
# The onMouseOver and onMouseOut event handlers interact with the
#	style sheet, to give visual feedback of the mouse's position.
# If instead of submit buttons, there were image buttons on screen, the same
# idea can be used to change the images' 'src' attributes, and hence toggle
# between 2 images, e.g. the way IE does with colorless and colored buttons.

push(@row,
	$q -> td({align => 'center'}, "a = '$a'"),
	$q -> td({align => 'center'}, "b = '$b'"),
	$q -> td
	(
		{align => 'center'},
		$q -> submit
		({
			name		=> 'Set a',
			value		=> "Set a to $a_count",
			class		=> 'submit',
			onFocus		=> "javascript:document.$form_name.action = '$url'; document.$form_name.a.value = '$a_count'",
			onMouseOver	=> "this.style.color = '$red'",
			onMouseOut	=> "this.style.color = '$text_color'"
		})
	),
	$q -> td
	(
		{align => 'center'},
		$q -> submit
		({
			name		=> 'Set a and b',
			value		=> "Set a to $a_count and b to $b_count",
			class		=> 'submit',
			onFocus		=> "javascript:document.$form_name.action = '$url'; document.$form_name.a.value = document.$form_name.a_count.value; document.$form_name.b.value = '$b_count'",
			onMouseOver	=> "this.style.color = '$green'",
			onMouseOut	=> "this.style.color = '$text_color'"
		})
	),
	$q -> td
	(
		{align => 'center'},
		$q -> submit
		({
			name		=> 'Set b',
			value		=> "Set b to $b_count",
			class		=> 'submit',
			onFocus		=> "javascript:document.$form_name.action = '$url'; document.$form_name.b.value = '$b_count'",
			onMouseOver	=> "this.style.color = '$blue'",
			onMouseOut	=> "this.style.color = '$text_color'"
		})
	),
	$q -> td
	(
		{align => 'center'},
		$q -> submit
		({
			name	=> 'Reset',
			value	=> 'Reset',
			class	=> 'submit',
			onFocus	=> "javascript:document.$form_name.action = '$url'; document.$form_name.a.value = '0'; document.$form_name.b.value = '0'"
		})
	),
	);

# The 'force' option must be used in the call to 'hidden', to override the
# form's default 'sticky' behaviour, since the values of $a_count and
# $b_count have changed since the script began running. Without the
# 'force', the form would retain the original values of these variables.
# Try removing the 'force' option on one of the calls, to see what happens.
# For $a and $b we want the opposite behaviour, in that the values are to
# stay fixed until some event handler does its work.

print	$q -> header(),
		$q -> start_html(),
		css(),
		$q -> center($q -> h1("$script: JavaScript demo") ),
		$q -> start_form({action => $q -> url(), name => $form_name}),
		$q -> hidden({name => 'a', value => $a}),
		$q -> hidden({name => 'b', value => $b}),
		$q -> hidden({name => 'a_count', value => $a_count, force => 1}),
		$q -> hidden({name => 'b_count', value => $b_count, force => 1}),
		$q -> table
		(
			{align => 'center', bgColor => $bg_color},
			$q -> Tr([@row])
		),
		$q -> end_form(),
		$q -> end_html();
