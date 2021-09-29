# NSRL-Nist-generator
Downloads and generates the latest NSRL Digest hash based on user selected categories

# Getting Started

## Setup

Begin by downloading the latest release of this code.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

## Usage

This script does use the sourceItemFactory to extract the containers produced by NSRL. This will require a licence that supports imager (or better!), so ARX, enterprise-workstation (not audited) etc.

Click the script from menu. Follow the prompts to select the categories you wish to combine. When completed open a new workbench tab and your list should appear in the filter items.

This script can also be run via nuix console. Append the options you'd like to use like the following and point the console to the script location.

    nuix_console.exe "C:\Scripts\Download NSRL.nuixscript\runme.rb" "Modern RDS (unique)" "Android RDS" "iOS RDS"

# How it works
Downloads file:
"https://s3.amazonaws.com/rds.nsrl.nist.gov/RDS/current/README.txt"

Scans this for the various categories that are possible to download

Presents this to the user

User can select the options they wish

After selection the sha1 is checked against the existing cache (script's temp directory) and if it doesn't match a new download will begin

Merge the files into a digest.hash named after the release version, this hash will be in the Nuix compatible format, unique and sorted for optimal performance.
