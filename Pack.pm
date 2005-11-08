package CGI::Cookie::Pack;
########################################################################
# Copyright (c) 2003-2005 Masanori HATA. All rights reserved.
# <http://go.to/hata>
########################################################################

#### Pragmas ###########################################################
use 5.008;
use strict;
use warnings;
#### Standard Libraries ################################################
require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(
    datetime_cookie
);

use Carp;
########################################################################

#### Module Dependencies ###############################################
use CGI::Uricode qw(uri_decode uri_escape uri_unescape);
########################################################################

#### Constants #########################################################
our $VERSION = '0.10'; # 2005-11-08 (since 2003-04-09)
########################################################################

=head1 NAME

CGI::Cookie::Pack - Pack in/out a large number of parameters to a small number of cookies.

=head1 SYNOPSIS

 use CGI::Cookie::Pack;
 
 # send cookies over HTTP which have composed parameters.
 @cookie = CGI::Cookie::Pack->packin(
     name  => 'packed',
     param => [
         name    => 'Masanori HATA'           ,
         mail    => 'lovewing@dream.big.or.jp',
         sex     => 'male'                    ,
         birth   => '2003-04-09'              ,
         nation  => 'Japan'                   ,
         pref    => 'Saitama'                 ,
         city    => 'Kawaguchi'               ,
         tel     => '+81-48-2XX-XXXX'         ,
         fax     => '+81-48-2XX-XXXX'         ,
         job     => 'student'                 ,
         role    => 'president'               ,
         hobby   => 'exaggeration'            ,
         ],
     );
 foreach my $cookie (@cookie) {
     print "Set-Cookie: $cookie\n";
 }
 print "Content-Type: text/html\n\n";
 
 # receive cookies over HTTP and get decomposed parameters.
 %param = CGI::Cookie::Pack->packout;

=head1 DESCRIPTION

With this module HTTP Cookie can transport more parameters than usual. In the ordinary way, a cookie can content one NAME and VALUE pair, then the combined NAME and VALUE string have size limit of 4096 bytes. In addition to that, there can be 20 cookies at most per server of domain. So in short, it can store only 20 parameters! Creation of this module is to intend to break through that limit.

=head1 METHODS

=over

=item packin(name => $name, param => [%param])

Object-Class method. This method internally using new(), name(), param(), monolith() and compose() methods. Simply using this method specified with some arguments, you will get packed combined NAME and VALUE string(s).

The arguments, C<name> and C<param> is not omittable. Value of C<param> argument must quoted by the square brackets to pass its anonymous reference as an array (however, you can use hash in the brackets).

Argument C<monolith> is optional. If you would compose a monolithic cookie even if it excessed 4096 bytes limit, give value of C<monolith> a positive number.

 packin(name => $name, param => [%param], monlith => 1)

=cut

sub packin (%) {
    my($class, %argv) = @_;
    my $self = $class->new;
    
    $self->param(@{ $argv{'param'} });
    
    if ($argv{'name'}) {
        $self->name($argv{'name'});
    }
    if ($argv{'monolith'}) {
        $self->monolith($argv{'monolith'});
    }
    
    $self->compose;
}

=item packout()

Object-Class method. This method internally using new(), monolith() and decompose() methods. Simply using this method specified with some arguments, you will get unpacked parameters.

Argument C<monolith> is optional. If you would decompose a monolithic composed cookie, you must give value of C<monolith> a positive number.

=cut

sub packout (%) {
    my($class, %argv) = @_;
    my $self = $class->new;
    
    if ($argv{'monolith'}) {
        $self->monolith($argv{'monolith'});
    }
    
    $self->decompose;
}

=item new()

Class method. Constructor.

=cut

sub new () {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    
    # default value
    $self->{'monolith'} = 0;
    
    return $self;
}

=item name($name)

Object method. Give name to the composed cookie.

=cut

sub name ($) {
    my $self = shift;
    
    $self->{'name'} = shift;
    
    return $self;
}

=item param(@param)

Object method. Give parameters to compose.

=cut

sub param (@) {
    my $self = shift;
    
    @{ $self->{'param'} } = @_;
    
    return $self;
}

=item monolith($num)

Object method. If you give a positive number, cookie will compose/decompose as a monolithic one. If you give 0 (default) or a negative number, cookie will not compose/decompose as a monolithic one.

=cut

sub monolith ($) {
    my($self, $argv) = @_;
    
    if ($argv) {
        $self->{'monolith'} = $argv;
    }
    else {
        $self->{'monolith'} = 0;
    }
    
    return $self;
}

=item compose()

Object method. Compose cookie(s).

The algorithm is realized by twice character escape. First, C<NAME> and C<VALUE> strings are PEA escaped. PEA escape is escape "%", "=" and "&" characters to "%P", "%E" and "%A" character squences. Then, each C<NAME> and C<VALUE> are paired with "=" character, and these all C<NAME=VALUE> pairs are joined with "&" character to a string. Second, the name of cookie (be given by name() method) and the joined C<NAME=VALUE> pairs string are uri-escaped, and then each uri-escaped strings are paired with "=" character.

If total size of the string excess 4096 bytes limit, the string is splitted to some cookies. Names of each splitted cookies are serialized by following "_" (underbar character) and two digit number. That is, names of cookies are to become like C<$name_XX>. Note that still in a case total size of the string do not excess 4096 byte limit, name of the cookie has serial number (C<$name_00>).

Exceptionally, under monolith mode, splitting won't do. Also cookie name serializing won't.

