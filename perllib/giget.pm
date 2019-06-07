use strict;
use util;


sub readin_html 
{
    my ($html_fname) = @_;

    open(HIN,"<$html_fname") 
	|| die "Unable to open $html_fname: $!\n";
    
    my $html_text;
    my $line;
    while (defined ($line=<HIN>)) {
	$html_text .= $line;
    }
    close(HIN);

    return $html_text;
}

sub stripout_anchortags
{
    my ($html_text) = @_;

    my @anchor_tags = ($html_text =~ m/(<a\s+.*?>)+/gs);

    return @anchor_tags;
} 


sub print_tags
{
    my (@tags) = @_;

    my $a;
    foreach $a ( @tags) {
	print "$a\n";
    }
}

sub filter_tags
{
    my ($filter_text,@tags) = @_;

    my @filtered_tags = ();

    my $t;
    foreach $t (@tags) {
	if ($t =~ m/$filter_text/x) {
	    push(@filtered_tags,$t);
	}
    }

    return @filtered_tags;
}

sub extract_urls {
    my (@tags) = @_;

    my @urls = ();

    my $t;
    foreach $t (@tags) {
	if ($t =~ m/href=([^ ]+)/i) {
	    my $url = $1;
	    $url =~ s/&amp;/&/g;
	    push(@urls,$url);
	}
    }

    return @urls;
}

sub get_gi_page
{
    my ($cgi_base,$cgi_call,$downloadto_fname) = @_;

    my $full_url = "$cgi_base$cgi_call";
    
    if ((!-e $downloadto_fname) || (-z $downloadto_fname)) {

	# the wget binary is dependent on the gnomelib_env (particularly lib/libiconv2.dylib) being set, particularly on Mac Lions (android too?)
	&util::set_gnomelib_env(); # this will set the gnomelib env once for each subshell launched, by first checking if GEXTGNOME is not already set

	my $cmd = "wget -nv -T 10 -nc -U \"Mozilla\" -O \"$downloadto_fname\" \"$full_url\"";
##	print STDERR "*** wget cmd:\n $cmd\n";

    `$cmd`;
    }

    if (-z $downloadto_fname) { 
	print STDERR "Warning: downloaded file 0 bytes!\n";
    }
}


