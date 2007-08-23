package Wx::Perl::Packager::PDKWindow;
use Wx qw( :everything );
use strict;
use base qw(Wx::Frame);
use vars qw($VERSION);
$VERSION = 0.09;
          
use Wx::Event qw(   EVT_MENU EVT_CLOSE 
                    EVT_BUTTON );

my($ID_MENU_FILE_EXIT)=(5);

use Win32;
use Win32::TieRegistry( Delimiter=>"/", qw( REG_SZ
                                            REG_EXPAND_SZ
                                            REG_DWORD
                                            REG_BINARY
                                            REG_MULTI_SZ
                                            KEY_READ
                                            KEY_WRITE
                                            KEY_ALL_ACCESS ));        


sub new{
   if(not exists $_[3]){ $_[3] = 'Wx::Perl::Packager  PDK Helper';}
   if(not exists $_[4]){ $_[4] = wxDefaultPosition;}
   if(not exists $_[5]){ $_[5] = wxDefaultSize;}
   if(not exists $_[6]){ $_[6] = wxDEFAULT_FRAME_STYLE;}
   my( $this ) = shift->SUPER::new( @_ );
   $this->initBefore();
   $this->Show(0);
   EVT_CLOSE($this,\&OnClose);
   $this->{MenuBar}= Wx::MenuBar->new;
   $this->{mnuFile}=Wx::Menu->new;
   $this->{MenuBar}->Append($this->{mnuFile},'File');
   my($itemmenu) = Wx::MenuItem->new($this->{mnuFile},$ID_MENU_FILE_EXIT,"Exit",'',0);
   $this->{mnuFile}->AppendItem($itemmenu);
   $this->SetMenuBar($this->{MenuBar});
   EVT_MENU($this,$ID_MENU_FILE_EXIT,\&OnMnuFileExit);
   $this->{pnlMain} = Wx::Panel->new($this,-1,[0,0],[426,221],wxNO_BORDER|wxTAB_TRAVERSAL);
   $this->{lblMain} = Wx::StaticText->new($this->{pnlMain},-1,"",[10,10],[368,41],wxST_NO_AUTORESIZE);
   $this->{lblMain}->SetLabel('This PDK helper will prepare a default .perlapp file with the necessary bound wxPerl DLLs.');
   $this->{btnCreate} = Wx::Button->new($this->{pnlMain},-1,"",[267,84],[80,22]);
   $this->{btnCreate}->SetLabel('Create File');
   EVT_BUTTON($this,$this->{btnCreate},\&OnBtnCreate);
   $this->{szvFrame} = Wx::BoxSizer->new(wxVERTICAL);
   $this->{szvPanelMain} = Wx::BoxSizer->new(wxVERTICAL);
   $this->{szButton} = Wx::BoxSizer->new(wxHORIZONTAL);
 
   $this->{szvFrame}->Add($this->{pnlMain},1,wxTOP|wxLEFT|wxBOTTOM|wxRIGHT|wxEXPAND|wxADJUST_MINSIZE,0);
   $this->{szvPanelMain}->Add($this->{lblMain},0,wxTOP|wxLEFT|wxBOTTOM|wxRIGHT|wxEXPAND,10);
   $this->{szvPanelMain}->Add($this->{szButton},1,wxTOP|wxLEFT|wxBOTTOM|wxRIGHT|wxALIGN_RIGHT,4);
   $this->{szButton}->Add($this->{btnCreate},0,wxTOP|wxLEFT|wxBOTTOM|wxRIGHT|wxALIGN_BOTTOM,3);
   $this->SetSizer($this->{szvFrame});$this->SetAutoLayout(1);$this->Layout();
   $this->{pnlMain}->SetSizer($this->{szvPanelMain});$this->{pnlMain}->SetAutoLayout(1);$this->{pnlMain}->Layout();
   $this->Refresh();
   $this->initAfter();
   return $this;
}


sub OnBtnCreate{ 
   my( $this,$event) = @_;
   $this->Close() if !$this->create_perlapp();
} 

sub OnClose{ 
   my( $this,$event) = @_;
   $event->Skip(1);
   $this->Destroy;

} 

sub OnMnuFileExit{
   my( $this,$event) = @_;
   $this->Close;
} 

sub initBefore{
   my( $this) = @_;
   $this->{CONFDATA} = {};
}
sub initAfter{
    my( $this) = @_;
    $this->app_initialise;
    $this->SetIcon( Wx::Icon->new($this->packager_path() . 'packager.ico', wxBITMAP_TYPE_ICO) ); 
    $this->Centre;
    $this->Show(1);
}

