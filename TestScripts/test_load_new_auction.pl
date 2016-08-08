#!perl -w
#--------------------------------------------------------------------
# getauction.pl script to get auction details
# (prototype for bidding/watching robot)
#
# Other program notes:
#--------------------------------------------------------------------

use strict;
use Auctionitis;

my $tm = Auctionitis->new();
   
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();                           # Initialise the product
$tm->login();

my $CategoryID   = "0080";
my $Title        = "Old Writing Pad";

my $Description  = "An auction of an old writing pad";

my $IsNew           = 0;
my $StartPrice      = 100.00;
my $ReservePrice    = 120.00;
my $BuyNowPrice     = 140.00;
my $DurationHours   = 2;       # 7 days = 10080 (time is in minutes)
my $AutoExtend      = 1;
my $Cash            = 0;
my $Cheque          = 0;
my $BankDeposit     = 0;
my $ClosedAuction   = 0;
my $SafeTrader      = 3;
my $Gallery         = 0;
my $BoldTitle       = 0;
my $Featured        = 0;
my $FeatureCombo    = 0;
my $HomePage        = 0;
my $PhotoID1        = 0;
my $PhotoID2        = 0;
my $PhotoID3        = 0;
my $PaymentInfo     = "I will take any reasonable form of payment";
my $Permanent       = 0;
my $FreeShipNZ      = 0;
my $ShippingInfo    = "Courier Post Only";

my $newauction = $tm->load_new_auction( CategoryID      =>   $CategoryID                ,
                                        Title           =>   $Title                     ,
                                        Description     =>   $Description               ,
                                        IsNew           =>   $IsNew                     ,
                                        DurationHours   =>   $DurationHours             ,
                                        $PhotoID1       ?    (PhotoID1 => $PhotoID1) :(),
                                        $PhotoID2       ?    (PhotoID2 => $PhotoID2) :(),
                                        $PhotoID3       ?    (PhotoID3 => $PhotoID3) :(),
                                        StartPrice      =>   $StartPrice                ,
                                        ReservePrice    =>   $ReservePrice              ,
                                        BuyNowPrice     =>   $BuyNowPrice               ,
                                        ClosedAuction   =>   $ClosedAuction             ,
                                        SafeTrader      =>   $SafeTrader                ,
                                        AutoExtend      =>   $AutoExtend                ,
                                        Cash            =>   $Cash                      ,
                                        Cheque          =>   $Cheque                    ,
                                        BankDeposit     =>   $BankDeposit               ,
                                        Gallery         =>   $Gallery                   ,
                                        BoldTitle       =>   $BoldTitle                 ,
                                        Featured        =>   $Featured                  ,
                                        FeatureCombo    =>   $FeatureCombo              ,
                                        HomePage        =>   $HomePage                  ,
                                        PaymentInfo     =>   $PaymentInfo               ,
                                        FreeShipNZ      =>   $FreeShipNZ                ,
                                        ShippingInfo    =>   $ShippingInfo              ,
                                        Permanent       =>   $Permanent                 );

   if ( $tm->{ErrorStatus} eq "1" ) {
        print "$tm->{ErrorMessage}\n"
   }
   
# List of fields that can be used with Load new Auction function:

# CategoryID 
# Title           
# Description     
# IsNew           
# TMBuyerEmail    
# DurationHours   
# StartPrice      
# ReservePrice    
# BuyNowPrice     
# ClosedAuction   
# AutoExtend      
# Cash            
# Cheque          
# BankDeposit     
# PaymentInfo     
# FreeShippingNZ  
# ShippingInfo    
# SafeTrader      
# $PhotoID1       
# $PhotoID2       
# $PhotoID3       
# Gallery         
# BoldTitle       
# Featured        
# FeatureCombo    
# HomePage        
# Permanent       
# MovieRating     
# MovieConfirm    
# AttributeName   
# AttributeValue  
# TMATT104        
# TMATT104_2      
# TMATT106        
# TMATT106_2      
# TMATT108        
# TMATT108_2      
# TMATT111        
# TMATT112        
# TMATT115        
# TMATT117        
# TMATT118        


print "Loaded new auction: $newauction ($Title)\n";

# Success.

print "Done\n";
exit(0);