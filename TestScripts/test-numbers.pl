#!perl -w

use strict;

my $a = 1;
my $b = "TWO";

print_result( $a, $b );

$a = 100;
$b = 20;

print_result( $a, $b );

$a = "One";
$b = 2;

print_result( $a, $b );

sub print_result {

    my $a = shift;
    my $b = shift;

    print "\nis $a less than $b ?\n";

    if ( $a lt $b ) {
        print "using LT operator results in less than result\n";
    }
    else {
        print "using LT operator results in greater than result\n";
    }
    
    if ( $a < $b ) {
        print "using < operator results in less than result\n";
    }
    else {
        print "using < operator results in greater than result\n";
    }
}


print "Done\n";
exit(0);
