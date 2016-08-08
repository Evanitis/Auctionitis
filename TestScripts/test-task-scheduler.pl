#################################################
# Example 1. How to get/set account information for a task  
#
use Win32::TaskScheduler;
use strict;

my $ACCOUNT_NAME    = shift;
my $ACCOUNT_PW      = shift;

my $TASK_NAME       = 'Auctionitis Update Database';
my $APP_NAME        = 'C:\Program Files\Auctionitis\Auctionitis.exe';
my $WORK_DIR        = 'C:\Program Files\Auctionitis';
my $APP_PARMS       = '-ACTION:UPDATEDB';


my $sch = Win32::TaskScheduler->New();

print "Account Information:".$sch->GetAccountInformation()."\n";

# Get a list of the current jobs in the scheduler and see if the current job exists
# If it exists delete it so we can add it back with the new details

my @jobs = $sch->Enum();

foreach my $j ( @jobs ) {
    print "$j\n";
    if ( $j eq $TASK_NAME.".job" ) {
        print "matched taskname\n";
        $sch->Delete( $TASK_NAME );   
    }
}

# Activate the task so we can work on it

$sch->Activate( $TASK_NAME );

# This adds a weekly schedule.

my %taskTrigger = (
    'BeginYear'     => 2009                             ,
    'BeginMonth'    => 7                                ,
    'BeginDay'      => 5                                ,
    'StartHour'     => 1                                ,
    'StartMinute'   => 0                                ,
    'TriggerType'   => $sch->TASK_TIME_TRIGGER_WEEKLY   ,
    'Type'          => {
        'WeeksInterval' => 1                    ,
        'DaysOfTheWeek' => $sch->TASK_MONDAY | $sch->TASK_TUESDAY | $sch->TASK_FRIDAY    ,    
    },
);

## This adds a dailyly schedule.
#
#my %taskTrigger = (
#    'BeginYear'     => 2009                             ,
#    'BeginMonth'    => 7                                ,
#    'BeginDay'      => 5                                ,
#    'StartHour'     => 1                                ,
#    'StartMinute'   => 0                                ,
#    'TriggerType'   => $sch->TASK_TIME_TRIGGER_DAILY    ,
#    'Type'=>{
#        'DaysInterval' => 1,
#    },
#);

# Set the general properties for the task

$sch->NewWorkItem( $TASK_NAME, \%taskTrigger );
$sch->SetApplicationName( $APP_NAME );
$sch->SetParameters( $APP_PARMS );
$sch->SetWorkingDirectory( $WORK_DIR );

# Set the Wake the Computer to run this task flag

$sch->SetFlags( $sch->TASK_FLAG_SYSTEM_REQUIRED ); 

# Set the max time to run

$sch->SetMaxRunTime( 7200000 );   # 1 hour

# Set the account and password to run under

$sch->SetAccountInformation( $ACCOUNT_NAME, $ACCOUNT_PW );

# Save the item

$sch->Save();

# Release the COM resources
$sch->End();


