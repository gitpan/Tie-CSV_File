#!/usr/bin/perl

use strict;
use warnings;
use Tie::CSV_File;
use File::Temp qw/tempfile tmpnam/;
use Test::More;
use t'CommonStuff;

sub test_option($%) {
    my ($expected_csv_text, $data, %option) = @_;
    my ($csv_fh,$csv_name) = tempfile();
    print $csv_fh $expected_csv_text;
    close $csv_fh;

    tie my @data, 'Tie::CSV_File', $csv_name, %option;
    is_deeply \@data, $data,
              "tied file eq_array to csv_data with options " . Dumper(\%option);
    untie @data;
}


use Test::More tests => scalar(CSV_FILES) + 7;

foreach (CSV_FILES) {
    my @option   = @{$_->[0]};
    my $csv_text = $_->[1];
    test_option $csv_text, CSV_DATA(), @option;
}

test_option CSV_FILE_TAB_SEPERATED, CSV_DATA(), 
            TAB_SEPERATED;
test_option CSV_FILE_COLON_SEPERATED, CSV_DATA(),
            COLON_SEPERATED;            
test_option SIMPLE_CSV_FILE_WHITESPACE_SEPERATED, SIMPLE_CSV_DATA(), 
            WHITESPACE_SEPERATED;
test_option SIMPLE_CSV_FILE_WHITESPACE_SEPERATED, SIMPLE_CSV_DATA(),
            WHITESPACE_SEPERATED, sep_char => '   ';            
test_option SIMPLE_CSV_FILE_COLON_SEPERATED, SIMPLE_CSV_DATA(), 
            COLON_SEPERATED;
test_option SIMPLE_CSV_FILE_SEMICOLON_SEPERATED, SIMPLE_CSV_DATA(),
            SEMICOLON_SEPERATED;

sub _written_content(@) {
    my $file = tmpnam();
    tie my @data, 'Tie::CSV_File', $file, @_;
    push @data, $_ for @{SIMPLE_CSV_DATA()};
    untie @data;
    open CSV, $file or die "Can't open CSV file $file: $!";
    my $content = join "", (<CSV>);
    close CSV;
    return $content;
}   

my $c1 = _written_content WHITESPACE_SEPERATED;
my $c2 = _written_content WHITESPACE_SEPERATED, sep_char => "\t";

$c1 =~ s/ /\t/gs;
is $c1, $c2, 
   "Changing the sep_char of WHITESPACE_SEPERATED should change the written content";
