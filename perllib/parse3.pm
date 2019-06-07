#Last: Keeping doing the processArg for handing different type of arguments

#parse3(\@_,$arguments,$self )

package parse3;

BEGIN {
    die "GSDLHOME not set\n" unless defined $ENV{'GSDLHOME'};
    die "GSDLOS not set\n" unless defined $ENV{'GSDLOS'};

    # - ensure perllib paths don't already exist in INC before adding, other-
    # wise we risk clobbering plugin/classifier inheritence implied by order
    # of paths in INC [jmt12]
    my $gsdl_perllib_path = $ENV{'GSDLHOME'} . '/perllib';
    my $found_path = 0;
    foreach my $inc_path (@INC)
    {
      if ($inc_path eq $gsdl_perllib_path)
      {
        $found_path = 1;
        last;
      }
    }
    if (!$found_path)
    {
      unshift (@INC, $gsdl_perllib_path);
      unshift (@INC, $gsdl_perllib_path . '/cpan');
    }
}

use util;



#--Local Util Functions----------------------------
#-----------------------------------------
# Name: transformArg
# Parameters: 1.(Array pointer of plugin pre-defined argument list)
# Pre-condition: Call this function and pass a array pointer of argument list.
# Post-condition: This function will transform the array to a hash table 
#                 with "Argument name" as its key
# Return value: Return a hash table of plugin pre-defined argument 
#               list with "argument name" as the key
#-----------------------------------------
sub transformArg
{
    my ($aryptSysArguList) = @_;
    my %hashArg;
    
    foreach my $hashOneArg (@{$aryptSysArguList})
    {
	if(!(defined $hashArg{$hashOneArg->{"name"}}))
	{
	    $hashArg{$hashOneArg->{"name"}} = $hashOneArg;
	}
    }
    return %hashArg;
}

sub checkRange
{
    my ($strRange,$intInputArg,$strArgName) = @_;
    my @aryRange = split(",",$strRange);
    if(defined $aryRange[0])
    {
	if($intInputArg < $aryRange[0])
	{
	    print STDERR " Parameter Parsing Error (Incorrect Range): when parse argument parameter for \"-$strArgName\"\n";
	    return 0;
	}
	else
	{
	    if(scalar(@aryRange) == 2)
	    { 
		if($intInputArg > $aryRange[1])
		{
		    print STDERR " Parameter Parsing Error (Incorrect Range): when parse argument parameter for \"-$strArgName\"\n";
		    return 0;
		}
	    }
	}
    }
    else{ die " System error: minimum range is not defined. Possible mistyping in Argument list for $strArgName\n";}
    return 1;
}

