# This class based on arcinfo.pm
package oaiinfo;

use constant INFO_STATUS_INDEX  => 0;
use constant INFO_TIMESTAMP_INDEX => 1;
use constant INFO_DATESTAMP_INDEX => 2;

my $OID_EARLIEST_TIMESTAMP = "_earliesttimestamp";
  # Declaring as my $OID_EARLIEST_TIMESTAMP rather than constant, because it's not straightforward
  # to use string constant as hash key (need to concat with empty str).
  # http://perldoc.perl.org/constant.html
  # But beware of using perl 'constant' as hash key:
  # https://stackoverflow.com/questions/96848/is-there-any-way-to-use-a-constant-as-hash-key-in-perl
  # http://forums.devshed.com/perl-programming-6/massive-using-constants-hash-keys-603600.html
  # https://perlmaven.com/constants-and-read-only-variables-in-perl
  # http://neilb.org/reviews/constants.html - compares different ways to declare constants in perl

use strict;

use arcinfo;
use dbutil;

# Store timestamp in 2 formats: internal and external (same as oailastmodified and oailastmodifieddate)
# These times indicate the last modified date for that document. In the case of the doc being deleted,
# it's the time the doc was deleted.

# File format read in: OID <tab> (Deletion-)Status <tab> Timestamp <tab> Datestamp

# A special record of the db contains the timestamp of the creation of the oai-inf.db for
# the collection, representing the collection's earliest datetimestamp.
# This record has $OID_EARLIEST_TIMESTAMP for OID.
# Its deletion status is maintained at NA, not applicable.
# In cases of older oai-inf.db files where there's no $OID_EARLIEST_TIMESTAMP record, this record
# is also created but with timestamp set to the oldest lastmodified date in oai-inf.db.

# Deletion status can be:
#  E = Doc with OID exists (has not been deleted from collection). Timestamp indicates last time of build
#  D = Doc with OID has been deleted. Timestamp indicates time of deletion
#  PD = Provisionally Deleted. The associated timestamps are momentarily unaltered.
#  NA = Not Applicable. Only for the special record with $OID_EARLIEST_TIMESTAMP as OID.

# oaidb is "always incremental": always reflects the I/B/R/D status of archive info db,
# before the indexing step of the build phase that alters the I/B/R/D contents of archive info db. 
# (I=index, B=been indexed, R=reindex; D=delete)

sub new {
    my $class = shift(@_);
    my ($config_filename, $infodbtype, $verbosity) = @_;
 
    my $self = { 
	'verbosity' => $verbosity || 0,
	'verbosity_threshold' => 5, # start printing debugging info from verbosity >= threshold
	'info'=>{} # map of {OID, array[deletion-status,timestamp,datestamp]} pairs
    };
    
    if(!defined $infodbtype) {
	$infodbtype = &dbutil::get_default_infodb_type();
    }
    $infodbtype = "gdbm" if ($infodbtype eq "gdbm-txtgz");
    $self->{'infodbtype'} = $infodbtype;

    # Create and store the db filenames we'll be working with (tmp and livedb)
    my $etc_dir = &util::get_parent_folder($config_filename);

    my $perform_firsttime_init = 0;
    $self->{'oaidb_live_filepath'} = &dbutil::get_infodb_file_path($infodbtype, "oai-inf", $etc_dir, $perform_firsttime_init);
    $self->{'oaidb_tmp_filepath'} = &dbutil::get_infodb_file_path($infodbtype, "oai-inf-tmp", $etc_dir, $perform_firsttime_init);
    $self->{'etc_dir'} = $etc_dir;
#    print STDERR "############ LIVE DB: $self->{'oaidb_live_filepath'}\n" if $self->{'verbosity'} >= $self->{'verbosity_threshold'};
#    print STDERR "############ TMP DB: $self->{'oaidb_tmp_filepath'}\n" if $self->{'verbosity'} >= $self->{'verbosity_threshold'};

    $self->{'oaidb_file_path'} = $self->{'oaidb_tmp_filepath'}; # db file we're working with

    return bless $self, $class;
}

