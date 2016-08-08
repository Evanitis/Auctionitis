#------------------------------------------------------------------------------------------------------------
# Test methods to download CSV files from TradeMe
#------------------------------------------------------------------------------------------------------------
#!perl -w

use strict;
use Auctionitis;

my $tm;

$tm = Auctionitis->new();
$tm->initialise( Product => "Auctionitis" );  # Initialise the product
$tm->login();
$tm->get_TM_sold_csv_file( Filename => "C:\\evan\\auctionitis103\\data\\soldcsv.csv" );
$tm->get_TM_unsold_csv_file( Filename => "C:\\evan\\auctionitis103\\data\\unsoldcsv.csv" );
$tm->get_TM_current_csv_file( Filename => "C:\\evan\\auctionitis103\\data\\Xcurrent.csv" );
$tm->get_TM_statement_csv_file( Filename => "C:\\evan\\auctionitis103\\data\\statement.csv" );
