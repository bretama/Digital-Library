###########################################################################
#
# AZCompactList.pm --
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
# classifier plugin for sorting alphabetically

package AZCompactList;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

use BaseClassifier;
use sorttools;
use FileUtils;

use Unicode::Normalize;

sub BEGIN {
    @AZCompactList::ISA = ('BaseClassifier');
}

our $doclevel_list = 
    [ {	'name' => "top",
 	'desc' => "{AZCompactList.doclevel.top}" },
      {	'name' => "firstlevel",
 	'desc' => "{AZCompactList.doclevel.firstlevel}" },
      { 'name' => "section",
	'desc' => "{AZCompactList.doclevel.section}" } ];

my $arguments = 
    [ { 'name' => "metadata",
	'desc' => "{AZCompactList.metadata}",
	'type' => "metadata",
	'reqd' => "yes" },
      { 'name' => "firstvalueonly",
	'desc' => "{AZCompactList.firstvalueonly}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "allvalues",
	'desc' => "{AZCompactList.allvalues}",
	'type' => "flag",
	'reqd' => "no" },
      { 'name' => "sort",
	'desc' => "{AZCompactList.sort}",
	'type' => "metadata",
#	'deft' => "Title",
	'reqd' => "no" },
      { 'name' => "removeprefix",
	'desc' => "{BasClas.removeprefix}",
	'type' => "regexp",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "removesuffix",
	'desc' => "{BasClas.removesuffix}",
	'type' => "regexp",
	'deft' => "",
	'reqd' => "no" },
      { 'name' => "mingroup",
	'desc' => "{AZCompactList.mingroup}",
	'type' => "int",
	'deft' => "1",
	'range' => "1,",
	'reqd' => "no" },
      { 'name' => "minnesting",
	'desc' => "{AZCompactList.minnesting}",
	'type' => "int",
	'deft' => "20",
	'range' => "2,",
	'reqd' => "no" },
      { 'name' => "mincompact",
	'desc' => "{AZCompactList.mincompact}",
	'type' => "int",
	'deft' => "10",
	'range' => "1,",
	'reqd' => "no" },
      { 'name' => "maxcompact",
	'desc' => "{AZCompactList.maxcompact}",
	'type' => "int",
	'deft' => "30",
	'range' => "1,",
	'reqd' => "no" },
      { 'name' => "doclevel",
	'desc' => "{AZCompactList.doclevel}",
	'type' => "enum",
	'list' => $doclevel_list,
	'deft' => "top",
	'reqd' => "no" },
      { 'name' => "freqsort",
	'desc' => "{AZCompactList.freqsort}",
	'type' => "flag"},
      { 'name' => "recopt",
	'desc' => "{AZCompactList.recopt}",
	'type' => "flag",
	'reqd' => "no" } ];

my $options = 
{ 	'name'     => "AZCompactList",
	'desc'     => "{AZCompactList.desc}",
	'abstract' => "no",
	'inherits' => "yes",
	'args'     => $arguments };


sub new {
    my ($class) = shift (@_);
    my ($pluginlist,$inputargs,$hashArgOptLists) = @_;
    push(@$pluginlist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);

    my $self = new BaseClassifier($pluginlist, $inputargs, $hashArgOptLists);

    if ($self->{'info_only'}) {
	# don't worry about any options etc
	return bless $self, $class;
    }
    
    if (!$self->{"metadata"}) {
	my $outhandle = $self->{'outhandle'};
	print $outhandle "AZCompactList Error: required option -metadata not supplied\n";
	$self->print_txt_usage("");  
	die "AZCompactList Error: required option -metadata not supplied\n";
    }

    $self->{'metadata'} = $self->strip_ex_from_metadata($self->{'metadata'});
    # Manually set $self parameters.
    $self->{'list'} = {};
    $self->{'listmetavalue'} = {};
    $self->{'list_mvpair'} = {};
    $self->{'reclassify'} = {};
    $self->{'reclassifylist'} = {};

    $self->{'buttonname'} = $self->generate_title_from_metadata($self->{'metadata'}) unless ($self->{'buttonname'});
    
    if (defined($self->{"removeprefix"}) && $self->{"removeprefix"}) {
	$self->{"removeprefix"} =~ s/^\^//; # don't need a leading ^
    }
    if (defined($self->{"removesuffix"}) && $self->{"removesuffix"}) {
	$self->{"removesuffix"} =~ s/\$$//; # don't need a trailing $
    }
	
    $self->{'recopt'} = ($self->{'recopt'} == 0) ? undef : "on";
    
    if (defined $self->{'sort'}) {
	$self->{'sort'} = $self->strip_ex_from_metadata($self->{'sort'});
    }
    # Clean out the unused keys
    if($self->{"removeprefix"} eq "") {delete $self->{"removeprefix"};}
    if($self->{"removesuffix"} eq "") {delete $self->{"removesuffix"};}

    return bless $self, $class;
}

