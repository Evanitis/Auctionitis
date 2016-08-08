#!perl -w
#--------------------------------------------------------------------
use strict;

my $word, $a, $b;
my %seen = ();

open my $outfile,  "> c:\\evan\\source\\testdata\\wordcount.log." or die "Cannot open wordcount.log: $!";
open my $outfile2,  "> c:\\evan\\source\\testdata\\wordlist.log." or die "Cannot open wordlist.log: $!";


while (<>) {
    while ( /(\w['\w-]*)/g ) {
        $seen{lc $1}++;
    }
}
foreach $word ( sort { $seen{$b} <=> $seen{$a} } keys %seen) {
    printf $outfile "%5d %s\n", $seen{$word}, $word;
}

# print the sorted list of words in alphabetic order

foreach $word (sort keys %seen) {
    printf $outfile2 "%5d %s\n", $seen{$word}, $word;
}

# print the wordcount hash in descending order



close $outfile;
close $outfile2;
# Success.
print "Success \n";
