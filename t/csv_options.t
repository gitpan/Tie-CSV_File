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

use constant TAB_SEPERATED_OPT => (
    sep_char     => "\t",
    quote_char   => undef,
    eol          => undef,
    escape_char  => undef,
    always_quote => 0
);

use constant SPLIT_SEPERATED_OPT => (
    sep_char     => '|',
    sep_re       => qr/\s*\|\s*/,
    quote_char   => undef,
    eol          => undef,
    escape_char  => undef,
    always_quote => 0,
);

use Test::More tests => 7;

test_option CSV_FILE_QUOTE_IS_SLASH,      quote_char   => '/';
test_option CSV_FILE_EOL_IS_EOL,          eol          => 'EOL';
test_option CSV_FILE_SEP_IS_SLASH,        sep_char     => '/';
test_option CSV_FILE_ESCAPE_IS_BACKSLASH, escape_char  => '\\';
test_option CSV_FILE_ALWAYS_QUOTE,        always_quote => 1;
test_option CSV_FILE_TAB_SEPERATED,       TAB_SEPERATED_OPT;
test_option CSV_FILE_SPLIT_SEPERATED,     SPLIT_SEPERATED_OPT;
