#!/usr/bin/perl

use strict;
use warnings;
use Tie::CSV_File;
use File::Temp qw/tmpnam/;
use Test::More;
use t'CommonStuff;

sub test_store($%) {
    use Data::Dumper;
    $Data::Dumper::Indent = undef;
    my ($expected_csv_text, %option) = @_;
    my $csv_name = tmpnam();
    
    my $written_csv_tied;
    my $written_csv_untied;

    SET_EACH_CELL: {
        tie my @data, 'Tie::CSV_File', $csv_name, %option;
        foreach my $line_nr (0 .. scalar(@{CSV_DATA()})-1) {
            my @column = @{ CSV_DATA()->[$line_nr] };
            foreach my $col_nr (0 .. $#column) {
                $data[$line_nr][$col_nr] = $column[$col_nr];
            }
        }
        open CSV, $csv_name or die "Could not open the csv file $csv_name: $!";
        $written_csv_tied = join "", (<CSV>);
        close CSV;
        is_deeply \@data, CSV_DATA(),
                  'set $data[$line][$col] to the CSV_DATA and expected to be equal'
        or diag "Tested text:\n$expected_csv_text";
        untie @data;
    }

    open CSV, $csv_name or die "Could not open the csv file $csv_name: $!";
    $written_csv_untied = join "", (<CSV>);
    close CSV;
    
    is $written_csv_tied, $written_csv_untied,
       "Changes are written without to wait for untieing";
    
    RE_READ: {
        tie my @data, 'Tie::CSV_File', $csv_name, %option;
        is_deeply \@data, CSV_DATA(),
                  'set $data[$line][$col] to the CSV_DATA, untied and retied'
        or diag "Tested text:\n$expected_csv_text",
                "Written CSV:\n$written_csv_untied";
        untie @data;
    }
}

use Test::More tests => 3 * scalar(CSV_FILES) + 3;

foreach (CSV_FILES) {
    my @option   = @{$_->[0]};
    my $csv_text = $_->[1];
    test_store $csv_text, @option;
}

{
    tie my @data, 'Tie::CSV_File', 'csv.dat';
    $data[2][2] = "(2,2)";
    is_deeply \@data, [ [], [], ['', '', "(2,2)"] ],
          "Set a data element, but didn't set some elements before";
    untie @data;
}

{
    tie my @data, 'Tie::CSV_File', 'csv.dat';
    is_deeply \@data, [ [], [], ['', '', "(2,2)"] ],
          "Set a data element, but didn't set some elements before - after rereading";
    untie @data;
}

{
    tie my @data, 'Tie::CSV_File', 'csv.dat';
    $data[-1][-1] = "-(2,2)";
    is_deeply \@data, [ [], [], ['', '', "-(2,2)"] ],
          "Set a data element at last line, last column";
    untie @data;
}
