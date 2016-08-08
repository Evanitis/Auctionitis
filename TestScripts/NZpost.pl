#! perl -w
use strict;
use NZPost;

my $post = NZPost->new();
$post->login();
