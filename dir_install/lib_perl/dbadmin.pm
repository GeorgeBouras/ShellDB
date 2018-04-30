# This module
#
#   * create database btrfs data files
#   * create/destroy their loop devices
#   * mount/umount the the data files
#       
# George Bouras
# george.mpouras@yandex.com, Athens, Greece

package	dbadmin;
use		strict;
use		warnings;
require Exporter;
our	$VERSION= '2.0.2';

my $user	= 'shelldb';
my $group	= 'shelldb';
my $sudo	= '/usr/bin/sudo';
my $losetup = '/usr/sbin/losetup';
my $btrfs	= '/usr/sbin/btrfs';
my $format	= '/usr/sbin/mkfs.btrfs';
my $findmnt	= '/usr/bin/findmnt';
my $mount	= '/usr/bin/mount';
my $umount	= '/usr/bin/umount';
my $chown	= '/usr/bin/chown';
my $find	= '/usr/bin/find';
my $rm		= '/usr/bin/rm'; 
my $df		= '/usr/bin/df';

#   Delete recursive a directory tree. Returns true on success
sub DeleteDeepDirectory
{
	if (-d $_[0]) {
	system "$find \"$_[0]\" -depth -exec $rm -rf {} \\; 1> /dev/null 2>&1";
	-d $_[0] ? 0 : 1
	}
	else {
	1
	}
}


#   true if a directory is a mountpoint otherlese false
sub IsItMounted
{
	if (-d $_[0]) {

		if  (system "$findmnt --noheadings --output SOURCE \"$_[0]\" 1> /dev/null 2>&1") {
		undef
		}
		else {
		1
		}
	}
	else {
	undef
	}
}


#   un-mount a directory
#   Returns:
#   on success : 0    , success
#   on error   : error, errormessage
sub Umount
{
	if (IsItMounted($_[0])) {

		if (system "$sudo $umount \"$_[0]\" 1> /dev/null 2>&1") {
		return 101, "$?"
		}
	}

DeleteDeepDirectory($_[0]) ? (0,'success') : (102,$?)
}





#   Add a new device (disk) to an existing volume for extra capacity.
#   Returns:
#   on success : 0    , success
#   on error   : error, errormessage
sub Add_new_device
{
my ($dir,$dev)= ("$_[0]/data", $_[1]);

	if ( system "$sudo $btrfs device add $dev \"$dir\" 1> /dev/null 2>&1" ) {
	103, "Could not add btrfs volume $dev at $dir because $?"
	}
	else {
	0,'success'
	}
}


#   Create a sparse file, attach it to a loop device, and return the loop device
sub Datafile_create
{
my $dir	= "$_[0]/storage";
my $size= $_[1];
my $i	= 1; while (-e "$dir/data.$i.img"){$i++}
my $file= "data.$i.img";

# Create a sparse data file
open	FILE, '+>', "$dir/$file" or return(104, "Could not create sparse file $dir/$file because $!");
binmode	FILE, ":raw";
seek	FILE, ($size-1), 0;
print	FILE "\0";
close	FILE;
Losetup_create("$dir/$file")
}


#   Create a loop device for a file
#   Before we trie to create a new device, we will search if there is already on for the file
#   Returns
#   on success : 0     , device
#   on error   : error , errormessage
sub Losetup_create
{
my $dev;

	unless ( ($dev) = qx[$losetup --associated "$_[0]"] =~/^(.*?):/ ) {
	
		if ( system "$sudo $losetup --find \"$_[0]\"" ) {
		return 105, "Could not create loopback device for $_[0] because $?"
		}

	($dev) = qx[$losetup --associated "$_[0]"] =~/^(.*?):/
	}

0,$dev
}


#   Detach the loopback device from all the files of a directory
#   Returns:
#   on success : 0    , success
#   on error   : error, errormessage
sub Losetup_detach
{
my $dir = "$_[0]/storage";
return(0,'success') unless -d $dir;
opendir DIR, $dir or return(106, "Could not directory $dir because $?");

	while ($_ = readdir DIR) {
	next if /^\.+$/ || -d $_;

		if ( my ($dev) =  qx[$sudo $losetup --associated "$dir/$_" 2> /dev/null] =~/^(.*?):/ ) {

			if (system "$sudo $losetup --detach $dev") {
			return 107, "Could not detach device $dev of file $dir/$_ because $?" 
			}
		}	
	}

closedir DIR;
0,'success'
}


#   Deletes all files from a directory (non recursive)
#   Returns:
#   on success : 0    , success
#   on error   : error, errormessage
sub Datafile_delete
{
my $dir = "$_[0]/storage";
return(0,'success') unless -d $dir;
opendir DIR, $dir or return(108, "Could not directory $dir because $?");

	while ($_ = readdir DIR) {
	next if /^\.+$/ || -d $_;
	unlink "$dir/$_" || return 109, "Could not delete file $dir/$_ because $!"
	}

closedir DIR;
0,'success'
}




#   Mount a btrfs subvolume
#   Returns:
#   on success : 0    , success
#   on error   : error, errormessage
sub Mount_volume
{
my ($dir,$dev)=@_;
my $subvolume = $dir=~/\/data$/ ? '__DATA' : '__SNAPSHOTS';

	unless ( IsItMounted($dir) ) {
	mkdir $dir or return(110, "Could not create directory $dir because $!") unless -d $dir;

		if ( system "$sudo $mount -t btrfs -o defaults,autodefrag,space_cache=v2,compress-force=lzo,subvol=$subvolume $dev \"$dir\"" ) {
		return 111, "Could not mount subvolume $subvolume of device $dev at $dir because $?"
		}

		if ( system "$sudo $chown $user:$group \"$dir\"" ) {
		return 112, "Could not give ownership to $user:$group to $dir because $?"
		}
	}

0,'success'
}



#   Format the loop device using as btrfs 
#	Mount it temporary and create the subvolumes : __DATA, __SNAPSHOTS
#   Then mount these subvolumes at  ../data  and  ../snapshots
sub Create_volume
{
my ($dir,$dev)=@_;
my ($db) = $dir =~/([^\\\/]+)$/;

	if ( system "$sudo $format -f -L $db --nodesize 4096 -d single -m single $dev 1> /dev/null 2>&1" ) {
	return 113, "At database $db could not format loopback device $dev as btrfs , shell error $?"
	}

	if ( system "$sudo $mount -t btrfs $dev \"$dir/tmp\"" ) {
	return 114, "At database $db could not temporary mount loop device $dev , shell error $?"
	}

	foreach (qw/__DATA __SNAPSHOTS/) {

		if ( system "$sudo $btrfs subvolume create \"$dir/tmp/$_\" 1> /dev/null 2>&1" ) {
		return 115, "Could not create database $db subvolume $_ at $dev , shell error $?"
		}
	}

	my ($error, $message) = dbadmin::Umount("$dir/tmp");
	return(116, "Could not umount database $db temporary mount $dir because $message") if $error;

	foreach (qw/data snapshots/) {
	my ($error,$message) = Mount_volume("$dir/$_", $dev);
	return($error,$message) if $error
	}

0,'success'
}





#   Check a mount point
#   Returns:
#   on success : 0     , [size, used, avail, used%]
#   on error   : error , errormessage
sub MountInfo
{
	if (IsItMounted $_[0]) {
	my ($size,$used,$avail,$pcent) = qx[$df --no-sync --human-readable --output=size,used,avail,pcent "$_[0]"] =~ /(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$/;
	0, [$size,$used,$avail,$pcent]
	}
	else {
	117, 'not mounted'
	}
}


1;# END OF MODULE