use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Tie::CSV_File',
    'VERSION_FROM'	=> 'CSV_File.pm', # finds $VERSION
    'PREREQ_PM'		=> {
        'Text::CSV_XS'    => 0,
        'Tie::File'       => 0,
        
        'Test::Exception' => 0,
        'Test::More'      => 0,
        'File::Temp'      => 0
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (AUTHOR     => 'Janek Schleicher <bigj@kamelfreund.de>') : ()),
);