sub app_initialise {
    my $this = shift;
    foreach ( @INC ) {
        my $path = "$_/Wx/Perl/Packager/packager.ico";
        if( -e  $path) {
          $path =~ s/packager\.ico$//;
          $this->packager_path($path);
          last;
        }
    }
    
}

sub packager_path {
    my $this = shift;
    if(@_) { $this->{CONFDATA}->{packager_path} = shift; }
    return $this->{CONFDATA}->{packager_path};
}

sub create_perlapp {
    my $this = shift;
    
    # Check where PerlApp is installed
    
    my $paipath = $this->get_perlapp_execpath();
    
    my $packerpath = $paipath;
    $packerpath =~ s/pai\.exe$/perlapp\.exe/;
    if(!$paipath) {
        Wx::MessageBox('Unable to locate path to PerlApp executable',
                      "Wx::Perl::Packager PDK Utility", 
                      wxOK|wxICON_ERROR|wxCENTRE, $this);
        return 0;
    }
    
    # GET FILEPATH
    my $filepath = undef;
    while (!$filepath) {
        $filepath = $this->get_file_name();
        if(!$filepath) {
            return 0 if $this->cancel_message('You have not selected a script to package');
        
        }
        
    }
    my @paths = split(/[\\\/]/, $filepath);
    my $scriptname = pop(@paths);
      
    my $scriptdir = join("\\", @paths);
    
    # SET PERLAPP
    my $apppath = undef;
    while (!$apppath) {
        $apppath = $this->get_perlapp_name($filepath);
        if(!$apppath) {
            return 0 if $this->cancel_message('You have not selected a name for the perlapp file.');
        
        }
        
    }
    
    # GET DLL PATHS
    my $wxpath = $Wx::wx_path;
    my $wxdlls = $Wx::dlls;
    
    # WRITE FILE
    open(FILE, ">$apppath");
    
    print FILE '#!' . $paipath . "\n";
    print FILE 'PAP-Version: 1.0' . "\n";
    
    print FILE 'Packer: ' . $packerpath . "\n";
    print FILE 'Script: ' . $scriptname . "\n";
    print FILE 'Cwd: ' . $scriptdir . "\n";
    
    foreach my $key (keys(%$wxdlls)) {
        my $bindline = 'Bind: ' . $wxdlls->{$key} . '[file=';
        $bindline .= $wxpath . "\\" . $wxdlls->{$key} . ',extract,mode=444]' . "\n";
        print FILE $bindline;
    }
    
    my $mingw32dll = qq($wxpath\\mingwm10.dll);
    if(-f $mingw32dll) {
        print FILE 'Bind: mingwm10.dll[file=' . $mingw32dll . ',extract,mode=444]' . "\n";
    }

    print FILE 'Clean: 0' ."\n";
        
    # create a datestamp
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    $mon += 1;

    my $datestamp = qq($year-);
    $datestamp .= sprintf("%02d", $mon) . '-' . sprintf("%02d", $mday);
    $datestamp .= ' ' . sprintf("%02d", $hour) . ':' . sprintf("%02d", $min) . ':' . sprintf("%02d", $sec);
    print FILE 'Date: ' . $datestamp . "\n";
    print FILE 'Debug: ' . "\n";
    print FILE 'Dependent: 0' . "\n";
    print FILE 'Dyndll: 0' . "\n";
    
    my $execname = $scriptname;
    $execname =~ s/(\.pl|\.pm)$/\.exe/;
    
    print FILE 'Exe: ' . $execname . "\n";
    print FILE 'Force: 0' . "\n";
    print FILE 'Gui: 1' . "\n";
    
    # GET THE HOSTAME
       
    print FILE 'Hostname: ' . lc(Win32::NodeName()) . "\n";
    print FILE 'No-Compress: 0' . "\n";
    print FILE 'No-Logo: 0' . "\n";
    print FILE 'Runlib: ' . "\n";
    print FILE 'Shared: none' . "\n";
    print FILE 'Tmpdir: ' . "\n";
    print FILE 'Verbose: 0' . "\n";
    print FILE 'Version-Comments: ' . "\n";
    print FILE 'Version-CompanyName: ' . "\n";
    print FILE 'Version-FileDescription: ' . "\n";
    print FILE 'Version-FileVersion: ' . "\n";
    print FILE 'Version-InternalName: ' . "\n";
    print FILE 'Version-LegalCopyright: ' . "\n";
    print FILE 'Version-LegalTrademarks: ' . "\n";
    print FILE 'Version-OriginalFilename: ' . "\n";
    print FILE 'Version-ProductName: ' . "\n";
    print FILE 'Version-ProductVersion: ' . "\n";
    print FILE 'Xclude: 0' . "\n";
    
    close(FILE);
    
    #launch perlapp
    
    $paipath = Win32::GetShortPathName($paipath);
    my $pdkcmd = '--packer ../perlapp.exe "' . $apppath . '"';
    #print qq(Running $paipath $pdkcmd ....\n\n);
    #system($paipath, $pdkcmd);
    wxTheApp->PDKExec($paipath);
    wxTheApp->PDKParams($pdkcmd);
    $this->Close();
 
}

