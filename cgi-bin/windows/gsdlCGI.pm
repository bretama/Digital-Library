package gsdlCGI;

# This file merges Michael Dewsnip's gsdlCGI.pm for GS2 and Quan Qiu's gsdlCGI4gs3.pm (GS3)

use strict; 
no strict 'subs';
no strict 'refs'; # allow filehandles to be variables and viceversa

use CGI;
use Cwd;
use MIME::Base64;

@gsdlCGI::ISA = ( 'CGI' ); 

our $server_software;
our $server_version;

sub BEGIN {
    $server_software = $ENV{'SERVER_SOFTWARE'};

    if (defined $server_software) {
	if ($server_software =~ m/^Microsoft-IIS\/(.*)$/) {
	    $server_version = $1;
	}
    }
}


sub prenew {
    my $class = shift @_;
       
    my $version;
    if (-e "gsdl3site.cfg") {
	$version = 3;
    } else {
	$version = 2;
    }

    my $self = {};

    if ($version == 2) {
	$self->{'site_filename'} = "gsdlsite.cfg";
	$self->{'greenstone_version'} = 2;
    } 
    elsif ($version == 3) {
	$self->{'site_filename'} = "gsdl3site.cfg";
	$self->{'greenstone_version'} = 3;
    }
    
    my $bself = bless $self, $class;

    $bself->setup_gsdl();

    return $bself;
}


sub new {
    my $class = shift @_;
    
    my $self;
   
    # We'll determine the correct config file in this constructor itself 
    # and use it to determine the Greenstone server's version. 
    # Perhaps later, another test can be used for finding out what version 
    # of the Greenstone server we are working with.
    my $version;
    if (-e "gsdl3site.cfg") {
	$version = 3;
    } else {
	$version = 2;
    }

    # POST that is URL-encoded (like a GET) is a line that needs to be read from STDIN
    if ((defined $ENV{'CONTENT_TYPE'}) && ($ENV{'CONTENT_TYPE'} =~ m/form-urlencoded/)) {
	my $line = <STDIN>;
	if ((defined $line) && ($line ne "")) { 
	    $self = new CGI($line);
	}
    }
    
    # If the conditions above did not hold, then self=new CGI(@_) 
    if (!defined $self) { 
	# It's a GET, or else a POST with Multi-part body
	$self = new CGI(@_);
    }


    if ($version == 2) {
	$self->{'site_filename'} = "gsdlsite.cfg";
	$self->{'greenstone_version'} = 2;
    } 
    elsif ($version == 3) {
	$self->{'site_filename'} = "gsdl3site.cfg";
	$self->{'greenstone_version'} = 3;
    }
    
    return bless $self, $class;
}


sub parse_cgi_args
{
    my $self = shift @_;
    my $xml = (defined $self->param("xml")) ? 1 : 0;

    $self->{'xml'} = $xml;

    my @var_names = $self->param;
    my @arg_list = ();
    foreach my $n ( @var_names ) {
	my $arg = "$n=";
	my $val =  $self->param($n);
	$arg .= $val if (defined $val);
	push(@arg_list,$arg);
    }
	
    $self->{'args'} = join("&",@arg_list);
}


sub clean_param
{
    my $self = shift @_;
    my ($param) = @_;

    my $val = $self->SUPER::param($param);
    $val =~ s/[\r\n]+$// if (defined $val);

    return $val;
}

sub safe_val
{
    my $self = shift @_;
    my ($val) = @_;

    # convert any encoded entities to true form
    $val =~ s/&amp;/&/osg;
    $val =~ s/&lt;/</osg;
    $val =~ s/&gt;/>/osg;
    $val =~ s/&quot;/\"/osg;
    $val =~ s/&nbsp;/ /osg;


    # ensure only alpha-numeric plus a few other special chars remain

    $val =~ s/[^[:alnum:]@\.\/\- :_]//g if (defined $val); 

    return $val;
}

