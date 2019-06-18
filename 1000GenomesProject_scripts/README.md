Files in this folder:

1000genomes_table.txt: Text file containing the SQL create statement used to generate a table for containing .vcf data. Has only been used in MySQL.

1000genomes_vcf_read.pl: perl script that retrieves a zipped .vcf file, unzips it locally, and reads headers and a couple of summaries of the contents of the file body into the table specified above.

1000genomes_output_json.pl: perl script that reads from that table and writes a DATS-format 1000 Genomes Project JSON file.

DATS.json: Output 1000 Genomes Project DATS JSON file.

validate_json.pl: perl script that validates user-specified JSON files against a user-specified schema, which has been used to validate the 1KGP JSON files against the DATS dataset_schema.json.

Usage notes:

These scripts require installation of the following perl modules:

Database connection (1000genomes_vcf_read.pl and 1000genomes_output_json.pl):
DBI
DBD::mysql

Retrieval of input data from servers at C3G (1000genomes_vcf_read.pl):
WWW::Mechanize
LWP::Simple

JSON retrieval and validation (validate_json.pl):
JSON
JSON::Validator

Validation also requires downloading the set of DATS schemata to a local directory; these can be found at https://github.com/biocaddie/DATS




