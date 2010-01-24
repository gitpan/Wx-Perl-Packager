###################################################################################
# Distribution    Wx::Perl::Packager
# File            Wx/Perl/Packager.pm
# Description:    Assist packaging wxPerl applicatons
# File Revision:  $Id: Packager.pm 33 2010-01-23 15:18:22Z  $
# License:        This program is free software; you can redistribute it and/or
#                 modify it under the same terms as Perl itself
# Copyright:      Copyright (c) 2006 - 2010 Mark Dootson
###################################################################################

package Wx::Perl::Packager;
use 5.008;
use strict;
use warnings;
require Exporter;
use base qw( Exporter );

our $VERSION = '0.18';

our $_require_overwite = 0;
our $_debug_print_on   = $ENV{WXPERLPACKAGER_DEBUGPRINT_ON} || 0;
our $handler;

#-----------------------------------------------
# Flag to force some cleanup on MSW
#-----------------------------------------------

$_require_overwite = 0;

for (@ARGV) {
    $_require_overwite = 1 if $_ eq '--force-overwrite-wx-libraries';
    $_debug_print_on   = 1 if $_ eq '--set-wx-perl-packager-debug-on';
}

&_start;

sub _start {
    #-----------------------------------------------
    # Main Handling
    #-----------------------------------------------  
    
    require Wx::Mini;
    require Wx::Perl::Packager::Mini;
    
    if ($^O =~ /^mswin/i) {
        require Wx::Perl::Packager::MSWin;
        $handler = Wx::Perl::Packager::MSWin->new;
    } elsif($^O =~ /^linux/i) {
        require Wx::Perl::Packager::Linux;
        $handler = Wx::Perl::Packager::Linux->new;
    } elsif($^O =~ /^darwin/i) {
        require Wx::Perl::Packager::MacOSX;
        $handler = Wx::Perl::Packager::MacOSX->new;
    } else {
        warn 'Wx::Perl:Packager is not implemented on this operating system';
    }
        
    $handler->configure if $handler;
    
    $handler->post_configure if $handler;
}

END {
    my $mainthread = 1;
    eval {
        my $threadid = threads->tid();
        $mainthread = ( $threadid ) ? 0 : 1;
        print STDERR qq(Thread ID $threadid\n) if $_debug_print_on;
    };
    $handler->cleanup_on_exit if( $handler && $mainthread );
}

#-----------------------------------------------
# Some utilities (retained for backwards compat)
#-----------------------------------------------

sub runtime {
    return $handler->get_config->get_runtime;
}

sub packaged {
    return $handler->get_config->get_packaged;
}

sub get_wxpath {
    return $handler->get_config->get_wx_load_path;
}

sub get_wxlibraries {
    my @libfiles = ();
    return @libfiles if packaged();
    my $libpath = get_wxpath();
    if( $libpath && (-d $libpath) ) {
        opendir(WXDIR, $libpath) or die qq(Could not open Wx Library Path : $libpath: $!);
        my @files = grep { /\.(so|dll)$/ } readdir(WXDIR);
        closedir(WXDIR);
        for (@files) {
            push( @libfiles, qq($libpath/$_) ) if($_ ne 'gdiplus.dll' );
        }   
    }
    return @libfiles;
}

sub get_wxboundfiles {
    my @libfiles = ();
    return @libfiles if packaged();
    my @files = get_wxlibraries();
    
    for (@files) {
        my $filepath = $_;
        my @vals = split(/[\\\/]/, $filepath);
        my $filename = pop(@vals);
        
        push( @libfiles, { boundfile   => $filename,
                           autoextract => 1,
                           file        => $filepath,
                         }
            );
    }
    return @libfiles;
}


=head1 NAME

Wx::Perl::Packager

=head1 VERSION

Version 0.18

=head1 SYNOPSIS

    Assist packaging wxPerl applications on Linux (GTK)  and MSWin
    
    For PerlApp/PDK and PAR
    
    At the start of your script ...
    
    #!/usr/bin/perl
    use Wx::Perl::Packager;
    use Wx;
    .....
    
    or if you use threads with your application
    #!/usr/bin/perl
    use threads;
    use threads::shared;
    use Wx::Perl::Packager;
    use Wx;

=head1 TEST

    There is a test script at Wx/Perl/Packager/resource/packtest.pl that you can
    use to test your packaging method. (i.e. package it);
    
=head1 DESCRIPTION

    Wx::Perl::Packager must be loaded before any part of Wx so should appear at the
    top of your main script. If you load any part of Wx in a BEGIN block, then you
    must load Wx::Perl::Packager before it in your first BEGIN block. This may cause
    you problems if you use threads within your Wx application. The threads
    documentation advises against loading threads in a BEGIN block - so don't do it.
    