sub generate_message
{
    my $self = shift @_;
    my ($message) = @_;


    binmode(STDOUT,":utf8");    
    print STDOUT "Content-type:text/plain\n\n$message";
}

sub generate_error
{
    my $self = shift @_;
    my ($mess) = @_;
    
    my $xml = $self->{'xml'};

    my $full_mess;
    my $args = $self->{'args'};

    if ($xml) {
	# Make $args XML safe
	my $args_xml_safe = $args;
	$args_xml_safe =~ s/&/&amp;/g;

	$full_mess =  "<Error>\n";
	$full_mess .= "  $mess\n";
	$full_mess .= "  CGI args were: $args_xml_safe\n";
	$full_mess .= "</Error>\n";
    }
    else {
	$full_mess = "ERROR: $mess\n  ($args)\n";
    }

    $self->generate_message($full_mess);

    die $full_mess;
}

sub generate_warning
{
    my $self = shift @_;
    my ($mess) = @_;
    
    my $xml = $self->{'xml'};

    my $full_mess;
    my $args = $self->{'args'};

    if ($xml) {
	# Make $args XML safe
	my $args_xml_safe = $args;
	$args_xml_safe =~ s/&/&amp;/g;

	$full_mess =  "<Warning>\n";
	$full_mess .= "  $mess\n";
	$full_mess .= "  CGI args were: $args_xml_safe\n";
	$full_mess .= "</Warning>\n";
    }
    else {
	$full_mess = "Warning: $mess ($args)\n";
    }

    $self->generate_message($full_mess);

    print STDERR $full_mess;
}


sub generate_ok_message
{
    my $self = shift @_;
    my ($mess) = @_;
    
    my $xml = $self->{'xml'};

    my $full_mess;

    if ($xml) {
	$full_mess =  "<Accepted>\n";
	$full_mess .= "  $mess\n";
	$full_mess .= "</Accepted>\n";
    }
    else {
	$full_mess = "$mess";
    }
 
    $self->generate_message($full_mess);
}