sub init 
{
    my $self = shift (@_);
    
    $self->{'list'} = {};
    $self->{'listmetavalue'} = {};
    $self->{'list_mvpair'} = {};
    $self->{'reclassify'} = {};
    $self->{'reclassifylist'} = {};
}

my $tmp = 0;

sub classify
{
    my $self = shift (@_);
    my ($doc_obj) = @_;

    my $doc_OID = $doc_obj->get_OID();
    my $outhandle = $self->{'outhandle'};

    my @sectionlist = ();
    my $topsection = $doc_obj->get_top_section();
    my $metaname = $self->{'metadata'};

    $metaname =~ s/(\/|\|).*//; # grab first name in n1/n2/n3 or n1|n2|n3 list
    my @commameta_list = split(/,|;/, $metaname);

    if ($self->{'doclevel'} =~ /^top(level)?/i)
    {
	push(@sectionlist,$topsection);
    }
    elsif ($self->{'doclevel'} =~ /^first(level)?/i)
    {
	my $toplevel_children = $doc_obj->get_children($topsection);
	push(@sectionlist,@$toplevel_children);
    }
    else # (all)?section(s)?
    {
	my $thissection = $doc_obj->get_next_section($topsection);
	while (defined $thissection) 
	{
	    push(@sectionlist,$thissection);
	    $thissection = $doc_obj->get_next_section ($thissection);
	}
    }

    my $thissection;
    foreach $thissection (@sectionlist)
    {
	my $full_doc_OID 
	    = ($thissection ne "") ? "$doc_OID.$thissection" : $doc_OID;

	if (defined $self->{'list_mvpair'}->{$full_doc_OID}) 
	{
	    print $outhandle "WARNING: AZCompactList::classify called multiple times for $full_doc_OID\n";
	} 
	$self->{'list'}->{$full_doc_OID} = [];	
	$self->{'listmetavalue'}->{$full_doc_OID} = [];
	$self->{'list_mvpair'}->{$full_doc_OID} = [];

	my $metavalues = [];
	foreach my $cmn (@commameta_list) {
	    my $cmvalues = $doc_obj->get_metadata($thissection,$cmn);
	    push(@$metavalues,@$cmvalues) if (@{$cmvalues});
	    last if (@{$cmvalues} && !$self->{'allvalues'});
	}

	my $metavalue;
	foreach $metavalue (@$metavalues) 
	{
	    # Tidy up use of white space in metavalue for classifying
	    $metavalue =~ s/^\s*//s;
	    $metavalue =~ s/\s*$//s;
	    $metavalue =~ s/\n/ /s;
	    $metavalue =~ s/\s{2,}/ /s;

	    # if this document doesn't contain the metadata element we're
	    # sorting by we won't include it in this classification
	    if (defined $metavalue && $metavalue =~ /\w/) 
	    {
		if (defined($self->{'removeprefix'}) &&
		    length($self->{'removeprefix'})) {
		    $metavalue =~ s/^$self->{'removeprefix'}//;

		    # check that it's not now empty
		    if (!$metavalue) {next;}
		}

		if (defined($self->{'removesuffix'}) &&
		    length($self->{'removesuffix'})) {
		    $metavalue =~ s/$self->{'removesuffix'}$//;

		    # check that it's not now empty
		    if (!$metavalue) {next;}
		}

		my $formatted_metavalue;
		if ($self->{'no_metadata_formatting'}) {
		    $formatted_metavalue = $metavalue;
		} else {
		    $formatted_metavalue = &sorttools::format_metadata_for_sorting($self->{'metadata'},	 $metavalue, $doc_obj);
		}
		
		#### prefix-str
		if (! defined($formatted_metavalue)) {
		    print $outhandle "Warning: AZCompactList: metavalue is ";
		    print $outhandle "empty\n";
		    $formatted_metavalue="";
		}

		my $mv_pair = { 'mv' => $metavalue, 'fmv' => $formatted_metavalue };
		push(@{$self->{'list'}->{$full_doc_OID}},$formatted_metavalue);
		push(@{$self->{'listmetavalue'}->{$full_doc_OID}} ,$metavalue);
		push(@{$self->{'list_mvpair'}->{$full_doc_OID}},$mv_pair);


		last if ($self->{'firstvalueonly'});
	    }
	}

	# This is used in reclassify below for AZCompactSectionList
	my $sortmeta = $doc_obj->get_metadata_element($thissection, $self->{'sort'});
	$self->{'reclassify'}->{$full_doc_OID} = [$doc_obj,$sortmeta];
    }
}

