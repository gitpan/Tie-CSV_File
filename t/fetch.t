#!/usr/bin/perl 

use strict;
use warnings;

use constant CSV_FILE => <<'CSV';
City,Inhabitants,"Nice to live"
Jena,100000,"Definitly ""yes"""
Gera,150000,"wouldn't agree"
Zeits,"not really","a bit better than in war"
,0,"in Nirvana you can't really live","believe me"

,,,,,
CSV

use constant CSV_DATA => [
    ['City',  'Inhabitants', 'Nice to live'],
    ['Jena',  100_000,       'Definitly "yes"'],
    ['Gera',  150_000,       'wouldn\'t agree'],
    ['Zeits', 'not really',  'a bit better than in war'],
    ['',      0,             'in Nirvana you can\'t really live', 'believe me'],
    [],
    [('') x 6]
];

use File::Temp qw/tempfile tmpnam/;

my ($csv_fh,$csv_name) = tempfile();
print $csv_fh CSV_FILE;
close $csv_fh;
END {
    unlink $csv_name;
}

use Test::More tests => 4;

use Tie::CSV_File;

tie my @data, 'Tie::CSV_File', $csv_name;
is_deeply \@data, CSV_DATA(), "tied file eq_array to csv_data";

is $data[-1][-1], CSV_DATA()->[-1]->[-1] , "last element in last row";
is $data[1_000][0], undef, "non existing element in the 100th line";

tie my @empty, 'Tie::CSV_File', tmpnam();
is_deeply \@empty, [], "tied empty file";
