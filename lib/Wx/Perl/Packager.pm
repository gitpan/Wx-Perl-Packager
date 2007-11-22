package Wx::Perl::Packager;
use 5.008;
use strict;

our ( $VERSION, $_pconfig );

$VERSION = 0.11;

require Wx::Mini;
$_pconfig = {};
$_pconfig->{libpath} = $Wx::wx_path || '';
$_pconfig->{libpath} =~ s/\\/\//g;
$_pconfig->{runtime} = 'PERL';
$_pconfig->{packed} = 0;
$_pconfig->{mingwref} = undef;
$_pconfig->{pdkdir} = undef;
$_pconfig->{modules} = {};      # hash of available wx modules
$_pconfig->{loaded} = [];       # list of loaded wx modules
$_pconfig->{coredlls} = [];     # base core and adv modules
$_pconfig->{librefs} = [];      # refs to DLLs loaded by dynaloader
$_pconfig->{gdiplus} = { boundfile => 'gdilib/gdiplus.dll',
                         needload  => undef, };

# get our module details
foreach my $modulekey ( keys (%{ $Wx::dlls })) {
    my $filename;
    if( $modulekey =~ /(base|core|adv)/) {
        $filename = qq(wxcore/$Wx::dlls->{$modulekey});
    } else {
        $filename = $Wx::dlls->{$modulekey};
    }
        
    $_pconfig->{modules}->{$modulekey} =
                    { filename => $filename,
                      loaded => 0,
                      libref => undef,
                    };
}

if ($^O =~ /^MSWin/) {
    
    # gdiplus flag
    my ($windesc, $wvmajor, $wvminor) = Win32::GetOSVersion();
    $_pconfig->{gdiplus}->{needload} = ( ( $wvmajor < 5 ) || ( ( $wvmajor == 5 ) && ( $wvminor < 1 ) ) ) ? 1 : 0;

    # figure out which environment
    
    if(my $pdkversion = $PerlApp::VERSION) {
        # PerlApp::VERSION is definitive for PerlApp
        my $execname = PerlApp::exe();
        if($execname =~ /.*pdkcheck\.exe$/) {
            # this is the package time PDK Check
            $_pconfig->{runtime} = 'PDKCHECK';
            $_pconfig->{packed} = 0;
            my $pdkcompilepath = $_pconfig->{libpath};
            $pdkcompilepath =~ s/\//\\/g ;
            $ENV{PATH} = $pdkcompilepath . ';' . $ENV{PATH};
        } else {
            # this is a running PerlApp
            $_pconfig->{runtime} = 'PERLAPP';
            $_pconfig->{packed} = 1;
            
            # create unique dir for core wxWidgets DLLs
            {
                require DynaLoader;
                my $basekey = 'wxlib-' . getlogin() . qq(-$Wx::alien_key-$Wx::VERSION-);
                $basekey =~ s/[^A-Za-z0-9\-_]/_/g;
                my $filesum = 1;
                for('base','core','adv') {
                    my $module = $_pconfig->{modules}->{$_};
                    $module->{pdksource} = PerlApp::extract_bound_file($module->{filename});
                    $filesum += (stat($module->{pdksource}))[7];
                }
            
                $basekey .= sprintf("%x", $filesum);
                
                my $tempdir = $ENV{TEMP};
                $tempdir = Win32::GetShortPathName($tempdir);
                $tempdir =~ s/\\/\//g;
                $_pconfig->{pdkdir} = qq($tempdir/$basekey);
                mkdir($_pconfig->{pdkdir}, 0700) if(!-d $_pconfig->{pdkdir});
                
                # For PerlApp we have added gdiplus.dll as a bound file
                # but without extracting at startup.
                # We extract it, and move it
                if($_pconfig->{gdiplus}->{needload}) {
                    my $gdidllpath = PerlApp::extract_bound_file($_pconfig->{gdiplus}->{boundfile});
                    my $gditarget = qq($_pconfig->{pdkdir}/gdiplus.dll);
                    Win32::CopyFile($gdidllpath, $gditarget, 0) if(-e $gdidllpath );
                }
                
                # extract mingwm10.dll if it is in the dir
                my $mingwdll = PerlApp::extract_bound_file('wxcore/mingwm10.dll');
                my $targetmingwdll = qq($_pconfig->{pdkdir}/mingwm10.dll);
                
                if(-e $mingwdll ) {
                    Win32::CopyFile($mingwdll, $targetmingwdll, 0);  # will not overwrite existing file
                    $_pconfig->{mingwref} = DynaLoader::dl_load_file($targetmingwdll);
                }                
                
                for('base','core','adv') {
                    my $module = $_pconfig->{modules}->{$_};
                    my $sourcedll = $module->{pdksource};
                    my $targetdll = qq($_pconfig->{pdkdir}/$Wx::dlls->{$_});
                    if(-e $sourcedll) {
                        Win32::CopyFile($sourcedll, $targetdll, 0);  # will not overwrite existing file
                        $module->{libref} = DynaLoader::dl_load_file($targetdll);
                    }
                }
            }
        }
    } elsif($0 =~ /.+\.exe$/) {
        # in PARL packed executables $0 contains the exec name
        $_pconfig->{runtime} = 'PARLEXE';
        $_pconfig->{packed} = 1;
        
        # For PAR::Packer the cache directory
        # is already on the path so all we need do
        # is extract the gdiplus dll to there
        
        # If we are in PARL, then we have PAR
        
        my $pargdifilepath = qq($ENV{PAR_TEMP}/gdiplus.dll);
        
        if($_pconfig->{gdiplus}->{needload} && (!-e $pargdifilepath) ) {
            my $zip = PAR::par_handle($0);
            eval {
                $zip->memberNamed( $_pconfig->{gdiplus}->{boundfile} )->extractToFileNamed( $pargdifilepath );
            };
            $@ = '';
        }
            
        
        
    } elsif($^X !~ /(perl)|(perl\.exe)$/i) {
        # in other executables - packed or otherwise - $^X contains the exec name - not '(w)perl'
        $_pconfig->{runtime} = 'PERL2EXE';
        $_pconfig->{packed} = 1;        
    }
    
    
    # If we need to define an empty wx_path
    
    if( $_pconfig->{packed} || ( $_pconfig->{runtime} eq 'PDKCHECK' ) ) {
        $Wx::wx_path = '';
    }
    
    # If we need to handle wx module load
    
    if( $_pconfig->{packed} ) {
        
        # set the Wx load subs
        require Wx;
        Wx::set_load_function( sub { my $modulekey = shift;
                        my $module = $_pconfig->{modules}->{$modulekey};
                        # don't load twice
                        return if( $module->{loaded} );
                        Wx::_load_file( $module->{filename} );
                        $module->{loaded} = 1;
                        push( @{ $_pconfig->{loaded} }, $module->{filename});
                        1; } );

        Wx::set_end_function( sub {
                        while( my $module = pop @{ $_pconfig->{loaded} } ) {
                            Wx::_unload_plugin( $module );
                        }
                        1; } );     
                        
    } elsif( $_pconfig->{runtime} eq 'PDKCHECK' ) {
        
        require Wx;
        Wx::set_load_function( sub { 1; } );
        Wx::set_end_function ( sub { 1; } );
    }  
    
}