# this subroutine will work out the starting contents of the tmp-db (temporary oai db):
# whether it should start off empty, or with the contents of any existing live-db, 
# or with the contents of any existing tmp-db.
sub init_tmpdb {
    my $self = shift(@_);
    my ($removeold, $have_manifest) = @_;

    # if we have a manifest file, then we pretend we are fully incremental for oaiinfo db.
    # removeold implies proper full-rebuild, whereas keepold or incremental means incremental
    if($have_manifest) { # if we have a manifest file, we're not doing removeold/full-rebuild either
	$removeold = 0;
    }

    my $do_pd_step = ($removeold) ? 1 : 0;
       # if $removeold, then proper full rebuild, will carry out step where all E will be marked as PD
       # else some kind of incremental build, won't do the extra PD pass 
       # which is the step marking existing OIDs (E) as PD (provisionally deleted)	
    
    my $oaidb_live_filepath = $self->{'oaidb_live_filepath'};
    my $oaidb_tmp_filepath = $self->{'oaidb_tmp_filepath'};
    my $infodbtype = $self->{'infodbtype'};
    # Note: the live db can only exist if the collection has been activated at least once before
    my $livedb_exists = &FileUtils::fileExists($oaidb_live_filepath);
    my $tmpdb_exists = &FileUtils::fileExists($oaidb_tmp_filepath);    

    my $initdb = 0;
    
    # work out what operation we need to do
    #    work with empty tmpdb
    #    copy_livedb_to_tmpdb
    #    work with existing tmpdb (so existing tmpdb will be topped up)

    # make_contents_of_tmpdb_empty
    # make_contents_of_tmpdb_that_of_livedb
    # continue_working_with_tmpdb ("contents_of_tmpdb_is_tmpdb")

    # We're going to prepare the starting state of tmpdb next. 
    # It can start off empty, start off with the contents of livedb, or it can start off with the contents
    # of the existing tmp db. Which of these three it is depends on the 3 factors: whether livedb exists,
    # whether tmpdb exists and whether or not removeold is true.
    # i.o.w. which of the 3 outcomes it is depends on the truth table built on the following 3 variables:
    #   LDB = LiveDB exists
    #   TDB = TmpDB exists
    #   RO = Removeold
    # OUTCOMES: 
    #   clean slate (create an empty tmpdb/make tmpdb empty)
    #   top up tmpDB (work with existing tmpdb)
    #   copy LiveDB to TmpDB (liveDB's contents become the contents of TmpDB, and we'll work with that)
    #
    # TRUTH TABLE:
    # ---------------------------------------
    # LDB TDB  RO | Outcome
    # ---------------------------------------
    #  0   0   0  | clean-slate
    #  0   0   1  | clean-slate
    #  0   1   0  | top-up-tmpdb
    #  0   1   1  | erase tmpdb, clean-slate
    #  1   0   0  | copy livedb to tmpdb
    #  1   0   1  | copy livedb to tmpdb
    #  1   1   0  | top-up-tmpdb
    #  1   1   1  | copy livedb to tmpd
    # ---------------------------------------
    # 
    # Dr Bainbridge worked out using Karnaugh maps that, from the above truth table:
    # => clean-slate/empty-tmpdb = !LDB && (RO || !TDB)
    # => top-up-tmpdb/work-with-existing-tmpdb = !RO && TDB
    # => copy-livedb-to-tmpdb = LDB && (!TDB || RO)
    # I had most of these tests, except that I hadn't (yet) merged the two clean slate instances
    # of first-build-ever and make-contents-of-tmpdb-empty

    #my $first_build_ever = (!$livedb_exists && !$tmpdb_exists);
    #my $make_contents_of_tmpdb_empty = (!$livedb_exists && $tmpdb_exists && $removeold);
    # Karnaugh map allows merging $first_build_ever and $make_contents_of_tmpdb_empty above
    # into: my $work_with_empty_tmpdb = (!$livedb_exists && (!$tmpdb_exists || $removeold));
    my $work_with_empty_tmpdb = (!$livedb_exists && (!$tmpdb_exists || $removeold));
    my $make_contents_of_tmpdb_that_of_livedb = ($livedb_exists && (!$tmpdb_exists || $removeold));
    my $work_with_existing_tmpdb = ($tmpdb_exists && !$removeold);

    if($work_with_empty_tmpdb) { # we'll use an empty tmpdb

	# If importing the collection for the very first time, neither db exists, 
	# so create an empty tmpdb.
	#
	# We also create an empty tmpdb when livedb doesn't exist and $removeold is true.
	# This can happen if we've never run activate (so no livedb),
	# yet had done some import (and perhaps building) followed by a full re-import now.
	# Since there was no activate and we're doing a removeold/full-rebuild now, can just
	# work with a new tmpdb, even though one already existed, its contents can be wiped out.
        # In such a scenario, we'll be deleting tmpdb. Then there  will be no livedb nor any tmpdb
	# any more, so same situation as if importing the very first time when no oaidb exists either.

	&dbutil::remove_db_file($self->{'infodbtype'}, $oaidb_tmp_filepath) if $tmpdb_exists; # remove the db file and any assoc files
	$initdb = 1; # new tmpdb
	
	# if the oai db is created the first time, it's like incremental and
	# "keepold" (keepold means "only add, don't reprocess existing"). So
	# no need to do the special passes dealing with "provisional deletes".
	$do_pd_step = 0;
	
    } elsif ($make_contents_of_tmpdb_that_of_livedb) {

	# If the livedb exists and we're doing a full rebuild ($removeold is true), 
	# copy livedb to tmp regardless of if tmpdb already exists.
	# Or if the livedb exists and tmpdb doesn't exist, it doesn't matter
	# if we're incremental or not: also copy live to tmp and work with tmp.
	
	# copy livedb to tmpdb
	&dbutil::remove_db_file($self->{'infodbtype'}, $oaidb_tmp_filepath) if $tmpdb_exists; # remove the db file and any assoc files
	&FileUtils::copyFiles($oaidb_live_filepath, $oaidb_tmp_filepath);
	
	$initdb = 0; # tmpdb exists, since we just copied livedb to tmpdb, so no need to init existing tmpdb

    } else { # $work_with_existing_tmpdb, so we'll build on top of what's presently already in tmpdb
	     # (we'll be topping up the current tmpdb)

	# !$removeold, meaning incremental
	# If incremental and have a tmpdb already, regardless of whether livedb exists,
	# then work with the existing tmpdb file, as this means we've been 
	# importing (perhaps followed by building) repeatedly without activating the 
	# last time but want to maintain the (incremental) changes in tmpdb.	    
	  
	$initdb = 0;

    } # Dr Bainbridge drew up Karnaugh maps on the truth table, which proved that all cases
                    # are indeed covered above, so don't need any other catch-all else here

    $self->{'oaidb_file_path'} = &dbutil::get_infodb_file_path($infodbtype, "oai-inf-tmp", $self->{'etc_dir'}, $initdb);
                                 # final param follows jmt's $perform_firsttime_init in inexport.pm

#    print STDERR "@@@@@ oaidb: $self->{'oaidb_file_path'}\n" if $self->{'verbosity'} >= $self->{'verbosity_threshold'};

    return ($do_pd_step, $initdb);
}

