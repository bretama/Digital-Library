###########################################################################
#
# AZCompactSectionList.pm --
#
# Experimental AZCompactList with fixes to handle section-level metadata
#
###########################################################################

package AZCompactSectionList;

use AZCompactList;
use FileUtils;

use strict;
no strict 'refs'; # allow filehandles to be variables and viceversa

sub BEGIN {
    @AZCompactSectionList::ISA = ('AZCompactList');
}

my $arguments = [
      { 'name' => "doclevel",
	'desc' => "{AZCompactList.doclevel}",
	'type' => "enum",
	'list' => $AZCompactList::doclevel_list,
	'deft' => "section",
	'reqd' => "no" },
		 ];
my $options = 
{ 	'name'     => "AZCompactSectionList",
	'desc'     => "{AZCompactSectionList.desc}",
	'abstract' => "no",
	'inherits' => "yes",
	'args'     => $arguments };

sub new {
    my ($class) = shift (@_);
    my ($classifierslist,$inputargs,$hashArgOptLists) = @_;
    push(@$classifierslist, $class);

    push(@{$hashArgOptLists->{"ArgList"}},@{$arguments});
    push(@{$hashArgOptLists->{"OptList"}},$options);
    
    my $self = new AZCompactList($classifierslist, $inputargs, $hashArgOptLists);

    return bless $self, $class;
}

#
# override reinit() & reclassify() to demonstrate possible bug fixes
# (search for SECTIONFIX? to see lines changed from AZCompactList.pm)
#
sub reinit 
{
    my ($self,$classlist_ref) = @_;
    
    my %mtfreq = ();
    my @single_classlist = ();
    my @multiple_classlist = ();

    # find out how often each metavalue occurs
    map 
    { 
	my $mv;
	foreach $mv (@{$self->{'listmetavalue'}->{$_}} )
	{
	    $mtfreq{$mv}++; 
	}
    } @$classlist_ref;

    # use this information to split the list: single metavalue/repeated value
    map
    { 
	my $i = 1;
	my $metavalue;
	foreach $metavalue (@{$self->{'listmetavalue'}->{$_}})
	{
	    if ($mtfreq{$metavalue} >= $self->{'mingroup'})
	    {
		push(@multiple_classlist,[$_,$i,$metavalue]); 
	    } 
	    else
	    {
		push(@single_classlist,[$_,$metavalue]); 
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
	    my $outhandle = $self->{'outhandle'};
	    print $outhandle "AZCompactList ERROR - couldn't find classifier \"$listname\"\n"; 
	    die "\n";
	}
    }

    # Create classifiers objects for each entry >= mingroup
    my $metavalue;
    foreach $metavalue (keys %mtfreq)
    {
	if ($mtfreq{$metavalue} >= $self->{'mingroup'})
	{
	    my $listclassobj;
	    my $doclevel = $self->{'doclevel'};
	    my $metaname  = $self->{'metadata'};
	    my @metaname_list = split('/',$metaname);
	    $metaname = shift(@metaname_list);
	    if (@metaname_list==0)
	    {
		my @args;
		push @args, ("-metadata", "$metaname");
# buttonname is also used for the node's title
		push @args, ("-buttonname", "$metavalue");
		push @args, ("-sort", $self->{'sort'});

		my $ptArgs = \@args;
		if ($doclevel =~ m/^top(level)?/i)
		{
		    eval ("\$listclassobj = new SimpleList([],\$ptArgs)"); warn $@ if $@;
		}
		else
		{
		    # SECTIONFIX?
		    #eval ("\$listclassobj = new SectionList($args)");
		    eval ("\$listclassobj = new SectionList([],\$ptArgs)");
		}
	    }
	    else
	    {
		$metaname = join('/',@metaname_list);
		
		my @args;
		push @args, ("-metadata", "$metaname");
# buttonname is also used for the node's title
		push @args, ("-buttonname", "$metavalue");
		push @args, ("-doclevel", "$doclevel");
		push @args, "-recopt";

		# SECTIONFIX?
		#eval ("\$listclassobj = new AZCompactList($args)");
		my $ptArgs = \@args;
		eval ("\$listclassobj = new AZCompactList([],\$ptArgs)");
	    }
	    if ($@) {
		my $outhandle = $self->{'outhandle'};
		print $outhandle "$@";
		die "\n";
	    }
	    
	    $listclassobj->init();

	    if (defined $metavalue && $metavalue =~ /\w/) 
	    {
		my $formatted_node = $metavalue;
		if ($self->{'metadata'} =~ m/^Creator(:.*)?$/)
		{
		    &sorttools::format_string_name_en(\$formatted_node);
		} 
		else 
		{
		    &sorttools::format_string_en(\$formatted_node);
		}
		
		$self->{'classifiers'}->{$metavalue} 
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
	my ($doc_OID,$mdoffset,$metavalue) = @$dm_pair;
        my $listclassobj;

	# find metavalue in list of sub-classifiers
	my $found = 0;
	my $node_name;
	foreach $node_name (keys %{$self->{'classifiers'}}) 
	{
	    my $resafe_node_name = $node_name;
	    $resafe_node_name =~ s/(\(|\)|\[|\]|\{|\}|\^|\$|\.|\+|\*|\?|\|)/\\$1/g;
	    if ($metavalue =~ m/^$resafe_node_name$/i) 
	    {
		my ($doc_obj, $sortmeta) = @{$self->{'reclassify'}->{$doc_OID}};

		# SECTIONFIX?  section must include multiple levels, e.g. '1.12'
		#if ($doc_OID =~ m/^.*\.(\d+)$/)
		if ($doc_OID =~ m/^[^\.]*\.([\d\.]+)$/)
		{
		    $self->{'classifiers'}->{$node_name}->{'classifyobj'}
		    # SECTIONFIX? classify can't handle multi-level section
		    #->classify($doc_obj, "Section=$1"); 
		    ->classify_section($1, $doc_obj, $sortmeta);
		}
		else
		{
		    $self->{'classifiers'}->{$node_name}->{'classifyobj'}
		    ->classify($doc_obj); 
		}
		
		$found = 1;
		last;
	    }
	}
	
	if (!$found)
	{
	    my $outhandle = $self->{'outhandle'};
	    print $outhandle "Warning: AZCompactList::reclassify ";
	    print $outhandle "could not find sub-node for $metavalue with doc_OID $doc_OID\n";
	}
    }
}

1;
