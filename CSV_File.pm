package Tie::CSV_File;

use strict;
use warnings;

require Exporter;

use Data::Dumper;
use Tie::Array;
use Text::CSV_XS;
use Tie::File;
use Params::Validate qw/:all/;
use Carp;

our @ISA = qw(Exporter Tie::Array);

our $VERSION = '0.16';

# There's a common misspelling of sepArated (an E instead of A)
# That's why all csv file definitions are defined even with an E and an A
sub __mispell($) {
    shift =~ /^(.*_SEP)A(RATED)/;
    return "$1E$2";
}

# Export all predefined file types
our @EXPORT = map {($_, __mispell $_)}
              map {$_ . "_SEPARATED"}
              qw/TAB COLON SEMICOLON PIPE WHITESPACE/;

use constant SPLIT_SEPARATED_STANDARD_OPTIONS => (
     quote_char   => undef,
     eol          => undef, # default
     escape_char  => undef,
     always_quote => 0     # default
);

use constant SEPARATOR_CHARS => (
    [TAB       => "\t"],
    [COLON     => ":"],
    [SEMICOLON => ";"],
    [PIPE      => "|"]
);

# Create typical file format constants,
# only different on their seperator chars
foreach (SEPARATOR_CHARS) {     
    my ($name, $char) = @$_;
    $name .= "_SEPARATED";
    eval "use constant $name => (sep_char => \$char, 
                                 SPLIT_SEPARATED_STANDARD_OPTIONS)";
    (my $name_with_spelling_mistake = $name) =~ s/(?<=SEP)A(?=RATED)/E/;
    eval "*$name_with_spelling_mistake = *$name";
};

use constant WHITESPACE_SEPARATED => (
     sep_re       => qr/\s+/,
     sep_char     => ' ',
     quote_char   => undef,
     eol          => undef, # default
     escape_char  => undef,
     always_quote => 0     # default
);
*WHITESPACE_SEPERATED = *WHITESPACE_SEPARATED;
#              ^                       ^        you see the difference