sub checkCharLength
{
    my ($intCharLength,$intInputArg,$strArgName) = @_;
    if($intCharLength =~ m/\d/)
    {
	if(length($intInputArg) != $intCharLength)
	{ 
	    print STDERR " Parameter Parsing Error (Incorrect Char_Length): when parse argument parameter for \"-$strArgName\"\n";
	    return 0;
	}
    }
    else
    {
	die " System error: incorrect char_length. Possible mistyping in Argument list for $strArgName\n";
    }
    return 1;
}
#-----------------------------------------
# Name: processArg
# Parameters: 1.(Hash pointer of one argument)
#             2.(Array pointer of the user given argument)
#             3.(Hash pointer of user given arguments' values)
# Pre-condition: Given a argument ($hashOneArg) 
# Post-condition: System will check whether it need to get parameter 
#                 from $aryptInputArguList or not, and also check the 
#                 given parameter is following the argument description
# Return value: 1 is parsing successful, 0 is failed.
#-----------------------------------------
sub processArg
{
    my ($hashOneArg,$aryptInputArguList,$hashInputArg) = @_;

    # Since these two variables are going to be 
    # used a lot, store them with some better names.
    my $strArgName = $hashOneArg->{"name"};
    my $strArgType = $hashOneArg->{"type"};

    # If the argument type is "flag" then 
    # set it to 1(which is "true") 
    if($strArgType eq "flag")
    {
	$hashInputArg->{$strArgName} = 1;
    }

    # If the argument type is "int" then
    # gets the next argument from $aryptInputArguList 
    # and check whether it is a digit
    # TODO: check its "range" and "char_length"
    elsif($strArgType eq "int")
    {
	my $intInputArg = shift(@{$aryptInputArguList});
	if ($intInputArg =~ /\d+/)
	{
	    $hashInputArg->{$strArgName} = $intInputArg;
	}
	else
	{
	    print STDERR " Error: occur in parse3.pm::processArg()\n Unmatched Argument: -$strArgName with type $strArgType\n";
	    return 0;
	}
    }

    # If the argument type is "enum" then
    elsif($strArgType eq "enum")
    {
	if(defined $hashOneArg->{"list"})
	{
	    my $aryptList = $hashOneArg->{"list"};
	    my $blnCheckInList = "false";
	    my $strInputArg = shift(@{$aryptInputArguList});
	    foreach my $hashEachItem (@$aryptList)
	    {
		if($strInputArg eq $hashEachItem->{"name"})
		{
		    $blnCheckInList = "true";
		}
		last if($blnCheckInList eq "true");
	    }
	    if($blnCheckInList ne "true")
	    {
		print STDERR " Error: occur in parse3.pm::processArg()\n Unknown Enum List Type: -$strArgName with parameter: $strInputArg\n";
		return 0;
	    } else {
		$hashInputArg->{$strArgName} = $strInputArg;
	    }
	    
	}
	else
	{
	    print STDERR " Error: occur in parse3.pm::processArg(2)\n Unknown Type: -$strArgName with type $strArgType\n";
	    return 0;
	}
    }

    # If the argument type is "string" or "metadata" then
    # just shift the next argument from $aryptInputArguList
    # TODO: make sure if there is any checking required for this two types
    elsif($strArgType eq "string" || $strArgType eq "metadata" || $strArgType eq "regexp" || $strArgType eq "url")
    {
	$hashInputArg->{$strArgName}= shift(@{$aryptInputArguList});
    }
    #if the argument type is "quotestr", then the next several arguments must be shifted from $aryptInputArugList
    #lets see if we can detect an end double quote
    elsif($strArgType eq "quotestr") 
    {
	my $tmpstr = shift(@{$aryptInputArguList}); 
	$hashInputArg->{$strArgName} = ""; 
	while($tmpstr !~ /\"$/)  {
             $hashInputArg->{$strArgName} = $hashInputArg->{$strArgName}." ".$tmpstr; 
	     $tmpstr = shift(@{$aryptInputArguList}); 
        }
        $hashInputArg->{$strArgName} = $hashInputArg->{$strArgName}." ".$tmpstr; 
    }
    else
    {
	print STDERR " Error: occur in parse3.pm::processArg(3)\n Unknown Type: -$strArgName with type $strArgType\n";
	return 0;
    }
    
    return 1;
}