sub get_filepath {
    my $self = shift (@_);
    return $self->{'oaidb_file_path'};
}

sub import_stage {
    my $self = shift (@_);
    my ($removeold, $have_manifest) = @_;
	
    my ($do_pd_step, $is_new_db) = $self->init_tmpdb($removeold, $have_manifest);
      # returns 1 for $do_pd_step if the step to mark oaidb entries as PD is required
      # if we're doing full rebuilding and it's NOT the first time creating the oai_inf db, 
      # then the tasks to do with PD (provisionally deleted) OAI OIDs should be carried out
      # Returns 1 for is_new_db to allow further one time initialisation of the new oai-inf.db

    $self->load_info();
    $self->print_info(); # DEBUGGING

    # A special record of the oai-inf.db will contain the timestamp when the oai-inf.db was created.
    # This represents the collection's "earliest datetimestamp". It should remain unaltered
    # for as long as oai-inf db exists. This record has the special OID of $OID_EARLIEST_TIMESTAMP.
    # This record should not be marked as PD, but remain as E, as it can't ever be deleted.
    # Although the status field for the $OID_EARLIEST_TIMESTAMP record is actually meaningless.    
    my $save_to_db = $self->insert_coll_earliest_timestamp($is_new_db);    
    
    if ($do_pd_step) {
	$self->mark_all_existing_as_provisionallydeleted();
	$self->print_info(); # DEBUGGING
	
	$save_to_db = 1;	
    }

    if($save_to_db) {
	# save changes to $self->{'info'} out to db file, now that we're done
	$self->save_info(); 
    }

}

