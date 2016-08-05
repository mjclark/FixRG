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
my @tmpbams; #stores the names of the temporary bam readgroup-only bams to be fixed in bam format
my @tmpsams; #stores the names of the temporary bam readgroup-only bams to be fixed in sam format

#USAGE
if(@ARGV != 4) {
	die("Usage: perl FixRG.pl <RAM [e.g. \"4G\"> <old.bam> <realigned.bam> </path/to/output_prefix>\n");
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
open OLDBAM, "$dirname/samtools view -H $OLDBAM |" or die("Could not open <$OLDBAM>.\n"); 
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


if(scalar @readgroups <1) {
	die("No readgroups found in header of <$OLDBAM>.\nPlease provide a BAM file containing the original readgroups in the header.\nExiting.\n");
} 


#Step 2: Create temp files for each Readgroup and pump RG reads from realigned BAM into each file

mkdir "tmp"; #creates temporary directory "tmp" in the current working directory
#fill the @tmpbam and @tmpsam array with the filenames for the temporary bams and sams
for(my $i=0; $i<scalar(@readgroups); $i++) {
	my $tmpbam_name = "tmp/$PREFIX.$flowcells[$i].$lanes[$i].tmp.bam";
	push @tmpbams, $tmpbam_name; 
	my $tmpsam_name = "tmp/$PREFIX.$flowcells[$i].$lanes[$i].tmp.sam";
	push @tmpsams, $tmpsam_name; 
}

#create the temporary SAM files and load the header into each of them
#note the header needs the @RGs from OLDBAM and the rest of the header from REBAM
open OLDBAM, "$dirname/samtools view -H $OLDBAM |" or die("Could not open <$OLDBAM>.\n");
open REBAM, "$dirname/samtools view -H $REBAM |" or die("Could not open <$REBAM>.\n");
while(my $line = <OLDBAM>) {
	chomp($line);
	if($line =~ m/^\@RG/) {
		for(my $i=0; $i<scalar(@tmpsams); $i++) {
			open(TMPSAM, ">>$tmpsams[$i]") or die("Could not write to <$tmpsams[$i]>.\n");
			print TMPSAM "$line\n";
			close(TMPSAM);
		}
	}
}
close(OLDBAM);
while(my $line = <REBAM>) {
	chomp($line);
	if($line =~ m/^\@(?!RG)/) {
		for(my $i=0; $i<scalar(@tmpsams); $i++) {
			open(TMPSAM, ">>$tmpsams[$i]") or die("Could not write to <$tmpsams[$i]>.\n");
			print TMPSAM "$line\n";
			close(TMPSAM);
		}
	}
}
#compress those header-containing sam files into bam files
for(my $i=0; $i<scalar(@tmpsams); $i++) {
	system("$dirname/samtools view -Sb $tmpsams[$i] > $tmpbams[$i]");
#	system("rm -r $tmpsams[$i]");
}

=cut
#load the actual reads from $REBAM into the correct readgroup tmpbams
open REBAM, "$dirname/samtools view $REBAM |" or die("Could not open <$REBAM>.\n");
while(my $line = <REBAM>) {
	chomp($line);
	for(my $i=0; $i<scalar(@readgroups); $i++) {
		if($line =~ m/(^\w+):(\w+):/)
			my $line_rg = $1;
			my $line_lane = $2;
			if($line_rg eq $readgroups[$i] && $line_lane eq $lanes[$i]) {
				open(TMPBAM, ">>$tmpbam") or die ("Could not write to <$tmpbam>.\n");
				print TMPBAM "$line\n";
				close(TMPBAM);
			}
		}
	}
}
=cut

#Step 3: Use Picard to add RGs to each file based on RGs in original BAM's header

#Step 4: Merge temp BAM files into output BAM file

#Step 5: Clean up
