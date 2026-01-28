# Ethiopia EMR Reference Application

[![Build and Publish](https://github.com/palladium-group/ethiopiaemr-distro-referenceapplication/actions/workflows/ci.yml/badge.svg)](https://github.com/palladium-group/ethiopiaemr-distro-referenceapplication/actions/workflows/ci.yml)

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

### Building Docker images with Maven settings secret (for custom Initializer module)

When building Docker images locally, the backend now needs access to a Maven `settings.xml`
that contains a GitHub Personal Access Token (PAT) so it can download the custom Initializer
module and related artifacts.

1. **Create Maven settings file with PAT**

   Create or update `~/.m2/settings.xml` with your GitHub PAT configured for the relevant
   repositories. For example:

   The distro POM already declares the GitHub repository; you only need to supply
   credentials. Use a `<server>` whose `id` matches the repository id in the POM
   (`github-palladiumkennya-initializer`):

   ```xml
   <settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                                 https://maven.apache.org/xsd/settings-1.0.0.xsd">

     <servers>
       <server>
         <id>github-palladiumkennya-initializer</id>
         <username>YOUR_GITHUB_USERNAME</username>
         <password>YOUR_GITHUB_PAT</password>
       </server>
     </servers>
   </settings>
   ```

   You can generate this file with placeholders using:

   ```bash
   mkdir -p "$HOME/.m2"

   cat > "$HOME/.m2/settings.xml" << 'EOF'
   <settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                                 https://maven.apache.org/xsd/settings-1.0.0.xsd">

     <servers>
       <server>
         <id>github-palladiumkennya-initializer</id>
         <username>YOUR_GITHUB_USERNAME</username>
         <password>YOUR_GITHUB_PAT</password>
       </server>
     </servers>
   </settings>
   EOF
   ```

2. **Build using Docker BuildKit and secret**

   From the repository root, run:

   ```bash
   DOCKER_BUILDKIT=1 docker build \
     --secret id=m2settings,src="$HOME/.m2/settings.xml" \
     -f Dockerfile \
     -t ethiopiaemr-backend:local .
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

---

## Local Development with OpenMRS SDK

You can run this distribution locally using the OpenMRS SDK for development and testing purposes.

### Prerequisites

- Java 8 or 11
- Maven 3.x
- MySQL 5.7+ or MariaDB 10.x
- [OpenMRS SDK](https://wiki.openmrs.org/display/docs/OpenMRS+SDK) installed

### Building the Distribution

```bash
# Clone the repository
git clone https://github.com/palladiumkenya/ethiopia-distro-referenceapplication.git
cd ethiopia-distro-referenceapplication

# Build the distribution (without optional modules)
mvn -U -P distro clean install

# Build with the SPA module (required for OpenMRS 3.x frontend)
mvn -U -P distro,with-spa clean install
```

### Running Locally with OpenMRS SDK

#### Option 1: Fresh Installation (New Database)

```bash
# Setup a new server using the built distribution
mvn openmrs-sdk:setup -DserverId=ethiopiaemr \
  -Ddistro=distro/target/distro.properties

# Run the server
mvn openmrs-sdk:run -DserverId=ethiopiaemr
```

The SDK will interactively prompt you for database connection details. To skip prompts, provide all parameters:

```bash
mvn openmrs-sdk:setup -DserverId=ethiopiaemr \
  -Ddistro=distro/target/distro.properties \
  -DdbDriver=mysql \
  -DdbUri=jdbc:mysql://localhost:3306/openmrs_ethiopia \
  -DdbUser=openmrs \
  -DdbPassword=openmrs
```

#### Option 2: Using an Existing Database

If you have an existing Ethiopia EMR database running on MySQL/MariaDB:

```bash
# Setup server pointing to existing database
mvn openmrs-sdk:setup -DserverId=ethiopiaemr \
  -Ddistro=distro/target/distro.properties \
  -DdbUri=jdbc:mysql://localhost:3306/openmrs

# Run the server
mvn openmrs-sdk:run -DserverId=ethiopiaemr
```

The SDK will prompt you for database credentials during setup. Alternatively, you can specify them inline:

```bash
mvn openmrs-sdk:setup -DserverId=ethiopiaemr \
  -Ddistro=distro/target/distro.properties \
  -DdbDriver=mysql \
  -DdbUri=jdbc:mysql://localhost:3306/openmrs \
  -DdbUser=openmrs \
  -DdbPassword=openmrs
```

#### Option 3: Importing a Database Dump

If you have a SQL dump file (e.g., from a production backup):

```bash
# 1. Create the database
mysql -u root -p -e "CREATE DATABASE openmrs_ethiopia CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"

# 2. Import the SQL dump
mysql -u root -p openmrs_ethiopia < /path/to/your/database_dump.sql

# 3. Setup the SDK server pointing to the imported database
mvn openmrs-sdk:setup -DserverId=ethiopiaemr \
  -Ddistro=distro/target/distro.properties \
  -DdbUri=jdbc:mysql://localhost:3306/openmrs_ethiopia

# 4. Run the server
mvn openmrs-sdk:run -DserverId=ethiopiaemr
```

**Important notes for existing/imported databases:**
- Ensure your database is compatible with OpenMRS Platform 2.x
- Back up your database before running with new modules
- The Initializer module will apply any new configurations on startup
- Check the server logs for any migration or compatibility issues
- Grant appropriate MySQL privileges to the database user

#### Running the Server

```bash
# Start the server
mvn openmrs-sdk:run -DserverId=ethiopiaemr

# Or run in debug mode (port 1044)
mvn openmrs-sdk:run -DserverId=ethiopiaemr -Ddebug
```

#### Accessing the Application

After starting the server:
- Legacy Admin UI: http://localhost:8080/openmrs
- OpenMRS 3.x Frontend: http://localhost:8080/openmrs/spa

> **Important:** The O3 frontend URL will only work if you built the distribution with the SPA module (`-P with-spa`). Without it, only the Legacy UI will be accessible.

---

## Optional Modules

Some modules are optional and can be conditionally included based on your deployment needs.

### SPA Module

The **SPA module** (`openmrs-module-spa`) serves the OpenMRS 3.x frontend directly from the OpenMRS backend.

**When is the SPA module needed?**

| Deployment Method | SPA Module Required | Reason |
|-------------------|---------------------|--------|
| **Docker Compose** (with gateway) | No | The nginx gateway serves the frontend separately |
| **Local SDK** (without gateway) | Yes | Backend must serve the O3 frontend directly |

For **local development using OpenMRS SDK** without the Docker gateway, you must include the SPA module to access the modern O3 user interface:

| Build Command | SPA Module | O3 Frontend Available (Local SDK) |
|--------------|------------|----------------------------------|
| `mvn -U -P distro install` | Not included | No |
| `mvn -U -P distro,with-spa install` | Included | Yes |

> **Note:** When running with Docker Compose, the gateway (nginx) routes `/openmrs/spa` requests to the separate frontend container, so the SPA module is not required in the backend.

#### Including Optional Modules

```bash
# Include SPA module using profile
mvn -U -P distro,with-spa clean install

# Or using property
mvn -U -P distro clean install -Dinclude.spa=true

# Include multiple optional modules
mvn -U -P distro,with-spa,with-cohort clean install

# Override module version
mvn -U -P distro,with-spa clean install -Dspa.version=2.0.0
```

### Adding New Optional Modules

To add a new optional module to this distribution:

1. **Add properties** in `distro/pom.xml`:
   ```xml
   <properties>
     <mymodule.version></mymodule.version>
     <omod.mymodule.entry></omod.mymodule.entry>
   </properties>
   ```

2. **Add a profile** in `distro/pom.xml`:
   ```xml
   <profile>
     <id>with-mymodule</id>
     <activation>
       <property>
         <name>include.mymodule</name>
         <value>true</value>
       </property>
     </activation>
     <properties>
       <mymodule.version>X.Y.Z</mymodule.version>
       <omod.mymodule.entry>omod.mymodule=${mymodule.version}</omod.mymodule.entry>
     </properties>
     <dependencies>
       <dependency>
         <groupId>org.openmrs.module</groupId>
         <artifactId>mymodule-omod</artifactId>
         <version>${mymodule.version}</version>
         <scope>provided</scope>
       </dependency>
     </dependencies>
   </profile>
   ```

3. **Add placeholder** in `distro/distro.properties`:
   ```properties
   ${omod.mymodule.entry}
   ```

---

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

## Frontend Configuration

Please note that we maintain separate files for running Distro locally versus deploying it to Kubernetes:

*   **Local Use**: Refer to `Dockerfile.local` when running the application on your local machine.
*   **Kubernetes Deployment**: Refer to `Dockerfile` for configuration specific to the Kubernetes environment.

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