sub building_stage_before_indexing() {
    my $self = shift (@_);    
    my ($archivedir) = @_;

    # load archive info db into memory
    my $arcinfo_doc_filename = &dbutil::get_infodb_file_path($self->{'infodbtype'}, "archiveinf-doc", $archivedir);
    my $arcinfo_src_filename = &dbutil::get_infodb_file_path($self->{'infodbtype'}, "archiveinf-src", $archivedir);
    my $archive_info = new arcinfo ($self->{'infodbtype'});
    $archive_info->load_info ($arcinfo_doc_filename);

    #my $started_from_scratch = &FileUtils::fileTest($self->{'oaidb_tmp_filepath'}, '-z'); # 1 if tmpdb is empty
        # -z test for file is empty http://www.perlmonks.org/?node_id=927447
   
    # load the oaidb file's contents into memory.
    $self->load_info();
    $self->print_info(); # DEBUGGING

    # process all the index, reindex and delete operations as indicated in arcinfo,
    # all the while ensuring all PDs are changed back to E for OIDs that exist in both arcinfo and oaiinfo db.  

    my $arcinfo_map = $archive_info->{'info'};

    foreach my $OID (keys %$arcinfo_map) {
	my $arcinf_tuple = $archive_info->{'info'}->{$OID};
	my $indexing_status = $arcinf_tuple->[arcinfo::INFO_STATUS_INDEX];
	             # use packageName::constant to refer to constants declared in another package,
	             # see http://perldoc.perl.org/constant.html

	print STDERR "######## OID: $OID - status: $indexing_status\n" if $self->{'verbosity'} >= $self->{'verbosity_threshold'};

	if($indexing_status eq "I") {
	    $self->index($OID); # add new as E with current timestamp/or set existing as E with orig timestamp
	} elsif($indexing_status eq "R") {
	    $self->reindex($OID); # update timestamp and ensure marked as E (if oid doesn't exist, add new)
	} elsif($indexing_status eq "D") {
	    $self->delete($OID); # set as D with current timestamp
	} elsif($indexing_status eq "B") { # B for "been indexed"
	    $self->been_indexed($OID); # will flip any PD to E if oid exists, else will add new entry for oid
	    # A new entry may be required if the collection had been built prior to turning this into
	    # an oaicollection. But what if we always maintain an oaidb? Still call $self->index() here.
	} else {
	    if ($self->{'verbosity'} >= $self->{'verbosity_threshold'}) {
		print STDERR "### oaiinfo::building_stage_before_indexing(): Unrecognised indexing status $indexing_status\n";
	    }
	}
    }

    # once all docs processed, go through oaiiinfo db changing any PDs to D along with current timestamp
    # to indicate that they're deleted
    $self->mark_all_provisionallydeleted_as_deleted();
    $self->print_info();
    
    # let's save to db file now that we're done
    $self->save_info();
    
}

