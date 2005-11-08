use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'CGI::Cookie::Pack',
    'VERSION_FROM' => 'Pack.pm',
    'PREREQ_PM'    => {
        'CGI::Uricode' => '0.07',
    },
    ($] >= 5.005 ? (
        'ABSTRACT' => 'Pack in/out a large number of parameters to a small number of cookies',
        'AUTHOR'   => 'Masanori HATA <http://go.to/hata>',
        ) : ()),
);
