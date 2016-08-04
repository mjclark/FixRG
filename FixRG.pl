#!i/usr/bin/perl

use strict;
use warnings;

#USAGE
if(@ARGV != 2) {
	die("Usage: perl FixRG.pl <RAM [e.g. \"4G\"> <old.bam> <realigned.bam> <output_prefix>\n");
}

#INPUTS
my $RAM = shift;
my $OLDBAM = shift;
my $REBAM = shift;
my $PREFIX = shift;

#PIPELINE
#Step 1: Open old BAM file and read in header with samtools


#Step 2: Create temp files for each Readgroup and pump RG reads from realigned BAM into each file

#Step 3: Use Picard to add RGs to each file based on RGs in original BAM's header

#Step 4: Merge temp BAM files into output BAM file

#Step 5: Clean up
