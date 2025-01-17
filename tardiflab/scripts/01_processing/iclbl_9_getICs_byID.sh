#!/bin/bash
#
# Finds a target sub-##_ses-# ID in an input plain text file and prints the comma-separated list of integer
# values for that dataset. These integers correspond to the Independent Components marked for removal in
# melodic-based denoising of rs-fMRI
#
#
# INPUTS:
#       $1 : full path to text file with ICs marked for removal
#       $2 : search ID (e.g., sub-02_ses-1)
#
#
# Example Usage:
# file_path="data.txt"         			# Replace with your actual file path
# search_id="sub-02_ses-1"     			# Replace with the ID you are looking for
# getICs_by_id "$file_path" "$search_id"
#
# 2025 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
#----------------------------------------------------------------------------------------------------------

 # Function to extract integer IC indices for a given sub-ses ID
getICs_by_id() {
    local file_path="$1"
    local search_id="$2"

# --> Loses commas between values in some cases
#   # unleash the power of awk!
#   awk -F, -v id="$search_id" '$1 == id { $1=""; print substr($0,2) }' "$file_path"


# --> Commas are always included, but doesn't strip trailing commas if rows have varying numbers of values!
    # Try again awk!
#    awk -F, -v id="$search_id" '$1 == id {$1=""; for (i=2; i<=NF; i++) {if (i > 2) { printf "," } printf "%s", $i} print ""}' "$file_path"
#    awk -F, -v id="$search_id" '$1 == id { $1=""; for (i=2; i<=NF; i++) { if (i > 2) { printf "," } printf "%s", $i } print "" }' "$file_path"

  # sed to the rescue!
  sed 's/,*$//' "$file_path" | awk -F, -v id="$search_id" '$1 == id { $1=""; fields = ""; for (i=2; i<=NF; i++) {fields = fields (fields == "" ? "" : ",") $i} print fields}'
}