sub reinit 
{
    my ($self,$classlist_ref) = @_;
    my $outhandle = $self->{'outhandle'};
    
    my %mtfreq = ();
    my @single_classlist = ();
    my @multiple_classlist = ();

    # find out how often each metavalue occurs
    map 
    { 
	foreach my $mvp (@{$self->{'list_mvpair'}->{$_}} )
	{
###	    print STDERR "*** plain mv = $mvp->{'mv'}\n";
###	    print STDERR "*** format mv = $mvp->{'fmv'}\n";

	    my $metavalue = $mvp->{'mv'};
	    $metavalue =~ s!^-!\\-!; # in case it starts with "-"
	    $mtfreq{$metavalue}++;
	}
    } @$classlist_ref;

    # use this information to split the list: single metavalue/repeated value
    map
    { 
	my $i = 1;
	my $metavalue;
	foreach my $mvp (@{$self->{'list_mvpair'}->{$_}})
	{
	    my $metavalue = $mvp->{'mv'};
	    $metavalue =~ s!^-!\\-!; # in case it starts with "-"
	    my $cs_metavalue = $mvp->{'mv'}; # case sensitive
	    if ($mtfreq{$metavalue} >= $self->{'mingroup'})
	    {
###		print STDERR "*** pushing on $cs_metavalue\n";
		push(@multiple_classlist,[$_,$i,$metavalue]); 
	    } 
	    else
	    {
		push(@single_classlist,[$_,$cs_metavalue]); 
		$metavalue =~ tr/[A-Z]/[a-z]/;
		$self->{'reclassifylist'}->{"Metavalue_$i.$_"} = $metavalue;
	    }
	    $i++;
	}
    } @$classlist_ref;
    
    
    # Setup sub-classifiers for multiple list

    $self->{'classifiers'} = {};

    my $pm;
    foreach $pm ("SimpleList", "SectionList")
    {
	my $listname 
	    = &FileUtils::filenameConcatenate($ENV{'GSDLHOME'},"perllib/classify/$pm.pm");
	if (-e $listname) { require $listname; }
	else 
	{ 
	    print $outhandle "AZCompactList ERROR - couldn't find classifier \"$listname\"\n"; 
	    die "\n";
	}
    }

    # Create classifiers objects for each entry >= mingroup
    my $metavalue;
    my $doclevel = $self->{'doclevel'};
    my $mingroup = $self->{'mingroup'};
    my @metaname_list = split(/\/|\|/,$self->{'metadata'});
    my $metaname = shift(@metaname_list);
    my $hierarchical = 0;
    if (scalar(@metaname_list) > 1) {
	$hierarchical = 1;
	$metaname = join('/',@metaname_list);
    }
    foreach $metavalue (sort keys %mtfreq)
    {
	if ($mtfreq{$metavalue} >= $mingroup)
	{
	    # occurs more often than minimum required to compact into a group
	    my $listclassobj;
	    
	    if (!$hierarchical) 
	    {	
		my @args;
		push @args, ("-metadata", "$metaname");
		# buttonname is also used for the node's title
		push @args, ("-buttonname", "$metavalue");
		push @args, ("-sort", $self->{'sort'});

		my $ptArgs = \@args;
		if ($doclevel =~ m/^top(level)?/i)
		{
		    eval ("\$listclassobj = new SimpleList([],\$ptArgs)"); 
		}
		else
		{
		    # first(level)? or (all)?section(s)?
		    eval ("\$listclassobj = new SectionList([],\$ptArgs)");
		}
	    }
	    else
	    {
		
		my @args;
		push @args, ("-metadata", "$metaname");
		# buttonname is also used for the node's title
		push @args, ("-buttonname", "$metavalue");
		push @args, ("-sort", $self->{'sort'});

		if (defined $self->{'removeprefix'}) {
		    push @args, ("-removeprefix", $self->{'removeprefix'});
		}
		if (defined $self->{'removesuffix'}) {
		    push @args, ("-removesuffix", $self->{'removesuffix'});
		}
		
		push @args, ("-doclevel", "$doclevel");
		push @args, ("-mingroup", $mingroup);
		push @args, "-recopt ";

		my $ptArgs = \@args;
		eval ("\$listclassobj = new AZCompactList([],\$ptArgs)");
	    }
	    
	    if ($@) {
		print $outhandle "$@";
		die "\n";
	    }
	    
	    $listclassobj->init();

	    if (defined $metavalue && $metavalue =~ /\w/) 
	    {
		my $formatted_node = $metavalue;

		if (defined($self->{'removeprefix'}) &&
		    length($self->{'removeprefix'})) {
		    $formatted_node =~ s/^$self->{'removeprefix'}//;
		    # check that it's not now empty
		    if (!$formatted_node) {next;}
		}
		if (defined($self->{'removesuffix'}) &&
		    length($self->{'removesuffix'})) {
		    $formatted_node =~ s/$self->{'removesuffix'}$//;
		    # check that it's not now empty
		    if (!$formatted_node) {next;}
		}

		$formatted_node = &sorttools::format_metadata_for_sorting($self->{'metadata'}, $formatted_node) unless $self->{'no_metadata_formatting'};

		# In case our formatted string is empty...
		if (! defined($formatted_node)) {
		    print $outhandle "Warning: AZCompactList: metavalue is ";
		    print $outhandle "empty\n";
		    $formatted_node="";
		}

		# use the lower case, for speed of lookup.
		my $meta_lc=lc($metavalue);
		$self->{'classifiers'}->{$meta_lc}
		= { 'classifyobj'   => $listclassobj,
		    'formattednode' => $formatted_node };
	    }
	}
    }


    return (\@single_classlist,\@multiple_classlist);
}


