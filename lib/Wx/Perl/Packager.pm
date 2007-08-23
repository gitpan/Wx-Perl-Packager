package Wx::Perl::Packager;

use 5.008;
use strict;
use Wx 0.49;

our ($VERSION, %_wxpack_wxdlls, @_wxpack_loadeddlls, $_wxpack_packed, $_wxpack_runtime);

$VERSION = 0.09;

=head1 NAME

Wx::Perl::Packager

=head1 VERSION

Version 0.09


=head1 SYNOPSIS

    For PerlApp/ PDK
    
    At the start of your script ...
    
    #!c:/path/to/perl.exe
    BEGIN { use Wx::Perl::Packager; }
    .....
    
    Then to start perlapp run 'wxpdk'
    
    
    For PAR

    At the start of your script ...

    #!c:/path/to/perl.exe
    BEGIN { use Wx::Perl::Packager; }
    .....

    Then to start pp run 'wxpar' exactly as you would run pp.
    
    e.g.  wxpar --gui --icon=myicon.ico -o myprog.exe myscript.pl
        
    For Perl2Exe
    
    At the start of your script ...
    
    #!c:path/to/perl.exe
    BEGIN { use Wx::Perl::Packager; }
    use Wx::Perl::Packager;
    
    within your script include markers for each of the
    wxWidgets DLLs
    
    e.g
    
    #perl2exe_bundle C:/Perl/site/lib/Alien/wxWidgets/msw_2_8_3_uni_cl_0/lib/wxmsw26u_core_vc_custom.dll
    #perl2exe_bundle C:/Perl/site/lib/Alien/wxWidgets/msw_2_8_3_uni_cl_0/lib/wxbase26u_vc_custom.dll
    
=cut
    
=head1 DESCRIPTION

    A module to assist packaging Wx based applications with PAR, 
    ActiveState PerlApp / PDK and Perl2Exe. All that is needed is 
    that you include a 'use' statement as the first item in your 
    BEGIN blocks. For Perl2Exe, an additional 'use' statement 
    outside any BEGIN block ensures correct object cleanup.
    
    Also provided are:
    
    wxpdk
    wxpar
        
    which assist in packaging the wxWidgets DLLs. 
    

=cut

if ($^O =~ /^MSWin/) {
    
    if(my $pdkversion = $PerlApp::VERSION) {
        # PerlApp::VERSION is definitive for PerlApp
        my $execname = PerlApp::exe();
        if($execname =~ /.*pdkcheck\.exe$/) {
            # this is the package time PDK Check
            $_wxpack_runtime = 'PDKCHECK';
            $_wxpack_packed = 0;
            my $pdkcompilepath = $Wx::wx_path;
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
    } else {
        $_wxpack_runtime = 'PERL';
        $_wxpack_packed = 0;
    }
    
    if( $_wxpack_packed || ( $_wxpack_runtime eq 'PDKCHECK' ) ) {
        require Wx::Mini;
        $Wx::Mini::wx_path = '';
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

