---
title: "Deploying IHP on a NixOS Server"
summary: A step by step guide on deploying a production Haskell application on a budget!
date: 2021-01-27T04:00:29-05:00
keywords: haskell nixos deploy ihp cloud server zac
---

I recently finished up the new API written in Haskell/IHP for my iOS app, [Attics](https://attics.io).
Before I shipped the app update, however, I needed to deploy this new API so that it's
available to all my users as they download the new app version. Since my app is free and doesn't generate any revenue,
I wanted to make sure my deployment was done in a cheap manner, but still stable enough to handle the app's 10k+ users.

### Alternative to this article: IHP Cloud

The developers of IHP, [digitally induced](), run a hosting platform for IHP apps called
[IHP Cloud](https://ihpcloud.com). It feels just like Heroku did for Rails apps -- just push
your code and it's online, no need to worry about the details. If their offerings work for your use case, I would highly recommend sticking with IHP Cloud so you can focus on building a great product instead of worrying about server configuration.

Since I'm deploying a free, open source app with some specific needs that IHP Cloud doesn't offer in their free and low cost tiers, I decided to explore how to host an IHP app on my own to give me the flexibility I need at a low cost.

### Technologies

Everything done in this article will be on a `t2.micro` EC2 instance running NixOS hosted on AWS. It'll work just the same if you use another cloud provider, or any NixOS server.

### Why NixOS?

Running the server on NixOS lets you write your server configuration in a declarative way, which makes keeping track of the state of the system and all the services running on it much easier than wrangling systemd configurations by hand. That being said, the documentation for NixOS can be rough at times, and in order to get everything working I needed to do a lot of googling. In the end though, I'm really happy with the setup and have no regrets with my choice!


### Caution!

I do not claim these to be best practices for deploying IHP or software in general. This is for a small, low traffic open source hobby project.
It works well for my use case, but make sure you verify everything yourself before relying on this code for your production apps.

### Step 1: Setup IHP Project

To organize things, I create a `Nix` subfolder in my IHP project that contains two files:

```
nixos.nix
configuration.nix
```

`nixos.nix` describes the build of a NixOS system:

```nix
import <nixpkgs/nixos> {
  system = "x86_64-linux";

  configuration = {
    imports = [
      ./configuration.nix
    ];
  };
}
```

And `configuration.nix` describes the system's configuration.

```nix
{ modulesPath, config, pkgs, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
    ];
  ec2.hvm = true;

  environment.systemPackages = [ pkgs.postgresql_11 ];
  swapDevices = [ { device = "/var/swapfile"; } ];

  time.timeZone = "America/New_York";

  services.fail2ban = {
    enable = true;
  };
}
```


### Step 2: Setup PostgreSQL

Add the following to your configuration to setup a PostgreSQL database, replacing "attics" with whatever you want your application to be named:

```nix
services.postgresql = {
  enable = true;
  package = pkgs.postgresql_11;
  ensureDatabases = [ "attics" ];
  ensureUsers = [
    {
      name = "attics";
      ensurePermissions = {
        "DATABASE attics" = "ALL PRIVILEGES";
      };
    }
  ];
  enableTCPIP = true;
  authentication = ''
    host    all             all             0.0.0.0/0            md5
  '';
};
```

Again, run `nixos-rebuild switch` to rebuild your config and start PostgreSQL.

Next we must setup a password for our user and enable the UUID extension for our database. From the shell, run
```
$ sudo -u postgres psql
psql (11.9)
Type "help" for help.

postgres=#
```

to open the Postgres console. Run the command

```
ALTER ROLE <your user> WITH PASSWORD '<password>';
```

to set the password. Next, switch to your database with the command `\c <database name>`, and run the command
`create extension if not exists "uuid-ossp";` to enable the UUID type required by IHP. Done!

You'll also need to run the `Schema.sql` script from your project here to setup the database.

### Step 3: Creating the app service

Assuming you have created a Docker image following [my last post](https://zacwood.me/posts/building-ihp-apps-github-actions/),
you can easily define a systemd service for your application with the following code

```nix
  virtualisation.docker.enable = true;

  systemd.services.attics = let
    dbUrl = "postgresql://<user>:<password>@<domain>:5432/<database name>";
  in {
    description = "Short description";

    enable = true;
    after = [ "network.target" "postgresql.service" "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      User = "root";
      ExecStartPre = [
        '' ${pkgs.bash}/bin/bash -c "${pkgs.docker}/bin/docker stop <your image> || true" ''
        '' ${pkgs.bash}/bin/bash -c "${pkgs.docker}/bin/docker rm <your image> || true" ''
        '' ${pkgs.docker}/bin/docker pull <your image>:latest ''
      ];
      ExecStart = ''
        ${pkgs.docker}/bin/docker run \
          --name attics \
          -p "8000:8000" \
          -e "DATABASE_URL=${dbUrl}" \
          -e "ATTICS_ENVIRONMENT=production" \
          <your image>:latest
      '';
    };
  };
```

A couple notes: before the app is started, we use the `bash` command to run a script that tries to stop and remove the container currently running. This will also pull the latest image to ensure the app is running the latest version. To reduce app downtime when updating, it might be worth doing this step before running.

To update your service, simply run `systemctl restart <service name>` and it'll pull the latest image and restart the app.

We need to use bash since `ExecPreStart` requires only one command -- this is a small hack to get around that. We also pull the image to make sure we're up to date.

### Step 4: Configuring Nginx

In order to grant access to the outside world to the application running on port 8000, we can setup a simple Nginx reverse proxy.
This step is easy: simply add the following to your configuration to enable an Nginx server with SSL enabled through LetsEncrypt.

```nix
services.nginx = {
  enable = true;
  virtualHosts."your domain" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:8000";
      };
    };
};
```

We also need to configure the firewall and accept the LetsEncrpyt terms before rebuilding:

```nix
networking = {
  hostName = "your app name";
  firewall = {
    enable = true;
    allowedTCPPorts = [ 80 443 22 5432 ];
  };
};

security.acme.email = "your email";
security.acme.acceptTerms = true;
```

### Logs

You can view all output of your application with `journald`, the built in logging solution for `systemd`.

```
journalctl -u <service name>
```

See `man journalctl` for other helpful options~

### Optional: Setting up Cron to run scripts

It's easy to configure cron with NixOS: just add a `services.cron`  block to your configuration like below.

```nix
  services.cron = let
    dbUrl = "<same url as above>";
    runScript = name: ''
        ${pkgs.docker}/bin/docker run \
          --rm \
          -e "DATABASE_URL=${dbUrl}" \
          -e "ATTICS_ENVIRONMENT=production" \
          <your image>:latest \
          bin/Script/${name}
    '';
  in {
    enable = true;
    systemCronJobs = [
      ''0 5 * * *  root  ${runScript "<your script name>"}''
    ];
  };

```

## Conclusion

After some initial trial and error learning Nix and trying to get things to run, I ended up with a simple setup that I'm happy with for my app. Again, this is by no means perfect and likely would not be appropriate for business critical infrastructure. Luckily that's not what my project is :)

I hope this helped give you an overview on how software can be deployed with NixOS. As long as you constantly have a browser tab open to the [NixOS options search page](https://search.nixos.org/options?), things will go pretty smoothly and you'll have a nice declarative configuration! Happy hacking!
