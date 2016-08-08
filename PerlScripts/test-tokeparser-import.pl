use strict;
use LWP::Simple;
use LWP::UserAgent;
use URI::URL;
use URI::Escape;
use HTTP::Request;
use HTTP::Response;
use HTTP::Headers;
use HTTP::Response;
use HTTP::Cookies;
use HTTP::Request::Common qw(POST);
use HTML::TokeParser;
use Auctionitis;
# class variables

my ($ua, $url, $req, $response, $content);

my $userid   = "evan\@auctionitis.co.nz";
my $password = "runestaff";

my %imp;
my $auctionref      = shift;
my $auctionstatus   = shift;

# Create the Auctionitis trademe object

my $tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();

# Set up the user agent pseudo-browser

$ua = LWP::UserAgent->new();
$ua->agent("Auctionitis/V1.0");
push @{$ua->requests_redirectable}, 'POST';  # Added 29/04/05
$ua->cookie_jar(HTTP::Cookies->new(file       => "lwpcookies.txt",
                                   autosave   => 1));
                                       
# log-in to Trademe

$url = "http://www.trademe.co.nz/Members/Login.aspx";                   
$req = POST $url, [url            =>  '/DEFAULT.ASP?'   ,
#                   test_auto      =>  ''               ,
                   email          =>  $userid           ,
                   password       =>  $password         ,
                   login_attempts =>  0                 ,
                   submitted      =>  'Y'               ];

$content = $ua->request($req)->as_string; # posts the data to the remote site i.e. logs in

# get the Sell similar item data page

$url="http://www.trademe.co.nz/MyTradeMe/AuctionDetailCommand.aspx";        # 21/05.2006

$req = POST $url, [
    "id"                             =>   $auctionref,
    ($auctionstatus eq "CURRENT"  )   ?   ("cmdSellSimilarItem"      => 'Sell similar item')    : () ,
    ($auctionstatus eq "SOLD"     )   ?   ("cmdSellSimilarItemSold"  => 'Sell similar item')    : () ,
    ($auctionstatus eq "UNSOLD"   )   ?   ("cmdSellSimilarItemSold"  => 'Sell similar item')    : () ,
];


($auctionstatus eq "CURRENT"    ) ? ( $imp{ AuctionStatus } = "CURRENT"  ) : (                          ) ;
($auctionstatus eq "SOLD"       ) ? ( $imp{ AuctionStatus } = "SOLD"     ) : (                          ) ;
($auctionstatus eq "SOLD"       ) ? ( $imp{ AuctionSold   } = 1          ) : ( $imp{ AuctionSold } = 0  ) ;
($auctionstatus eq "UNSOLD"     ) ? ( $imp{ AuctionStatus } = "UNSOLD"   ) : (                          ) ;


# Submit the auction details to TradeMe (HTTP POST operation) 

$content = $ua->request($req)->as_string;

# parse the data using the toke parser module

my $select_group;

my $stream = new HTML::TokeParser(\$content);