=cut

sub compose () {
    my $self = shift;
    
    my $Name = $self->{'name'};
    unless ($Name) {
        croak "The name of cookie is not omittable";
    }
    
    my @avjointed;
    for (my $i = 0; $i < $#{ $self->{'param'} }; $i += 2) {
        my($attr, $value) = (${ $self->{'param'} }[$i], ${ $self->{'param'} }[$i + 1]);
        
        _escape_PEA($attr );
        _escape_PEA($value);
        
        push @avjointed, "$attr=$value";
    }
    my $Value = join '&', @avjointed;
    
    uri_escape($Name );
    uri_escape($Value);
    
    if ($self->{'monolith'} > 0) {
        my $NeV = "$Name=$Value";
        if (length($NeV) > 4096) {
            carp "Size of the cookie is over 4096 bytes"
        }
        return $NeV;
    }
    else {
        _cutter($Name, $Value);
    }
}
# escape "%" (Percentage sign), "=" (Equal sign) and "&" (Ampersand sign)
sub _escape_PEA ($) {
    utf8::encode($_[0]);
    
    $_[0] =~ s/%/%P/g;
    $_[0] =~ s/=/%E/g;
    $_[0] =~ s/&/%A/g;
    
    utf8::decode($_[0]);
    return 1;
}

sub _cutter ($$) {
    my($Name, $Value) = @_;
    
    my $limit = 4096 - length($Name) - 4; # 4 = length("_XX=")
    
    my @Value;
    while ($Value) {
        my $part;
        if ( length($Value) >= $limit) {
            $part  = substr($Value, 0, $limit);
            $Value = substr($Value, $limit);
        }
        else {
            $part  = $Value;
            $Value = '';
        }
        push @Value, $part;
    }
    
    if ($#Value > 19) {
        if ($#Value > 99) {
            croak "Overflowed number of the cookies (max 100)";
        }
        else {
            carp "Number of the cookies is over 20";
        }
    }
    
    for (my $i = 0; $i <= $#Value; $i++ ) {
        my $serial = sprintf('%02d', $i);
        $Value[$i] = $Name . "_$serial=$Value[$i]";
    }
    
    return @Value;
}

=item decompose()

Object method. Decompose parameters from composed cookie(s).

The algorithm is the reversed procedure of composing. First, take out uri-escaped string from splitted cookies in $ENV{'HTTP_COOKIE'}, and then uri-unescape it. Second, extract from that uri_unescaped string to C<NAME> and C<VALUE> pairs, and then PEA unescape them.

You could implement the above procedure also at the client side with JavaScript.

Note that monolith mode would affect decomposing procedure, too.

=cut

sub decompose () {
    my $self = shift;
    
    my $Value;
    if ($self->{'monolith'} > 0) {
        $Value = $ENV{'HTTP_COOKIE'};
        $Value =~ s/^.*?=//;
    }
    else {
        my @cookie = split /[\s\t]*;[\s\t]*/, $ENV{'HTTP_COOKIE'};
        
        my @ordered;
        foreach my $cookie (@cookie) {
            my($Name, $Value) = split /=/, $cookie;
            $Name =~ s/^.*?_(\d{2})$/$1/;
            $ordered[$Name] = $Value;
        }
        $Value = join '', @ordered;
    }
    
    uri_unescape($Value);
    
    my @avjointed = split /&/, $Value;
    
    my @a_v;
    for (my $i = 0; $i <= $#avjointed; $i++) {
        my($attr, $value) = split /=/, $avjointed[$i];
        
        _unescape_PEA($attr );
        _unescape_PEA($value);
        
        push @a_v, ($attr, $value);
    }
    
    return @a_v;
}
# unescape "%" (Percentage sign), "=" (Equal sign) and "&" (Ampersand sign)
sub _unescape_PEA ($) {
    utf8::encode($_[0]);
    
    $_[0] =~ s/%A/&/g;
    $_[0] =~ s/%E/=/g;
    $_[0] =~ s/%P/%/g;
    
    utf8::decode($_[0]);
    return 1;
}

=item datetime_cookie($unix_time)

Exportable function. This function returns date-time string which is formatted with Netscape Cookie Specification L<http://wp.netscape.com/newsref/std/cookie_spec.html>. C<$unix_time> is offset in seconds from the unix epoch time (1970-01-01 00:00:00 UTC).

=cut

sub datetime_cookie ($) {
    my $time  = shift;
    
    my($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
      gmtime($time);
    
    $year += 1900;
    $mon  = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$mon];
    $wday = qw(Sun Mon Tue Wed Thu Fri Sat)[$wday];
    foreach my $digit ($mday, $hour, $min, $sec) {
        $digit = sprintf('%02d', $digit);
    }
    
    return "$wday, $mday-$mon-$year $hour:$min:$sec GMT";
}

########################################################################
1;
__END__

=head1 SEE ALSO

=over

=item Netscape: L<http://wp.netscape.com/newsref/std/cookie_spec.html> (Cookie)

=item RFC 2965: L<http://www.ietf.org/rfc/rfc2965.txt> (Cookie)

=item HTML 4: L<http://www.w3.org/TR/html4/interact/forms.html#h-17.13.4.1> (uri-encode)

=back

=head1 AUTHOR

Masanori HATA L<http://go.to/hata> (Saitama, JAPAN)

=head1 COPYRIGHT

Copyright (c) 2003-2005 Masanori HATA. All rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

