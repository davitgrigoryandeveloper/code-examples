#!/usr/bin/env bash

set -euo pipefail

echo "Analyzing Docker volumes..."

# Get all volumes
all_volumes=$(docker volume ls -q)

# Get volumes in use by running containers
used_volumes=$(docker ps -q | xargs -r docker inspect --format '{{ range .Mounts }}{{ .Name }} {{ end }}')

# Find unused volumes
unused_volumes=$(comm -23 <(echo "$all_volumes" | sort) <(echo "$used_volumes" | tr ' ' '\n' | sort | uniq))

# Function to attempt volume removal
remove_volume() {
    local volume=$1
    if docker volume rm "$volume" &>/dev/null; then
        echo "Removed volume: $volume"
    else
        echo "Failed to remove volume: $volume (may still be in use)"

        # Find containers using this volume (including stopped ones)
        local using_containers=$(docker ps -a --filter volume="$volume" --format '{{.ID}}')
        if [ -n "$using_containers" ]; then
            echo "  Containers using this volume:"
            while IFS= read -r container_id; do
                # Get container information including ID, Name, and Status
                container_info=$(docker inspect --format '{{.Id}} {{.Name}} {{.State.Status}}' "$container_id" 2>&1)
                
                
                # Check if docker inspect command was successful
                if [ $? -eq 0 ]; then
                    read -r full_id name status <<< "$container_info"
                    short_id=${full_id:0:12}
                    echo "      ID: $short_id, Name: $name, Status: $status"
                else
                    echo "      Failed to inspect container $container_id. Error: $container_info"
                fi
            done <<< "$using_containers"
        else
            echo "  No container information available. The volume might be referenced by a missing container."
        fi
    fi
}

# Print and remove unused volumes
if [ -z "$unused_volumes" ]; then
    echo "No unused volumes found."
else
    echo "Attempting to remove the following unused volumes:"
    echo "$unused_volumes"
    echo

    echo "$unused_volumes" | while read -r volume; do
        remove_volume "$volume"
    done
fi

echo "Done."
