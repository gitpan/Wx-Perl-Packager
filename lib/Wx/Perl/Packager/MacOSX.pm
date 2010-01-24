###################################################################################
# Distribution    Wx::Perl::Packager
# File            Wx/Perl/Packager/MacOSX.pm
# Description:    module for MacOSX specific handlers
# File Revision:  $Id: MacOSX.pm 35 2010-01-24 08:30:07Z  $
# License:        This program is free software; you can redistribute it and/or
#                 modify it under the same terms as Perl itself
# Copyright:      Copyright (c) 2006 - 2010 Mark Dootson
###################################################################################
package Wx::Perl::Packager::MacOSX;
use strict;
use warnings;
require Wx::Perl::Packager::Base;
use base qw(  Wx::Perl::Packager::Base );

our $VERSION = '0.18';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    
    return $self;
}

1;
