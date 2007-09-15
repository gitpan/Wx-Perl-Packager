package Wx::Perl::Packager;

use 5.008;
use strict;
use Wx 0.49;

our ( $VERSION, %_wxpack_wxdlls, @_wxpack_loadeddlls, $_wxpack_packed, 
      $_wxpack_runtime, $_wxlibpath, $_wxlibfiles );

$VERSION = 0.10;

require Wx::Mini;
$_wxlibpath = $Wx::wx_path;
$_wxlibpath =~ s/\\/\//g;

$_wxlibfiles = [];
if(-d $_wxlibpath ) {
    opendir(WXDIR, $_wxlibpath) or die qq(Could not open $_wxlibpath: $!);
    my @files = grep { /\.(so|dll)$/ } readdir(WXDIR);
    closedir(WXDIR);
    for (@files) {
        my $filepath = qq($_wxlibpath/$_);
        push( @{ $_wxlibfiles }, $filepath );
    }
}

$_wxpack_runtime = 'PERL';
$_wxpack_packed = 0;

if ($^O =~ /^MSWin/) {
    
    if(my $pdkversion = $PerlApp::VERSION) {
        # PerlApp::VERSION is definitive for PerlApp
        my $execname = PerlApp::exe();
        if($execname =~ /.*pdkcheck\.exe$/) {
            # this is the package time PDK Check
            $_wxpack_runtime = 'PDKCHECK';
            $_wxpack_packed = 0;
            my $pdkcompilepath = $_wxlibpath;
            $pdkcompilepath =~ s/\//\\/g ;
            $ENV{PATH} = $pdkcompilepath . ';' . $ENV{PATH};
        } else {
            # this is a running PerlApp
            $_wxpack_runtime = 'PERLAPP';
            $_wxpack_packed = 1;
        }
    } elsif($0 =~ /.+\.exe$/) {
        # in PARL packed executables $0 contains the exec name
        $_wxpack_runtime = 'PARLEXE';
        $_wxpack_packed = 1;
        
    } elsif($^X !~ /(perl)|(perl\.exe)$/i) {
        # in other executables - packed or otherwise - $^X contains the exec name - not '(w)perl'
        $_wxpack_runtime = 'PERL2EXE';
        $_wxpack_packed = 1;
        
    }
    
    if( $_wxpack_packed || ( $_wxpack_runtime eq 'PDKCHECK' ) ) {
        require Wx::Mini;
        $Wx::wx_path = '';
        foreach my $dllkey ( keys (%{ $Wx::dlls })) {
            $_wxpack_wxdlls{$dllkey} = { filename => $Wx::dlls->{$dllkey},
                                  loaded => 0,
                                };
        }
    }
    
    if( $_wxpack_packed ) {
        
        require Wx;
        Wx::set_load_function( sub { my $dllkey = shift;
                        
                        # don't load twice
                        return if( $_wxpack_wxdlls{$dllkey}->{loaded} );
                        my $dllfile = $_wxpack_wxdlls{$dllkey}->{filename};
                        Wx::_load_file( $dllfile );
                        $_wxpack_wxdlls{$dllkey}->{loaded} = 1;
                        push(@_wxpack_loadeddlls, $dllfile);
                        1; } );

        Wx::set_end_function( sub {
                        while( my $module = pop @_wxpack_loadeddlls ) {
                            Wx::_unload_plugin( $module );
                        }
                        1; } );
                        
    } elsif( $_wxpack_runtime eq 'PDKCHECK' ) {
        
        require Wx;
        Wx::set_load_function( sub { 1; } );
        Wx::set_end_function( sub { 1; } );
        
    }
}

sub runtime {
    return $_wxpack_runtime;
}

sub packaged {
    return $_wxpack_packed;
}

sub get_wxpath {
    return $_wxlibpath;
}

sub get_wxlibraries {
    return @{ $_wxlibfiles };
} 

=head1 NAME

Wx::Perl::Packager

=head1 VERSION

Version 0.10

=head1 SYNOPSIS

    For All Packagers:
    
    At the start of your script ...
    
    #!c:/path/to/perl.exe
    use Wx::Perl::Packager;
    .....
    
    or if you use threads with your application
    #!c:/path/to/perl.exe
    use threads;
    use threads::shared;
    use Wx::Perl::Packager;
    
    Wx::Perl::Packager must be loaded before any part of Wx so should appear at the
    top of your main script. If you load any part of Wx in a BEGIN block, then you
    must load Wx::Perl::Packager before it in your first BEGIN block. This may cause
    you problems if you use threads within your Wx application. The threads
    documentation advises against loading threads in a BEGIN block - so don't do it.
    
    For PerlApp
    
    To start perlapp run 'wxpdk'
   
    For PAR

    run 'wxpar' exactly as you would run pp.
    
    e.g.  wxpar --gui --icon=myicon.ico -o myprog.exe myscript.pl

    For Perl2Exe
    
    At the start of your script ...
    
    #!c:/path/to/perl.exe
    BEGIN { use Wx::Perl::Packager; }
    use Wx::Perl::Packager;
    
    Note that for Perl2Exe if you load Wx::Perl::Packager within a BEGIN block, you
    must also 'use' it outside the BEGIN block. The version of Perl2Exe that I
    tested does not seem to parse BEGIN blocks.
    
    within your script include markers for each of the
    wxWidgets DLLs
    
    e.g
    
    #perl2exe_bundle C:/Perl/site/lib/Alien/wxWidgets/msw_2_8_3_uni_cl_0/lib/wxmsw26u_core_vc_custom.dll
    #perl2exe_bundle C:/Perl/site/lib/Alien/wxWidgets/msw_2_8_3_uni_cl_0/lib/wxbase26u_vc_custom.dll

=head1 DESCRIPTION

    This module assists in packaging wxPerl applications using PerlApp, PAR and Perl2Exe.
    Usage is simple:  use Wx::Perl::Packager;
    The module also provides methods, some of which are probably only useful during
    the packaging process.

    Also provided are:
    
    wxpdk
    wxpar
        
    which assist in packaging the wxWidgets DLLs. 

=head2 Methods

=item Wx::Perl::Packager::runtime()

    returns PERLAPP, PARLEXE, PERL2EXE or PERL to indicate how the script is begin run.
    (Under PerlApp, pp packaged PAR, Perl2Exe or as a Perl script.

    my $env = Wx::Perl::Packager::runtime();

=item Wx::Perl::Packager::packaged()

    returns 1 or 0 (for true / false ) to indicate if script is running packaged or as
    a Perl script;

    my $packaged = Wx::Perl::Packager::packaged();

=item Wx::Perl::Packager::get_wxpath()

    returns the path to the directory where wxWidgets library modules are stored.
    Only useful when packaging a script;

    my $wxpath = Wx::Perl::Packager::get_wxpath();

=item Wx::Perl::Packager::get_wxlibraries()

    returns a list of the full path names of all wxWidgets library modules.
    Only useful when packaging a script. If called within a packaged script,
    returns an empty list;

    my @wxlibs = Wx::Perl::Packager::get_wxlibraries();


=head1 AUTHOR

Mark Dootson, C<< <mdootson at cpan.org> >>

=head1 DOCUMENTATION

You can find documentation for this module with the perldoc command.

    perldoc Wx::Perl::Packager

=head1 ACKNOWLEDGEMENTS

Mattia Barbon for wxPerl.

=head1 COPYRIGHT & LICENSE

Copyright 2006,2007 Mark Dootson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Wx::Perl::Packager

__END__