sub runtime {
    return $_pconfig->{runtime};
}

sub packaged {
    return $_pconfig->{packed};
}

sub get_wxpath {
    return $_pconfig->{libpath};
}

sub get_wxlibraries {
    my @libfiles = ();
    return @libfiles if $_pconfig->{packed};
    if( $_pconfig->{libpath} && (-d $_pconfig->{libpath}) ) {
        opendir(WXDIR, $_pconfig->{libpath}) or die qq(Could not open $_pconfig->{libpath}: $!);
        my @files = grep { /\.(so|dll)$/ } readdir(WXDIR);
        closedir(WXDIR);
        for (@files) {
            push( @libfiles, qq($_pconfig->{libpath}/$_) ) if($_ ne 'gdiplus.dll' );
        }   
    }
    return @libfiles;
}

sub get_wxboundfiles {
    my @libfiles = ();
    return @libfiles if $_pconfig->{packed};
    my @files = get_wxlibraries();
    
    for (@files) {
        my $filepath = $_;
        my @vals = split(/[\\\/]/, $filepath);
        my $filename = pop(@vals);
        for( 'adv', 'core', 'base' ) {
            if( ($_pconfig->{modules}->{$_}->{filename} =~ /$filename$/) || ( $filename eq 'mingwm10.dll' ) ) {
                $filename = qq(wxcore/$filename);
            }
        }
        
        push( @libfiles, { boundfile   => $filename,
                           autoextract => 1,
                           file        => $filepath,
                         }
            );
    }
    
    # addgdiplus lib
    my $gdipluspath = $_pconfig->{libpath};
    $gdipluspath =~ s/lib$/os\/gdiplus.dl_/i;
    if( -e $gdipluspath ) {
        push( @libfiles, { boundfile   => $_pconfig->{gdiplus}->{boundfile},
                           autoextract => 0,
                           file        => $gdipluspath
                           }
            );
    }
    return @libfiles;
}

