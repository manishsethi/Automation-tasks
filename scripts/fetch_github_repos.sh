#!/bin/bash

# GitHub username and personal access token
GITHUB_USERNAME=""
GITHUB_TOKEN=""

# Output CSV file
OUTPUT_CSV="github_repos.csv"

# Write CSV header
echo "RepoName,DefaultBranch,RepoURL,TreeURL" > "$OUTPUT_CSV"

# Function to retrieve repositories from a single page
fetch_repos() {
    local page=$1
    curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" \
        "https://api.github.com/user/repos?per_page=100&page=$page&type=owner" | jq -r --arg username "manishsethi" '.[] | "\(.name),\(.default_branch),\(.html_url),https://github.com/\($username)/\(.name)/tree/\(.default_branch)"'
}

# Retrieve all pages of repositories
page=1
while true; do
    repos=$(fetch_repos $page)
    if [[ -z "$repos" ]]; then
        break
    fi
    echo "$repos" >> "$OUTPUT_CSV"
    ((page++))
done

echo "Repository information has been saved to $OUTPUT_CSV"
