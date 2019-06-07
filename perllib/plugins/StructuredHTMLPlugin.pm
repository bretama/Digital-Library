###########################################################################
#
# StructuredHTMLPlugin.pm -- html plugin with extra facilities for teasing out 
# hierarchical structure (such as h1, h2, h3, or user-defined tags) in an 
# HTML document
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 1999 New Zealand Digital Library Project
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
###########################################################################
# This plugin is to process an HTML file where sections are divided by 
# user-defined headings tags. As it is difficult to predict what user's definition
# this plugin allows to detect the user-defined titles up to three levels (level1, level2, level3...)
# as well as allows to get rid of user-defined Table of Content (TOC)...
# format:e.g. level1 (Abstract_title|ChapterTitle|Referencing Heading) level2(SectionHeading)...

package StructuredHTMLPlugin;

use HTMLPlugin;
use ImageConverter; # want the identify method
use util;

use strict; # every perl program should have this!
no strict 'refs'; # make an exception so we can use variables as filehandles

sub BEGIN {
    @StructuredHTMLPlugin::ISA = ('HTMLPlugin');
}

my $arguments = 
    [
     { 'name' => "level1_header",
       'desc' => "{StructuredHTMLPlugin.level1_header}",
       'type' => "regexp",
       'reqd' => "no",
       'deft' => "" },
     { 'name' => "level2_header",
       'desc' => "{StructuredHTMLPlugin.level2_header}",
       'type' => "regexp",
       'reqd' => "no",
       'deft' => "" },
     { 'name' => "level3_header",
       'desc' => "{StructuredHTMLPlugin.level3_header}",
       'type' => "regexp",
       'reqd' => "no",
       'deft' => "" },
     { 'name' => "title_header",
       'desc' => "{StructuredHTMLPlugin.title_header}",
       'type' => "regexp",
       'reqd' => "no",
       'deft' => "" },
     { 'name' => "delete_toc",
       'desc' => "{StructuredHTMLPlugin.delete_toc}",
       'type' => "flag",
       'reqd' => "no"},
     { 'name' => "toc_header",
       'desc' => "{StructuredHTMLPlugin.toc_header}",
       'type' => "regexp",
       'reqd' => "no",
       'deft' => "" }     
     ];

my $options = { 'name'     => "StructuredHTMLPlugin",
		'desc'     => "{StructuredHTMLPlugin.desc}",
		'abstract' => "no",
		'inherits' => "yes",
		'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);
    
    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
    
    my $self = new HTMLPlugin($pluginlist, $inputargs, $hashArgOptLists);
    
    return bless $self, $class;
}