END {
    for('adv','core','base') {
        my $libref = $_pconfig->{modules}->{$_}->{libref};
        DynaLoader::dl_unload_file( $libref ) if $libref;
    }
    DynaLoader::dl_unload_file( $_pconfig->{mingwref} ) if $_pconfig->{mingwref};
}

    
=head1 NAME

Wx::Perl::Packager

=head1 VERSION

Version 0.11

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
    
    To start perlapp gui run 'wxpdk' without any arguments.
    
    To use perlapp from the command line you can use wxpdk to create argument file
    
    wxpdk -A argfile.args
    
    then:
    
    perlapp @argfile.args--norunlib --dyndll --gui --exe foo.exe foo.pl
    
    To create a full .perlapp file without loading GUI
    
    wxpdk -S foo.pl -P foo.parlapp
    
    All options to wxpdk are
    
    -S    scriptname to package
    -P    perlapp file to write
    -A    args file to write with wxPerl dependencies
    -H    print these options

    Wx::Perl::Packager now supports the --dyndll option for PerlApp. The wxWidgets DLLs
    are not themselves dynamically loaded.
    
    Wx::Perl::Packager does not support the --clean option for PerlApp
    
    Wx::Perl::Packager works with PerlApp by moving the following extracted bound
    wxWidgets files to a separate temp directory:
    
    base
    core
    adv
    mingwm10.dll if present
    gdiplus.dll if needed by OS.
    
    The name of the directory is created using the logged in username, wxWidgets versions
    the file sizes of the wxWidgets DLLs. This ensures that your application gets the
    correct Wx dlls whilst also ensuring that only one temp directory is ever created
    for a unique set of wxWidgets DLLs
    
    base, core, adv and mingwm10.dll should be bound as wxcore/dllname.dll.
    All other wxWidgets dlls should be bound as 'dllname.dll'.
    
    The wxpdk utility takes care of this for you.

   
    For PAR

    run 'wxpar' exactly as you would run pp.
    
    e.g.  wxpar --gui --icon=myicon.ico -o myprog.exe myscript.pl
    
    NOTE: For PAR::Packer, if you are distributing wxWidgets libs with
    GDI+ support (wxGraphicsContext) and you don't use wxpar, you must
    distribute gdiplus.dll separately for those Windows operating systems
    that require it. If you use wxpar and the Alien::wxWidgets PPM's from
    http://www.wxperl.co.uk/ it is packaged for you and loaded where the
    operating system requires.

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
    
    #perl2exe_bundle C:/Perl/site/lib/Alien/wxWidgets/msw_2_8_7_uni_gcc_3_4/lib/wxmsw28u_core_gcc_wxperl.dll
    #perl2exe_bundle C:/Perl/site/lib/Alien/wxWidgets/msw_2_8_7_uni_gcc_3_4/lib/wxbase28u_gcc_wxperl.dll

=head1 DESCRIPTION

    This module assists in packaging wxPerl applications using PerlApp, PAR and Perl2Exe.
    Usage is simple:  use Wx::Perl::Packager;
    The module also provides methods, some of which are probably only useful during
    the packaging process.

    Also provided are:
    
    wxpdk
    wxpar
        
    which assist in packaging the wxWidgets DLLs.

=head2 GDI+

    Recent versions of wxWidgets may require access to GDI+.
    This is part of the operating system for MS Windows XP and later. For earlier
    versions of Windows, a redistributable of gdiplus.dll is required and
    available from MS.
    You should bind this to your executable as
    
    gdilib/gdiplus.dll
    
    For PDK/PerlApp - do not automatically extract at runtime.
    For PAR, add using --addfile option.
    
    If you do this, Wx::Perl::Packager will determine the operating system version
    at runtime and extract gdiplus.dll to the path if the host OS requires
    it.
    
    If you are using recent PPM packages from http://www.wxperl.co.uk, the
    gdiplus.dll is included.
    
    Running wxpar or wxpdk will pick up the gdiplus.dllautomatically and
    package it correctly.

=head2 Methods

=item Wx::Perl::Packager::runtime()

    returns PERLAPP, PARLEXE, PERL2EXE or PERL to indicate how the script was executed.
    (Under PerlApp, pp packaged PAR, Perl2Exe or as a Perl script.

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
    
    boundfile   =>  the relative name of the file when bound (e.g mydir/myfile.dll)
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

Copyright 2006,2007 Mark Dootson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Wx::Perl::Packager

__END__