sub activate_collection { # move tmp db to live db
    my $self = shift (@_);

    my $oaidb_live_filepath =  $self->{'oaidb_live_filepath'};
    my $oaidb_tmp_filepath = $self->{'oaidb_tmp_filepath'};

    my $livedb_exists = &FileUtils::fileExists($oaidb_live_filepath);
    my $tmpdb_exists = &FileUtils::fileExists($oaidb_tmp_filepath);

    if($tmpdb_exists) {
	if($livedb_exists) {
	    #&dbutil::remove_db_file($self->{'infodbtype'}, $oaidb_live_filepath); # remove the db file and any assoc files
	    &dbutil::rename_db_file_to($self->{'infodbtype'}, $oaidb_live_filepath, $oaidb_live_filepath.".bak"); # rename the db file and any assoc files
	}
	#&FileUtils::moveFiles($oaidb_tmp_filepath, $oaidb_live_filepath);
	&dbutil::rename_db_file_to($self->{'infodbtype'}, $oaidb_tmp_filepath, $oaidb_live_filepath); # rename the db file and any assoc files

	if ($self->{'verbosity'} >= $self->{'verbosity_threshold'}) {
		print STDERR "#### Should now have MOVED $self->{'oaidb_tmp_filepath'} to $self->{'oaidb_live_filepath'}\n";
	}
	
    } else {
	if ($self->{'verbosity'} >= $self->{'verbosity_threshold'}) {
	    print STDERR "@@@@@ In oaiinfo::activate_collection():\n";
	    print STDERR "@@@@@   No tmpdb at $self->{'oaidb_tmp_filepath'}\n";
	    print STDERR "@@@@@   to make 'live' by moving to $self->{'oaidb_live_filepath'}.\n";
	}
    }
}

##################### SPECIFIC TO PD-STEP ####################


# mark all existing, E (non-deleted) OIDs as Provisionally Deleted (PD)
# this subroutine doesn't save to oai-inf.DB
# the caller should call save_info when they want to save to the db
sub mark_all_existing_as_provisionallydeleted {
    my $self = shift (@_);
    
    print STDERR "@@@@@ oaiinfo::mark_all_E_as_PD(): Marking the E entries as PD\n" if $self->{'verbosity'} >= $self->{'verbosity_threshold'};

    my $infomap = $self->{'info'};

    foreach my $OID (keys %$infomap) { # Mac Mountain Lion wants %$map, won't accept %$self->{'info'}
	my $OID_info = $self->{'info'}->{$OID};
	my $curr_status = $OID_info->[INFO_STATUS_INDEX];
	if($curr_status eq "E") {	    
	    $OID_info->[INFO_STATUS_INDEX] = "PD";
	}
    }
}

# mark all OIDs that are Provisionally Deleted (PD) as deleted, and set to current timestamp
# To be called at end of build. Again, the caller should save to DB by calling save_info.
sub mark_all_provisionallydeleted_as_deleted {
    my $self = shift (@_);
    
    print STDERR "@@@@@ oaiinfo::mark_all_PD_as_D(): Marking the PD entries as D\n" if $self->{'verbosity'} >= $self->{'verbosity_threshold'};

    my $infomap = $self->{'info'};

    foreach my $OID (keys %$infomap) {
	my $OID_info = $self->{'info'}->{$OID};
	my $curr_status = $OID_info->[INFO_STATUS_INDEX];
	if($curr_status eq "PD") {
	    $self->set_info($OID, "D", $self->get_current_time());
	}
    }
}


##################### GENERAL, NOT SPECIFIC TO PD-STEP ####################