sub TIEARRAY {
    my ($class, $fname) = (shift(), shift());
    
    # Parameter validation
    my %options = validate( @_, {
        quote_char   => {default => q/"/,  type => SCALAR | UNDEF},
        eol          => {default => undef,    type => SCALAR | UNDEF},
        sep_char     => {default => q/,/,  type => SCALAR | UNDEF},
        sep_re       => {default => undef, isa  => 'Regexp'},
        escape_char  => {default => q/"/,  type => SCALAR | UNDEF},
        always_quote => {default => 0,     type => SCALAR | UNDEF}
    });
    
    $options{binary} = 1;   # to handle with 'ä','ö','ü' and so on, not for "\n"
    
    # Check for some cases to warn
    unless( defined $options{sep_char} ) {
        carp "The sep_char should either be defined or not mentioned, ".
             "but I got something like sep_char => undef\n" .
             "It's interpreted as the default value ',' (a comma)!";
        $options{sep_char} = ',';
    }
    unless ( (my $l = length $options{sep_char}) == 1) {
        carp "The sep_char should have a length of 1, not $l"
    }
    
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
    my @csv_options = map {$self->{$_}} qw/csv eol sep_char sep_re/;
    tie my @fields, 'Tie::CSV_File::Line', $self->{lines}, $line_nr, @csv_options;
    return \@fields;
}

sub STORE {
    my ($self, $line_nr, $columns) = @_;
    my $csv = $self->{csv};
    if (@$columns) {
        $csv->combine(@$columns) or die "Can't store " . Dumper($columns);
        $self->{lines}->[$line_nr] = $csv->string;
    } else {
        $self->{lines}->[$line_nr] = $self->{eol} || '';
    }
}

sub DELETE {
    my ($self, $line_nr) = @_;
    delete $self->{lines}->[$line_nr];
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
        $csv->parse($line) and push @fields, $csv->fields();
        if (defined( my $sep_char = $self->{sep_char} )) {
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

sub DELETE {
    my ($self, $col_nr) = @_;
    $self->STORE($col_nr,"");
}

1;
__END__

=head1 NAME

Tie::CSV_File - ties a csv-file to an array of arrays

=head1 SYNOPSIS

  use Tie::CSV_File;

  tie my @data, 'Tie::CSV_File', 'xyz.dat';
  print "Data in 3rd line, 5th column: ", $data[2][4];
  untie @data;
  
  # or to read a tabular, or a whitespace or a (semi-)colon separated file
  tie my @data, 'Tie::CSV_File', 'xyz.dat', TAB_SEPARATED;
  # or  use instead COLON_SEPARATED, SEMICOLON_SEPARATED, PIPE_SEPARATED,
  #         or even WHITESPACE_SEPARATED
  
  # or to read something own defined
  tie my @data, 'Tie::CSV_File', 'xyz.dat', sep_char     => '|',
                                            sep_re       => qr/\s*\|\s*/,
                                            quote_char   => undef,
                                            eol          => undef, # default
                                            escape_char  => undef,
                                            always_quote => 0;  # default
                                            
  $data[1][3] = 4;
  $data[-1][-1] = "last column in last line";
  
  $data[0] = [qw/Name Address Country Phone/];
  push @data, ["Gates", "Redmond",  "Washington", "0800-EVIL"];
  push @data, ["Linus", "Helsinki", "Finnland",   "0800-LINUX"];
  
  delete $data[3][2];

=head1 DESCRIPTION

C<Tie::CSV_File> represents a regular csv file as a Perl array of arrays.  
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
  
Please pay attention that deleting an array element has a slightly
different meaning to the normal behaviour.
Deleting an element set the element empty ("" or []),
but not undef.

  delete $data[5];    # similar to $data[5] = [];
  delete $data[5][5]; # similar to $data[5][5] = "";

In fact, in a file there is no value undefined.
A cell of the CSV-File can only be empty ("").
Undefined values signalizes that the line or the column doesn't exist.
Especially the lines C<,,,> and C<"","","",""> are the same for
C<Tie::CSV_File> and the second version could be changed
without a warning to the first one when you write to the tied array.
  
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
that aren't separated with different characters,
e.g. sometimes one whitespace, sometimes more,
I added the sep_re option (defaults to C<undef>). 

If it is specified,
sep_char is ignored when reading,
instead something similar to split at the sepater is done
to find out the fields.

E.g.,
you can say

  tie my @data, 'Tie::CSV_File', 'xyz.dat', sep_re       => qr/\s+/,
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

Note also, that C<sep_char> is used to write data.
As the name suggests C<sep_char> should only consists of one char.
It gives you a warning if you try something else.

=head2 Predefined file types

Without any options you define a standard csv file.
However, tabular separated, colon separated and whitespace separated files
are also commonly used, so they are predefined.
That's why it's possible to say:

  tie my @data, 'Tie::CSV_File', 'xyz.dat', TAB_SEPARATED;
  tie my @data, 'Tie::CSV_File', 'xyz.dat', COLON_SEPARATED;
  tie my @data, 'Tie::CSV_File', 'xyz.dat', SEMICOLON_SEPARATED;
  tie my @data, 'Tie::CSV_File', 'xyz.dat', PIPE_SEPARATED;
  tie my @data, 'Tie::CSV_File', 'xyz.dat', WHITESPACE_SEPARATED;

There's a common mistake writing C<SEPARATED>. Often there's written 
C<SEPERATED> (with an E at the 4th letter instead of an A).
In fact, up till version 0.11, this module had also this spelling mistake
implemented. As this module tries to be friendly (and backward compatible), 
it also accepts the (in this way) mispelled versions of predefined file types.
Thanks a lot to Harald Fuchs who found this typo.

=over 

=item TAB_SEPARATED

It's defined with:

     sep_char     => "\t",
     quote_char   => undef,
     eol          => undef, # default
     escape_char  => undef,
     always_quote => 0     # default
     
Note, that the data isn't allowed to contain any tab.

=item COLON_SEPARATED

It's defined with:

     sep_char     => ":",
     quote_char   => undef,
     eol          => undef, # default
     escape_char  => undef,
     always_quote => 0     # default

Note, that the data isn't allowed to contain any colon.

=item SEMICOLON_SEPARATED

It's defined with:

     sep_char     => ";",
     quote_char   => undef,
     eol          => undef, # default
     escape_char  => undef,
     always_quote => 0     # default

Note, that the data isn't allowed to contain any colon.

Allthough that looks very similar to CSV files,
SEMICOLON_SEPARATED doesn't quote data and can't work
properly with quoted data. If you want just a normal
CSV file with semicolons instead of commas,
just write

  tie my @data, 'Tie::CSV_File', 'xyz.dat', sep_char => ";";

=item PIPE_SEPARATED

It's defined with:

     sep_char     => "|",
     quote_char   => undef,
     eol          => undef, # default
     escape_char  => undef,
     always_quote => 0     # default

Note, that the data isn't allowed to contain any pipe delimeter.

=item WHITESPACE_SEPARATED

It's defined with:

     sep_re       => qr/\s+/,
     sep_char     => ' ',
     quote_char   => undef,
     eol          => undef, # default
     escape_char  => undef,
     always_quote => 0     # default

Note that it reads with splitting at all whitespace sequences.
Especially it's not possible to define an empty field.
Note also, that when setting an element,
all whitespace sequences are transformed to a simple blank.

=back

Of course, you can overwrite some options.
E.g., let's assume that you have a whitespace separated file,
but you want to write a tab instead of a blank when changing the data.
That can be done with:

   tie my @data, 'Tie::CSV_File', 'xyz.dat', WHITESPACE_SEPARATED, sep_char => "\t";


Please suggest me other useful file types,
I could predeclare.

=head2 EXPORT

By default these constants are exported:

  TAB_SEPARATED
  COLON_SEPARATED
  SEMICOLON_SEPARATED
  PIPE_SEPARATED
  WHITESPACE_SEPARATED

(There are also some mispelled versions of these filetypes
 exported, please look at the documentation for predefined file types
 for details).

=head1 BUGS

This module is slow,
even slower than necessary with object oriented features.
I'll change it when implementing some more features.

This module expects that the tied file doesn't change
from anywhere else as this module when it is tied.
But the file isn't locked, so it's your job to take care about.

Please inform me about every bug or missing feature of this module.

=head1 TODO

Possibility to give (memory) options at tieing,
like mode, memory, dw_size
similar to Tie::File.

Discuss differences to L<AnyData> module.

Discuss differenced to L<DBD::CSV> module.

Implement binary mode.

Option like C<filter => sub { s/\s+/ / }>
that would specify a routine called
before a line is processed.
Perhaps even process is a sensfull name to this option.

Warn if sep_char isn't matched with the specified sep_re.

=head1 THANKS

Thanks a lot to Harald Fuchs,
who found the typos in

  *_SEPARATED
       ^
      (there had been an E instead of an A)

=head1 SEE ALSO

L<Tie::File>
L<Text::CSV>
L<Text::CSV_XS>
L<AnyData>
L<DBD::CSV>

=head1 AUTHOR

Janek Schleicher, E<lt>bigj@kamelfreund.de<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2002 by Janek Schleicher

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
