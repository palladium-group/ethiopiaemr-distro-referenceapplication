# Ethiopia EMR Reference Application

[![Build and Publish](https://github.com/palladiumkenya/ethiopia-distro-referenceapplication/actions/workflows/ethiopia-distro-build.yml/badge.svg)](https://github.com/palladiumkenya/ethiopia-distro-referenceapplication/actions/workflows/ethiopia-distro-build.yml)

This project holds the build configuration for the Ethiopia EMR reference application.

## Quick start

### Prerequisites
- Docker and Docker Compose installed
- Git installed
- At least 4GB RAM available for Docker
- A MySQL dump file of the Ethiopia EMR database (place it in the `mysql-dump` folder)

### Package the distribution and prepare the run

```bash
# Clone the repository
git clone https://github.com/palladiumkenya/ethiopia-distro-referenceapplication.git
cd ethiopia-distro-referenceapplication

# Create mysql-dump directory if it doesn't exist
mkdir -p mysql-dump

# Place your Ethiopia EMR database dump file in the mysql-dump directory
# The dump file should be named with .sql extension
# Example: ethiopiaemr_dump.sql

# Build the distribution
docker compose build
```

### Run the application

```bash
# Start the application
docker compose up -d

# To view logs
docker compose logs -f
```

The Ethiopia EMR UI is accessible at:
- Modern UI: http://localhost/openmrs/spa
- Legacy UI: http://localhost/openmrs

Default credentials:
- Username: admin
- Password: Admin123



## Overview

This distribution consists of four main components:

* db - MariaDB database for storing Ethiopia EMR data (requires initial database dump)
* backend - OpenMRS backend with Ethiopia EMR modules and configurations
* frontend - Nginx container serving the Ethiopia EMR 3.x frontend
* gateway - Nginx reverse proxy that manages routing between frontend and backend services

## Configuration

This project uses the [Initializer](https://github.com/mekomsolutions/openmrs-module-initializer) module
to configure metadata. The Initializer configuration is maintained in a separate repository:

[Ethiopia EMR Content Repository](https://github.com/palladiumkenya/openmrs-content-ethiopiaemr)

The configuration is organized as follows:
- `configuration/` - Contains all backend configurations
  - `frontend/` - Frontend-specific configurations
  - `backend/` - Backend-specific configurations

To help maintain organization, please follow these naming conventions:
- Use `-core_demo` suffix for demo data files
- Use `-core_data` suffix for core configuration files

## Troubleshooting

If you encounter any issues:

1. Check if all containers are running:
```bash
docker compose ps
```

2. View container logs:
```bash
docker compose logs [service-name]
```

3. Restart the application:
```bash
docker compose down
docker compose up -d
```

4. Reset the database (WARNING: This will delete all data):
```bash
docker compose down -v
docker compose up -d
```

5. Database initialization issues:
   - Ensure your database dump file is in the `mysql-dump` directory
   - The dump file should be a valid MySQL dump with .sql extension
   - Check the db container logs for any initialization errors:
   ```bash
   docker compose logs db
   ```

## Support

For support, please:
1. Check the [Ethiopia EMR documentation](https://wiki.openmrs.org/display/projects/EthiopiaEMR)
2. Report issues on the [GitHub repository](https://github.com/palladiumkenya/ethiopia-distro-referenceapplication/issues)