sub print_info {
    my $self = shift (@_);

    if ($self->{'verbosity'} < $self->{'verbosity_threshold'}) {
	return;
    }
	
    print STDERR "###########################################################\n";
    print STDERR "@@@@@ oaiinfo::print_info(): oaidb in memory contains: \n";
    
    my $infomap = $self->{'info'};

    foreach my $OID (keys %$infomap) {
	print STDERR "OID: $OID";
	print STDERR " status: " . $self->{'info'}->{$OID}->[INFO_STATUS_INDEX];
	print STDERR " time: " . $self->{'info'}->{$OID}->[INFO_TIMESTAMP_INDEX];
	print STDERR " date: " . $self->{'info'}->{$OID}->[INFO_DATESTAMP_INDEX];
	print STDERR "\n";
    }

    print STDERR "###########################################################\n";
}


# When a fresh oai-inf.db is created, this method is called to add the db's special
# record representing the collection's earliest timestamp.
# OID=$OID_EARLIEST_TIMESTAMP, deletion_status=NA for not applicable, and current timestamp/date.
# For older oai-inf.db's that don't yet have this record, a record will be added too,
# but with the timestamp set to the oldest last modified date for the collection's docs.
sub insert_coll_earliest_timestamp {
    my $self = shift (@_);
    my ($is_new_db) = @_;

    my $current_time = $self->get_current_time();
    my $save_to_db = 0;

    
    print STDERR "@@@@@ oaiinfo::insert_coll_earliest_timestamp(): " if $self->{'verbosity'} >= $self->{'verbosity_threshold'};
    
    if($is_new_db) {
	
	print STDERR "New db. Setting timestamp of oai-inf.db creation.\n" if $self->{'verbosity'} >= $self->{'verbosity_threshold'};
	
	$self->set_info($OID_EARLIEST_TIMESTAMP, "NA", $current_time);
	$save_to_db = 1;
    }
    
    else { # oai-inf.db already exists, ensure it has an [$OID_EARLIEST_TIMESTAMP] set

	my $earliesttimestamp_record = $self->{'info'}->{$OID_EARLIEST_TIMESTAMP};
	
	if (!defined $earliesttimestamp_record) {
	    # oai-inf.db exists, but doesn't contain an [$OID_EARLIEST_TIMESTAMP] record yet.
	    # Let's create one for it:
	    # Work out the earliest lastmodified datetime in the collection, by inspecting
	    # the last modified timestamp for each doc in the collection
	    
	    my $earliest_timestamp = $current_time;
	    
	    my $infomap = $self->{'info'}; # Mac Mountain Lion wants %$map, won't accept %$self->{'info'}	    
	    foreach my $OID (keys %$infomap) {
		my $OID_info = $self->{'info'}->{$OID};
		my $lastmodified = $OID_info->[INFO_TIMESTAMP_INDEX];
		if($lastmodified < $earliest_timestamp) {
		    $earliest_timestamp = $lastmodified;
		}
	    }
	    
	    print STDERR "Collection timestamp not yet set for $OID_EARLIEST_TIMESTAMP. Setting to earliest found: $earliest_timestamp\n" if $self->{'verbosity'} >= $self->{'verbosity_threshold'};
	    
	    $self->set_info($OID_EARLIEST_TIMESTAMP, "NA", $earliest_timestamp);
	    $save_to_db = 1;
	} else {
	    print STDERR "Collection timestamp was already set\n" if $self->{'verbosity'} >= $self->{'verbosity_threshold'};
	}
    }

    return $save_to_db;
}


# Find the OID, if it exists, make its status=E for existing. Leave its timestamp alone.
# If the OID doesn't yet exist, add it as a new entry with status=E and with current timestamp.
sub index { # Add a new oid with current time and E. If the oid was already present, mark as E
    my $self = shift (@_);
    my ($OID) = @_;
    
    my $OID_info = $self->{'info'}->{$OID};
    
    if (defined $OID_info) { # if OID is present, this will change status back to E, timestamp unchanged
	$OID_info->[INFO_STATUS_INDEX] = "E";
	
    } else { # if OID is not present, then it's now added as existing from current time on
	$self->set_info($OID, "E", $self->get_current_time());
    }
}

