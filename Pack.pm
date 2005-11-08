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
our $VERSION = '0.11'; # 2005-11-08 (since 2003-04-09)
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

Object-Class method. This method internally using new(), monolith() and decompose() methods. Simply using this method, you will get unpacked parameters. You may utilize unpacked parameters to input into a hash (%).

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

The algorithm is simple as L<CGI::Cookie> do. First, all strings of parameters (both of C<KEY> and C<VALUE>) are uri-escaped. By uri-escape, most of sign characters (including "&" sign) are escaped to "%HH" string. While that, "&" sign can be safely used in "Set-Cookie: " HTTP header because it is a "token" character (for the definition of "token", refer to RFC 2616 L<http://www.ietf.org/rfc/rfc2616.txt>). So second, all uri-escaped parameters (both of C<KEY> and C<VALUE>) are joined by "&" sign as separator to make a single string. Third, at last, name of cookie (of course it is also uri-escaped) and that united string are combined by "=" sign as separater.

If total size of the string excess 4096 bytes limit, the string is splitted to some cookies. Names of each splitted cookies are serialized by following "_" (underbar character) and two digit number. That is, names of cookies are to become like C<$name_XX>. Note that still in a case total size of the string do not excess 4096 byte limit, name of the cookie has serial number (C<$name_00>).

Exceptionally, under monolith mode, splitting won't do. Also cookie name serializing won't.

=cut

sub compose () {
    my $self = shift;
    
    my $name = $self->{'name'};
    unless ($name) {
        croak "The name of cookie is not omittable";
    }
    
    uri_escape($name);
    foreach my $string (@{ $self->{'param'} }) {
        uri_escape($string);
    }
    
    my $value = join '&', @{ $self->{'param'} };
    
    if ($self->{'monolith'} > 0) {
        my $n_v = "$name=$value";
        if (length($n_v) > 4096) {
            carp "Size of the cookie is over 4096 bytes"
        }
        return $n_v;
    }
    else {
        _cutter($name, $value);
    }
}

sub _cutter ($$) {
    my($name, $value) = @_;
    
    my $limit = 4096 - length($name) - 4; # 4 = length("_XX=")
    
    my @value;
    while ($value) {
        my $part;
        if (length($value) >= $limit) {
            $part  = substr($value, 0, $limit);
            $value = substr($value, $limit);
        }
        else {
            $part  = $value;
            $value = '';
        }
        push @value, $part;
    }
    
    if ($#value > 19) {
        if ($#value > 99) {
            croak "Overflowed number of the cookies (max 100)";
        }
        else {
            carp "Number of the cookies is over 20";
        }
    }
    
    for (my $i = 0; $i <= $#value; $i++ ) {
        my $serial = sprintf('%02d', $i);
        $value[$i] = $name . "_$serial=$value[$i]";
    }
    
    return @value;
}

=item decompose()

Object method. Decompose parameters from composed cookie(s).

The algorithm is the reversed procedure of composing. First, take out united string from splitted cookies in $ENV{'HTTP_COOKIE'}, and then separate it to individual parameters. Second, uri-unescape all strings of parameters (both of C<KEY> and C<VALUE>).

You could implement the above procedure also at the client side with JavaScript.

Note that monolith mode would affect decomposing procedure, too.

=cut

sub decompose () {
    my $self = shift;
    
    my $value;
    if ($self->{'monolith'} > 0) {
        $value = $ENV{'HTTP_COOKIE'};
        $value =~ s/^.*?=//;
    }
    else {
        my @cookie = split /[\s\t]*;[\s\t]*/, $ENV{'HTTP_COOKIE'};
        
        my @ordered;
        foreach my $cookie (@cookie) {
            my($name, $fragment) = split /=/, $cookie;
            $name =~ s/^.*?_(\d{2})$/$1/;
            $ordered[$name] = $fragment;
        }
        $value = join '', @ordered;
    }
    
    my @param = split /&/, $value;
    
    foreach my $string (@param) {
        uri_unescape($string);
    }
    
    return @param;
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