sub reclassify 
{
    my ($self,$multiple_cl_ref) = @_;

    # Entries in the current classify list that are "book nodes"
    # should be recursively classified.
    #--
    foreach my $dm_pair (@$multiple_cl_ref) 
    {
	my ($doc_OID,$mdoffset,$metavalue,$cs_metavalue) = @$dm_pair;
        my $listclassobj;

	# find metavalue in list of sub-classifiers
	# check if we have a key (lower case) for this metadata value
	my $node_name=lc($metavalue);
	if (exists $self->{'classifiers'}->{$node_name})
	{
	    my ($doc_obj, $sortmeta) = @{$self->{'reclassify'}->{$doc_OID}};

	    # record the metadata value offset temporarily, so eg AZList can
	    # get the correct metadata value (for multi-valued metadata fields)
	    $doc_obj->{'mdoffset'}=$mdoffset;

	    if ($doc_OID =~ m/^[^\.]*\.([\d\.]+)$/)
	    {
		my $section=$1;
		if ($self->{'doclevel'} =~ m/^top(level)?/i) { # toplevel
		    $self->{'classifiers'}->{$node_name}->{'classifyobj'}
		    ->classify($doc_obj,"Section=$section");
		} else { 
		    # first(level)? or (all)?section(s)? 

		    # classify() can't handle multi-level section, so use
		    # classify_section()
		    # ... thanks to Don Gourley for this...

		    $self->{'classifiers'}->{$node_name}->{'classifyobj'}
		    ->classify_section($section, $doc_obj, $sortmeta);
		}
	    }
	    else
	    {
		$self->{'classifiers'}->{$node_name}->{'classifyobj'}
		->classify($doc_obj); 
	    }
	} else { # this key is not in the hash
	    my $outhandle=$self->{outhandle};
	    print $outhandle "Warning: AZCompactList::reclassify ";
	    print $outhandle "could not find sub-node for metadata=`$metavalue' with doc_OID $doc_OID\n";
	}
    }
}