while ( my $token = $stream->get_token() ) {

    if ( $token->[0] eq 'S' and $token->[1] eq 'input' ) {
    
        #Category ID

        if ( uc( $token->[2]{ 'name' } ) eq 'CATEGORYID'            )       {
            
            $imp{ Category      } = $token->[2]{ 'value' };
        }

        # Auction Title

        if ( uc( $token->[2]{ 'name' } ) eq 'TITLE'                 )       {
            
            $imp{ Title         } = $token->[2]{ 'value' };
        }

        # Auction subtitle

        if ( uc( $token->[2]{ 'name' } ) eq 'SUBTITLE'              )       {
        
            $imp{ Subtitle      } = $token->[2]{ 'value' };
        }

        # "Is New" Flag
        
        if ( uc( $token->[2]{ 'name' } ) eq 'IS_NEW'                )       {
            
            if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED'         )       {
        
                $imp{ IsNew        } = 1;
            }
            else {
                $imp{ IsNew        } = 0;
            }
         }

        # Start Price

        if ( uc( $token->[2]{ 'name' } ) eq 'STARTPRICE'            )       {
        
            $imp{ StartPrice    } = $token->[2]{ 'value' };
        }

        # Reserve Price

        if ( uc( $token->[2]{ 'name' } ) eq 'RESERVEPRICE'          )       {
        
            $imp{ ReservePrice  } = $token->[2]{ 'value' };
        }

        # BuyNow Price

        if ( uc( $token->[2]{ 'name' } ) eq 'BUYNOWPRICE' ) {
            
            $imp{ BuyNowPrice   } = $token->[2]{ 'value' };
        }

        # Auction Duration type 

        if ( uc( $token->[2]{ 'name' } ) eq 'DURATION_TYPE' ) {

            if ( uc($token->[2]{ 'value' } ) eq 'EASY' and uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {
        
                $imp{ EndType } = "DURATION";
            }

            if ( uc($token->[2]{ 'value' } ) eq 'ADVANCED' and uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {
        
                $imp{ EndType } = "FIXEDEND";
            }
        }

        # Closed Auction (authorised members only)  *** CHECK this carefully !!!
        
        if ( uc( $token->[2]{ 'name' } ) eq 'CLOSED' ) {
            
            if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {
        
                $imp{ ClosedAuction } = 1;
            }
            else {
                $imp{ ClosedAuction } = 0;
            }
         }
          
        # Delivery options 
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY' ) {

            if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                if ( uc($token->[2]{ 'value' } ) eq 'UNDECIDEDED' ) {
        
                    $imp{ ShippingOption       } = 1;
                }
                elsif ( uc($token->[2]{ 'value' } ) eq 'FREE' ) {
                
                    $imp{ ShippingOption       } = 2;
                }
                elsif ( uc($token->[2]{ 'value' } ) eq 'CUSTOM' ) {
                
                    $imp{ ShippingOption       } = 3;
                }
            }
        }
        
        # Delivery Cost 01
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_1'       )       {
        
            $imp{ DCost1    } = $token->[2]{ 'value' };
        }

        # Delivery Text 01
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_1'     )       {
        
            $imp{ DText1    } = $token->[2]{ 'value' };
            
        }

        # Delivery Cost 02
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_2'       )       {
        
            $imp{ DCost2    } = $token->[2]{ 'value' };
        }

        # Delivery Text 02
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_2'     )       {
        
            $imp{ DText2    } = $token->[2]{ 'value' };
            
        }
        # Delivery Cost 03
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_3'       )       {
        
            $imp{ DCost3    } = $token->[2]{ 'value' };
        }

        # Delivery Text 03
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_3'     )       {
        
            $imp{ DText3    } = $token->[2]{ 'value' };
            
        }
        
        # Delivery Cost 04
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_4'     )       {
        
            $imp{ DCost4    } = $token->[2]{ 'value' };
        }

        # Delivery Text 04
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_4'   )       {
        
            $imp{ DText4    } = $token->[2]{ 'value' };
            
        }
        # Delivery Cost 05
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_5'     )       {
        
            $imp{ DCost5    } = $token->[2]{ 'value' };
        }

        # Delivery Text 05
         
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_5'   )       {
        
            $imp{ DText5    } = $token->[2]{ 'value' };
            
        }
        # Delivery Cost 06
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_6'     )       {
        
            $imp{ DCost6    } = $token->[2]{ 'value' };
        }

        # Delivery Text 06
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_6'   )       {
        
            $imp{ DText6    } = $token->[2]{ 'value' };
            
        }
        # Delivery Cost 07
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_7'     )       {
        
            $imp{ DCost7    } = $token->[2]{ 'value' };
        }

        # Delivery Text 07
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_7'   )       {
        
            $imp{ DText7    } = $token->[2]{ 'value' };
            
        }

        # Delivery Cost 08
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_8'     )       {
        
            $imp{ DCost8    } = $token->[2]{ 'value' };
        }

        # Delivery Text 08
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_8'   )       {
        
            $imp{ DText8    } = $token->[2]{ 'value' };
            
        }

        # Delivery Cost 09
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_9'     )       {
        
            $imp{ DCost9    } = $token->[2]{ 'value' };
        }

        # Delivery Text 09
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_9'   )       {
        
            $imp{ DText9    } = $token->[2]{ 'value' };
            
        }
        # Delivery Cost 10
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_COST_10'    )       {
        
            $imp{ DCost10   } = $token->[2]{ 'value' };
        }

        # Delivery Text 10
        
        if ( uc( $token->[2]{ 'name' } ) eq 'DELIVERY_METHOD_10'  )       {
        
            $imp{ DText10   } = $token->[2]{ 'value' };
            
        }
        
        # Payment Info options

        if ( uc( $token->[2]{ 'name' } ) eq 'PAYMENT_INFO' ) {

            # Bank Deposit
           
            if (  uc($token->[2]{ 'value' } ) eq 'BANK_DEPOSIT' ) {
            
                if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ BankDeposit } = 1;
                }
                else {
                    $imp{ BankDeposit } = 0;
                }
            }
            
            # Credit Card
            
            if (  uc($token->[2]{ 'value' } ) eq 'CREDIT_CARD' ) {
            
                if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ CreditCard } = 1;
                }
                else {
                    $imp{ CreditCard } = 0;
                }
            }
            
            # Cash on Pickup
            
            if (  uc($token->[2]{ 'value' } ) eq 'CASH_ON_PICKUP' ) {
            
                if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ CashOnPickup } = 1;
                }
                else {
                    $imp{ CashOnPickup } = 0;
                }
            }
            
            # Paymate
            
            if (  uc($token->[2]{ 'value' } ) eq 'PAYMATE' ) {
            
                if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ Paymate } = 1;
                }
                else {
                    $imp{ Paymate } = 0;
                }
            }
            
            # Safe Trader
            
            if (  uc($token->[2]{ 'value' } ) eq 'SAFE_TRADER' ) {
            
                if ( uc($token->[2]{ 'checked' } ) eq 'CHECKED' ) {

                    $imp{ SafeTrader } = 1;
                }
                else {
                    $imp{ SafeTrader } = 0;
                }
            }
            
            # Payment information "Other"
            
            if (  uc($token->[2]{ 'id' } ) eq 'PAYMENT_INFO_OTHER_TEXT' ) {

                $imp{ PaymentInfo } = $token->[2]{ 'value' };
            }
        }

        # Buyer Email
        
        if ( uc( $token->[2]{ 'name' } ) eq 'SEND_BUYER_EMAIL' ) {
        
            if ( uc($token->[2]{ 'value' } ) eq 'Y' )  {
        
                $imp{ TMBuyerEmail } = 1;
            }
            else {

                $imp{ TMBuyerEmail } = 0;
            }
        }
        
        # Cot Safety Confirmation
        
        if ( uc( $token->[2]{ 'name' } ) eq '57' )  {
        
            $imp{ AttributeName     } = $token->[2]{ 'name'  };
            $imp{ AttributeValue    } = $token->[2]{ 'value' };
        }
        
        # Game rating Confirmation
        
        if ( uc( $token->[2]{ 'name' } ) eq '137' )  {
        
            $imp{ AttributeName     } = $token->[2]{ 'name'  };
            $imp{ AttributeValue    } = $token->[2]{ 'value' };
        }

        # Digital camera attributes - Megapixels
        
        if ( uc( $token->[2]{ 'name' } ) eq '117' )  {              
        
            $imp{ TMATT117          } = $token->[2]{ 'value' };
        }

        # Digital camera attributes - Optical Zoom

        if ( uc( $token->[2]{ 'name' } ) eq '118' )  {              
        
            $imp{ TMATT118          } = $token->[2]{ 'value' };
        }

        # Monitor Attribute - Size
        
        if ( uc( $token->[2]{ 'name' } ) eq '115' )  {
        
            $imp{ TMATT115          } = $token->[2]{ 'value' };
        }

        # Desktop Attribute - Speed MHz/Ghz
        
        if ( uc( $token->[2]{ 'name' } ) eq '104' )  {
        
            $imp{ TMATT104          } = $token->[2]{ 'value' };
        }

        # Desktop Attribute - RAM
        
        if ( uc( $token->[2]{ 'name' } ) eq '106' )  {
        
            $imp{ TMATT106          } = $token->[2]{ 'value' };
        }

        # Desktop Attribute - HDD SIze
        
        if ( uc( $token->[2]{ 'name' } ) eq '108' )  {
        
            $imp{ TMATT108          } = $token->[2]{ 'value' };
        }
    }

    if ( $token->[0] eq 'S' and $token->[1] eq 'select' ) {

        $select_group = $token->[2]{ 'name' };
    }

    if ( $token->[0] eq 'E' and $token->[1] eq 'select' ) {

        $select_group = "";
    }

    # Check the individual options in the select groups for what was selected

    if ( $token->[0] eq 'S' and $token->[1] eq 'option' ) {

        # Auction Duration values

        if ( uc( $select_group ) eq 'AUCTION_LENGTH' ) {

            if ( uc( $token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ DurationHours } = $token->[2]{ 'value' };
            }
        }

        # Auction Duration values - Fixed end

        if ( uc( $select_group ) eq 'SET_END_DAYS' ) {

            if ( uc( $token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ EndDays } = $token->[2]{ 'value' };
            }
        }

        if ( uc( $select_group ) eq 'SET_END_HOUR' ) {

            if ( uc( $token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ EndTime } = $token->[2]{ 'value' };
            }
        }

        # Pickup Options

        if ( uc( $select_group ) eq 'PICKUP' ) {

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                if ( uc ($token->[2]{ 'value' } ) eq 'ALLOW' ) {

                    $imp{ PickupOption       } = 1;
                }
                elsif ( uc ($token->[2]{ 'value' } ) eq 'DEMAND' ) {

                    $imp{ PickupOption       } = 2;
                }
                elsif ( uc ($token->[2]{ 'value' } ) eq 'FORBID' ) {

                    $imp{ PickupOption       } = 3;
                }
            }
        }
        
        # Clothing Attributes

        if ( ( uc( $select_group ) eq  '86' ) or
             ( uc( $select_group ) eq  '87' ) or
             ( uc( $select_group ) eq  '88' ) or
             ( uc( $select_group ) eq  '89' ) or
             ( uc( $select_group ) eq  '91' ) or
             ( uc( $select_group ) eq  '92' ) or
             ( uc( $select_group ) eq  '93' ) or
             ( uc( $select_group ) eq '130' ) ) {

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ AttributeName     } = $select_group;
                $imp{ AttributeValue    } = $token->[2]{ 'value' };
            }
        }

        # Mobile Phone Accessories Attributes

        if ( uc( $select_group ) eq '120' ) {

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ AttributeName     }   = $select_group;
                $imp{ AttributeValue    }   = $token->[2]{ 'value' };
            }
        }

        # Mobile Phone Accessories Attributes

        if ( uc( $select_group ) eq '116' ) {

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ AttributeName     }   = $select_group;
                $imp{ AttributeValue    }   = $token->[2]{ 'value' };
            }
        }


        # Movie Rating Accessories Attributes

        if ( uc( $select_group ) eq '55' ) {

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ MovieRating       }   = $token->[2]{ 'value' };
                $imp{ MovieConfirm      }   = 1;
            }
        }
 

        # Desktop Attribute - Speed MHz/Ghz

        if ( uc( $select_group ) eq '104' ) {

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ TMATT104_2        } = $token->[2]{ 'value' }
            }
        }

        # Desktop Attribute - RAM

        if ( uc( $select_group ) eq '106' ) {

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ TMATT106_2        } = $token->[2]{ 'value' }
            }
        }
         # Desktop Attribute - HDD

        if ( uc( $select_group ) eq '108' ) {

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ TMATT108_2        } = $token->[2]{ 'value' }
            }
        }
        # Desktop Attribute - CD Drive

        if ( uc( $select_group ) eq '111' ) {

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ TMATT111          } = $token->[2]{ 'value' }
            }
        }
         # Desktop Attribute - Monitor Type

        if ( uc( $select_group ) eq '112' ) {

                $imp{ TMATT112          } = "";

            if ( uc ($token->[2]{ 'selected' } ) eq 'SELECTED' ) {

                $imp{ TMATT112          } = $token->[2]{ 'value' }
            }
        }
   }
    
    # Auction Description
    
    if ( $token->[0] eq 'S' and $token->[1] eq 'textarea' and uc( $token->[2]{ 'name' } ) eq 'BODY' ) {

        $imp{ Description } = $stream->get_text();
        # $imp{ Description } =~ s/\x0D\x0A/\n/gs;                   # change mem cr/lf to new lines  
    }
}

