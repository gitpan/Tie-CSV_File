#!/usr/bin/perl 

use strict;
use warnings;

use Tie::CSV_File;
use Test::Exception;
use Test::Warn;

use Test::More tests => 3;

{
dies_ok { tie my @data, 'Tie::CSV_File', '/foo/bar/nonsens/nonsens.csv' }
        "tied an unknown file in an impossible directory";
}

{
dies_ok { tie my @data, 'Tie::CSV_File', 'here.dat', 'unknown option' => 3 }
          qr/parameter/,
          "Unknown options should let it die";
}

{             
dies_ok { tie my @data, 'Tie::CSV_File', 'here.dat', 'eol' => ['an arrayref'] }
        "Only scalar values are allowed for options";
}
