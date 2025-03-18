# nexus-cleaner

Script for removing old artifact versions from Sonatype Nexus Repository Docker repository. This tool helps maintain your Nexus repository by keeping only the latest 3 versions of each component and removing older versions.

## Post-Cleanup Steps

After removing artifacts, it is recommended to perform the following actions in Nexus to free up space:

1. **Delete unused manifests and images**:
    - Navigate to the "Admin" section in Nexus.
    - Go to "System" > "Tasks".
    - Create or run the task "Docker - Delete unused manifests and images".

2. **Compact blob store**:
    - Navigate to the "Admin" section in Nexus.
    - Go to "System" > "Tasks".
    - Create or run the task "Admin - Compact blob store".

## Requirements

- bash
- curl
- jq
- sqlite3

## Configuration

1. Copy `.env.example` to `.env`:
```bash
cp .env.example .env
```

2. Configure the following variables in `.env`:
```
NEXUS_URL="http://your-nexus-url/service/rest/v1"
REPOSITORY="your_repository_name"
USERNAME="your_username"
PASSWORD="your_password"
DB_NAME="nexus_components.db"
```

## Usage

Run the script:
```bash
./nexus-cleaner.sh
```

The script will:
1. Connect to your Nexus repository
2. Fetch all components and store them in a SQLite database
3. For each component:
   - Keep the latest 3 versions
   - Delete all older versions
4. Display progress and deletion details

## How it Works

1. Creates/resets a SQLite database to store component information
2. Fetches all components from Nexus using pagination
3. Stores component data (ID, name, version) in the database
4. Groups components by name and sorts versions
5. Keeps the 3 most recent versions of each component
6. Deletes all older versions via the Nexus API

## License

MIT License - see LICENSE file for details