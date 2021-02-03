---
title: "Building IHP Apps with GitHub Actions"
date: 2021-01-20T09:29:41-05:00
keywords: nix ihp haskell github actions build production server yaml ghc
---

When installing software with Nix, if the target isn't available in a binary cache somewhere, the software will be built on your machine from source.
This is fine for a development machine, but when deploying software on a remote server this can be tricky depending on the resources available. Building Haskell programs is a long, resource intensive process,
so on a `t2.micro` EC2 instance it's pretty much a lost cause.

Luckily, with GitHub Actions we can use Docker and Nix to build our IHP app and ship a small image containing only what is necessary to run the app.
This took a lot of trial and error to get working, so hopefully this can help you save time and get your application up and running!

## Building a Nix derivation

I wasn't able to use `nix-build` to build a derivation of my project with the Nix files included with IHP, so to get this working I copied the structure of the Nix files included in the project
and changed what was needed to get a build to work. I split up the code into two files, `default.nix` which is used as the entry point for `nix-build`, and
`build.nix` which actually creates the derivation for the project.

These files assume your IHP project lives in a folder named `./web`.

```nix
# default.nix
{ ... }:

let
  ihp = builtins.fetchGit {
      url = "https://github.com/digitallyinduced/haskellframework.git";
      ref = "refs/tags/v0.8.0";
  };
in
  import ./build.nix {
    ihp = ihp;
    haskellDeps = p: with p; [
        cabal-install
        base
        wai
        text
        hlint
        p.ihp
    ];
    otherDeps = p: with p; [
        # Native dependencies, e.g. imagemagick
    ];
    projectPath = ./web;
  }
```

There's a lot going on in the build file, but don't fear: this is mainly copied from the IHP project to get all the dependencies needed, and then uses the build and install phases in `mkDerivation` to build binaries and copy them to the output.

```nix
# build.nix
{ compiler ? "ghc8103"
, ihp
, haskellDeps ? (p: [])
, otherDeps ? (p: [])
, projectPath ? ./.
}:

let
    pkgs = import "${toString projectPath}/Config/nix/nixpkgs-config.nix" { ihp = ihp; };
    ghc = pkgs.haskell.packages.${compiler};
    allHaskellPackages = ghc.ghcWithPackages
      (p: builtins.concatLists [ [p.haskell-language-server] (haskellDeps p) ] );
    allNativePackages = builtins.concatLists [
      (otherDeps pkgs)
      [pkgs.postgresql]
    ];
in
    pkgs.stdenv.mkDerivation {
        name = "attics";
        buildPhase = ''
          make -f ${ihp}/lib/IHP/Makefile.dist -B build/bin/RunOptimizedProdServer
          make -f ${ihp}/lib/IHP/Makefile.dist -B build/bin/Script/<your script name>
        '';
        installPhase = ''
          mkdir -p $out
          cp -r build/bin $out/bin

          mkdir -p $out/static
          cp -r ./static $out

          mkdir -p $out/Config
          cp -r ./Config $out
        '';
        dontFixup = true;
        src = (import <nixpkgs> {}).nix-gitignore.gitignoreSource [] projectPath;
        buildInputs = builtins.concatLists [[allHaskellPackages] allNativePackages];
        shellHook = "eval $(egrep ^export ${allHaskellPackages}/bin/ghc)";
    }
```

## Dockerfile

Our Dockerfile uses a NixOS image to build the project using the Nix files we defined above. To start out:

```dockerfile
FROM nixos/nix AS builder

# update packages
RUN nix-channel --update nixpkgs

# speed up compile time by using digitallyinduced's cachix cache
RUN nix-env -i cachix
RUN cachix use digitallyinduced

RUN mkdir -p /app/web

# since IHP won't be linked on our system, clone a local copy
RUN nix-env -i git
RUN git clone https://github.com/digitallyinduced/ihp.git /app/web/IHP

ADD web /app/web
WORKDIR /app

ADD build.nix .
ADD default.nix .

RUN nix-build
```

So far, this Dockerfile will build our project and create a symlink pointing to its place in the Nix store in the `./result` directory. At this point, the image is pretty huge: about 10GB! This is mainly build dependencies like GHC. When shipping to production, we don't want to keep these around. This is where the beauty of Nix comes in: we can use the `nix-store` command to get only the runtime dependencies for our derivation, and copy them over to a fresh image using Docker multi-stage builds.

Continuting on in the same Dockerfile...

```dockerfile
# Store all runtime dependencies in a folder
RUN mkdir /tmp/nix-store-closure
RUN cp -R $(nix-store -qR result/) /tmp/nix-store-closure

# Start a new image
FROM scratch

# Copy over runtime dependencies, application code, and library
COPY --from=builder /tmp/nix-store-closure /nix/store
COPY --from=builder /app/result /app
COPY --from=builder /app/web/IHP /app/IHP

# certs for HTTPS requests
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

WORKDIR /app

CMD ["bin/RunProdServer"]
```

After building this Dockerfile, the result will be an image containing a `bin` folder, `Config` folder, `static` folder, and `IHP` folder, which is is all that is needed to run an IHP app. Use the `DATABASE_URL` environment variable to point to your PostgreSQL database, start the image, and your IHP app will be up and running.

```sh
docker run -p "8000:8000" -e "DATABASE_URL=..." <your image name>
```

Also, easily run any of the scripts you defined in the Nix build:

```sh
docker run -p "8000:8000" -e "DATABASE_URL=..." <your image name> bin/Script/<script name>
```

Next week, I'll write about the complete setup on a NixOS server using all of the above -- stay tuned :)

## Building and publishing with GitHub actions

Today we'll use Docker Hub to host our image, but you can use any container service you prefer. Refer to the GitHub Actions documentaion to find out how to authenticate with your service of choice, and then everything else should work the same.

Assuming you have Docker Hub repo for your project, and a Personal Access Token stored in your GitHub secrets, we can create a file `.github/workflows/publish-docker-image.yml` with the following contents:

```yaml
name: Publish Docker image
on:
  push:
    branches: master

jobs:
  build-and-publish:
    runs-on: ubuntu-latest
    steps:
      -
        name: Checkout
        uses: actions/checkout@v2
      -
        name: Set up QEMU
        uses: docker/setup-qemu-action@v1
      -
        name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1
      -
        name: Login to DockerHub
        uses: docker/login-action@v1
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_PAT }}
      -
        name: Build and push
        uses: docker/build-push-action@v2
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: <username>/<repo>:latest
```

After pushing this file to your GitHub repository, an action will be triggered which will build your application and deploy it to Docker Hub. Super easy, and best of all free!

## That's it!

Now you have a Docker image which contains a built IHP application. This can be deployed in any way you deploy Docker images. To keep costs low, I deployed my project on an AWS EC2 instance running NixOS along with a PostgreSQL database. Come back next Wednesday for a guide on getting that working, and as always please leave a comment with any questions or suggestions.

I'd also like to give huge thanks to Marco for his excellent post about using multi-stage builds and Nix over at [his blog](https://marcopolo.io/code/nix-and-small-containers/). I never would have been able to figure this out without that post!