sub get_reclassify_info 
{
    my $self = shift (@_);
    
    my $node_name;
    foreach $node_name (keys %{$self->{'classifiers'}}) 
    {
        my $classifyinfo 
	    = $self->{'classifiers'}->{$node_name}->{'classifyobj'}
	        ->get_classify_info();
        $self->{'classifiers'}->{$node_name}->{'classifyinfo'} 
	    = $classifyinfo;
        $self->{'reclassifylist'}->{"CLASSIFY.$node_name"} 
	    = $self->{'classifiers'}->{$node_name}->{'formattednode'};
    }
}


sub alpha_numeric_cmp
{
    my ($self,$a,$b) = @_;

    my $title_a = $self->{'reclassifylist'}->{$a};
    my $title_b = $self->{'reclassifylist'}->{$b};
    
    if ($title_a =~ m/^(\d+(\.\d+)?)/)
    {
	my $val_a = $1;
	if ($title_b =~ m/^(\d+(\.\d+)?)/)
	{
	    my $val_b = $1;
	    if ($val_a != $val_b)
	    {
		return ($val_a <=> $val_b);
	    }
	}
    }
    
    return ($title_a cmp $title_b);
}

sub frequency_cmp
{
    my ($self,$a,$b) = @_;


    my $title_a = $self->{'reclassifylist'}->{$a};
    my $title_b = $self->{'reclassifylist'}->{$b};

    my $a_freq = 1;
    my $b_freq = 1;

    if ($a =~ m/^CLASSIFY\.(.*)$/)
    {
	my $a_node = $1;
	my $a_nodeinfo = $self->{'classifiers'}->{$a_node}->{'classifyinfo'};
	$a_freq = scalar(@{$a_nodeinfo->{'contains'}});
    }
    
    if ($b =~ m/^CLASSIFY\.(.*)$/)
    {
	my $b_node = $1;
	my $b_nodeinfo = $self->{'classifiers'}->{$b_node}->{'classifyinfo'};
	$b_freq = scalar(@{$b_nodeinfo->{'contains'}});
    }

    return $b_freq <=> $a_freq;
}

sub get_classify_info {
    my $self = shift (@_);

    my @classlist =keys %{$self->{'list_mvpair'}}; # list all doc oids

    my ($single_cl_ref,$multiple_cl_ref) = $self->reinit(\@classlist);
    $self->reclassify($multiple_cl_ref);
    $self->get_reclassify_info();

    my @reclassified_classlist;
    if ($self->{'freqsort'})
    {
	@reclassified_classlist 
	    = sort { $self->frequency_cmp($a,$b) } keys %{$self->{'reclassifylist'}};
	# supress sub-grouping by alphabet
	map { $self->{'reclassifylist'}->{$_} = "A".$self->{'reclassifylist'}; } keys %{$self->{'reclassifylist'}};
    }
    else
    {
#	@reclassified_classlist 
#	    = sort {$self->{'reclassifylist'}->{$a} cmp $self->{'reclassifylist'}->{$b};} keys %{$self->{'reclassifylist'}};

	# alpha_numeric_cmp is slower than "cmp" but handles numbers better ...

	@reclassified_classlist
	    = sort { $self->alpha_numeric_cmp($a,$b) } keys %{$self->{'reclassifylist'}};

    }

    return $self->splitlist (\@reclassified_classlist);
}

