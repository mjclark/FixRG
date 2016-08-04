#!i/usr/bin/perl

use strict;
use warnings;
use File::Basename;

#GLOBAL VARIABLES
#All three global arrays below are indexed the same way b/c they are pulled from the same lines
my @readgroups; #stores the readgroups from $OLDBAM
my @flowcells; #stores the flowcell IDs in RG order
my @lanes; #stores the lanes in RG order
my $dirname = dirname(__FILE__); #stores the directory this script is contained in so that subsequent calls of external programs (e.g. samtools, picard) in the same directory can be performed

#USAGE
if(@ARGV != 4) {
	die("Usage: perl FixRG.pl <RAM [e.g. \"4G\"> <old.bam> <realigned.bam> <output_prefix>\n");
}

#INPUTS
my $RAM = shift;
my $OLDBAM = shift;
my $REBAM = shift;
my $PREFIX = shift;

#FILE TESTS
#Check for existence of files passed to script


#PIPELINE
#Step 1: Open old BAM file,read in header with samtools, and load arrays
open OLDBAM, "./samtools view -H $OLDBAM |" or die("Could not open <$OLDBAM>.\n"); 
while(my $line = <OLDBAM>) {
	chomp($line);
	#pull the entire readgroup line, the flowcell, and the lane from each line and store in the appropriate arrays
	if($line =~ m/^\@RG\s+ID:\w+\s+PL:\w+\s+PU:(\w+).(\w+).\w+\s+LB:\w+/) {
		push @readgroups, $line;
		push @flowcells, $1;
		push @lanes, $2;
	}
}
close(OLDBAM);
=cut
for(my $i=0; $i<scalar(@readgroups); $i++) {
	print "INDEX: $i\n$readgroups[$i]\n$flowcells[$i]\n$lanes[$i]\n\n";
}
=cut
if(scalar @readgroups <1) {
	die("No readgroups found in header of <$OLDBAM>.\nPlease provide a BAM file containing the original readgroups in the header.\nExiting.\n");
} 

#Step 2: Create temp files for each Readgroup and pump RG reads from realigned BAM into each file

#Step 3: Use Picard to add RGs to each file based on RGs in original BAM's header

#Step 4: Merge temp BAM files into output BAM file

#Step 5: Clean up