sub get_file_name {
    my $this = shift;
    my $filepath = undef;
    
    my $flags;
    
    if ( Wx::wxVERSION() < 2.008000 ) {
        $flags = wxOPEN|wxFILE_MUST_EXIST|wxCENTRE;
    } else {
        $flags = wxFD_OPEN|wxFD_FILE_MUST_EXIST;
    }
    
    
    my $dialog = Wx::FileDialog->new
        ( $this, "Select a Perl script to package", '', '',
                 "Perl Scripts (*.pl, *.pm)|*.pl;*.pm|All Files (*.*)|*.*",
                  $flags );
        
    if( $dialog->ShowModal != wxID_CANCEL ) {
        $filepath = $dialog->GetPath;
    }
    $dialog->Destroy;
    return $filepath;
}

sub get_perlapp_name {
    my $this = shift;
    my $filepath = shift;
    
    my @paths = split(/[\\\/]/, $filepath);
    my $filename = pop(@paths);
    
    $filename =~ s/\.[^\.]*$//;
    $filename .= '.perlapp';
    
    my $directory = join('/', @paths);
    
    my $flags;
        
    if ( Wx::wxVERSION() < 2.008000 ) {
        $flags = wxSAVE|wxOVERWRITE_PROMPT|wxCENTRE;
    } else {
        $flags = wxFD_SAVE|wxFD_OVERWRITE_PROMPT;
    }
    
    
    my $dialog = Wx::FileDialog->new
        ( $this, "Select a name for the perlapp file", '', '',
                 "PerlApp file (*.perlapp)|*.perlapp",
                  $flags );
    
    $dialog->SetDirectory($directory);
    $dialog->SetFilename($filename);
    $dialog->SetPath($directory . '/' . $filename);
    
        
    if( $dialog->ShowModal != wxID_CANCEL ) {
        $filepath = $dialog->GetPath;
    }
    $dialog->Destroy;
    return $filepath;
}

sub cancel_message {
    my ($this, $msg) = @_;
    my $message = $msg . qq(\n\nDo you wish to exit the Wx::Perl::Packager PDK utility?);
    if(Wx::MessageBox($message,
                      "Wx::Perl::Packager PDK Utility", 
                      wxYES_NO|wxICON_QUESTION|wxCENTRE, $this) == wxYES) {
        return 1;
    } else {
        return 0;
    }
   
}

sub get_perlapp_execpath {
    my $this = shift;
    my $pai;
    
    # regkeys perl_auto_file / Perlapp.Project to return pai.exe or perlapp.exe
    
    my @keys = qw( perlapp_auto_file Perlapp.Project);
    
    for (@keys) {  
        my $regkey= $Registry->{"HKEY_CLASSES_ROOT/$_/Shell/Open/Command/"};
       
        my $path = $regkey->{"/"};
        if($path =~ /^"([^"]*)/) {
            my $filepath = $1;
            $filepath =~ s/perlapp.exe$/lib\\pai.exe/i;
            $pai = $filepath;
            last;
        }
    }
    if($pai && -e $pai) {
        return $pai;
    } else {
        # try program file dirs
        my @files = ( "$ENV{PROGRAMFILES}\\ActiveState Perl Dev Kit 7.0\\bin\\lib\\pai.exe", "$ENV{PROGRAMFILES}\\ActiveState Perl Dev Kit 6.0\\bin\\lib\\pai.exe" );
        for my $file (@files) {
            if( -e $file) {
                $pai = $file;
                last;
            }
        }
    }
    
    if($pai && -e $pai) {
        return $pai;
    } else {
        return undef;
    }
}

__END__

1;