sub process {
    my $self = shift (@_);
    my ($textref, $pluginfo, $base_dir, $file, $metadata, $doc_obj, $gli) = @_;
    my $outhandle = $self->{'outhandle'};

    my @head_and_body = split(/<body/i,$$textref);
    my $head = shift(@head_and_body);
    my $body_text = join("<body", @head_and_body);
    $head =~ m/<title>(.+)<\/title>/i;
    my $doctitle = $1 if defined $1;
    if (defined $self->{'metadata_fields'} && $self->{'metadata_fields'}=~ /\S/) {
	my @doc_properties = split(/<xml>/i,$head);
	my $doc_heading = shift(@doc_properties);
	my $rest_doc_properties = join(" ", @doc_properties);

	my @extracted_metadata = split(/<\/xml>/i, $rest_doc_properties);
	my $extracted_metadata = shift (@extracted_metadata);
	$self->extract_metadata($extracted_metadata, $metadata, $doc_obj);
    }
    
    # set the title here if we haven't found it yet
    if (!defined $doc_obj->get_metadata_element ($doc_obj->get_top_section(), "Title")) {
	if (defined $doctitle && $doctitle =~ /\S/) {
	    $doc_obj->add_metadata($doc_obj->get_top_section(), "Title", $doctitle);
	} else {
	    $self->title_fallback($doc_obj,$doc_obj->get_top_section(),$file);
	}
    }

    # If delete_toc is enabled, it means to get rid of toc and tof contents.
    # get rid of TOC and TOF sections and their title
    if (defined $self->{'delete_toc'} && ($self->{'delete_toc'} == 1)){
	if (defined $self->{'toc_header'}&& $self->{'toc_header'} =~ /\S/){
	    $body_text =~ s/<p class=(($self->{'toc_header'})[^>]*)>(.+?)<\/p>//isg;
	}
    }
    
    if (defined $self->{'title_header'} && $self->{'title_header'}=~ /\S/){
	$self->{'title_header'} =~ s/^(\()(.*)(\))/$2/is;
	$body_text =~ s/<p class=(($self->{'title_header'})[^>]*)>(.+?)<\/p>/<p class=$1><h1>$3<\/h1><\/p>/isg;
    }

    if (defined $self->{'level1_header'} && $self->{'level1_header'}=~ /\S/ ){
     	$self->{'level1_header'} =~ s/^\((.*)\)/$1/i;
	$body_text =~ s/<p class=(($self->{'level1_header'})[^>]*)>(.+?)<\/p>/<p class=$1><h1>$3<\/h1><\/p>/isg;
    }
    
    if (defined $self->{'level2_header'} && $self->{'level2_header'}=~ /\S/){
	$self->{'level2_header'} =~ s/^\((.*)\)/$1/i;
	$body_text =~ s/<p class=(($self->{'level2_header'})[^>]*)>(.+?)<\/p>/<p class=$1><h2>$3<\/h2><\/p>/isg;
    }
    
    if (defined $self->{'level3_header'} && $self->{'level3_header'}=~ /\S/ ){
	$self->{'level3_header'} =~ s/^\((.*)\)/$1/is;
	$body_text =~ s/<p class=(($self->{'level3_header'})[^>]*)>(.+?)<\/p>/<p class=$1><h3>$3<\/h3><\/p>/isg;
    }
    
    # Tidy up extra new lines
    $body_text =~ s/(<p[^>]*><span[^>]*><o:p>&nbsp;<\/o:p><\/span><\/p>)//isg;
    $body_text =~ s/(<p[^>]*><o:p>&nbsp;<\/o:p><\/p>)//isg;
    
    # what was the following line for. effectively unused. do we need it??
    #$section_text .= "<!--\n<Section>\n-->\n";
    #my $top_section_tag = "<!--\n<Section>\n-->\n";
    #$body_text =~ s/(<div.*)/$top_section_text$doctitle$1/i;
    #$body_text =~ s/(<div.*)/$top_section_tag$1/i;
    my $body = "<body".$body_text;
    
    my $section_text = $head;
    
    # split HTML text on <h1>, <h2> etc tags
    my @h_split = split(/<h/i,$body);
    
    my $hnum = 0;

    my $sectionh1 = 0;
    $section_text .= shift(@h_split);
    
    my $hc;
    foreach $hc ( @h_split )
    {
	if ($hc =~ m/^([1-3])\s*.*?>(.*)$/s)
	{
	    my $new_hnum = $1;
	    my $hc_after = $2;
	    
	    if ($hc_after =~ m/^(.*?)<\/h$new_hnum>/is)
	    {
		my $h_text = $1;
		$hc =~ s/^(\&nbsp\;)+/\&nbsp\;/g;
		# boil HTML down to some interesting text
		$h_text =~ s/^[1-3]>//;
		$h_text =~ s/<\/?.*?>//sg;
		$h_text =~ s/\s+/ /sg;
		$h_text =~ s/^\s$//s;
		$h_text =~ s/(&nbsp;)+\W*/&nbsp;/sg;
		
		if ($h_text =~ m/\w+/)
		{
		    if ($new_hnum > $hnum)
		    {
			# increase section nesting
			$hnum++;
			while ($hnum < $new_hnum)
			{
			    my $spacing = "  " x $hnum;
			    $section_text .= "<!--\n";
			    $section_text .= $spacing."<Section>\n";
			    $section_text .= "-->\n";
			    $hnum++;
			}
		    }
		    else # ($new_hnum <= $hnum)
		    {
			# descrease section nesting
			while ($hnum >= $new_hnum)
			{
			    my $spacing = "  " x $hnum;
			    $section_text .= "<!--\n";
			    $section_text .= $spacing."</Section>\n";
			    $section_text .= "-->\n";
			    $hnum--;
			}
			$hnum++;
		    }

		    my $spacing = "  " x $hnum;
		    $section_text .= "<!--\n";
		    $section_text .= $spacing."<Section>\n";
		    $section_text .= $spacing."  <Description>\n";
		    $section_text .= $spacing."    <Metadata name=\"Title\">$h_text</Metadata>";
		    $section_text .= $spacing."  </Description>\n";
		    $section_text .= "-->\n";
		    
		    #print $outhandle $spacing."$h_text\n"
		    #	if $self->{'verbosity'} > 2;
		    
		    $sectionh1++ if ($hnum==1);
		}
	    }
	    else {
###		print STDERR "***** hc = <h$hc\n\n";
	    }
	    $section_text .= "<h$hc";
	}
	else
	{
	    $section_text .= "<h$hc";
	}
    }

    while ($hnum >= 1)
    {
	my $spacing = "  " x $hnum;
	$section_text .= "<!--\n";
	$section_text .= $spacing."</Section>\n";
	$section_text .= "-->\n";
	$hnum--;
    }

    $section_text .= "<!--\n</Section>\n-->\n";

    $$textref = $section_text;
    
#    if ($sectionh1>0)
#    {
#	print $outhandle "  Located section headings ..."
#	    if $self->{'verbosity'} > 1;
#    }
    
    $$textref =~ s/<!\[if !vml\]>/<![if vml]>/g;
    
    $$textref =~ s/(&nbsp;)+/&nbsp;/sg;    
    
    ## $$textref =~ s/<o:p>&nbsp;<\/o:p>//g; # used with VML to space figures?
    
    $self->SUPER::process(@_);
    
}


