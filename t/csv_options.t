#!/usr/bin/perl

use strict;
use warnings;
use Tie::CSV_File;
use File::Temp qw/tempfile tmpnam/;
use Test::More;
use t'CommonStuff;

sub test_option($%) {
    use Data::Dumper;
    $Data::Dumper::Indent = undef;
    my ($expected_csv_text, %option) = @_;
    my ($csv_fh,$csv_name) = tempfile();
    print $csv_fh $expected_csv_text;
    close $csv_fh;

    tie my @data, 'Tie::CSV_File', $csv_name, %option;
    is_deeply \@data, CSV_DATA(), 
              "tied file eq_array to csv_data with options " . Dumper(\%option);
    untie @data;
}


use Test::More tests => scalar(CSV_FILES);

foreach (CSV_FILES) {
    my @option   = @{$_->[0]};
    my $csv_text = $_->[1];
    test_option $csv_text, @option;
}
