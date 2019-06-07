###########################################################################
#
# manifest.pm --
#
# A component of the Greenstone digital library software
# from the New Zealand Digital Library Project at the 
# University of Waikato, New Zealand.
#
# Copyright (C) 2006-2010 New Zealand Digital Library Project
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

package manifest;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use XMLParser;
use dbutil;

our $self;

sub new {
    my ($class) = shift (@_);
    my ($infodbtype,$archivedir) = @_;

    $self = {} ;
    # we can now mark a manifest with a version number
    $self->{'version'} = 1;
    $self->{'index'} = {};
    $self->{'reindex'} = {};
    $self->{'delete'} = {};

    my $arcinfo_doc_filename 
	= &dbutil::get_infodb_file_path($infodbtype, "archiveinf-doc", $archivedir);

    if (-e $arcinfo_doc_filename) {
	# Only store the infodb-doc filename if it exists
	# If it doesn't exist then this means the collection has not been
	#   built yet (or else the archives folder has been deleted).
	#   Either way we have no way to look up which files
	#   are associated with an OID.  If we we encounter an OID
	#   tag later on, we will use the fact that this field is
	#   not defined to issue a warning

	$self->{'_arcinfo-doc-filename'} = $arcinfo_doc_filename;
	$self->{'_infodbtype'} = $infodbtype;
    }

    return bless $self, $class;
}

# /** @function get_version()
#  */
sub get_version
{
  my $self = shift(@_);
  return $self->{'version'};
}
# /** get_version() **/

sub parse
{
    my ($self) = shift (@_);
    my ($filename) = @_;

    my $parser = new XML::Parser('Style' => 'Stream',
                                 'Handlers' => {'Char' => \&Char,
                                                'XMLDecl' => \&XMLDecl,
                                                'Entity' => \&Entity,
                                                'Doctype' => \&Doctype,
                                                'Default' => \&Default
                                                });

    $parser->parsefile($filename);
}

sub StartDocument {$self->xml_start_document(@_);}
sub XMLDecl {$self->xml_xmldecl(@_);}
sub Entity {$self->xml_entity(@_);}
sub Doctype {$self->xml_doctype(@_);}
sub StartTag {$self->xml_start_tag(@_);}
sub EndTag {$self->xml_end_tag(@_);}
sub Text {$self->xml_text(@_);}
sub PI {$self->xml_pi(@_);}
sub EndDocument {$self->xml_end_document(@_);}
sub Default {$self->xml_default(@_);}

# This Char function overrides the one in XML::Parser::Stream to overcome a
# problem where $expat->{Text} is treated as the return value, slowing
# things down significantly in some cases.
sub Char {
    use bytes;  # Necessary to prevent encoding issues with XML::Parser 2.31+
    $_[0]->{'Text'} .= $_[1];
    return undef;
}

# Called at the beginning of the XML document.
sub xml_start_document {
    my $self = shift(@_);
    my ($expat) = @_;

}

# Called for XML declarations
sub xml_xmldecl {
    my $self = shift(@_);
    my ($expat, $version, $encoding, $standalone) = @_;
}

# Called for XML entities
sub xml_entity {
  my $self = shift(@_);
  my ($expat, $name, $val, $sysid, $pubid, $ndata) = @_;
}

# Called for DOCTYPE declarations - use die to bail out if this doctype
# is not meant for this plugin
sub xml_doctype {
    my $self = shift(@_);
    my ($expat, $name, $sysid, $pubid, $internal) = @_;
    die "Manifest Cannot process XML document with DOCTYPE of $name";
}

