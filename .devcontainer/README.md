# Dev Container for AccessSystem

## What Is a Devcontainer?

A _devcontainer_ defines a reproducible development environment using Docker and Visual Studio Dev Containers extension. It lets contributors open this repository inside a container that has the toolchain, dependencies, and configuration preinstalled so everyone develops in the same environment.

## This Folder

The files in this folder configure the development container used by VS Code. Key files include:
- `Dockerfile` — builds the container image used for the workspace.
- `devcontainer.json` — VS Code settings for launching the container, exposed ports, mounts, and forwarded commands.

## Intended Usage

Use the devcontainer to develop, run tests, and iterate on the application locally. In VS Code, open the repository, then use "Remote-Containers: Reopen in Container" (or the Dev Containers command palette) to start the environment. The editor will build the image (if needed), create a container, and attach the workspace.

To speed up project starts, we prebuild the `base` stage of the Dockerfile and host it as `ghcr.io/swindonmakers/access-system-dev` which is used as the local devcontainer.

## Rebuild and Start

To rebuild the image from the Dockerfile and reopen the container in VS Code, choose "Rebuild Container" in the Dev Containers menu. From the command line you can build the image manually and run it for debugging or inspection:

- Build image (named `access-system-dev`) from the project's root folder:
    ```
    docker build -f .devcontainer/Dockerfile -t access-system-dev .
    ```

- Run an interactive shell in the container:
    ```
    docker run --rm -it -v "$PWD":/workspace -w /workspace access-system-dev /bin/bash
    ```

Adjust the commands above to match your shell and local workflow.

## Local-Only Image Warning

The Docker image built from the files in this folder is intended strictly for local development and reproducible contributor environments. It is not hardened, audited, or configured for production use. Do not deploy this image to production or public registries without reviewing and adjusting:
- user permissions and non-root users
- secrets and environment variables
- exposed ports and network configuration
- installed debugging and build tools that should not be in production images

## Customizing

You can customize `devcontainer.json` and the `Dockerfile` to add editors, debuggers, language servers, or extra packages. When you change the Dockerfile, rebuild the container from VS Code so changes are applied.

## Troubleshooting

If build fails, check the build log in VS Code's Dev Containers output panel. Common fixes:
- Ensure Docker is running and you have permission to use the Docker daemon.
- Increase Docker resources (CPU / memory) if builds fail during compilation.
- Remove old images/containers that may conflict: `docker system prune --all --volumes` (careful: this removes images and volumes).

## Further reading

VS Code Dev Containers: https://code.visualstudio.com/docs/devcontainers/containers
