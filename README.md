<a name="readme-top"></a>

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

## About The Project

This Docker application was created by factoring out many reusable code artifacts from my [various projects][tailucas-url] over a number of years. Since this work was not a part of a group effort, the test coverage is predictably abysmal :raised_eyebrow: and Python documentation notably absent :expressionless:. This package takes a submodule dependency on another one of my [common packages][pylib-url]. While this application is almost entirely boilerplate, it can run as a stand-alone application and serves the basis for any well-behaved Python application. The design is opinionated with the use of [ZeroMQ][zmq-url] but this is not a strict requirement. This project has a required dependency on [1Password][1p-url] for both build and run time (explained later). If this is unacceptable, you'll need to fork this project or send a pull request for a substitute like Bitwarden or equivalent.

Enough talk! What do I get?

* An Alpine Docker application that is specifically designed to act as a Docker base image for derived applications, or can be forked to run as is. This includes a variety of boilerplate entrypoint scripts that can be trivially overridden.
* Powerful threading and inter-thread data handling functions with significant resilience to unchecked thread death.
* Sample [Healthchecks][healthchecks-url] cron job with built-in container setup (you'd think that this would be simple and well documented).
* Pre-configured process control using [supervisor](http://supervisord.org/).
* Automatic syslog configuration to log to the Docker host rsyslog.
* Support for AWS-CLI if appropriate AWS environment variables are present, like `AWS_DEFAULT_REGION`.
* Python dependency management using [Poetry][poetry-url].

Here is a breakdown of some of the sample application features and structure:

* [app.__init__.py](https://github.com/tailucas/base-app/blob/master/app/__init__.py): Sets a global for `APP_NAME` and `WORK_DIR` which currently assumes the location `/opt/app`.
* [app.__main__.py](https://github.com/tailucas/base-app/blob/master/app/__main__.py): The naming of this entrypoint is intentional so that derived application containers can easily override this and existing application bootstrapping logic just works<sup>TM</sup>. After basic imports, a 1Password connect SDK [CredsConfig](https://github.com/tailucas/base-app/blob/723bbef3a4f5380d722dae52bcb52537b4e44bc1/app/__main__.py#L12) struct is instantiated which tells [pylib][pylib-url] which credentials to pull from the 1Password connect server. Next, a variety of pylib imports are done to bring the needed functionality into the application. A [ZeroMQ][zmq-url] URL is defined called `URL_WORKER_APP` for inter-thread communication using their "lockless programming" paradigm. [DataReader](https://github.com/tailucas/base-app/blob/723bbef3a4f5380d722dae52bcb52537b4e44bc1/app/__main__.py#LL41C7-L41C17) demonstrates the use of the `AppThread` and `Closeable` functions which abstract away thread instantiation, thread death tracking and bring the context manager to gracefully handle errors and shutdown. A tenet of ZeroMQ is to not share sockets between threads and is managed for you with this implementation. A few lines of code bring a lot of powerful resilience features. `DataReader` pretends to fetch some useful data and then uses its ZeroMQ `PUSH` socket to forward any to whatever has a sink URL to `URL_WORKER_APP`. [EventProcessor](https://github.com/tailucas/base-app/blob/723bbef3a4f5380d722dae52bcb52537b4e44bc1/app/__main__.py#LL64C7-L64C21) illustrates the consumer which is analogous to the main application loop. The [main](https://github.com/tailucas/base-app/blob/723bbef3a4f5380d722dae52bcb52537b4e44bc1/app/__main__.py#L78) entrypoint instantiates these classes, echoes some environment variable keys to the log that are visible to the application which is useful for debugging environment bootstrap. All threads wait on a Python `threading.Event` object for quick shutdown should the signal arrive. When set, the main application and all non-daemon threads have a chance to complete, aided by a [helper](https://github.com/tailucas/base-app/blob/723bbef3a4f5380d722dae52bcb52537b4e44bc1/app/__main__.py#L110). Another helper routine [zmq_term](https://github.com/tailucas/base-app/blob/723bbef3a4f5380d722dae52bcb52537b4e44bc1/app/__main__.py#L109) helps with getting ZeroMQ shutdown done. By design *ALL* ZeroMQ sockets must be closed gracefully in order for the application to exit. Any non-trivial applications need active management of sockets to avoid spending hours working out why the application shutdown is blocked. This is one of a few powerful features of this application and package.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

Technologies that help make this package useful:

[![1Password][1p-shield]][1p-url]
[![Amazon AWS][aws-shield]][aws-url]
[![Poetry][poetry-shield]][poetry-url]
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

Beyond the Python dependencies defined in the [Poetry configuration](pyproject.toml), the package init carries hardcoded dependencies on [Sentry][sentry-url] and [1Password][1p-url] in order to function. Unless you want these and are effectively extending my [base project][baseapp-url], you're likely better off forking this package and cutting out what you do not need.

### Installation

0. :stop_sign: This project uses [1Password Secrets Automation][1p-url] to store both application key-value pairs as well as runtime secrets. It is assumed that the connect server containers are already running on your environment. If you do not want to use this, then you'll need to fork this package and make the changes as appropriate. It's actually very easy to set up, but note that 1Password is a paid product with a free-tier for secrets automation. Here is an example of how this looks for my application and the generation of the docker-compose.yml relies on this step. Your secrets automation vault must contain an entry called `ENV.base_app` with these keys:

* `DEVICE_NAME`: For naming the container. This project uses `base-app`.
* `APP_NAME`: Used for referencing the application's actual name for the logger. This project uses `base_app`.
* `OP_CONNECT_SERVER`, `OP_CONNECT_TOKEN`, `OP_CONNECT_VAULT`: Used to specify the URL of the 1Password connect server with associated client token and Vault ID. See [1Password](https://developer.1password.com/docs/connect/get-started#step-1-set-up-a-secrets-automation-workflow) for more.
* `HC_PING_URL`: [Healthchecks][healthchecks-url] URL of this application's current health check status.

With these configured, you are now able to build the application.

In addition to this, [additional runtime configuration](https://github.com/tailucas/base-app/blob/d4e5b0bcaabfb5f29094a1c977d1027e38549bad/app/__main__.py#L12-L14) is used by the application, and also need to be contained within the secrets vault. With these configured, you are now able to run the application.

1. Clone the repo
   ```sh
   git clone https://github.com/tailucas/base-app.git
   ```
2. Verify that the git submodule is present.
   ```sh
   git submodule init
   git submodule update
   ```
4. Make the Docker runtime user and set directory permissions. :hand: Be sure to first review the Makefile contents for assumptions around user IDs for Docker.
   ```sh
   make user
   ```
5. Now generate the docker-compose.yml:
   ```sh
   make setup
   ```
6. And generate the Docker image:
   ```sh
   make build
   ```
7. If successful and the local environment is running the 1Password connect containers, run the application. For foreground:
   ```sh
   make run
   ```
   For background:
   ```sh
   make rund
   ```

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
[license-url]: https://github.com/tailucas/base-app/blob/master/LICENSE.txt

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
[poetry-url]: https://python-poetry.org/
[poetry-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=Poetry&color=60A5FA&logo=Poetry&logoColor=FFFFFF&label=
[python-url]: https://www.python.org/
[python-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=Python&color=3776AB&logo=Python&logoColor=FFFFFF&label=
[rabbit-url]: https://www.rabbitmq.com/
[rabbit-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=RabbitMQ&color=FF6600&logo=RabbitMQ&logoColor=FFFFFF&label=
[sentry-url]: https://sentry.io/
[sentry-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=Sentry&color=362D59&logo=Sentry&logoColor=FFFFFF&label=
[zmq-url]: https://zeromq.org/
[zmq-shield]: https://img.shields.io/static/v1?style=for-the-badge&message=ZeroMQ&color=DF0000&logo=ZeroMQ&logoColor=FFFFFF&label=
