<a name="readme-top"></a>

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

## About The Project

This Docker application was created by factoring out many reusable code artifacts from my [various projects][tailucas-url] over a number of years. Since this work was not a part of a group effort, the test coverage is predictably abysmal :raised_eyebrow: and Python documentation notably absent :expressionless:. This package takes a submodule dependency on another one of my [common packages][pylib-url]. While this application is almost entirely boilerplate, it can run as a stand-alone application and serves the basis for any well-behaved Python application. The design is opinionated with the use of [ZeroMQ][zmq-url] but this is not a strict requirement. This project has a required dependency on [1Password][1p-url] for both build and run time (explained later). If this is unacceptable, you'll need to fork this project or send a pull request for a substitute like Bitwarden or equivalent.

Enough talk! What do I get?

* An Ubuntu-based Docker application specifically designed to act as a Docker base image for derived applications, or can be run standalone. This includes boilerplate entrypoint scripts (`base_entrypoint.sh`, `app_entrypoint.sh`) that can be easily overridden.
* Multi-language support: Python (with [uv][uv-url] dependency management), Java (Amazon Corretto 25 via SDKMan), and Rust (workspace with `rapp` and `rlib` crates).
* Powerful threading and inter-thread data handling via [ZeroMQ][zmq-url] with significant resilience to unchecked thread death.
* Sample [Healthchecks][healthchecks-url] integration with built-in cron job orchestration.
* Pre-configured process control using [supervisor](http://supervisord.org/).
* Automatic syslog configuration to log to the Docker host rsyslog.
* Support for AWS-CLI if appropriate AWS environment variables are present (e.g., `AWS_DEFAULT_REGION`).
* Support for [Cronitor][cronitor-url] health check monitoring via configuration.

### Project Architecture

The project is organized into multiple language components:

**Python Application** (`app/`)
* [app.__main__.py](app/__main__.py): The primary application entrypoint using `asyncio`. Demonstrates [ZeroMQ][zmq-url]-based inter-thread communication patterns.
  - `DataReader`: Example thread that generates data and pushes it via ZeroMQ
  - `DataRelay`: Demonstrates the `ZmqRelay` pattern for message transformation
  - `EventProcessor`: Example consumer thread that receives and processes data
* Uses [tailucas_pylib][pylib-url] for common utilities including threading, configuration, credentials management, and ZeroMQ helpers
* Integrates [Sentry][sentry-url] for error tracking
* Managed dependencies via [uv][uv-url] (see [pyproject.toml](pyproject.toml))

**Java Application** (`src/`)
* Maven-based build using Java 25 (Amazon Corretto)
* Compiled as part of the Docker build into an executable JAR (`app.jar`)
* Example application in `src/main/java/tailucas/app/App.java`

**Rust Components** (`rapp/`, `rlib/`)
* `rlib/`: Shared Rust library with utility functions
* `rapp/`: Example Rust application demonstrating library usage
* Built as part of container initialization (see [rust_setup.sh](rust_setup.sh))

**Configuration & Orchestration**
* `config/supervisord.conf`: Process supervision configuration for running multiple services
* `config/app.conf`: Application configuration with credential references
* `config/cron/`: Crontab entries for scheduled jobs
* `entrypoint.sh`: Orchestrates base setup, app setup, and supervisor startup

The sample Python application demonstrates key resilience patterns:
* Thread lifecycle management with automatic death tracking via `thread_nanny`
* [ZeroMQ][zmq-url] "lockless programming" for safe inter-thread communication
* Graceful shutdown with signal handling and socket cleanup
* Configuration and credential management via 1Password Secrets Automation

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

Technologies that help make this package useful:

[![1Password][1p-shield]][1p-url]
[![Amazon AWS][aws-shield]][aws-url]
[![uv][uv-shield]][uv-url]
[![Python][python-shield]][python-url]
[![RabbitMQ][rabbit-shield]][rabbit-url]
[![Sentry][sentry-shield]][sentry-url]
[![ZeroMQ][zmq-shield]][zmq-url]

Also:

* [Cronitor][cronitor-url]
* [Healthchecks][healthchecks-url]
* [MessagePack][msgpack-url]

![GitHub](https://img.shields.io/static/v1?style=for-the-badge&message=GitHub&color=181717&logo=GitHub&logoColor=FFFFFF&label=)

* [Botoflow][botoflow-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- GETTING STARTED -->
## Getting Started

Here is some detail about the intended use of this package.

### Prerequisites

Beyond the Python dependencies defined in the [project configuration](pyproject.toml), the application has runtime dependencies on [Sentry][sentry-url] and [1Password][1p-url] for secrets management. The application also includes Java (using Amazon Corretto via SDKMan) and Rust components. Unless you want these integrations and are extending this [base project][baseapp-url], you're likely better off forking this package and cutting out what you do not need.

### Required Tools
Install these tools and make sure that they are on the environment `$PATH`.

* `task` for project build orchestration: https://taskfile.dev/installation/#install-script

* `docker` and `docker-compose` for container builds and execution: https://docs.docker.com/engine/install/
* `mvn` Maven for Java build orchestration: https://maven.apache.org/download.cgi
* `uv` for Python dependency management: https://docs.astral.sh/uv/getting-started/installation/

* `java` and `javac` for Java build and runtime: Amazon Corretto or similar JDK
* `python3` for Python runtime: https://www.python.org/downloads/
* `cargo` and `rustc` for Rust build and runtime: https://www.rust-lang.org/tools/install

### Installation

0. :stop_sign: This project uses [1Password Secrets Automation][1p-url] to store both application configuration and runtime secrets. It is assumed that the 1Password Connect server container is already running in your environment. If you do not want to use this, fork this package and adapt the configuration management accordingly. 1Password is a paid product with a free tier for secrets automation. 

   Your 1Password Secrets Automation vault must contain an entry called `ENV.base_app` with these minimum keys:
   * `DEVICE_NAME`: For container naming. Default: `base-app`
   * `APP_NAME`: Application name for logging. Default: `base_app`
   * `OP_CONNECT_HOST`, `OP_CONNECT_TOKEN`, `OP_CONNECT_VAULT`: 1Password Connect server configuration
   * `HC_PING_URL`: [Healthchecks][healthchecks-url] URL for health check status reporting
   * `CRONITOR_MONITOR_KEY`: [Cronitor][cronitor-url] API key for cron job monitoring (optional)

   Additionally, the application requires:
   * `Sentry/__APP_NAME__/dsn`: [Sentry][sentry-url] DSN for error tracking (see [app.conf](config/app.conf))

1. Clone the repo
   ```sh
   git clone https://github.com/tailucas/base-app.git
   cd base-app
   ```

2. Start the development container
   ```sh
   make
   ```
   This uses [Dev Container CLI](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli) to set up a development environment with Python, Java, Rust, and Docker-in-Docker capabilities.

3. Inside the development container, build the project artifacts
   ```sh
   task build
   ```
   This builds Java components with Maven and prepares the Docker image.

4. Configure the application by generating the `.env` file with secrets from 1Password
   ```sh
   task configure
   ```
   This creates the runtime configuration needed by the application.

5. Run the application:
   
   For foreground (interactive, see logs in real-time):
   ```sh
   task run
   ```
   
   For background (detached mode):
   ```sh
   task rund
   ```
   
   The background mode works with Docker-out-of-Docker, allowing you to exit the dev container without stopping the running application.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Build System

The project uses a task-based build system:

* **[Taskfile.yml](Taskfile.yml)**: Primary build orchestration using [task](https://taskfile.dev/). Key tasks:
  - `task build`: Build Docker container image
  - `task run`: Run container in foreground with full output
  - `task rund`: Run container detached in background
  - `task configure`: Generate runtime `.env` file from 1Password secrets
  - `task java`: Build Java artifacts (requires Java 21+, Maven, and `javac`)
  - `task python`: Initialize Python virtual environment with [uv][uv-url]
  - `task datadir`: Create and configure shared data directory

* **[Makefile](Makefile)**: Development container setup
  - `make` (or `make dev`): Build and enter development container
  - `make check`: Verify required tools are installed

* **[Dockerfile](Dockerfile)**: Multi-stage Docker build
  - **Builder stage**: Compiles Java artifacts using Maven and Amazon Corretto 25
  - **Runtime stage**: Ubuntu-based with Java, Python 3.12+, Rust, supervisor, cron, and syslog support
  - User `app` (UID 999) runs the application with appropriate permissions

* **.devcontainer**: VS Code dev container configuration with Docker-out-of-Docker, Python, Java, and Rust support

* **GitHub Actions** ([.github/workflows/main.yml](.github/workflows/main.yml)): Automated multi-architecture builds
  - Builds for `linux/amd64` and `linux/arm64`
  - Pushes to Docker Hub (`docker.io/tailucas/base-app`) and GitHub Container Registry (`ghcr.io/tailucas/base-app`)
  - Triggered on push to main branch or manual dispatch

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- USAGE EXAMPLES -->
## Usage

I have [various projects][tailucas-url] that extend this Docker application. This [Base Project](https://github.com/tailucas/base-app) serves as my [Docker base image](https://hub.docker.com/repository/docker/tailucas/base-app/tags?page=1&ordering=last_updated) from which other projects are derived. While I may briefly run it locally in order to get basic functions, it it usually built, tagged and pushed to Docker so that the other applications can extend the functionality as needed.

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- LICENSE -->
## License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>


<!-- ACKNOWLEDGMENTS -->
## Acknowledgments

* [Template on which this README is based](https://github.com/othneildrew/Best-README-Template)
* [All the Shields](https://github.com/progfay/shields-with-icon)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/tailucas/base-app.svg?style=for-the-badge
[contributors-url]: https://github.com/tailucas/base-app/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/tailucas/base-app.svg?style=for-the-badge
[forks-url]: https://github.com/tailucas/base-app/network/members
[stars-shield]: https://img.shields.io/github/stars/tailucas/base-app.svg?style=for-the-badge
[stars-url]: https://github.com/tailucas/base-app/stargazers
[issues-shield]: https://img.shields.io/github/issues/tailucas/base-app.svg?style=for-the-badge
[issues-url]: https://github.com/tailucas/base-app/issues
[license-shield]: https://img.shields.io/github/license/tailucas/base-app.svg?style=for-the-badge
[license-url]: https://github.com/tailucas/base-app/blob/master/LICENSE

[baseapp-url]: https://github.com/tailucas/base-app
[pylib-url]: https://github.com/tailucas/pylib
[tailucas-url]: https://github.com/tailucas

[1p-url]: https://developer.1password.com/docs/connect/
[1p-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=1Password&color=0094F5&logo=1Password&logoColor=FFFFFF&label=
[aws-url]: https://aws.amazon.com/
[aws-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=Amazon+AWS&color=232F3E&logo=Amazon+AWS&logoColor=FFFFFF&label=
[botoflow-url]: https://github.com/boto/botoflow
[cronitor-url]: https://cronitor.io/
[healthchecks-url]: https://healthchecks.io/
[msgpack-url]: https://msgpack.org/
[uv-url]: https://docs.astral.sh/uv/
[uv-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=uv&color=60A5FA&logo=uv&logoColor=FFFFFF&label=
[python-url]: https://www.python.org/
[python-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=Python&color=3776AB&logo=Python&logoColor=FFFFFF&label=
[rabbit-url]: https://www.rabbitmq.com/
[rabbit-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=RabbitMQ&color=FF6600&logo=RabbitMQ&logoColor=FFFFFF&label=
[sentry-url]: https://sentry.io/
[sentry-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=Sentry&color=362D59&logo=Sentry&logoColor=FFFFFF&label=
[zmq-url]: https://zeromq.org/
[zmq-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=ZeroMQ&color=DF0000&logo=ZeroMQ&logoColor=FFFFFF&label=
