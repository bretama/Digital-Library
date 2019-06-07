#!/usr/bin/perl -w

use strict; 

use CGI::Carp qw(fatalsToBrowser); 
use CGI; 

my $gsdl_cgi;
my $gsdl_home;
my $gsdl_tmp_dir;

my $debugging_enabled = 0; # if 1, if enabled deleting files will not happen

BEGIN {
    
    $|=1; # Force auto-flushing for output

    eval('require "./gsdlCGI.pm"');
    if ($@)
    {
	print STDOUT "Content-type:text/plain\n\n";
	print STDOUT "ERROR: $@\n";
	exit 0;
    }

}


sub get_progress_filename
{
    my ($uploaded_file) = @_;

    my $progress_file = $uploaded_file;

    $progress_file =~ s{^(.*)\/}{}; 
    $progress_file =~ s/\.*?$//;
    $progress_file .= "-progress.txt";

    my $progress_filename = &util::filename_cat($gsdl_tmp_dir, $progress_file);

    return $progress_filename;
}

sub get_file_central_filename
{
    my $file_central = &util::filename_cat($gsdl_tmp_dir,"file-central.txt");

    return $file_central;
}

sub read_file_central
{
    my $fc_filename = get_file_central_filename();

    my @fc_list;

    if (open(FCIN,"<$fc_filename")) {
	
	my $fc_list_str = do { local $/; <FCIN> };
	@fc_list = split(/\n/,$fc_list_str);

	close(FCIN);
    }
    else {
	# OK to have no file-central.txt to start with
	# return empty list
	@fc_list = ();
    }

    return \@fc_list;
    
}

sub remove_from_file_central
{
    my ($filename,$fc_list) = @_;

    my @new_fc_list = ();

    my $removed = 0;

    foreach my $f (@$fc_list) {

	if ($f ne $filename) {
	    push(@new_fc_list,$f);
	}
	else {
	    $removed = 1;
	}
    }

    if (!$removed) {
	print STDERR "Warning: Failed to locate '$filename' in file-central.txt\n";
    }

    return \@new_fc_list;
}

sub add_to_file_central
{
    my ($filename,$fc_list) = @_;

    my @new_fc_list = @$fc_list;

    my $duplicate = 0;
    foreach my $f (@new_fc_list) {

	if ($f eq $filename) {
	    $duplicate = 1;
	}
    }

    if (!$duplicate) {
	push(@new_fc_list,$filename);
    }
    else {
	print STDERR "Warning: Ingoring request to add duplicate entry:\n";
	print STDERR "         '$filename' into file-central.txt\n"
	}

    return \@new_fc_list;
}



sub write_file_central
{
    my ($fc_list) = @_;

    my $fc_filename = get_file_central_filename();


    if (open(FCOUT,">$fc_filename")) {
	
	foreach my $f (@$fc_list) {
	    print FCOUT "$f\n";
	}

	close(FCOUT);

    
	# Ensure it can be edited by owner of Greenstone install (if needed)
	chmod(0777,$fc_filename);
    }
    else {
	print STDERR "Error: Failed to write out $fc_filename\n";
	print STDERR "$!\n";
    }
}

sub monitor_upload 
{            
    my ($uploading_file, $buffer, $bytes_read, $data) = @_;
    
    $bytes_read ||= 0; 
    
    my $progress_filename = get_progress_filename($uploading_file);

    if (! -f $progress_filename) {
	my $fc_list = read_file_central();
	$fc_list = add_to_file_central($uploading_file,$fc_list);
	write_file_central($fc_list);
    }
    
    open(COUNTER, ">$progress_filename"); 
    
    my $per = 0; 
    if ($ENV{CONTENT_LENGTH} > 0) { 
        $per = int(($bytes_read * 100) / $ENV{CONTENT_LENGTH});
    }
    print COUNTER $per;
    close(COUNTER); 
    
    # Useful debug to slow down a 'fast' upload
    # Sleep for 10 msecs
    #select(undef, undef, undef, 0.01);
    #select(undef, undef, undef, 0.1);
}



