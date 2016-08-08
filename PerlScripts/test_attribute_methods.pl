#!perl -w
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm;

$tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect(); 

my $dbh=DBI->connect('dbi:ODBC:Auctionitis', {AutoCommit => 1} ) 
     || die "Error opening Auctions database: $DBI::errstr\n";


my $cat = 762;
my $field = "89";
my $value = "8901";

test_input( $cat, $field, $value );

$cat = 762;
$field = "222";
$value = "9604";

test_input( $cat, $field, $value );

$cat = 023;

test_input( $cat, $field, $value );

$cat = 4715;

test_input( $cat, $field, $value );

$cat = 3408;
$field = "Pentax";

test_input( $cat, $field, $value );


$cat = 3408;
$field = "116";
$value = "Pentax";

test_input( $cat, $field, $value );


$cat = 3408;
$field = "116";
$value = "Pentax";

test_input( $cat, $field, $value );


$cat = 762;
$field = "96";
my $value = "Sandshoes";

test_input( $cat, $field, $value );

# Success.

print "Done\n";
exit(0);

sub test_input {

    my $c = shift;
    my $f = shift;
    my $v = shift;

    if ( attribute_has_combo( $c ) ) {

        print "Category ".$c." has an associated combo box\n";
        if ( is_valid_attribute_value ( $c, $f, $v ) ) {
            print "Attribute Field [ ".$f." ] and Attribute Value [ ".$v. " ] are valid for supplied Category [ ".$c." ].\n";
        }
        else {
            print "Attribute Field [ ".$f." ] or Attribute Value [ ".$v. " ] not valid for supplied Category [ ".$c." ].\n";
        }
    }
    else {

        print "Category ".$cat." does not have an associated combo box\n";
    }

    if ( get_attribute_procedure( $c )  ) {

        print "Category ".$c." has an associated procedure [ ".get_attribute_procedure ( $c )." ]\n";
    }
    else {
        print "Category ".$cat." does not have an associated procedure\n";
    }


}

sub attribute_has_combo {

    my $cat     =   shift;
    my $SQL     =   qq {    SELECT      COUNT(*)
                            FROM        Attributes
                            WHERE       AttributeCategory   = ?        
                            AND         AttributeCombo      = 1 } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $cat ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $combo = $sth->fetchrow_array;

    $sth->finish;

    return $combo;
    
}

sub get_attribute_procedure {

    my $cat     =   shift;
    my $text    =   shift;
    my $SQL     =   qq {    SELECT      AttributeProcedure
                            FROM        Attributes
                            WHERE       AttributeCategory   = ? } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $cat ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $proc = $sth->fetchrow_array;

    $sth->finish;

    return $proc;
    
}

#
# This method validates that the AttributeField and Attribute Value are valid for the supplied category
#
sub is_valid_attribute_value {

    my $cat     =   shift;
    my $field   =   shift;
    my $value   =   shift;

    my $SQL     =   qq {    SELECT      COUNT(*)
                            FROM        Attributes
                            WHERE       AttributeCategory   = ?
                            AND         AttributeField      = ?
                            AND         AttributeValue      = ? } ;

    my $sth = $dbh->prepare($SQL) || die "Error preparing statement: $DBI::errstr\n";
    
    $sth->execute( $cat, $field, $value ) || die "Error exexecuting statement: $DBI::errstr\n";
    
    my $proc = $sth->fetchrow_array;

    $sth->finish;

    return $proc;
    
}

