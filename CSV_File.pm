package Tie::CSV_File;

use strict;
use warnings;

require Exporter;

use Tie::Array;
use Text::CSV_XS;
use Tie::File;
use Params::Validate qw/:all/;

our @ISA = qw(Exporter Tie::Array);

# nothing to export

our $VERSION = '0.07';

sub TIEARRAY {
    my ($class, $fname) = (shift(), shift());
    my %options = validate( @_, {
        quote_char   => {default => q/"/,  type => SCALAR | UNDEF},
        eol          => {default => undef, type => SCALAR | UNDEF},
        sep_char     => {default => q/,/,  type => SCALAR | UNDEF},
        sep_re       => {default => undef, isa  => 'Regexp'},
        escape_char  => {default => q/"/,  type => SCALAR | UNDEF},
        always_quote => {default => 0,     type => SCALAR | UNDEF}
    });
    tie my @lines, 'Tie::File', $fname or die "Can't open $fname: $!";
    my $self = {
        lines   => \@lines,
        csv     =>  Text::CSV_XS->new(\%options),
        eol     => $options{eol},
        sep_re  => $options{sep_re}
    };
    bless $self, $class;
}

sub FETCHSIZE {
    my ($self) = @_;
    return scalar( @{ $self->{lines} } );
}

sub FETCH {
    my ($self, $line_nr) = @_;
    tie my @fields, 'Tie::CSV_File::Line', 
        $self->{lines}, $line_nr, $self->{"csv"}, 
                                  $self->{"eol"}, 
                                  $self->{"sep_char"}, 
                                  $self->{"sep_re"};
    return \@fields;
}

sub STORE {
    my ($self, $line_nr, $columns) = @_;
    my $csv = $self->{csv};
    if (@$columns) {
        use Data::Dumper;
        $csv->combine(@$columns) or die "Can't store " . Dumper($columns);
        $self->{lines}->[$line_nr] = $csv->string;
    } else {
        $self->{lines}->[$line_nr] = $self->{eol} || '';
    }
}

package Tie::CSV_File::Line;

use strict;
use warnings;

use Tie::Array;
use Text::CSV_XS;
use Tie::File;
use Params::Validate qw/:all/;

our @ISA = qw(Exporter Tie::Array);

sub TIEARRAY {
    my ($class, $data, $line_nr, $csv, $eol, $sep_char, $sep_re) = @_;
    my $self = bless {
        data     => $data,
        line_nr  => $line_nr,
        csv      => $csv,
        eol      => $eol,
        sep_char => $sep_char,
        sep_re   => $sep_re
    }, $class;
}

sub columns {
    my $self = shift;
    my @fields = ();     # even if there aren't any fields, it's an empty list
    my $line  = $self->{data}->[$self->{line_nr}];
    defined($line) or return \@fields;
    if (my $eol = $self->{eol}) {
        $line =~ s/\Q$eol\E$//;
    }
    if (my $re = $self->{sep_re}) {
        push @fields, 
            map {defined($_) ? $_ : ''}  # empty fields shall be '', not undef
            grep !/$re/,                 # ugly, but needed see downside
            split /($re)/, $line;        # needed, as perl has problems with 
                                         # split /x/,"xxxxxxxxxx"; or similar
        push @fields, '' if $line =~ /$re$/; # needed when the last element is empty 
                                             # - it won't be catched with split
    } else {
        my $csv    = $self->{csv};
        push @fields, $csv->fields() if $csv->parse($line);
        if (my $sep_char = $self->{sep_char}) {
            push @fields, '' if $line =~ /\Q$sep_char\E$/;
        }
    }
    return \@fields;

}

sub FETCHSIZE {
    my ($self) = @_;
    return scalar( @{$self->columns} );
}

sub FETCH {
    my ($self, $col_nr) = @_;
    $self->columns->[$col_nr];
}

sub STORE {
    my ($self, $col_nr, $value) = @_;
    my $csv = $self->{csv};
    my @col = @{ $self->columns };
    $col[$col_nr] = $value;
    $csv->combine( @col );
    $self->{data}->[$self->{line_nr}] = $csv->string;
}

1;
__END__

=head1 NAME

Tie::CSV_File - ties a csv-file to an array of arrays

=head1 SYNOPSIS

  use Tie::CSV_File;

  tie my @data, 'Tie::File', 'xyz.dat';
  print "Data in 3rd line, 5th column: ", $data[2][4];
  untie @data;
  
  # or to read a tabular seperated file
  tie my @data, 'Tie::File', 'xyz.dat', sep_char     => "\t",
                                        quote_char   => undef,
                                        eol          => undef, # default
                                        escape_char  => undef,
                                        always_quote => 0;     # default
                                        
  # or to read a simple white space seperated file
  tie my @data, 'Tie::File', 'xyz.dat', sep_re       => qr/\s+/,
                                        sep_char     => ' ',
                                        quote_char   => undef,
                                        eol          => undef, # default
                                        escape_char  => undef,
                                        always_quote => 0;     # default
  
  $data[1][3] = 4;
  $data[-1][-1] = "last column in last line";
  
  $data[0] = [qw/Name Address Country Phone/];
  push @data, ["Gates", "Redmond",  "Washington", "0800-EVIL"];
  push @data, ["Linus", "Helsinki", "Finnland",   "0800-LINUX"];
  
  [NOT YET IMPLEMENTED]
  delete $data[3][2];

=head1 DESCRIPTION

C<Tie::File> represents a regular csv file as a Perl array of arrays.  
The first dimension of the represents the line-nr in the original file,
the second dimension represents the col-nr.
Both indices are starting with 0.
You can also access with the normal array value,
e.g. C<$data[-1][-1]> stands for the last field in the last line,
or C<@{$data[1]}> stands for the columns of the second line.

An empty field has the value C<''>, 
while a not existing field has the value C<undef>.
E.g. about the file

  "first field",,
  "last field"
  
  "the above line is empty"
  
we can say

  $data[0][0] eq "first field"
  $data[0][1] eq ""
  !defined $data[0][2] 
  
  $data[1][0] eq "last field"
  
  @{$data[1]}  # is an empty list ()
  !defined $data[1][0]

  $data[2][0] eq "the above line is empty"

  !defined $data[$x][$y] # for every $x > 3, $y any 
  
Note, that it is possible also, to change the data.

  $data[0][0]   = "first line, first column";
  $data[3][7]   = "anywhere in the world";
  $data[-1][-1] = "last line, last column";
  
  $data[0] = ["Last name", "First name", "Address"];
  push @data, ["Schleicher", "Janek", "Germany"];
  my @header = @{ shift @data };
  
You can't delete something,
but it will be implemented soon.
  
There's only a small part of the whole file in memory,
so this module will work also for large files.
Please look the L<Tie::File> module for any details,
as I use it to read the lines of the file.

But it won't work with large fields,
as all fields of one line are parsed,
even if you only want to get one field.

=head2 CSV options for tieing

Similar to C<Text::CSV_XS>,
you can add the following options:

=over

=item  quote_char   {default: "}
=item  eol          {default: undef},
=item  sep_char     {default: ,}
=item  escape_char  {default: "}
=item  always_quote {default: 0}

=back

Please read the documentation of L<Text::CSV_XS> for details.

Note, that the binary option isn't available.

In addition to have an easier working with files,
that aren't seperated with different characters,
e.g. sometimes one whitespace, sometimes more,
I added the sep_re option (defaults to C<undef>). 

If it is specified,
sep_char is ignored when reading,
instead something similar to split at the sepater is done
to find out the fields.

E.g.,
you can say

  tie my @data, 'Tie::File', 'xyz.dat', sep_re       => qr/\s+/,
                                        quote_char   => undef,
                                        eol          => undef, # default
                                        escape_char  => undef,
                                        always_quote => 0;     # default
                                        
to read something like

    PID TTY          TIME CMD
 1200 pts/0    00:00:00 bash
 1221 pts/0    00:00:01 nedit
 1224 pts/0    00:00:01 nedit
 1228 pts/0    00:00:06 nedit
 1318 pts/0    00:00:01 nedit
 1605 pts/0    00:00:00 ps

Note, that the value of sep_re must be a regexp object,
e.g. generated with C<qr/.../>.
A simple string produces an error.

Note also, that sep_char is used to write data.

=head2 EXPORT

None by default.

=head1 BUGS

The indirect write methods like
C<push @data, [1, 2]>,
C<push @{$data[3]}, ["a", "b"]> or
similar to slices aren't tested directly.
I hope that the implementation of L<Tie::Array> is
good enough for it.
It will be tested extensivly with the future versions.

This module is slow,
even slower than necessary with object oriented features.
I'll change it when implementing some more features.

Please inform me about every bug or missing feature of this module.

=head1 TODO

Implement deleting possibilities.

Possibility to give (memory) options at tieing,
like mode, memory, dw_size
similar to Tie::File.

Discuss differences to L<AnyData> module.

Implement binary mode.

Option like C<filter => sub { s/\s+/ / }>
that would specify a routine called
before a line is processed.
Perhaps even process is a sensfull name to this option.

Create constants for tabulator seperated, whitespace seperated, ... files.

Warn if sep_char isn't matched with a specified sep_re.

=head1 SEE ALSO

L<Tie::File>
L<Text::CSV>
L<Text::CSV_XS>
L<AnyData>

=head1 AUTHOR

Janek Schleicher, E<lt>big@kamelfreund.de<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Janek Schleicher

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