sub upload_file { 

    my ($gsdl_cgi,$full_filename) = @_;
    
    my $fh       = $gsdl_cgi->upload('uploadedfile');
    my $filename = $gsdl_cgi->param('uploadedfile');
    
    return '' if ! $filename;     
    
    open (OUTFILE, '>' . $full_filename) 
        || die("Can't write to $full_filename: $!");        

    binmode(OUTFILE);

    while (my $bytesread = read($fh, my $buffer, 1024)) { 
        print OUTFILE $buffer; 
    } 
    
    close (OUTFILE);
    chmod(0666, $full_filename);  
    
}

sub remove_progress_file 
{ 
    my ($uploaded_file) = @_;

    my $progress_filename = get_progress_filename($uploaded_file);

    unlink($progress_filename)
	unless $debugging_enabled;

    my $fc_list = read_file_central();
    $fc_list = remove_from_file_central($uploaded_file,$fc_list);
    write_file_central($fc_list);
}


sub unzip_archives_doc
{
    my ($gsdl_cgi,$gsdl_home,$collect_home,$collect,$zip_filename) = @_;

    my $lang_env = $gsdl_cgi->clean_param("lr") || "";

    my $import_dir = &util::filename_cat($collect_home,$collect,"import");

    # Unzip $zip_filename in the collection's import folder
    my $java = $gsdl_cgi->get_java_path();
    my $jar_dir= &util::filename_cat($gsdl_home, "bin", "java");
    my $java_classpath = &util::filename_cat($jar_dir,"GLIServer.jar");

    if (!-f $java_classpath) {
	my $progname = $0;
	$progname =~ s/^.*[\/\\]//;
	my $mess = "$progname:\nFailed to find $java_classpath\n";
	$gsdl_cgi->generate_error($mess);
    }

    my $java_args = "\"$zip_filename\" \"$import_dir\"";

    $ENV{'LANG'} = $lang_env;
    my $java_command = "\"$java\" -classpath \"$java_classpath\" org.greenstone.gatherer.remote.Unzip $java_args"; 

    my $java_output = `$java_command`;
    my $java_status = $?;
    if ($java_status > 0) {
	my $report = "Java failed: $java_command\n--\n";
	$report .= "$java_output\n";
	$report .= "Exit status: " . ($java_status / 256) . "\n";
	$report .= $gsdl_cgi->check_java_home();

	$gsdl_cgi->generate_error($report);
    }
    else {
	# Remove the zip file once we have unzipped it, since it is an intermediate file only
	`chmod -R a+rw $import_dir/HASH*`;
	unlink($zip_filename) unless $debugging_enabled;
    }
}


sub rebuild_collection
{
    my ($collect) = @_;

    my $bin_script = &util::filename_cat($gsdl_home,"bin","script");
##    my $inc_rebuild_pl = &util::filename_cat($bin_script,"incremental-rebuild.pl");

    my $rebuild_cmd = "perl -S incremental-rebuild.pl \"$collect\"";

    my $rebuild_output = `$rebuild_cmd 2>&1`;
    my $rebuild_status = $?;
    if ($rebuild_status > 0) {
	my $report = "Perl rebuild failed: $rebuild_cmd\n--\n";
	$report .= "$rebuild_output\n";
	$report .= "Exit status: " . ($rebuild_status / 256) . "\n";
##	$report .= $gsdl_cgi->check_perl_home();

#	$report .= "PATH = ". $ENV{'PATH'}. "\n";


	$gsdl_cgi->generate_error($report);
    }
}

