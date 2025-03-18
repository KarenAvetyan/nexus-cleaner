#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | xargs)
else
    echo "Error: .env file not found"
    exit 1
fi

# Validate required environment variables
required_vars=("NEXUS_URL" "REPOSITORY" "USERNAME" "PASSWORD" "DB_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: $var is not set in .env file"
        exit 1
    fi
done

# Delete the database file if it exists
if [ -f "$DB_NAME" ]; then
    rm "$DB_NAME"
    echo "Existing database $DB_NAME deleted"
fi

# Initialize SQLite database
sqlite3 "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS components (
    id TEXT PRIMARY KEY,
    name TEXT,
    version TEXT
);
EOF

# Function to process components
process_components() {
    local json="$1"
    
    echo "$json" | jq -r '.items[] | [.id, .name, .version] | @csv' | \
    while IFS=',' read -r id name version; do
        # Remove quotes from the CSV values
        id="${id//\"/}"
        name="${name//\"/}"
        version="${version//\"/}"
        
        sqlite3 "$DB_NAME" <<EOF
INSERT OR REPLACE INTO components (id, name, version)
VALUES ('$id', '$name', '$version');
EOF
    done
}

# Initial request
continuation_token=""
while true; do
    endpoint="${NEXUS_URL}/components?repository=${REPOSITORY}"
    
    if [ ! -z "$continuation_token" ]; then
        endpoint="${endpoint}&continuationToken=${continuation_token}"
    fi
    
    # Make API request
    response=$(curl -u ${USERNAME}:${PASSWORD} \
        -X GET \
        -H "Accept: application/json" \
        "$endpoint")

    # Check if the request was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from Nexus"
        exit 1
    fi
    
    # Process the components
    process_components "$response"
    
    # Check for continuation token
    continuation_token=$(echo "$response" | jq -r '.continuationToken // empty')
    
    # Break if no continuation token
    if [ -z "$continuation_token" ]; then
        break
    fi
    
    echo "Fetching next page with token: $continuation_token"
done

echo "Data import completed successfully!"

# List all unique names and their versions
echo -e "\nListing all components:"
mapfile -t components < <(sqlite3 "$DB_NAME" "SELECT name FROM components GROUP BY name;")

# Write result to array
for component in "${components[@]}"; do
    mapfile -t versions < <(sqlite3 "$DB_NAME" "SELECT version FROM components WHERE name=\"$component\" ORDER BY version;")
    
    # Use foreach on array for all items except last 3
    for ((i=0; i<${#versions[@]}-3; i++)); do
        mapfile -t ids < <(sqlite3 "$DB_NAME" "SELECT id FROM components WHERE name=\"$component\" AND version=${versions[i]};")
        for id in "${ids[@]}"; do
            endpoint="${NEXUS_URL}/components/${id}"
            curl -u ${USERNAME}:${PASSWORD} -X DELETE "$endpoint"
            echo "Component: $component, Version: ${versions[i]}, ID: $id"
        done
    done
done