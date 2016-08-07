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
print STDERR "Opening old BAM file, reading in headers.\n";
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
print STDERR "Creating temp files for each readgroup.\n";
mkdir "tmp"; #creates temporary directory "tmp" in the current working directory
#fill the @tmpbam and @tmpsam array with the filenames for the temporary bams and sams
for(my $i=0; $i<scalar(@readgroups); $i++) {
	my $tmpbam_name = "tmp/$PREFIX.$flowcells[$i].$lanes[$i].tmp.bam";
	push @tmpbams, $tmpbam_name; 
	my $tmpsam_name = "tmp/$PREFIX.$flowcells[$i].$lanes[$i].tmp.sam";
	push @tmpsams, $tmpsam_name; 
}
print STDERR "Loading headers into temporary SAM files.\n";
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
close(REBAM);
#compress those header-containing sam files into bam files
print STDERR "Generating temporary readgroup BAM files.\n";
for(my $i=0; $i<scalar(@tmpsams); $i++) {
	system("$dirname/samtools view -Sb $tmpsams[$i] > $tmpbams[$i]");
	system("$dirname/samtools index $tmpbams[$i]");
}

#load the actual reads from $REBAM into the correct readgroup tmpbams
print STDERR "Loading actual reads from realigned BAM into the temp readgroup BAMs.\n";
open REBAM, "$dirname/samtools view $REBAM |" or die("Could not open <$REBAM>.\n");
my $counter=0;
print STDERR "Now on line:\n";
print STDERR "$counter";
while(my $line = <REBAM>) {
	$counter++;
	print STDERR "\r$counter";
	chomp($line);
	for(my $i=0; $i<scalar(@readgroups); $i++) {
		if($line =~ m/(^\w+):(\w+):/) {
			my $line_rg = $1;
			my $line_lane = $2;
			if($line_rg eq $flowcells[$i] && $line_lane eq $lanes[$i]) {
				#creating a temporary one-read BAM file to feed into samtools cat
				my $tmpsam_rg = "tmp/$PREFIX.$flowcells[$i].$lanes[$i].tmp.rg.sam"; 
				open(TMPSAMRG, ">>$tmpsam_rg") or die ("Could not write to <$tmpsam_rg>.\n");
				open(TMPSAM, $tmpsams[$i]) or die("Could not read to <$tmpsams[$i]>.\n");
				while(my $samline = <TMPSAM>) {
					chomp($samline);
					print TMPSAMRG "$samline\n";
				}
				print TMPSAMRG "$line\n";
				close(TMPSAM);
				close(TMPSAMRG);
				my $tmpbam_rg = "tmp/$PREFIX.$flowcells[$i].$lanes[$i].tmp.rg.bam";
				system("$dirname/samtools view -Sb $tmpsam_rg > $tmpbam_rg");
				system("$dirname/samtools index $tmpbam_rg");

				#cat the one read onto the end of the BAM file
				my $tmpbam_cat = "tmp/$PREFIX.$flowcells[$i].$lanes[$i].tmp.rg.cat.bam";
				system("$dirname/samtools cat $tmpbams[$i] $tmpbam_rg > $tmpbam_cat");
				system("mv $tmpbam_cat $tmpbams[$i]");
				system("$dirname/samtools index $tmpbams[$i]");

				#clean up tmp files for this segment
				system("rm -r $tmpbam_rg*");
				system("rm -r $tmpsam_rg*");
			}
		}
	}
}
close(REBAM);
print STDERR "\n";
print STDERR "Finished!\n";

#Step 3: Use Picard to fix RGs to each file based on RGs in original BAM's header
print STDERR "Fixing the RGs in each RG BAM file.\n";
my @tmpbam_replacedrg;
for(my $i=0; $i<scalar(@readgroups); $i++) {
	my $tmpbam_name = "tmp/$PREFIX.$flowcells[$i].$lanes[$i].tmp.replacedrg.bam";
	push @tmpbam_replacedrg, $tmpbam_name;
	my @rg_line = split(/\s+/, $readgroups[$i]);
	my $RGID = $rg_line[1];
	my $RGPL = $rg_line[2];
	my $RGPU = $rg_line[3];
	my $RGLB = $rg_line[4];
	my $RGPI = $rg_line[5];
	my $RGSM = $rg_line[6];
	my $picardcmd = "java -Xmx$RAM -jar $dirname/picard.jar I=$tmpbams[$i] O=$tmpbam_name SO=coordinate RGID=$RGID RGPL=$RGPL RGPU=$RGPU RGLB=$RGLB RGPI=$RGPI RGSM=$RGSM";
	system("$picardcmd");
	system("$dirname/samtools index $tmpbam_name");
}

#Step 4: Merge temp BAM files into output BAM file
print STDERR "Merge the temporary RG BAM files into the final BAM file.\n";
my $mergedbam_cmd = "java -Xmx$RAM -jar $dirname/picard.jar SO=coordinate O=$PREFIX.rgfixed.bam";
for(my $i=0; $i<scalar(@tmpbam_replacedrg); $i++) {
	$mergedbam_cmd = $mergedbam_cmd . " I=$tmpbam_replacedrg[$i]";
}
system("$mergedbam_cmd");

#Step 5: Clean up