sub get_config_info {
    my $self = shift @_;
    my ($infotype, $optional) = @_;

    my $site_filename = $self->{'site_filename'};
    open (FILEIN, "<$site_filename") 
	|| $self->generate_error("Could not open $site_filename");

    my $config_content = "";
    while(defined (my $line = <FILEIN>)) {
	$config_content .= $line;
    }
    close(FILEIN);

    my ($loc) = ($config_content =~ m/^$infotype\s+((\".+\")|(\S+))\s*\n/m);
    $loc =~ s/\"//g if defined $loc;

    if ((!defined $loc) || ($loc =~ m/^\s*$/)) {
	if((!defined $optional) || (!$optional)) {
	    $self->generate_error("$infotype is not set in $site_filename");
	}
    }

    return $loc;
}

sub get_gsdl3_src_home{
    my $self = shift @_;
    if (defined $self->{'gsdl3srchome'}) {
	return $self->{'gsdl3srchome'};
    }

    my $gsdl3srchome = $self->get_config_info("gsdl3srchome");

    if(defined $gsdl3srchome) {
	$gsdl3srchome =~ s/(\/|\\)$//; # remove trailing slash
    }
    $self->{'gsdl3srchome'} = $gsdl3srchome;

    return $gsdl3srchome;
}


sub get_gsdl_home {
    my $self = shift @_;
    
    if (defined $self->{'gsdlhome'}) {
	return $self->{'gsdlhome'};
    }

    my $gsdlhome = $self->get_config_info("gsdlhome");

    $gsdlhome =~ s/(\/|\\)$//; # remove trailing slash

    $self->{'gsdlhome'} = $gsdlhome;

    return $gsdlhome;
}

sub get_gsdl3_home {
    my $self = shift @_;
    my ($optional) = @_;
    
    if (defined $self->{'gsdl3home'}) {
	return $self->{'gsdl3home'};
    }

    my $gsdl3home = $self->get_config_info("gsdl3home", $optional);

    if(defined $gsdl3home) {
	$gsdl3home =~ s/(\/|\\)$//; # remove trailing slash
	$self->{'gsdl3home'} = $gsdl3home;
    }
    return $gsdl3home;
}

sub get_java_home {
    my $self = shift @_;
    my ($optional) = @_;
    
    if (defined $self->{'javahome'}) {
	return $self->{'javahome'};
    }

    my $javahome = $self->get_config_info("javahome", $optional);
    if(defined $javahome) {
	$javahome =~ s/(\/|\\)$//; # remove trailing slash
	$self->{'javahome'} = $javahome;
    }
    return $javahome;
}

sub get_perl_path {
    my $self = shift @_;
    my ($optional) = @_;
    
    if (defined $self->{'perlpath'}) {
	return $self->{'perlpath'};
    }

    my $perlpath = $self->get_config_info("perlpath", $optional);

    if(defined $perlpath) {
	$perlpath =~ s/(\/|\\)$//; # remove trailing slash
	$self->{'perlpath'} = $perlpath;
    }
    return $perlpath;
}

sub get_gsdl_os {
    my $self = shift @_;
    
    my $os = $^O;

    if ($os =~ m/linux/i) {
	return "linux";
    }
    elsif ($os =~ m/mswin/i) {
	return "windows";
    }
    elsif ($os =~ m/macos/i) {
	return "darwin";
    }
    else {
	# return as is.
	return $os;
    }
}

sub get_library_url_suffix {
    my $self = shift @_;
    
    if (defined $self->{'library_url_suffix'}) {
	return $self->{'library_url_suffix'};
    }

    my $optional = 1; # ignore absence of gwcgi if not found
    my $library_url = $self->get_config_info("gwcgi", $optional);
    if(defined $library_url) {
	$library_url =~ s/(\/|\\)$//; # remove trailing slash
    }
    else {

	if($self->{'greenstone_version'} == 2) {
	    $library_url = $self->get_config_info("httpprefix", $optional);
	    $library_url = "/greenstone" unless defined $library_url;
	    $library_url = "$library_url/cgi-bin/library.cgi"; # same extension for linux and windows
	} 
	else { # greenstone 3 or later and gwcgi not defined
	    $library_url = "/greenstone3"; #"/greenstone3/library";
	}
    }

    $self->{'library_url_suffix'} = $library_url;
    return $library_url;
}

sub setup_fedora_homes {
    my $self = shift @_;
    my ($optional) = @_;

    # The following will still allow the FEDORA_HOME and FEDORA_VERSION environment 
    # variables to have been set outside the gsdlsite.cfg file. Existing env vars 
    # are only overwritten if they've *also* been defined in gsdlsite.cfg.

    if (!defined $self->{'fedora_home'}) # Don't need to go through it all again if we'd already done this before
    {
	# First look in the gsdlsite.cfg file for the fedora properties to be defined
	# and set $ENV{FEDORA_HOME} and $ENV{FEDORA_VERSION} if values were provided
	$self->{'fedora_home'} = $self->get_config_info("fedorahome", $optional);
	
	if (defined $self->{'fedora_home'}) {
	    $ENV{'FEDORA_HOME'} = $self->{'fedora_home'}; 
	} 
	elsif (defined $ENV{'FEDORA_HOME'}) { # check environment variable
	    $self->{'fedora_home'} = $ENV{'FEDORA_HOME'};
	}
	
	# if FEDORA_HOME is now defined, we can look for the fedora version that is being used
	if (defined $ENV{'FEDORA_HOME'}) 
	{
	    # first look in the file
	    $self->{'fedora_version'} = $self->get_config_info("fedoraversion", $optional);

	    if (defined $self->{'fedora_version'}) {
		$ENV{'FEDORA_VERSION'} = $self->{'fedora_version'};
	    } 
	    elsif (defined $ENV{'FEDORA_VERSION'}) { # then check environment variable
		$self->{'fedora_version'} = $ENV{'FEDORA_VERSION'};
	    } 
	    else { # finally, default to version 3 and warn the user
		$ENV{'FEDORA_VERSION'} = "3";
		$self->{'fedora_version'} = $ENV{'FEDORA_VERSION'};
		#$self->generate_ok_message("FEDORA_HOME is set, but not FEDORA_VERSION, defaulted to: 3.");
	    }
	}
    }
}

# sets optional customisable values to do with Open Office
sub setup_openoffice {
    my $self = shift @_;
    my ($optional) = @_;

    if (!defined $self->{'soffice_home'}) # Don't need to go through it all again if we'd already done this before
    {
		# Look in gsdlsite.cfg for whether the openoffice 
		# and jodconverter properties have been defined
		$self->{'soffice_home'} = $self->get_config_info("soffice_home", $optional);
		$self->{'soffice_host'} = $self->get_config_info("soffice_host", $optional);
		$self->{'soffice_port'} = $self->get_config_info("soffice_port", $optional);
		$self->{'jodconverter_port'} = $self->get_config_info("jodconverter_port", $optional);
		
		if (defined $self->{'soffice_home'}) {
			$ENV{'SOFFICE_HOME'} = $self->{'soffice_home'}; 
		}	
		if (defined $self->{'soffice_host'}) {
			$ENV{'SOFFICE_HOST'} = $self->{'soffice_host'}; 
		}
		if (defined $self->{'soffice_port'}) {
			$ENV{'SOFFICE_PORT'} = $self->{'soffice_port'}; 
		}
		if (defined $self->{'jodconverter_port'}) {
			$ENV{'JODCONVERTER_PORT'} = $self->{'jodconverter_port'};
		}
	}
}

sub setup_gsdl {
    my $self = shift @_;
    my $optional = 1; # ignore absence of specified properties in gsdl(3)site.cfg if not found

    my $gsdlhome = $self->get_gsdl_home();
    my $gsdlos = $self->get_gsdl_os();
    $ENV{'GSDLHOME'} = $gsdlhome;
    $ENV{'GSDLOS'} = $gsdlos;

    if (defined $server_software) {
	if ($server_software =~ m/^Microsoft-IIS/) {
	    # Printing to STDERR, by default, goes to the web page in IIS
	    # Send it instead to Greenstone's error.txt
	    
	    my $error_filename = "$gsdlhome/etc/error.txt"; # OK for Windows
	    open STDERR, ">> $error_filename"
		or  die "Can't write to $error_filename: $!\n";
	    binmode STDERR;
	}
    }

    my $library_url = $self->get_library_url_suffix(); # best to have GSDLOS set beforehand
    $self->{'library_url_suffix'} = $library_url;

    my $cgibin = "cgi-bin/$ENV{'GSDLOS'}";
    $cgibin = $cgibin.$ENV{'GSDLARCH'} if defined $ENV{'GSDLARCH'};

    unshift(@INC, "$ENV{'GSDLHOME'}/$cgibin"); # This is OK on Windows
    unshift(@INC, "$ENV{'GSDLHOME'}/perllib");
    unshift(@INC, "$ENV{'GSDLHOME'}/perllib/cpan");
	unshift(@INC, "$ENV{'GSDLHOME'}/perllib/cgiactions");

    require util;

    if($self->{'greenstone_version'} == 3) {
	my $gsdl3srchome = $self->get_gsdl3_src_home();
	$ENV{'GSDL3SRCHOME'} = $gsdl3srchome;

	my $gsdl3home = $self->get_gsdl3_home($optional);
	# if a specific location for GS3's web folder is not provided,
	# assume the GS3 web folder is in the default location
	if(!defined $gsdl3home) { 
	    $gsdl3home = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, "web");
	    $self->{'gsdl3home'} = $gsdl3home;
	} 
	$ENV{'GSDL3HOME'} = $gsdl3home;
    }
    
    my $gsdl_bin_script = &FileUtils::filenameConcatenate($gsdlhome,"bin","script");
    &util::envvar_prepend("PATH",$gsdl_bin_script);
    
    my $gsdl_bin_os = &FileUtils::filenameConcatenate($gsdlhome,"bin",$gsdlos);
    &util::envvar_prepend("PATH",$gsdl_bin_os);
    
    # set up ImageMagick for the remote server in parallel to what setup.bash does
    my $magick_home = &FileUtils::filenameConcatenate($gsdl_bin_os,"imagemagick");
    if(-e $magick_home) {
	&util::envvar_prepend("PATH", $magick_home);

	# Doesn't look like 'bin' and 'lib' are used for Windows version anymore,
	# but that might just be one particular installation pattern, and there's
	# no harm (that I can see) in keeping them in

	my $magick_bin = &FileUtils::filenameConcatenate($magick_home,"bin");
	my $magick_lib = &FileUtils::filenameConcatenate($magick_home,"lib");

	&util::envvar_prepend("PATH", $magick_bin);

	if(!defined $ENV{'MAGICK_HOME'} || $ENV{'MAGICK_HOME'} eq "") {
	    $ENV{'MAGICK_HOME'} = $magick_home;
	}
	
	if($gsdlos eq "linux") {
	    &util::envvar_prepend("LD_LIBRARY_PATH", $magick_lib);
	} elsif ($gsdlos eq "darwin") {
	    &util::envvar_prepend("DYLD_LIBRARY_PATH", $magick_lib);
	}

    }

    # set up GhostScript for the remote server in parallel to what setup.bash does
    my $ghostscript_home = &FileUtils::filenameConcatenate($gsdl_bin_os,"ghostscript");
    if(-e $ghostscript_home) {
	my $ghostscript_bin = &FileUtils::filenameConcatenate($ghostscript_home,"bin");
	&util::envvar_prepend("PATH", $ghostscript_bin);

	if(!defined $ENV{'GS_LIB'} || $ENV{'GS_LIB'} eq "") {
	    $ENV{'GS_LIB'} = &FileUtils::filenameConcatenate($ghostscript_home,"share","ghostscript","8.63","lib");	    
	}
	if(!defined $ENV{'GS_FONTPATH'} || $ENV{'GS_FONTPATH'} eq "") {
	    $ENV{'GS_FONTPATH'} = &FileUtils::filenameConcatenate($ghostscript_home,"share","ghostscript","8.63","Resource","Font");
	}
    }

    # If the "perlpath" property is set in the gsdl(3)site.cfg config file, it is
    # prepended to PATH only if the same perl bin dir path is not already on PATH env
    my $perl_bin_dir = $self->get_perl_path($optional);
    if(defined $perl_bin_dir)
    {
	&util::envvar_prepend("PATH", $perl_bin_dir);

	#my ($perl_home) = ($perl_bin_dir =~ m/(.*)[\\|\/]bin[\\|\/]?$/);
	my ($tailname,$perl_home) = File::Basename::fileparse($perl_bin_dir, "\\.(?:[^\\.]+?)\$");
	$ENV{'PERL5LIB'} = &FileUtils::filenameConcatenate($perl_home, "lib");

	# add vendor\lib if it exists to PERL5LIB
	# Strawberry Perl has a perl\vendor\lib folder. Check for it, if it exists add it to PATH for windows
	# (Windows adds paths to library/dll files to PATH)
	my $vendor_lib = &FileUtils::filenameConcatenate($perl_home, "vendor", "lib");
	if(FileUtils::fileExists($vendor_lib)) {
	    &util::envvar_prepend("PATH", $vendor_lib) if $gsdlos eq "windows";
	    &util::envvar_append("PERL5LIB", $vendor_lib); 
	}

	if($gsdlos eq "darwin") {
	    &util::envvar_prepend("DYLD_LIBRARY_PATH", &FileUtils::filenameConcatenate($perl_home,"5.8.9","darwin-thread-multi-2level","CORE"));
	} elsif($gsdlos eq "linux") {
	    &util::envvar_prepend("LD_LIBRARY_PATH", &FileUtils::filenameConcatenate($perl_home,"5.8.9","i686-linux-thread-multi","CORE"));
	}
    }
    elsif ($gsdlos eq "windows") 
    {
	# Perl comes installed with the GS Windows Release Kit. However, note that if GS 
	# is from SVN, the user must have their own Perl and put it on the PATH or set
	# perlpath in the gsdl site config file.
	$perl_bin_dir = &FileUtils::filenameConcatenate($gsdlhome, "bin", "windows", "perl", "bin");
	if(-e $perl_bin_dir) {
	    &util::envvar_append("PATH", $perl_bin_dir);

	    my ($tailname,$perl_home) = File::Basename::fileparse($perl_bin_dir, "\\.(?:[^\\.]+?)\$");
	    my $vendor_lib = &FileUtils::filenameConcatenate($perl_home, "vendor", "lib");
	    if(FileUtils::fileExists($vendor_lib)) {
		&util::envvar_prepend("PATH", $vendor_lib) if $gsdlos eq "windows";
		&util::envvar_append("PERL5LIB", $vendor_lib); 
	    }
	}
    }
    
    # If javahome is explicitly set in the gsdl site config file then it will override
    # any env variable JAVA_HOME. A GS2 server does not set JAVA_HOME, though java is on
    # the path. Therefore, if Fedora is being used for FLI with GS2, then javahome must 
    # be set in gsdlsite.cfg or the JAVA_HOME env var must be explicitly set by the user.
    my $java_home = $self->get_java_home($optional);
    if(defined $java_home) {
	$ENV{'JAVA_HOME'} = $java_home;
    }


    # Process any extension setup.pl files
    my @ext_homes = ();

    my $gsdl_ext_home = &FileUtils::filenameConcatenate($gsdlhome,"ext");
    push(@ext_homes,$gsdl_ext_home);

    if ($self->{'greenstone_version'} == 3) {
	my $gsdl3srchome = $self->get_gsdl3_src_home();
	my $gsdl3_ext_home = &FileUtils::filenameConcatenate($gsdl3srchome,"ext");
	push(@ext_homes,$gsdl3_ext_home);
    }

    # Don't pass the arguments to gliserver.pl (e.g. cmd=check-installation) to Greenstone extensions' setup files
    print STDERR "Args: " . join(",", @ARGV)."\n";
    my @saved_args = @ARGV;
    if (scalar(@ARGV>0)) {
	@ARGV=();
    }

    foreach my $ext_home (@ext_homes) {
	# Should really think about making this a subroutine

	if (opendir(EXTDIR,$ext_home) ) {
	    my @pot_ext_dir = grep { $_ !~ m/^\./ } readdir(EXTDIR);
	    
	    closedir(EXTDIR);
	    
	    foreach my $ed (@pot_ext_dir) {
		my $full_ext_dir = &FileUtils::filenameConcatenate($ext_home,$ed);

		if (-d $full_ext_dir) {

		    my $full_ext_perllib_dir = &FileUtils::filenameConcatenate($full_ext_dir,"perllib");
		    if (-d $full_ext_perllib_dir) {
			unshift (@INC, $full_ext_perllib_dir);
		    }

		    my $full_inc_file = &FileUtils::filenameConcatenate($full_ext_dir,
							    "$ed-setup.pl");
		    if (-f $full_inc_file) {
			
			my $store_cwd = Cwd::cwd();
			
			chdir($full_ext_dir);
			require "./$ed-setup.pl";
			chdir($store_cwd);
		    }
		}
	    }
	}
    }

    # restore the args to gliserver.pl
    @ARGV = @saved_args;
    print STDERR "Args: " . join(",", @ARGV)."\n";

    # FEDORA_HOME and FEDORA_VERSION are needed (by scripts g2f-import and g2f-buildcol).
    $self->setup_fedora_homes($optional);


    # Check for any customisations to Open-Office if on Windows
    if ($gsdlos eq "windows") {
	$self->setup_openoffice($optional);
    }

    # If perl_perturb_keys isn't set, then search results with remote GS
    # return different documents from the ones that should be returned
    $ENV{'PERL_PERTURB_KEYS'}=0;
    $ENV{'WGETRC'}=&FileUtils::filenameConcatenate($gsdlhome,"bin",$gsdlos,"wgetrc");
}

sub greenstone_version {
    my $self = shift @_;
    return $self->{'greenstone_version'};
}

sub library_url_suffix {
    my $self = shift @_;
    return $self->{'library_url_suffix'};
}

# Only useful to call this after calling setup_gsdl, as it uses some environment variables
# Returns the Greenstone collect directory, or a specific collection directory inside collect
sub get_collection_dir {
    my $self = shift @_;
    my ($site, $collection) = @_; # both may be undefined
    
    my $collection_directory;
    if($self->{'greenstone_version'} == 2 && defined $ENV{'GSDLHOME'}) {
	if(defined $collection) {
	    $collection_directory = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "collect", $collection);
	} else {
	    $collection_directory = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'}, "collect");
	}
    }
    elsif($self->{'greenstone_version'} == 3) {
	if(defined $ENV{'GSDL3HOME'}) {
	    if(defined $collection) {
		$collection_directory = &FileUtils::filenameConcatenate($ENV{'GSDL3HOME'}, "sites", $site, "collect", $collection);
	    } else {
		$collection_directory = &FileUtils::filenameConcatenate($ENV{'GSDL3HOME'}, "sites", $site, "collect");
	    }
	}
	elsif(defined $ENV{'GSDL3SRCHOME'}) {
	    if(defined $collection) {
		$collection_directory = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, "web", "sites", $site, "collect", $collection);
	    } else {
		$collection_directory = &FileUtils::filenameConcatenate($ENV{'GSDL3SRCHOME'}, "web", "sites", $site, "collect");
	    }
	}
    }
    return $collection_directory;
}

