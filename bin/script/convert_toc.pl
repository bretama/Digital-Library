#! /usr/bin/perl -w

# convert_toc.pl converts old <<TOC>> marked up files to use the new
# <Section> syntax (suitable for processing by HTMLPlug -description_tags

use File::Basename;

my $level = 0;

sub main {
  open STDIN, "<$ARGV[0]" or die "$ARGV[0]: $!\n";
  open STDOUT, ">$ARGV[1]" or die "$ARGV[1]: $!\n";

  my $dirname = &File::Basename::dirname($ARGV[0]);

  my $content = "";
  
  while (<STDIN>) {
    $_ =~ s/[\cJ\cM]+$/\n/;
    $content .= $_;
  }

  # fix images
  $content =~ s/&lt;&lt;I&gt;&gt;\s*(\w+\.(?:png|jpe?g|gif))\s*(.*?)<\/p>/rename_image_old($1, $2, $dirname)/iegs;
  $content =~ s/<img\s+src=\"?(\w+\.(?:png|jpe?g|gif))\"?/rename_image($1, $dirname)/iegs;

  # process section title
  $content =~ s/(?:<P[^>]*>|<BR>)(?:\s*<\/?[^>]*>)*?&lt;&lt;TOC(\d+)&gt;&gt;(.*?)(?=<\/?P[^>]*>|<BR>)/
      process_toc ($1, $2)/sige;

  # close the remaining sections
  my $section_ending = "<!--\n";
  for (my $j = 0; $j < $level; $j++) {
    $section_ending .= "</Section>\n";
  }
  $section_ending .= "-->\n";
  $content =~ s/(<\/body>)/$section_ending.$1/sie;

  print STDOUT $content;
  close STDOUT; close STDIN;
}

sub process_toc {
  my ($thislevel, $title) = @_;
  my $toc = '';
 
  $title =~ s/<[^>]+>//sg;
  $title =~ s/^\s+//s;
  $title =~ s/\s+$//s;
  $title =~ s/\n/ /sg;

  $toc .= "\n<!--\n";

  if ($thislevel <= $level) {
    for (my $i = 0; $i < ($level-$thislevel+1); $i++) {
	$toc .= "</Section>\n";
    }
  }

  $toc .= "<Section>\n".
	"  <Description>\n".
	"    <Metadata name=\"Title\">$title</Metadata>\n".
	"  </Description>\n".
	"-->\n";

  $level = $thislevel;

  return $toc;
}

sub rename_image_old {
    my ($image_name, $following_text, $dirname) = @_;

    &rename_image($image_name, $dirname);

    return "<center><img src=\"$image_name\"><br>$following_text<\/center><\/p>\n";
}


# may need to rename image files if case isn't consistent
# (i.e. collections prepared on windows may have images named
# AAA.GIF which are linked into the HTML as aaa.gif)
sub rename_image {
    my ($image_name, $dirname) = @_;


    if (!-e "$dirname/$image_name") {

	my ($pre, $ext) = $image_name =~ /^([^\.]+)\.(.*)$/;
	my $image_name_uc = uc($image_name);
	my $image_name_lc = lc($image_name);
	my $image_name_ul = uc($pre) . "." . lc($ext);
	my $image_name_lu = lc($pre) . "." . uc($ext);

	if (-e "$dirname/$image_name_uc") {
	    print STDERR "renaming $dirname/$image_name_uc --> $dirname/$image_name\n";
	    rename ("$dirname/$image_name_uc", "$dirname/$image_name");

	} elsif (-e "$dirname/$image_name_lc") {
	    print STDERR "renaming $dirname/$image_name_lc --> $dirname/$image_name\n";
	    rename ("$dirname/$image_name_lc", "$dirname/$image_name");
	
	} elsif (-e "$dirname/$image_name_ul") {
	    print STDERR "renaming $dirname/$image_name_ul --> $dirname/$image_name\n";
	    rename ("$dirname/$image_name_ul", "$dirname/$image_name");
	
	} elsif (-e "$dirname/$image_name_lu") {
	    print STDERR "renaming $dirname/$image_name_lu --> $dirname/$image_name\n";
	    rename ("$dirname/$image_name_lu", "$dirname/$image_name");
	
	} else {
	    print STDERR "ERROR**** $dirname/$image_name could not be found\n";
	    if (open (ERROR, ">>error.txt")) {
		print ERROR "ERROR**** $dirname/$image_name could not be found\n";
		close ERROR;
	    }
	}
    }
    return "<img src=\"$image_name\"";
}



&main;