=head2 For PerlApp on MS Windows
    
    putting Wx::Perl:Packager at the top of your script as described above should be
    all that is required for recent versions of PerlApp.

=head2 For PerlApp on Linux
    
    if you are using the PPMs from http://www.wxperl.co.uk/repository ( add this
    to your repository list), packaging with PerlApp is possible.
    
    You must add each wxWidgets dll that you use as a bound file.
    e.g. <perlpath>/site/lib/Alien../wxbase28u_somename.so
    should be bound simply as 'wxbase28u_somename.so' and should be
    set to extract automatically.
    
    YOU MUST also bind <perlpath>/site/lib/auto/Wx/Wx.so as
    'wxmain.so' alongside your wxwidgets modules. This is the current work around
    for a segmentation fault when PerlApp exits. Hopefully there will be
    a better solution soon.  
    
=head2 PerlApp General
    
    Wx::Perl::Packager does not support the --dyndll option for PerlApp.
    
    Wx::Perl::Packager does not support the --clean option for PerlApp
    
    Wx::Perl::Packager works with PerlApp by moving the following bound or included
    wxWidgets files to a separate temp directory:
    
    base
    core
    adv
    mingwm10.dll if present
    gdiplus.dll if needed by OS.
    wxmain.so (required on linux)
    
    The name of the directory is created using the logged in username, and the full path
    of the executable. This ensures that your application gets the correct Wx dlls whilst
    also ensuring that only one permanent temp directory is ever created for a unique set
    of wxWidgets DLLs
    
    All the wxWidgets dlls and mingwm10.dll should be bound as 'dllname.dll'.
    (i.e. not in subdirectories)
    
    The wxpdk utility takes care of this for you for PDK versions less than 8.x
    For PDK versions 8 and above, wxpdk should not be used.

=head2 For PAR
    
    run 'wxpar' exactly as you would run pp.
    
    e.g.  wxpar --gui --icon=myicon.ico -o myprog.exe myscript.pl
    
    Also provided are:
    
    wxpdk (PerlApp version 7.x and below )
    wxpar
    
    which assist in packaging the wxWidgets DLLs.

=head2 Nasty Internals
    
    see comments in Wx:Perl::Packager::Linux

=head2 Methods

=item Wx::Perl::Packager::runtime()

    returns PERLAPP, PARLEXE, or PERL to indicate how the script was executed.
    (Under PerlApp, pp packaged PAR, or as a Perl script.

    my $env = Wx::Perl::Packager::runtime();

=item Wx::Perl::Packager::packaged()

    returns 1 or 0 (for true / false ) to indicate if script is running packaged or as
    a Perl script.

    my $packaged = Wx::Perl::Packager::packaged();

=item Wx::Perl::Packager::get_wxpath()

    returns the path to the directory where wxWidgets library modules are stored.
    Only useful when packaging a script.

    my $wxpath = Wx::Perl::Packager::get_wxpath();

=item Wx::Perl::Packager::get_wxboundfiles()

    returns a list of hashrefs where the key value pairs are:
    
    boundfile   =>  the relative name of the file when bound (e.g myfile.dll)
    file        =>  the source file on disc
    autoextract =>  0/1  should the file be extracted on startup
    
    Only useful when packaging a script. If called within a packaged script,
    returns an empty list. In addition to the wxWidgets dlls, this function
    will also return the external and required bound location of the
    gdiplus.dll if present in Alien::wxWidgets. If bound to the packaged
    executable at the required location, Wx::Perl::Packager will ensure that
    gdiplus.dll is on the path if your packaged executable is run on an
    operating system that requires it.
    
    my %wxlibs = Wx::Perl::Packager::get_wxboundfiles();

=item Wx::Perl::Packager::get_wxlibraries()

    This function is deprecated. Use get_wxboundfiles() instead.
    
    returns a list of the full path names of all wxWidgets library modules.
    Only useful when packaging a script. If called within a packaged script,
    returns an empty list.
    
    Use Wx::Perl::Packager::get_wxlibraries();
    my @wxlibs = Wx::Perl::Packager::get_wxlibraries();


=head1 AUTHOR

Mark Dootson, C<< <mdootson at cpan.org> >>

=head1 DOCUMENTATION

You can find documentation for this module with the perldoc command.

    perldoc Wx::Perl::Packager

=head1 ACKNOWLEDGEMENTS

Mattia Barbon for wxPerl.

=head1 COPYRIGHT & LICENSE

Copyright 2006 - 2010 Mark Dootson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

# End of Wx::Perl::Packager

__END__

