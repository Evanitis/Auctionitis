#!/usr/bin/perl -w
use strict;
use Tk;
my $text1;
my $topwindow = MainWindow->new();
$topwindow->Label('-text' => 'Radio and checkbutton widget example')->pack();

$topwindow->Radiobutton(-text => "Radio 1",
                        -command => sub {
        $text1->delete('1.0', 'end');
        $text1->insert('end', "You clicked Radio 1");})->pack();
$topwindow->Radiobutton(-text => "Radio 2",
                        -value => "0",
                        -command => sub {
        $text1->delete('1.0', 'end');
        $text1->insert('end', "You clicked Radio 2");})->pack();
$topwindow->Checkbutton(-text => "Check 1",
                        -command => sub {
        $text1->delete('1.0', 'end');
        $text1->insert('end', "You clicked Check 1");})->pack();
$topwindow->Checkbutton(-text => "Check 2",
                        -command => sub {
        $text1->delete('1.0', 'end');
        $text1->insert('end', "You clicked Check 2");})->pack();
$text1 = $topwindow->Text('-width' => 40,
                             '-height' => 2)->pack();
MainLoop;
        