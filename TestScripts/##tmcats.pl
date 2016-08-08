#!perl -w

my    $infile = "c:\\evan\\trademe\\documents\\category_index[1].txt";
open  (INPUT, "< $infile") or die "Cannot open $infile: $!";

# sample line form trademe category listsing:
# <a href="/Computers/Peripherals/Joysticks-gamepads/mcat-0002-0362-0521-.htm">Joysticks & gamepads</a>

while (<INPUT>) {
      while   (m/(<a href=\".+?mcat\-.+?\.htm\">.+?<\/a>?)/g) {
           print "$1\n";
      }
}
