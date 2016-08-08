#!perl -w
#--------------------------------------------------------------------
# gettmdata.pl retrieve data from trademe for analysis and automation
# to run the script: perl.exe c:\evan\trademe\gettmdata.pl 
#
# Other program notes:
#--------------------------------------------------------------------

use strict;

my $data;

my $input = "C:\\Evan\\AuctionitisBase\\TradeMe pages\\My TradeMe lists\\UnSold Listings.txt";

# $data = parse($input);

foreach my $auction ( @$data ) {

#    print "Auction: $auction->{AuctionRef} Closes: $auction->{CloseDate} at $auction->{CloseTime}\n";

}

$input = "C:\\Evan\\AuctionitisBase\\TradeMe pages\\My TradeMe lists\\Sold Listings.txt";

$data = parse($input);

foreach my $auction ( @$data ) {

    print "Auction: $auction->{AuctionRef} Closes: $auction->{CloseDate} at $auction->{CloseTime}\n";

}

$input = "C:\\Evan\\AuctionitisBase\\TradeMe pages\\My TradeMe lists\\Current Listings.txt";

# $data = parse($input);

my $count = scalar(@$data);

print "Count $count\n";

foreach my $auction ( @$data ) {

#    print "Auction: $auction->{AuctionRef} Closes: $auction->{CloseDate} at $auction->{CloseTime}\n";

}

# Success.

print "Done\n";


#---------------------------------------------------------------------------------------------------

sub parse {

    my $infile = shift;
    my @auctions;

    print "processing file: $infile\n\n";

    local $/;                                                       #slurp mode (undef)
    local *F;                                                       #create local filehandle
    open(F, "< $infile") || die "Cant find file $input";
    my $content = <F>;                                              #read whole file
    close(F);                                                       # ignore retval


    print "Evaluating data with expression #1\n\n";                 # Sold and #unsold listings

    while ( $content =~ m/(Closed: )(.+?)(<\/small>)(.+?)(<small>\(#)(.+?)(\)<\/small>)/gm) {
            my $auction  = $6;                                      # Auction ref
            my $cldate = calc_close_date($2,"PAST");
            my $cltime = calc_close_time($2);
            
            # put anonymous auction details hash in return array
            
            push ( @auctions, { AuctionRef => $auction, CloseDate => $cldate, CloseTime => $cltime } );         

#            print "Auction: $auction Closes: $cldate at $cltime\n";
    }


    print "Evaluating data with expression #2\n\n";                 # Current listings

    while ( $content =~ m/(Closes: )(.+?)(<\/small>)(.+?)(<small>\(#)(.+?)(\)<\/small>)/gm) {
            my $auction  = $6;                                      # Auction ref
            my $cldate = calc_close_date($2,"FUTURE");
            my $cltime = calc_close_time($2);

            # put anonymous auction details hash in return array
            
            push ( @auctions, { AuctionRef => $auction, CloseDate => $cldate, CloseTime => $cltime } );         

#            print "Auction: $auction Closes: $cldate at $cltime\n";


    }

    return \@auctions;

}

sub calc_close_time {

    my $expr = shift;
    my $hh;
    
    $expr =~ m/(&nbsp;&nbsp;)(.+?)(:)(.+?)(&nbsp;)(am|pm)/;
    
    ($6 eq "pm") ? ($hh = $2) : ($hh = $2 + 12);

    my $mm = $4;
    my $closed = $hh.":".$mm;

    return $closed
    
}

sub calc_close_date {

    my $dateexpr    = shift;
    my $listtype    = shift;
    
    $dateexpr =~ m/(&nbsp;)(.+?)(&nbsp;)(.+?)(&nbsp;)(.+?)(&nbsp;&nbsp;)/;

    my $curmth = (localtime)[4]+1;
    my $curyr  = (localtime)[5]+1900;

    my ($dd,$mm,$yy);

    $dd = $4;

    print "CM $curmth CY $curyr DD $dd";

    if      ( $6 eq 'Jan' ) { $mm =  1; }
    elsif   ( $6 eq 'Feb' ) { $mm =  2; }
    elsif   ( $6 eq 'Mar' ) { $mm =  3; }
    elsif   ( $6 eq 'Apr' ) { $mm =  4; }
    elsif   ( $6 eq 'May' ) { $mm =  5; }
    elsif   ( $6 eq 'Jun' ) { $mm =  6; }
    elsif   ( $6 eq 'Jul' ) { $mm =  7; }
    elsif   ( $6 eq 'Aug' ) { $mm =  8; }
    elsif   ( $6 eq 'Sep' ) { $mm =  9; }
    elsif   ( $6 eq 'Oct' ) { $mm = 10; }
    elsif   ( $6 eq 'Nov' ) { $mm = 11; }
    elsif   ( $6 eq 'Dec' ) { $mm = 12; }

    print " MM $mm";

    if ( $listtype eq "FUTURE" ) {

        if      ( $mm lt $curmth ) { $yy =  $curyr + 1;  }
        elsif   ( $mm eq $curmth ) { $yy =  $curyr;      }
        elsif   ( $mm gt $curmth ) { $yy =  $curyr;      }
    }

    if ( $listtype eq "PAST" ) {
    
        if      ( $mm <  $curmth ) { $yy =  $curyr;     print " <LT> "; }
        elsif   ( $mm == $curmth ) { $yy =  $curyr;     print " <EQ> ";  }
        elsif   ( $mm >  $curmth ) { $yy =  $curyr - 1;     print " <GT> "; }
    }

    print " MM $mm";

    print " YY $yy ";
    
    my $closet = $dd."-".$mm."-".$yy;

    print "Closed: $closet\n";
    return $closet
    
}

