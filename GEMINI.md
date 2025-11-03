# GEMINI.md

## Project Overview

This project contains the deployment configuration for the Tsunami Events core management systems, an integrated equipment rental and warehouse management solution. The system is composed of two main Go applications, **RentalCore** and **WarehouseCore**, which share a single **MySQL** database. The stack also includes a **Mosquitto MQTT broker** for real-time LED bin highlighting in the warehouse. The entire system is containerized and managed using `docker-compose`.

- **RentalCore**: Handles job management, customer data, and invoicing.
- **WarehouseCore**: Manages physical warehouse inventory, device tracking, and location mapping.

The project is currently undergoing a refactoring to migrate all warehouse-related funtionality from `RentalCore` to `WarehouseCore`, as detailed in `plan.md`.

## Building and Running

The application is designed to be run with Docker and Docker Compose.

### Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+

### Running the Application

1.  **Create Environment File:**
    ```bash
    cp .env.example .env
    ```
    *Note: You may need to edit the `.env` file to set database passwords and other configuration options.*

2.  **Start the services:**
    ```bash
    docker-compose up -d
    ```

This command will build the Docker images, start all the services, and initialize the database.

### Accessing the Applications

- **RentalCore**: [http://localhost:8081](http://localhost:8081)
- **WarehouseCore**: [http://localhost:8082](http://localhost:8082)

Default credentials are `admin`/`admin`.

## Development Conventions

Based on the `plan.md` file, the project follows a structured development process for migrating features:

1.  **Analysis**: Understand the existing functionality in `RentalCore` and `WarehouseCore`.
2.  **Implementation**: Implement the features in `WarehouseCore`.
3.  **Deactivation**: Remove or disable the functionality in `RentalCore`.
4.  **Testing**: Write and run tests for both services.
5.  **Documentation**: Update `README.md` and other relevant documentation.
6.  **Docker**: Build and push new Docker images for each service after each phase.