sub get_entry {
    my $self = shift (@_);
    my ($title, $childtype, $metaname, $thistype) = @_;
    # organise into classification structure
    my %classifyinfo = ('childtype'=>$childtype,
                        'Title'=>$title,
                        'contains'=>[],
			'mdtype'=>$metaname);

    $classifyinfo{'thistype'} = $thistype
        if defined $thistype && $thistype =~ /\w/;

    return \%classifyinfo;
}



# splitlist takes an ordered list of classifications (@$classlistref) and 
# splits it up into alphabetical sub-sections.
sub splitlist {
    my $self = shift (@_);
    my ($classlistref) = @_;
    my $classhash = {};

    # top level
    my @metanames = split(/\/|\|/,$self->{'metadata'});
    my $metaname = shift(@metanames);

    my $childtype = "HList";
    $childtype = "VList" if (scalar (@$classlistref) <= $self->{'minnesting'});

    my $title = $self->{'buttonname'}; # should always be defined by now.
    my $classifyinfo;
    if (!defined($self->{'recopt'}))
    {
	$classifyinfo 
	    = $self->get_entry ($title, $childtype, $metaname, "Invisible");
    }
    else
    {
	$classifyinfo 
	    = $self->get_entry ($title, $childtype, $metaname, "VList");
    }

    # don't need to do any splitting if there are less than 'minnesting' classifications
    if ((scalar @$classlistref) <= $self->{'minnesting'}) {
	foreach my $subOID (@$classlistref) {
            if ($subOID =~ /^CLASSIFY\.(.*)$/ 
		&& defined $self->{'classifiers'}->{$1}) 
	    {
                push (@{$classifyinfo->{'contains'}}, 
		      $self->{'classifiers'}->{$1}->{'classifyinfo'});
            } 
	    else 
	    {
		$subOID =~ s/^Metavalue_(\d+)\.//;
		my $metaname_offset = $1 -1;
		my $oid_rec = {'OID'=>$subOID, 'offset'=>$metaname_offset};
		push (@{$classifyinfo->{'contains'}}, $oid_rec);
	    }
	}
	return $classifyinfo;
    }
	
    # first split up the list into separate A-Z and 0-9 classifications
    foreach my $classification (@$classlistref) {
	my $title = $self->{'reclassifylist'}->{$classification};
	$title =~ s/&(.){2,4};//g; # remove any HTML special chars
	$title =~ s/^(\W|_)+//g; # remove leading non-word chars

	# only want first character for classification
	$title =~ m/^(.)/; # always a char, or first byte of wide char?
	if (defined($1) && $1 ne "") {
	    $title=$1;

	    # remove any accents on initial character by mapping to Unicode's
	    # normalized decomposed form (accents follow initial letter)
	    # and then pick off the initial letter 
	    my $title_decomposed = NFD($title); 
	    $title = substr($title_decomposed,0,1);
	} else {
	    print STDERR "no first character found for \"$title\" - \"" .
		$self->{'reclassifylist'}->{$classification} . "\"\n";
	}
	$title =~ tr/[a-z]/[A-Z]/;

	if ($title =~ /^[0-9]$/) {$title = '0-9';}
	elsif ($title !~ /^[A-Z]$/) {
	    my $outhandle = $self->{'outhandle'};
	    print $outhandle "AZCompactList: WARNING $classification has badly formatted title ($title)\n";
	}
	$classhash->{$title} = [] unless defined $classhash->{$title};
	push (@{$classhash->{$title}}, $classification);
    }
    $classhash = $self->compactlist ($classhash);

    my @tmparr = ();
    foreach my $subsection (sort keys (%$classhash)) {
	push (@tmparr, $subsection);
    }
    
    # if there's a 0-9 section it will have been sorted to the beginning
    # but we want it at the end
    if ($tmparr[0] eq '0-9') {
	shift @tmparr;
	push (@tmparr, '0-9');
    }
    foreach my $subclass (@tmparr) 
    {
	my $tempclassify 
	    = (scalar(@tmparr)==1) 
		? ($self->get_entry(" ", "VList", $metaname))
		: ($self->get_entry($subclass, "VList", $metaname));


	foreach my $subsubOID (@{$classhash->{$subclass}}) 
	{
            if ($subsubOID =~ /^CLASSIFY\.(.*)$/ 
		&& defined $self->{'classifiers'}->{$1}) 
	    {
		# this is a "bookshelf" node... >1 entry compacted
                push (@{$tempclassify->{'contains'}}, 
		      $self->{'classifiers'}->{$1}->{'classifyinfo'});
		# set the metadata field name, for mdoffset to work
		$self->{'classifiers'}->{$1}->{'classifyinfo'}->{'mdtype'}=
		    $metaname;
	    }
	    else
	    {
		$subsubOID =~ s/^Metavalue_(\d+)\.//;
		# record the offset if this metadata type has multiple values
		my $metaname_offset = $1 -1;
		my $oid_rec = {'OID'=>$subsubOID, 'offset'=>$metaname_offset};
		push (@{$tempclassify->{'contains'}}, $oid_rec);
	    }
	}
	push (@{$classifyinfo->{'contains'}}, $tempclassify);
    }

    return $classifyinfo;
}