sub local_rm_r
{
    my $self = shift @_;
    my ($local_dir) = @_;

    my $prefix_dir = getcwd(); 
    my $full_path = &FileUtils::filenameConcatenate($prefix_dir,$local_dir);
    
    if ($prefix_dir !~ m/collect/) {
	$self->generate_error("Trying to delete outside of Greenstone collect: $full_path");
    }

    # Delete recursively
    if (!-e $full_path) {
	$self->generate_error("File/Directory does not exist: $full_path");
    }

    &FileUtils::removeFilesRecursive($full_path);
}


sub get_java_path()
{
    # Check the JAVA_HOME environment variable first
    if (defined $ENV{'JAVA_HOME'}) {
	my $java_home = $ENV{'JAVA_HOME'};
	$java_home =~ s/\/$//;  # Remove trailing slash if present (Unix specific)
	return &FileUtils::filenameConcatenate($java_home, "bin", "java");
    }

    elsif (defined $ENV{'JRE_HOME'}) {
	my $jre_home = $ENV{'JRE_HOME'};
	$jre_home =~ s/\/$//;  # Remove trailing slash if present (Unix specific)
	return &FileUtils::filenameConcatenate($jre_home, "bin", "java");
    }

    # Hope that Java is on the PATH
    return "java";
}


