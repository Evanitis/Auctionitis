#!C:\Perl\bin\perl.exe -w

use strict;

while (<>) {
    s/(^<TR><TD>)(.+?)(<\/TD><TD>)(.+?)(<\/TD><TD>)(.+?)(<\/TD><TD>)(.+?)(<\/TD><\/TR>$)/$2,$4,"$6",$8/ig;
    print;
}


sub usage {
    (my $progname = $0) =~ s/.*[\\\/]//;
    die "Usage: $progname [<file>...]\n";
}

=begin Filter-Builder

This chunk encodes the Filter Builder state.  If this file is opened
with the Filter Builder, it uses this to restore the state.  You can
delete this section if you don't need to open the script in Filter
Builder again.

FB1:BQYDAAAABgQCAAAAAQQDAAAADQoBMQAAAAtpZ25vcmVfY2FzZQQCAAAA
AAAAAAxyZXBsX3Zhcl9yZWYKUihePFRSPjxURD4pKC4rPykoPFwvVEQ+PFRE
PikoLis/KSg8XC9URD48VEQ+KSguKz8pKDxcL1REPjxURD4pKC4rPykoPFwv
VEQ+PFwvVFI+JCkAAAACcmUEAgAAAAQKCy1iYWNrZ3JvdW5kCgZ5ZWxsb3cK
Cy1mb3JlZ3JvdW5kCgVibGFjawAAAA1tYXRjaHRhZ19jb25mCIkAAAAJcmVf
Z3JvdXBzCgAAAAAKZmlyc3Rfb25seQoGeWVsbG93AAAABWNvbG9yBAIAAAAA
AAAACnJlX3Zhcl9yZWYKDSQyLCQ0LCIkNiIsJDgAAAAEcmVwbApNKF48VFI+
PFREPikoLis/KSg8L1REPjxURD4pKC4rPykoPC9URD48VEQ+KSguKz8pKDwv
VEQ+PFREPikoLis/KSg8L1REPjwvVFI+JCkAAAAEdGV4dAoCUjEAAAACaWQK
AAAAAAZyZV9lcnIKATEAAAAHZW5hYmxlZAAAAAdyZXBsYWNlBAMAAAAHCgEx
AAAAB3JlcGxhY2UKATEAAAAFaW5wdXQKATAAAAAEZGVzYwoBMAAAAAN2YXIK
ATEAAAAGb3V0cHV0CIEAAAAFaHBhbmUKATEAAAAGc2VsZWN0AAAABHZpZXcK
AAAAAARkZXNjBAIAAAAAAAAACXZhcmlhYmxlcwogMzY0OGJkOWFjNDQ5ZTEy
YWUzZmQ3MDc0NjEyYjFmMGQAAAADbWQ1BAIAAAABBAMAAAAMCgExAAAAC2ln
bm9yZV9jYXNlCgAAAAACcmUEAgAAAAQKCy1iYWNrZ3JvdW5kCgcjMTlkOGZm
CgstZm9yZWdyb3VuZAoFYmxhY2sAAAANbWF0Y2h0YWdfY29uZgiAAAAACXJl
X2dyb3VwcwoHIzE5ZDhmZgAAAAVjb2xvcgoAAAAABnJlX25lZwQCAAAAAAAA
AApyZV92YXJfcmVmCgAAAAAEdGV4dAoCUzEAAAACaWQKAAAAAAZyZV9lcnIK
AAAAAAdlbmFibGVkCghtYXRjaGluZwAAAAJvcAAAAAZzZWxlY3Q7nl97h3yW
1DQyfoWxYe6n

=end Filter-Builder