# Upon reindexing a document with identifier OID, change its timestamp to current time
# if a new OID, then add as new entry with status=E and current timestamp
sub reindex { # update timestamp if oid is already present, if not (unlikely), add as new
    my $self = shift (@_);
    my ($OID) = @_;

    my $OID_info = $self->{'info'}->{$OID};    
    $self->set_info($OID, "E", $self->get_current_time()); # Takes care of 3 things:
       # if OID exists, updates modified time to indicate the doc has been reindexed 
       # if OID exists, ensures any status=PD is flipped back to E for this OID doc (as we know it exists);
       # if the OID doesn't yet exist, adds a new OID entry with status=E and current timestamp.

}

# Does the same as index():
# OIDs that have been indexed upon rebuild may still be new to the oaidb: GS2 collections
# are not OAI collections by default, unlike GS3 collections. Imagine rebuilding a (GS2) collection
# 5 times and then setting them to be an OAI collection. In that case, the doc OIDs in the collection
# may not be in the oaidb yet. Unless, we decide (as is the present case) to always maintain an oaidb 
# (always creating an oaidb regardless of whether the collection has OAI support turned on or not).
sub been_indexed {
    my $self = shift (@_);
    my ($OID) = @_;

    $self->index($OID);
}

# Upon deleting a document with identifier OID, 
# set status to deleted and change its timestamp to current time
sub delete {
    my $self = shift (@_);
    my ($OID) = @_;

    # the following method will set to current time if no timestamp provided,
    # But by being explicit here, the code is easier to follow
    $self->set_info($OID, "D", $self->get_current_time());

}

#############################################################
sub get_current_time {
    my $self = shift (@_);
    return time; # current time

    # localtime(time) returns an array of values (day, month, year, hour, min, seconds) or singular string
    # return localtime; # same as localtime(time); # http://perldoc.perl.org/functions/localtime.html
    
}

sub get_datestamp {
    my $self = shift (@_);
    my ($timestamp) = @_;

    my ($seconds, $minutes, $hours, $day_of_month, $month, $year,
	    $wday, $yday, $isdst) = localtime($timestamp);

    my $datestamp = sprintf("%d%02d%02d",1900+$year,$month+1,$day_of_month);

    return $datestamp;
}

sub _load_info_txt 
{
    my $self = shift (@_);
    my ($filename) = @_;

    if (defined $filename && &FileUtils::fileExists($filename)) {
	open (INFILE, $filename) || 
	    die "oaiinfo::load_info couldn't read $filename\n";

	my ($line, @lineparts);
	while (defined ($line = <INFILE>)) {
	    $line =~ s/\cM|\cJ//g; # remove end-of-line characters
	    @lineparts = split ("\t", $line);
	    if (scalar(@lineparts) >= 2) {
		$self->set_info (@lineparts);
	    }
	}
	close (INFILE);
    }

}

sub _load_info_db
{
    my $self = shift (@_);
    my ($filename) = @_;

    my $infodb_map = {};

    &dbutil::read_infodb_file($self->{'infodbtype'}, $filename, $infodb_map);

    foreach my $oid ( keys %$infodb_map ) {
	my $vals = $infodb_map->{$oid};
	# interested in oid, timestamp, deletion status

	my ($deletion_status) = ($vals=~/^<status>(.*)$/m);
	my ($timestamp) = ($vals=~/^<timestamp>(.*)$/m);
	my ($datestamp) = ($vals=~/^<datestamp>(.*)$/m);
	
	$self->add_info ($oid, $deletion_status, $timestamp, $datestamp);
    }
}

