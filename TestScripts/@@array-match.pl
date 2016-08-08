foreach my $match (@userNameMatches) {
        #next LINES if (m/^$match\,/);
        next LINES if (m/^$match\,/i);   # made case-insensitive 27/06/03 RJH
}

=LOOKUP(WEEKDAY(A245),{1,2,3,4,5,6,7;"Sun","Mon","Tue","Wed","Thu","Fri","Sat"})