sub resize_if_necessary
{
    my ($self,$front,$back,$base_dir,$href) = @_;
    
    # dig out width and height of image, if there
    my $img_attributes = "$front back";
    my ($img_width)  = ($img_attributes =~ m/\s+width=\"?(\d+)\"?/i);
    my ($img_height) = ($img_attributes =~ m/\s+height=\"?(\d+)\"?/i);
    
    # derive local filename for image based on its URL
    my $img_filename = $href;
    $img_filename =~ s/^[^:]*:\/\///;
    $img_filename = &util::filename_cat($base_dir, $img_filename);
    
    # Replace %20's in URL with a space if required. Note that the filename
    # may include the %20 in some situations
    if ($img_filename =~ /\%20/) {
	if (!-e $img_filename) {
	    $img_filename =~ s/\%20/ /g;
	}
    }
    if ((-e $img_filename) && (defined $img_width) && (defined $img_height)) {
	# get image info on width and height
	
	my $outhandle = $self->{'outhandle'};
	my $verbosity = $self->{'verbosity'};

	my ($image_type, $actual_width, $actual_height, $image_size) 
	    = &ImageConverter::identify($img_filename, $outhandle, $verbosity);
	
	#print STDERR "**** $actual_width x $actual_height";
	#print STDERR " (requested: $img_width x $img_height)\n";

	if (($img_width < $actual_width) || ($img_height < $actual_height)) {
	    #print $outhandle "Resizing $img_filename\n" if ($verbosity > 0);
	    
	    # derive new image name based on current image
	    my ($tailname, $dirname, $suffix)
		= &File::Basename::fileparse($img_filename, "\\.[^\\.]+\$");
	    
	    my $resized_filename 
		= &util::filename_cat($dirname, $tailname."_resized".$suffix);
	    
	    #print STDERR "**** suffix = $suffix\n";
	    
	    # Generate smaller image with convert
	    my $newsize = "$img_width"."x$img_height";
	    my $command = "convert -interlace plane -verbose "
		."-geometry $newsize \"$img_filename\" \"$resized_filename\"";
	    $command = "\"".&util::get_perl_exec()."\" -S gs-magick.pl $command";
	    #print $outhandle "ImageResize: $command\n" if ($verbosity > 2);
	    #my $result = '';
	    #print $outhandle "ImageResize result: $result\n" if ($verbosity > 2);
	}
    }
    return $href;
}

sub replace_images {
    my $self = shift (@_);
    my ($front, $link, $back, $base_dir, 
	$file, $doc_obj, $section) = @_;
    # remove quotes from link at start and end if necessary
    if ($link=~/^\"/) {
	$link=~s/^\"//;$link=~s/\"$//;
	$front.='"';
	$back="\"$back";
    }
    
    $link =~ s/\n/ /g;
    
    my ($href, $hash_part, $rl) = $self->format_link ($link, $base_dir, $file);
    
##    $href = $self->resize_if_necessary($front,$back,$base_dir,$href);
    
    my $middle = $self->add_file ($href, $rl, $hash_part, $base_dir, $doc_obj, $section);
    
    return $front . $middle . $back;
}

sub extract_metadata 
{
    my $self = shift (@_);
    my ($textref, $metadata, $doc_obj) = @_;
    my $outhandle = $self->{'outhandle'};
    
    return if (!defined $textref);

    my $separator = $self->{'metadata_field_separator'};
    if ($separator eq "") {
	undef $separator;
    }
    # metadata fields to extract/save. 'key' is the (lowercase) name of the
    # html meta, 'value' is the metadata name for greenstone to use
    my %find_fields = ();
    my ($tag,$value);

    my $orig_field = "";
    foreach my $field (split /\s*,\s*/, $self->{'metadata_fields'}) {
	# support tag<tagname>
	if ($field =~ /^(.*?)\s*<(.*?)>$/) {
	    # "$2" is the user's preferred gs metadata name
	    $find_fields{lc($1)}=$2; # lc = lowercase
	    $orig_field = $1;
	} else { # no <tagname> for mapping
	    # "$field" is the user's preferred gs metadata name
	    $find_fields{lc($field)}=$field; # lc = lowercase
	    $orig_field = $field;
	}

	if ($textref =~ m/<o:$orig_field>(.*)<\/o:$orig_field>/i){
	    $tag = $orig_field;
	    $value = $1;
	    if (!defined $value || !defined $tag){
		#print $outhandle "StructuredHTMLPlugin: can't find VALUE in \"$tag\"\n";
		next;
	    } else {
		# clean up and add
		chomp($value); # remove trailing \n, if any
		$tag = $find_fields{lc($tag)};
		#print $outhandle " extracted \"$tag\" metadata \"$value\"\n" 
		#    if ($self->{'verbosity'} > 2);
		if (defined $separator) {
		    my @values = split($separator, $value);
		    foreach my $v (@values) {
			$doc_obj->add_utf8_metadata($doc_obj->get_top_section(), $tag, $v) if $v =~ /\S/;
		    }
		}
		else {
		    $doc_obj->add_utf8_metadata($doc_obj->get_top_section(), $tag, $value);
		}
	    }
	}
    }
}

1;