sub main { 

    # gsdlCGI->prenew() constructs a 'lite' version of the object where the
    # GSDL environment has been setup
    #
    # This is needed because the main call the gsdlCGI->new takes an 
    # initializer rountine -- monitor_upload() -- as a parameter, AND THAT 
    # routine (which is called before the constructor is finished) needs to 
    # know the tmp directory to use to write out the progress file.

    my $gsdl_config = gsdlCGI->prenew();

    $gsdl_home    = $gsdl_config->get_gsdl_home();
    $gsdl_tmp_dir = &util::get_toplevel_tmp_dir();  

    require talkback;

    # Use the initializer mechanism so a 'callback' routine can monitor
    # the progress of how much data has been uploaded

    $gsdl_cgi = gsdlCGI->new(\&monitor_upload); 


    require CGI::Ajax;

    my $perlAjax = new CGI::Ajax('check_status' => \&check_status);


    if ($gsdl_cgi->param('process')) { 

	my $uploaded_file = $gsdl_cgi->param('uploadedfile');
	my $full_filename = &util::filename_cat($gsdl_tmp_dir,$uploaded_file);

	my $done_html = &talkback::generate_done_html($full_filename);

        if ($gsdl_cgi->param('yes_upload')) { 
            upload_file($gsdl_cgi,$full_filename); 

	    my $collect      = $gsdl_cgi->param('toCollect');
	    my $collect_home = &util::filename_cat($gsdl_home,"collect");

	    unzip_archives_doc($gsdl_cgi,$gsdl_home,$collect_home,$collect,$full_filename);
	    rebuild_collection($collect);
        }   

        print $gsdl_cgi->header(); 
        print $done_html; 

        remove_progress_file($uploaded_file);   
    }
    else {         

	my $upload_html_form;

	#my $oid     = $gsdl_cgi->param('oid');
	#my $collect = $gsdl_cgi->param('collect');
	my $uniq_file = $gsdl_cgi->param('uploadedfile');   

	#my $uniq_file = "$collect-$oid-doc.zip";
	# Light-weight (hidden) form with progress bar

	$upload_html_form 
	    = &talkback::generate_upload_form_progressbar($uniq_file);
	
        print $perlAjax->build_html($gsdl_cgi, $upload_html_form);
    }
}


main(); 


#=====

sub inc_wait_dots
{
    my $wait_filename = &util::filename_cat($gsdl_tmp_dir,"wait.txt");
    open(WIN,"<$wait_filename");
    my $wait = <WIN>;
    close(WIN);

    $wait = ($wait+1) %6;
    my $wait_dots = "." x ($wait+1);

    open(WOUT,">$wait_filename");
    print WOUT "$wait\n";
    close(WOUT);

    return $wait_dots;
}


sub check_status_single_file
{
    my ($filename) = @_;
    
    my $monitor_filename = get_progress_filename($filename);

    if (! -f  $monitor_filename ) {
	return "";
    }
                
    open my $PROGRESS, '<', $monitor_filename or die $!;
    my $s = do { local $/; <$PROGRESS> };
    close ($PROGRESS); 
    
    my $fgwidth = int($s * 1.5); 
    my $bgwidth = 150 - $fgwidth;
  
    my $fgcol = "background-color:#dddd00;";
    my $bgcol = "background-color:#008000;";

    my $style_base = "height:10px; float:left;";

    my $r = "";
    $r .= "<div>$filename:</div>";
    $r .= "<nobr>";
    $r .= "<div style=\"width: ${fgwidth}px; $fgcol $style_base\"></div>"; 
    $r .= "<div style=\"width: ${bgwidth}px; $bgcol $style_base\"></div>";
    $r .= "<div style=\"float:left; width: 80px\">&nbsp;$s%</div>"; 
    $r .= "</nobr>";
    $r .= "<br />";

    return $r; 
}


sub check_status_all
{
    my $file_central = get_file_central_filename();

    my $html = "";

    my $fc_list = read_file_central();

    foreach my $f (@$fc_list) {
	$html .= check_status_single_file($f);
    }

    return $html;

}

 
# Accessed from HTML web page through the majic of perlAjax 

sub check_status 
{    

    my $wait_dots = inc_wait_dots();
    my $dots_html = "Waiting for transfer: $wait_dots<br>";

    my $filename = $gsdl_cgi->param('uploadedfile');

    my $inner_html;

    if ((defined $filename) && ($filename ne "")) {
	$inner_html = check_status_single_file($filename);
    }
    else {
	$inner_html = check_status_all();
    }

    my $html = ($inner_html ne "") ? $inner_html : $dots_html;

    return $html;
}
