#!/usr/bin/perl 

use strict;
use warnings;

use Tie::CSV_File;
use Test::Exception;

use Test::More tests => 1;

dies_ok { tie my @data, 'Tie::CSV_File', '/foo/bar/nonsens/nonsens.csv' }
        "tied an unknown file in an impossible directory";