sub compactlist {
    my $self = shift (@_);
    my ($classhashref) = @_;
    my $compactedhash = {};
    my @currentOIDs = ();
    my $currentfirstletter = "";
    my $currentlastletter = "";
    my $lastkey = "";

    # minimum and maximum documents to be displayed per page.
    # the actual maximum will be max + (min-1).
    # the smallest sub-section is a single letter at present
    # so in this case there may be many times max documents
    # displayed on a page.
    my $min = $self->{'mincompact'}; 
    my $max = $self->{'maxcompact'};

    foreach my $subsection (sort keys %$classhashref) {
	if ($subsection eq '0-9') {
	    @{$compactedhash->{$subsection}} = @{$classhashref->{$subsection}};
	    next;
	}
	$currentfirstletter = $subsection if $currentfirstletter eq "";
	if ((scalar (@currentOIDs) < $min) ||
	    ((scalar (@currentOIDs) + scalar (@{$classhashref->{$subsection}})) <= $max)) {
	    push (@currentOIDs, @{$classhashref->{$subsection}});
	    $currentlastletter = $subsection;
	} else {

	    if ($currentfirstletter eq $currentlastletter) {
		@{$compactedhash->{$currentfirstletter}} = @currentOIDs;
		$lastkey = $currentfirstletter;
	    } else {
		@{$compactedhash->{"$currentfirstletter-$currentlastletter"}} = @currentOIDs;
		$lastkey = "$currentfirstletter-$currentlastletter";
	    } 
	    if (scalar (@{$classhashref->{$subsection}}) >= $max) {
		$compactedhash->{$subsection} = $classhashref->{$subsection};
		@currentOIDs = ();
		$currentfirstletter = "";
		$lastkey=$subsection;
	    } else {
		@currentOIDs = @{$classhashref->{$subsection}};
		$currentfirstletter = $subsection;
		$currentlastletter = $subsection;
	    }
	}
    }

    # add final OIDs to last sub-classification if there aren't many otherwise
    # add final sub-classification

    # don't add if there aren't any oids
    if (! scalar (@currentOIDs)) {return $compactedhash;}

    if (scalar (@currentOIDs) < $min) {
	my ($newkey) = $lastkey =~ /^(.)/;
	@currentOIDs = (@{$compactedhash->{$lastkey}}, @currentOIDs);
	delete $compactedhash->{$lastkey};
	@{$compactedhash->{"$newkey-$currentlastletter"}} = @currentOIDs;
    } else {
	if ($currentfirstletter eq $currentlastletter) {
	    @{$compactedhash->{$currentfirstletter}} = @currentOIDs;
	} else {
	    @{$compactedhash->{"$currentfirstletter-$currentlastletter"}} = @currentOIDs;
	} 
    }

    return $compactedhash;
}

1;


