package Tie::CSV_File;

use strict;
use warnings;

require Exporter;

use Tie::Array;
use Text::CSV_XS;
use Tie::File;

our @ISA = qw(Exporter Tie::Array);

# nothing to export

our $VERSION = '0.01';

sub TIEARRAY {
    my ($class, $fname) = @_;
    tie my @lines, 'Tie::File', $fname or die "Can't open $fname: $!";
    my $self = {
        lines => \@lines,
        csv   =>  Text::CSV_XS->new()
    };
    bless $self, $class;
}

sub FETCHSIZE {
    my ($self) = @_;
    return scalar( @{ $self->{lines} } );
}

sub FETCH {
    my ($self, $line_nr) = @_;
    my $line   = $self->{lines}->[$line_nr];
    my $csv = $self->{csv};
    $csv->parse($line)
        ?   do { my @fields = $csv->fields();
                 return \@fields
               }
        :   return [];   # an unparseable part is empty, but not undefined!!
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
  
  [NOT YET IMPLEMENTED]
  $data[1][3] = 4;
  $data[-1][-1] = "last column in last line";
  push @data, [qw/Jan Feb Mar/];
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
  
Note, that it isn't possible yet to change the data.

There's only a small part of the whole file in memory,
so this module will work also for large files.
Please look the L<Tie::File> module for any details,
as I use it to read the lines of the file.

But it won't work with large fields,
as all fields of one line are parsed,
even if you only want to get one field.

=head2 EXPORT

None by default.

=head1 TODO

Implement a writable array of arrays.

Possibility to give options at tieing,
like quote_char, esc_char, sep_char, binary, mode, memory, dw_size.

=head1 SEE ALSO

L<Tie::File>
L<Text::CSV>
L<Text::CSV_XS>

=head1 AUTHOR

Janek Schleicher, E<lt>big@kamelfreund.de<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Janek Schleicher

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
