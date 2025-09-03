#!/bin/sh

# Function to handle the renaming process
rename_dist_folder() {
    local pattern=$1
    local dist_folder_name=$2
    local folder_name=$(find /app/spa -name "$pattern" -type d | head -n 1 | sed 's|/app/spa/||')

    # Check if the folder_name is not empty
    if [ -n "$folder_name" ]; then
        # Check if the specific 'dist' directory exists
        if [ -d "/app/spa/$dist_folder_name" ]; then
            # Rename the specific 'dist' directory to the found folder name
            mv "/app/spa/$dist_folder_name" "/app/spa/$folder_name"
            echo "The '$dist_folder_name' directory has been renamed to '$folder_name'"

            # Now copy the renamed folder back into the 'frontend' directory
            cp -r "/app/spa/$folder_name" /app/spa/
            echo "The renamed folder has been copied back into the 'frontend' directory."
            mv "/app/spa/$folder_name" "/app/spa/$dist_folder_name"
        else
            echo "The '$dist_folder_name' directory does not exist in the expected location."
        fi
    else
        echo "No directory matching the pattern '$pattern' was found within the 'frontend' directory."
    fi
}

# Handle renaming for openmrs-esm-form-entry-app-*
rename_dist_folder "openmrs-esm-form-entry-app-*" "dist-form-entry" 
rename_dist_folder "openmrs-esm-patient-tests-app-*" "dist-patient-tests"

# Replace favicon.ico
cp favicon.ico /app/spa/