# if no filename is passed in (and you don't generally want to), then
# it tries to load in <collection>/etc/oai-inf.<db> if it exists
sub load_info {
    my $self = shift (@_);
    my ($filename) = @_;

    $self->{'info'} = {};

    $filename = $self->{'oaidb_file_path'} unless defined $filename;

    if (&FileUtils::fileExists($filename)) {
	if ($filename =~ m/\.inf$/) {
	    $self->_load_info_txt($filename);
	}
	else {
	    $self->_load_info_db($filename);
	}
    }

}

sub _save_info_txt {
    my $self = shift (@_);
    my ($filename) = @_;

    my ($OID, $info);

    open (OUTFILE, ">$filename") || 
	die "oaiinfo::save_info couldn't write $filename\n";
  
    foreach $info (@{$self->get_OID_list()}) {
	if (defined $info) {
	    print OUTFILE join("\t", @$info), "\n";
	}
    }
    close (OUTFILE);
}

# if no filename is passed in (and you don't generally want to), then
# this subroutine tries to write to <collection>/etc/oai-inf.<db>.
sub _save_info_db {
    my $self = shift (@_);
    my ($filename) = @_;

    $filename = $self->{'oaidb_file_path'} unless defined $filename;
    my $infodbtype = $self->{'infodbtype'};

    # write out again. Open file for overwriting, not appending.
    # Then write out data structure $self->{'info'} that has been maintaining the data in-memory. 
    my $infodb_handle = &dbutil::open_infodb_write_handle($infodbtype, $filename);

    my $infomap = $self->{'info'};
    foreach my $oid ( keys %$infomap ) {
	my $OID_info = $self->{'info'}->{$oid};
	my $val = "<status>".$OID_info->[INFO_STATUS_INDEX];
	$val .= "\n<timestamp>".$OID_info->[INFO_TIMESTAMP_INDEX];
	$val .= "\n<datestamp>".$OID_info->[INFO_DATESTAMP_INDEX]."\n";
	&dbutil::write_infodb_rawentry($infodbtype,$infodb_handle,$oid,$val);
    }
    &dbutil::close_infodb_write_handle($infodbtype, $infodb_handle);
}

sub save_info {
    my $self = shift (@_);
    my ($filename) = @_;

    if(defined $filename) {
	if ($filename =~ m/(contents)|(\.inf)$/) {
	    $self->_save_info_txt($filename);
	}
	else {
	    $self->_save_info_db($filename);
	}
    } else {
	$self->_save_info_db();
    }
}


sub set_info { # sets existing or appends
    my $self = shift (@_);
    my ($OID, $del_status, $timestamp) = @_;

    if(!defined $timestamp) { # get current date timestamp
	$timestamp = $self->get_current_time();
    }
    my $datestamp = $self->get_datestamp($timestamp);

    $self->{'info'}->{$OID} = [$del_status, $timestamp, $datestamp];

}

sub add_info { # called to load a single record from file into memory, so it should be provided all 4 fields
    my $self = shift (@_);
    my ($OID, $del_status, $timestamp, $datestamp) = @_;

    $self->{'info'}->{$OID} = [$del_status, $timestamp, $datestamp];
}


# returns a list of the form [[OID, deletion_status, timestamp, datestamp], ...]
sub get_OID_list 
{
    my $self = shift (@_);

    my @list = ();
	
    my $infomap = $self->{'info'};
    foreach my $OID (keys %$infomap) {	
	my $OID_info = $self->{'info'}->{$OID};

	push (@list, [$OID, $OID_info->[INFO_STATUS_INDEX], 
		      $OID_info->[INFO_TIMESTAMP_INDEX],
		      $OID_info->[INFO_DATESTAMP_INDEX]
	      ]);
    }

    return \@list;
}


# returns the number of entries so far, including deleted ones
# http://stackoverflow.com/questions/1109095/how-can-i-find-the-number-of-keys-in-a-hash-in-perl
sub size {
    my $self = shift (@_);
    my $infomap = $self->{'info'};
    return (scalar keys %$infomap);
}

1;
