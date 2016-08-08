use strict;
use Term::ReadKey;

my $TMATT038;
my $choice = 0;

system('cls');
print "Setup for New DVD Fields\n\n";
print "Select Default Value for DVD Condition:\n\n";
print "1 = Brand New\n";
print "2 = As New\n";
print "3 = Good\n";
print "4 = Poor\n\n";

while ($choice == 0) {

    $choice = Get_Choice();
    if ($choice == 1)       { $TMATT038 = "Brand New";    }
    elsif ($choice == 2)    { $TMATT038 = "As New";       }
    elsif ($choice == 3)    { $TMATT038 = "Good";         }
    elsif ($choice == 4)    { $TMATT038 = "Poor";         }
    else                    { 
        system('cls');
        print "Setup for New DVD Fields\n\n";
        print "Select Default Value for DVD Condition:\n\n";
        print "1 = Brand New\n";
        print "2 = As New\n";
        print "3 = Good\n";
        print "4 = Poor\n\n";
        print "$choice is not one of the available options - please make another selection\n\n";
        $choice = 0;                
    }
}

print "\n\n--------------------------------------\n";
print "Item selected was $TMATT038\n";

sub Get_Choice {

    ReadMode 'cbreak';
    my $key = ReadKey(0);
    ReadMode 'normal';
    
    return $key;

}