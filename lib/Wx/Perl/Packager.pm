package Wx::Perl::Packager;

use 5.008;
use strict;
use Wx 0.49;
require Exporter;

our @ISA = qw(Exporter);

use vars qw($VERSION $WXDLLS @LOADEDWINDLLS $RUNTIME $PACKED @PDKCHECKDLLS);

$VERSION = 0.02;
our @EXPORT = qw();

$WXDLLS = {};
@LOADEDWINDLLS = ();
$PACKED = 0;

=head1 NAME

Wx::Perl::Packager

=head1 VERSION

Version 0.02


=head1 SYNOPSIS

    For PerlApp/ PDK
    
    At the start of your script ...
    
    #!c:path/to/perl.exe
    BEGIN { use Wx::Perl::Packager; }
    .....
    
    Then to start perlapp run 'wxpdk'
    
    
    For PAR

    At the start of your script ...

    #!c:path/to/perl.exe
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
    
    #perl2exe_bundle C:/Perl/site/lib/Alien/wxWidgets/msw_2_6_3_uni_mslu_cl_0/lib/wxmsw26u_core_vc_custom.dll
    #perl2exe_bundle C:/Perl/site/lib/Alien/wxWidgets/msw_2_6_3_uni_mslu_cl_0/lib/wxbase26u_vc_custom.dll
    
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
    
    require Wx;
    
    foreach my $dllkey ( keys (%{ $Wx::dlls })) {
        $WXDLLS->{$dllkey} = { filename => $Wx::dlls->{$dllkey},
                               loaded => 0,
                              };
    }

    if(my $pdkversion = $PerlApp::VERSION) {
        # PerlApp::VERSION is definitive for PerlApp
        my $execname = PerlApp::exe();
        if($execname =~ /.*pdkcheck\.exe$/) { 
            $RUNTIME = 'PDKCHECK';
            __prepare_for_pdk_check();
        } else {
            $RUNTIME = 'PERLAPP';
            $PACKED = 1;
            
        }
    } elsif($0 =~ /.+\.exe$/) {
        # in PARL packed executables $0 contains the exec name
        $RUNTIME = 'PARLEXE';
        $PACKED = 1;
        
    } elsif($^X !~ /(perl)|(perl\.exe)$/i) {
        # in other executables - packed or otherwise - $^X contains the exec name - not 'perl'
        $RUNTIME = 'PERL2EXE';
        $PACKED = 1;
    } else {
        $RUNTIME = 'PERL';
    }
    
    if($PACKED) {

        Wx::set_load_function( sub { my $dllkey = shift;
                        
                        # don't load twice
                        return if($WXDLLS->{$dllkey}->{loaded});
                        my $dllfile = $WXDLLS->{$dllkey}->{filename};
                        Wx::_load_file( $dllfile );

                        $WXDLLS->{$dllkey}->{loaded} = 1;

                        push(@LOADEDWINDLLS, $dllfile);
                        1; } );

        Wx::set_end_function( sub {
                        while( my $module = pop @LOADEDWINDLLS) {
                            Wx::_unload_plugin( $module );
                        }

                        1; } );
                        
    } elsif($RUNTIME eq 'PDKCHECK') {
        
        Wx::set_load_function( sub { my $dllkey = shift; 1; } );
        Wx::set_end_function( sub { 
                                while(my $libref = pop(@PDKCHECKDLLS) ){
                                    DynaLoader::dl_unload_file( $libref );
                                }
            
                         1; } );
    }
                    
                        
} else {
    # not mswin
    $RUNTIME = 'PERL';
}

sub runtime {
    return $RUNTIME;
}

sub __prepare_for_pdk_check {
    my $pdkcompilepath = $Wx::wx_path;
    $pdkcompilepath =~ s/\//\\/g ;
    $ENV{PATH} = $pdkcompilepath . ';' . $ENV{PATH};
}


=head1 AUTHOR

Mark Dootson, C<< <mdootson at cpan.org> >>

=head1 DOCUMENTATION

You can find documentation for this module with the perldoc command.

    perldoc Wx::Perl::Packager

=head1 ACKNOWLEDGEMENTS

Mattia Barbon for wxPerl.

=head1 COPYRIGHT & LICENSE

Copyright 2006 Mark Dootson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Wx::Perl::Packager

__END__