# Called for every start tag. The $_ variable will contain a copy of the
# tag and the %_ variable will contain the element's attributes.
sub xml_start_tag
{
    my $self = shift(@_);
    my ($expat, $element) = @_;
    my $attributes = \%_;

    if (($element eq "Filename") || ($element eq "OID"))
    {
	$self->{'item-val'} = "";
    }
    elsif ($element eq "Manifest")
    {
      if (defined $attributes->{'version'})
      {
        $self->{'version'} = $attributes->{'version'};
      }
    }
    else
    {
	if (defined($self->{'file-type'}))
	{
	    print STDERR "Warning: Malformed XML manifest\n";
	    print STDERR "         Unrecognized element $element nested inside " . $self->{'file-type'} . ".\n";
	}
	else
        {
	    my $filetype = lc($element);
	    $self->{'file-type'} = $filetype;
	    if (!defined $self->{$filetype})
            {
		print STDERR "Warning: <$element> is not one of the registered tags for manifest format.\n";
	    }
	}

    }
}

# Called for every end tag. The $_ variable will contain a copy of the tag.
sub xml_end_tag
{
    my $self = shift(@_);
    my ($expat, $element) = @_;

    #print STDERR "@@@@ element: $element\n";

    if ($element eq "Filename")
    {
	my $filetype = $self->{'file-type'};
	my $filename  = $self->{'item-val'};

	#print STDERR "@@@@ filename: $filename\n";

	$self->{$filetype}->{$filename} = 1;
	$self->{'item-val'} = undef;
    }
    elsif ($element eq "OID") {
	# look up src and assoc filenames used by this doc oid

	my $filetype = $self->{'file-type'};
	my $oid  = $self->{'item-val'};

	if (defined $self->{'_infodbtype'}) {

	    my $infodbtype = $self->{'_infodbtype'};
	    my $arcinfo_doc_filename = $self->{'_arcinfo-doc-filename'};
	    
	    my $doc_rec = &dbutil::read_infodb_entry($infodbtype, $arcinfo_doc_filename, $oid);
	    
	    my $doc_source_file = $doc_rec->{'src-file'}->[0];

	    if(!$doc_source_file) {
		$self->{'item-val'} = undef;
	    }
	    else {
		my $assoc_files = $doc_rec->{'assoc-file'};
		my @all_files = ($doc_source_file);
		push(@all_files,@$assoc_files) if defined $assoc_files;
		
		foreach my $filename (@all_files) {
		    
		    $filename = &util::placeholders_to_abspath($filename);
		    
		    if (!&FileUtils::isFilenameAbsolute($filename)) {
			$filename = &util::filename_cat($ENV{'GSDLCOLLECTDIR'},$filename);
		    }
		    
		    $self->{$filetype}->{$filename} = 1;
		}
	    }
	}
	else {
	    print STDERR "Warning: No archiveinf-doc database in archives directory.\n";
	    print STDERR "         Unable to look up source files that constitute document $oid.\n";
	}

	$self->{'item-val'} = undef;
    }
    else
    {
	$self->{'file-type'} = undef;
    }
}

# Called just before start or end tags with accumulated non-markup text in
# the $_ variable.
sub xml_text {
    my $self = shift(@_);
    my ($expat) = @_;

    if (defined $self->{'item-val'}) {
	my $text = $_;
	chomp($text);

	$text =~ s/^\s+//;
	$text =~ s/\s+$//;	
	
	$self->{'item-val'} .= $text if ($text !~ m/^\s*$/);
    }
}

# Called for processing instructions. The $_ variable will contain a copy
# of the pi.
sub xml_pi {
    my $self = shift(@_);
    my ($expat, $target, $data) = @_;
}

# Called at the end of the XML document.
sub xml_end_document {
    my $self = shift(@_);
    my ($expat) = @_;

    if (defined $self->{'import'}) {
	print STDERR "Warning: <Import> tag is deprecated.\n";
	print STDERR "         Processing data as if it were tagged as <Index>\n";
	$self->{'index'} = $self->{'import'};
    }

}

# Called for any characters not handled by the above functions.
sub xml_default {
    my $self = shift(@_);
    my ($expat, $text) = @_;
}


1;
