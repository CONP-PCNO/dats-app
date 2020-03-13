#!/usr/bin/perl
#
#  refseq_crawler.pl - update reference sequence entries for CONP
#                    - EOB - Mar 03 2020
#
# usage: refseq_crawler.pl $home_directory $home_repository
#
# Note: This script calls on the 'hub" commandline tool for generating pull requests at github.com.  
# If you do not already have this installed, that should be done with the command (on Ubuntu systems)
#
#   sudo snap install hub --classic
#
# and configured with
#
#   git config --global hub.protocol https
#
# before running this script
#
########################################

$home_directory  = $ARGV[0];
$home_repository = $ARGV[1];

@organisms = ("Callithrix_jacchus","Homo_sapiens","Mus_musculus");
@org_taxa  = ("vertebrate_mammalian","vertebrate_mammalian","vertebrate_mammalian"); # may not always be vertebrate_mammalian if we add other organisms

$o            = 0;
$any_changes  = 0;
$message_text = "'Reference sequences update'";

while ($o < @organisms) {
	$local_working_directory = "$home_directory/conp-dataset/projects/refseq/refseq_".$organisms[$o]."/";
	$ncbi_working_directory  = "ftp://ftp.ncbi.nlm.nih.gov/genomes/refseq/".$org_taxa[$o]."/".$organisms[$o]."/";

	# retrieve the most recent summary

	chdir $local_working_directory;

	$temp_summary_filename  = $local_working_directory."temp_summary.txt";
	$ncbi_summary_filename  = $ncbi_working_directory."assembly_summary.txt";
	system "wget -O $temp_summary_filename $ncbi_summary_filename";

	# if this has changed

	$current_summary_filename = $local_working_directory."assembly_summary.txt";
	if (`diff $temp_summary_filename $current_summary_filename` ne '') {  # execute and retrieve output of system command

		# extract location of new files for retrieval

		open(IN, "$temp_summary_filename") || die "Can't open $temp_summary_filename to read";
		$latest_assembly_location = "";  
		while ($inline = <IN>) {
			@input_fields = ();
			unless ($inline =~ /^#/) {  # ignore comment lines
      				@input_fields = split (/\t/,$inline);
				if ($input_fields[10] eq "latest") {   
					$latest_assembly_location = $input_fields[19];
				}
				# fixed column numbers taken from https://www.ncbi.nlm.nih.gov/genome/doc/ftpfaq 
				# which starts count from 1 rather than 0
			}
		}
		close(IN);

		$latest_assembly_identifier = (split(/\//, $latest_assembly_location))[-1]; # split at "/" and retrieve last value

		if ($latest_assembly_location eq "") {  
			die "Could not identify latest release in assembly summary file";
		}
		else {
			$any_changes = 1;
			$ncbi_fasta_filename = $latest_assembly_location."/".$latest_assembly_identifier."_genomic.fna.gz";
			$ncbi_gff_filename   = $latest_assembly_location."/".$latest_assembly_identifier."_genomic.gff.gz";
	
			$local_fasta_filename = $organisms[$o].".fna.gz";
			$local_gff_filename   = $organisms[$o].".gff.gz";

			# remove and redownload updated files

			system "rm $local_fasta_filename";
			system "git annex addurl $ncbi_fasta_filename --file $local_fasta_filename";

			system "rm $local_gff_filename";
			system "git annex addurl $ncbi_gff_filename --file $local_gff_filename";
		
			# update file containing annotation data

			system "rm $current_summary_filename";
			system "mv $temp_summary_filename $current_summary_filename";
			system "datalad add --to-git $current_summary_filename";

			# update DATS.json

			$dats_filename   = $local_working_directory."DATS.json";
			@dats_lines = ();
			$dats_line_count = 0;

			open(IN_DATS, "$dats_filename") || die "Can't open $dats_filename to read";
			while ($inline = <IN_DATS>) {
				$dats_lines[$dats_line_count] = $inline;
				++$dats_line_count;
			}
			close(IN_DATS);

			$edit_count = 0;
 			while ($edit_count < $dats_line_count) {
				$editline = $dats_lines[$edit_count];
			
				if ($editline =~ /"version":/) {
					$dats_lines[$edit_count] = "\t\"version\": \"".$latest_assembly_identifier."\",\n";
				}
				if ($editline =~ /"storedIn":/) {
					$dats_lines[$edit_count + 1] = "\t\t\"name\": \"".$latest_assembly_location."\"\n";
				}
				if ($editline =~ /"date":/) {
					@current_date = localtime();	
					$dats_lines[$edit_count] = "\t\t\t\"date\": \"".($current_date[5]+1900)."-".sprintf("%02s",$current_date[4])."-".sprintf("%02s",$current_date[3])." ".sprintf("%02s",$current_date[2]).":".sprintf("%02s",$current_date[1]).":".sprintf("%02s",$current_date[0])."\"\n";
				}
				if ($editline =~ /\"category\": \"FTP link to GFF file containing detailed annotations\"/) {
					$dats_lines[$edit_count + 3] = "\t\t\t\t\t\"value\": \"".$ncbi_gff_filename."\"\n";
				}
			
				++$edit_count;
			}

			$out_count = 0;
	     		open(OUT_DATS, ">$dats_filename") || die "Can't open $dats_filename to write";
			while ($out_count < $dats_line_count) {
				print OUT_DATS $dats_lines[$out_count];
				++$out_count;
			}
			close(OUT_DATS);

			system "datalad add --to-git $dats_filename";
			$message_line = "'Updating reference genome files for $organisms[$o] to version $latest_assembly_identifier.' ";
			system "datalad save -m '$message_line'";
			$message_text .= " -m $message_line";
			system "datalad publish --to origin";
		}
}
	else {
		system "rm $temp_summary_filename";
		print  "No change in $ncbi_summary_filename since last check\n";
	}
	++$o;
}

if ($any_changes == 1) {
	$local_working_directory = "$home_directory/conp-dataset/";
	chdir $local_working_directory;
	system "datalad save";
	system "datalad publish --to origin";
	system "hub pull-request -b CONP-PCNO/conp-dataset:master -h $home_repository/conp-dataset:master -m $message_text";
}
else {
	print "\n\n====\n\nNo changes in any reference genome files since last update\n\n====\n";
} 

exit();