# Set the category attribute value using the auction category

my $catval = $imp{ Category };

if ( $tm->has_attributes($catval) ) {

    $imp{ AttributeCategory } = $catval;
}
else {
    
    $catval = $tm->get_parent($catval);
}

if ( $catval ne 0 ) {

    if ( $tm->has_attributes($catval) ) {

        $imp{ AttributeCategory } = $catval;
    }
    else {

        $catval = $tm->get_parent($catval);
    }
}

if ( $catval ne 0 ) {

    if ( $tm->has_attributes($catval) ) {

        $imp{ AttributeCategory } = $catval;
    }
    else {

        $catval = $tm->get_parent($catval);
    }
}

if ( $catval ne 0 ) {

    if ( $tm->has_attributes($catval) ) {

        $imp{ AttributeCategory } = $catval;
    }
}

my $tm;

$tm = Auctionitis->new();
$tm->initialise(Product => "Auctionitis");  # Initialise the product
$tm->DBconnect();


if ( exists $imp{ TMATT112 }  ) {
    my $monitor = $tm->get_monitor_type( $auctionref );
    print "Monitor: $monitor\n";
    $imp{ TMATT112 } = $monitor ;
}

if ( exists $imp{ MovieRating }  ) {
    delete $imp{ AttributeName      };
    delete $imp{ AttributeValue     };
    delete $imp{ Attributecategory  };
}

# print out the imported record in sorted key order

foreach my $k (sort keys %imp) {
    print "$k => $imp{$k}\n";
}

my $auctionkey = $tm->add_auction_record_202( %imp );

my $x = 1;

while ( $x < 11 ) {

    my $ck = "DCost".$x;    # Delivery cost Key
    my $tk = "DText".$x;    # Delivery text key

    if ( $imp{ $ck } ) {

        $tm->add_shipping_details_record (
            AuctionKey                 =>   $auctionkey ,
            Shipping_Details_Seq       =>   $x          ,
            Shipping_Details_Cost      =>   $imp{ $ck } ,
            Shipping_Details_Text      =>   $imp{ $tk } ,          
            Shipping_Option_Code       =>   ""          ,
        );
    }    
    $x++;
}