sub check_java_home()
{
    # Return a warning unless the JAVA_HOME environment variable is set
    if (!defined $ENV{'JAVA_HOME'}) {
	return "JAVA_HOME environment variable not set. Might not be able to find Java unless in PATH (" . $ENV{'PATH'} . ")";
    }

    return "";
}


sub checked_chdir
{
    my $self = shift @_;
    my ($dir) = @_;

    if (!-e $dir) {
	$self->generate_error("Directory '$dir' does not exist");
    }

    chdir $dir
	|| $self->generate_error("Unable to change to directory: $dir");
}

# used with old GS3 authentication
sub rot13()
{
    my $self = shift @_;
    my ($password)=@_;
    my @password_arr=split(//,$password);
    
    my @encrypt_password;
    foreach my $str (@password_arr){
	my $char=unpack("c",$str);
	if ($char>=97 && $char<=109){
	    $char+=13;
	}elsif ($char>=110 && $char<=122){
	    $char-=13;
	}elsif ($char>=65 && $char<=77){
	    $char+=13;
	}elsif ($char>=78 && $char<=90){
	    $char-=13;
	}
	$char=pack("c",$char);
	push(@encrypt_password,$char);
    }
    return join("",@encrypt_password);
}

# used along with new GS3 authentication
sub hash_pwd()
{
    my $self = shift @_;
    my ($password)=@_;

    my $gsdl3srchome = $ENV{'GSDL3SRCHOME'};
    
    my $java = get_java_path();
    my $java_gsdl3_classpath = &FileUtils::filenameConcatenate($gsdl3srchome, "web", "WEB-INF", "lib", "gsdl3.jar");
    my $java_remaining_classpath = &FileUtils::filenameConcatenate($gsdl3srchome, "web", "WEB-INF", "lib", "*"); # log4j etc
    my $java_classpath;
    my $gsdlos = $ENV{'GSDLOS'};
    if ($gsdlos !~ m/windows/){
	$java_classpath = $java_gsdl3_classpath . ":" . $java_remaining_classpath;
    }else{
	$java_classpath = $java_gsdl3_classpath . ";" . $java_remaining_classpath;
    } # can't use util::envvar_prepend(), since the $java_classpath here is not a $ENV type env variable
    
    my $java_command="\"$java\" -classpath \"$java_classpath\" org.greenstone.gsdl3.service.Authentication \"$password\""; # 2>&1";
    my $hashedpwd = `$java_command`;

    return $hashedpwd;
}

sub encrypt_key
{
    my $self = shift @_;

    # I think the encryption method used on the key may be the same for GS3 and GS2
    # (The encryption method used on the pw definitely differs between the two GS versions)
    if (defined $self->param("ky")) {
	require "$self->{'gsdlhome'}/perllib/cpan/Crypt/UnixCrypt.pm";  # This is OK on Windows
	$self->param('-name' => "ky", '-value' => &Crypt::UnixCrypt::crypt($self->clean_param("ky"), "Tp"));
    }
}

sub encrypt_password
{
    my $self = shift @_;
    
    if (defined $self->param("pw")) { ##
	if ($self->{'greenstone_version'} == 3) { # GS3 is in Java, so needs different encryption
	    #$self->param('-name' => "pw", '-value' => $self->rot13($self->clean_param("pw"))); ## when using old GS3 authentication

	    my $hashedPwd = $self->hash_pwd($self->clean_param("pw")); # for GS3's new Authentication
	    $self->param('-name' => "pw", '-value' => $hashedPwd);
	}
	else { # GS2 (and versions of GS other than 3?)
	    #require "$self->{'gsdlhome'}/perllib/util.pm";  # This is OK on Windows
	    require "$self->{'gsdlhome'}/perllib/cpan/Crypt/UnixCrypt.pm";  # This is OK on Windows
	    $self->param('-name' => "pw", '-value' => &Crypt::UnixCrypt::crypt($self->clean_param("pw"), "Tp"));
	}
    } 
}


sub decode {
    my ($self, $text) = @_;
    $text =~ s/\+/ /g;
    $text = &MIME::Base64::decode_base64($text);

    return $text;
}

1;

