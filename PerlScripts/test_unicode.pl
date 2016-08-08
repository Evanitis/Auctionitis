use Unicode::String;

my $string = "Doggle\'s are great !";

my $u = Unicode::String->new($string);

print $u->ucs2;

print $u->utf8;

print "done.\n"