sub parse_gi_search_page 
{
    my ($ga_base,$search_term_dir,$downloaded_fname,$currpage_url) = @_;

    my $nextpage_url = undef;

    my @imgref_urls = ();

    my $downloaded_text = readin_html($downloaded_fname);
    if (defined $downloaded_text) {
	my @anchor_tags = stripout_anchortags($downloaded_text);
	
	my @thumbimg_tags = filter_tags("imgres\\?",@anchor_tags);
	my @nextpage_tags = filter_tags("images\\?.*?start=\\d+",@anchor_tags);
	
	my @thumbimg_urls = extract_urls(@thumbimg_tags);
	my @nextpage_urls = extract_urls(@nextpage_tags);

	my $curr_start = 0;
	if ($currpage_url =~ m/start=(\d+)/) {
	    $curr_start = $1;
	}

	my $pot_url;
	foreach $pot_url (@nextpage_urls) {
	
	    my ($next_start) = ($pot_url =~ m/start=(\d+)/);
	    if ($next_start>$curr_start) {
		$nextpage_url = $pot_url;
		last;
	    }
	}

#	print "-" x 40, "\n";
	my $c = 1;
	my $p = 1;

	foreach my $tvu (@thumbimg_urls) {
	    my ($img_url) = ($tvu =~ m/imgurl=([^&]*)/);
	    $img_url =~ s/%25/%/g;

	    my ($imgref_url) = ($tvu =~ m/imgrefurl=([^&]*)/);
##	    print STDERR "****imgref_url = $imgref_url\n";
	    $imgref_url =~ s/%25/%/g;
	    
	    my ($img_ext) = ($img_url =~ m/\.(\w+)$/);
	    $img_ext = lc($img_ext);

	    # remove http:// if there, so later we can explicitly add it in
	    $img_url =~ s/^http:\/\///; 

	    print "Downloading image url http://$img_url\n";
	    my $output_fname = "$search_term_dir/img_$c.$img_ext";

	    get_gi_page("http://",$img_url,$output_fname);

	    if (-s $output_fname == 0) {
		unlink $output_fname;
	    }
	    else {
		my $command = "\"".&util::get_perl_exec()."\" -S gs-magick.pl identify \"$output_fname\" 2>&1";
		my $result = `$command`;
		
		my $status = $?;
		# need to shift the $? exit code returned by system() by 8 bits and
		# then convert it to a signed value to work out whether it is indeed > 0
		#$status >>= 8;
		#$status = (($status & 0x80) ? -(0x100 - ($status & 0xFF)) : $status);
		#if($status > 0 ) {
		if($status != 0 ) { 
		    print STDERR "**** NOT JPEG: output_fname \n";
		    unlink $output_fname;
		} 
		else {
		    
		    my $type =   'unknown';
		    my $width =  'unknown';
		    my $height = 'unknown';
		    
		    my $image_safe = quotemeta $output_fname;
		    if ($result =~ /^$image_safe (\w+) (\d+)x(\d+)/) {
			$type = $1;
			$width = $2;
			$height = $3;
		    }
		    
		    my $imagick_cmd = "\"".&util::get_perl_exec()."\" -S gs-magick.pl";
		    
		    if (($width ne "unknown") && ($height ne "unknown")) {
			if (($width>200) || ($height>200)) {
			    `$imagick_cmd convert \"$output_fname\" -resize 200x200 /tmp/x.jpg`;
			    `/bin/mv /tmp/x.jpg \"$output_fname\"`;
			}
		    }
		    $c++;
		}
	    }

	    push(@imgref_urls,$imgref_url);

	    last if ($c==3); # Only take first 2

	    $p++;

	    if ($p==20) {
		print STDERR "*** Unable to get enough images after 20 passes\n";
		last;
	    }


	}

	if (defined $nextpage_url) {
	    print "Next page URL:\n";
	    print_tags($nextpage_url);
	}
#	print "-" x 40, "\n";
    }

    return ($nextpage_url, \@imgref_urls);
}

sub make_search_term_safe
{
    my ($search_terms) = @_;

    my $search_term_safe = join("+",@$search_terms);
    $search_term_safe =~ s/\"/%22/g;
    $search_term_safe =~ s/ /+/g;

    return $search_term_safe;
}

sub gi_query_url
{
    my ($search_term) = @_;

    my $search_term_safe = make_search_term_safe($search_term);

    my $nextpage_url 
	= "/images?as_filetype=jpg&imgc=color\&ie=UTF-8\&oe=UTF-8\&hl=en\&btnG=Google+Search";
    $nextpage_url .= "\&q=$search_term_safe";

    return $nextpage_url;
}

sub gi_url_base
{
    return "http://images.google.com";
}

sub giget
{
    my ($search_terms,$output_dir) = @_;
    my $imgref_urls = [];

    if (!-e $output_dir) {
	mkdir($output_dir);
    
    }
	
    print STDERR "Searching Google Images for: ", join(", ",@$search_terms), "\n";

    my $gi_base = gi_url_base();
    my $nextpage_url = gi_query_url($search_terms);
    
    my $respage_fname = "$output_dir/respage1.html";
    get_gi_page($gi_base,$nextpage_url,$respage_fname);
    
    ($nextpage_url, $imgref_urls) 
	= parse_gi_search_page($gi_base,$output_dir,
			       $respage_fname,$nextpage_url);
#    else {
#	print STDERR "  Images already mirrored\n";
#    }

    print STDERR "-" x 40, "\n";

    return $imgref_urls;
}


1;
