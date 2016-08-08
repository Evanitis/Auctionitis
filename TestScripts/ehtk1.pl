#!/usr/bin/perl -w

use strict;
use Tk;

# Create main window
my $main = MainWindow->new();

# Add a Label and a Button to main window
$main->Label(-text => 'Button and text widget example')->pack();
$main->Button(-text => "Click me",
	      -command => \&display)->pack(-side => "left");
my $text1 = $main->Text('-width' => 40, '-height' => 2)->pack();
$text1->bind('<Double-1>', \&display);
sub display
{
    $text1->insert('end', "Hello");
}
# Spin the message loop
MainLoop;