#--Main Parsing Function----------------------------
#-----------------------------------------
# Name: parse
# Parameters: 1.(Array pointer of the user given argument)
#             2.(Array pointer of plugin pre-defined argument list)  
#             3.(Hash pointer, where we store all the argument value)
# Pre-condition: Plugin gives the parameters to parse function in parse3 
# Post-condition: Store all the default or user given values to the hash->{$ArgumentName}.
#                 Since hash may be a plugin $self, plugin will have every values we set.
#             4. Optional "allow_extra_options" argument. If this is set, then
#                its ok to have arguments that are not in the predefined list
# Return value: -1 if parsing is unsuccessful
#                other value for success. This will be 0 unless "allow_extra_options" is set, in which case it will be the number of extra arguments found. 
#-----------------------------------------
sub parse
{
    # Get the user supplied arguments pointer "\@_"
    my $aryptUserArguList = shift; 

    # Check if allow extra arguments
    my $blnAllowExtraOptions = "false";
    
    if(scalar(@_) == 3)
    { 
	my $strAllowExtraOptions = pop @_;
	
	if ($strAllowExtraOptions eq "allow_extra_options") 
	{
	    $blnAllowExtraOptions = "true";    
	} 
    }
    
    my ($aryptSysArguList,$self) = @_;
    my %hashArg;
    my %hashInputArg;
    my @ExtraOption;

    # Transform the system argument (predefined the code) 
    # from array to hash table for increasing performance
    %hashArg = &transformArg($aryptSysArguList);

    # Process each User input argument and store the 
    # information into hashInputArg
    while (my $strOneArg = shift(@{$aryptUserArguList}))
    {
	# Check whether it start with a "-" sign
	if ($strOneArg =~ /^-+\w/)
	{
	    # If it is start with a "-" sign then take it off
	    $strOneArg =~ s/^-+//;

	    # If the inputed argument is defined in the argument 
	    # list from this plugin then process
	    
	    if(defined $hashArg{$strOneArg})
	    {
		#$%^
		#print "($strOneArg) is processed\n";
		# Process this argument and store the related 
		# information in %hashInputArg
		if(processArg($hashArg{$strOneArg},$aryptUserArguList,\%hashInputArg) == 0){ 
		    print STDERR "<BadArgumentValue a=$strOneArg>\n";
		    return -1;}
	    }
	    
	    # Else check if it allows extra options, if yes 
	    # then push it to a new array, else return fault
	    else
	    {
		if($blnAllowExtraOptions eq "true")
		{
		    push(@ExtraOption,"-$strOneArg");
		}
		else
		{
		    print STDERR "<BadArgument a=$strOneArg>\n";
		    print STDERR " Error: occur in parse3.pm::parse()\n Extra Arguments: $strOneArg\n";
		    return -1;
		}
	    }
	}
	
	# This part follow the previous parsing system. 
	# It doesn't return error message even user
	# gave a invalid argument.
	else
	{
	    if($blnAllowExtraOptions eq "true")
	    {
		push(@ExtraOption,$strOneArg);
	    }
	    else
	    {
		print STDERR " Error: occur in parse3.pm::parse()\n Invalid Argument: $strOneArg\n";
		return -1;
	    }
	}
    }

    # Store the extra option back 
    # to the user given argument list.
    @$aryptUserArguList = @ExtraOption;
    
    # Now we go through all the pre defined arguments, 
    # if the user has specified the arguments then just 
    # set to whatever they set. Otherwise use the default value
    foreach my $hashOneArg (@{$aryptSysArguList})
    {
	my $strArgName = $hashOneArg->{"name"};

	# If the strArgName has defined in the %hashInputArg, 
	# this means users has give this argument, store the 
	# user given to self->{"$strArgName"}
	if(defined $hashInputArg{$strArgName})
	{
	    if(defined $hashOneArg->{"range"}) 
	    {
		if(checkRange($hashOneArg->{"range"},$hashInputArg{$strArgName},$strArgName) == 0){ return -1;}
	    }
	    if(defined $hashOneArg->{"char_length"})
	    {
		if(checkCharLength($hashOneArg->{"char_length"},$hashInputArg{$strArgName},$strArgName) == 0){ return -1;}
	    }
	    $self->{"$strArgName"} = $hashInputArg{"$strArgName"};
	}
	elsif (!defined $self->{$strArgName}) 
	{
	    # don't want to override default with superclass value
	  
	    # Else use the default value of the arguments, 
	    # if there is no default value, then it must be a flag, 
	    # then set it to 0 (which is false)
	
	    if(defined $hashOneArg->{"deft"})
	    {
		$self->{"$strArgName"} = $hashOneArg->{"deft"};
	    }
	    else
	    {
		if($hashOneArg->{"type"} eq "flag"){ 
		    $self->{"$strArgName"} = 0;
		}
		else {
		    # all other cases, use "" as default
		    $self->{"$strArgName"} = "";
		}
	    }
	}
    }

    # If allow_extra_options is set, then return the number of arguments left in the argument list.
    if($blnAllowExtraOptions eq "true")
    {
	return scalar(@$aryptUserArguList);
    }
    else
    {
	return 0;
    }
}

1;
