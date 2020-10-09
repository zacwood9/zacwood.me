---
layout: post
title: "So you want to contribute to SRCT?"
summary: "An in depth, zero-to-hero guide on making your first contributions to open source"
date: 2019-06-12T11:30:03+00:00
---

Hey there, future SRCT contributor! Student Run Computing and Tech
(SRCT) is a student organization at GMU that builds open source
software for the Mason community while providing a great opportunity
for students from all backgrounds to gain valuable, real world,
technical experience. The tools we use to build our software is widely
used throughout industry, and plus, it's fun!

This post will serve as an in depth introduction to contributing to
SRCT projects and open-source projects more generally.

<!--description-->

### What does SRCT do?

We build open source software. What's that? At the most basic level,
an open source project has all of its source code freely available
online, and anyone can contribute or make changes to that source code
to enhance the project. This is really important for us -- it means
that anyone: Mason students, professors, whoever, can use their
talents to improve our projects and make life for Mason students a
little bit better.

### But I'm not a CS major! (or, I'm just a freshman!)

It's okay! The most impactful contributors we've ever had haven't been
CS majors. Hardly anyone comes into SRCT knowing anything about
contributing to open source. Luckily, we're here to teach you and
we're more than happy to help you anywhere along the way and answer
any of your questions!

## Getting Started

### Slack!

We use Slack for all communications in our org. It's a great place to
get involved with projects and socialize, so it's necessary if you
want to become involved with SRCT. There's always members online happy
to help with any issues you will inevitably run across

To sign up, go to <https://srct.slack.com/signup> and make an account
with your GMU email. Download the app on your computer and phone too!
It's much better experience and makes it easier to keep up.


### Registering on GitLab

All of our projects can be found on our GitLab page, found at
<https://git.gmu.edu>. Go there and sign up using your GMU login by
clicking on the "GMU Login" button in the bottom right corner. Once
you're in, you can see all the SRCT *repositories* (or projects) [on
our organization's page.](https://git.gmu.edu/srct?sort=stars_desc)

In this article, we'll be contributing to the
[srctweb](https://git.gmu.edu/srct/srctweb) project, which is our
website. It's live at [srct.gmu.edu](https://srct.gmu.edu) if you want
to take a look!

### Getting the code on our system

Before we can start to make changes to the code, we first need to get
it on our machine. To do this we'll need to install `git`, which is
the most important tool we work with.

What is `git`? Git is a *version control system*, which, according to
the [GitHub
handbook](https://guides.github.com/introduction/git-handbook/),
"tracks the history of changes as people and teams collaborate on
projects together". Git is also *distributed*, which means that the
copy of the project you have on your machine is yours alone. No matter
how bad it gets screwed up, it will never affect the central copy
called the *origin*. In our case, the origin is the copy stored on
GitLab.

To install `git`, refer to the [installation instructions on the
srctweb
README](https://git.gmu.edu/srct/srctweb#1-install-git-on-your-system).

Once you have it installed, open up your terminal. This is where we'll
be doing most of our work today. Let's make a folder, or *directory*,
to keep SRCT projects in.

```bash
$ mkdir SRCT
```

Now navigate to the directory using the `cd` (change directory) command.

```bash
$ cd SRCT
```

To get the srctweb project on our system, we need to *clone* it, or
essentially download a copy from GitLab. The link can be found by
clicking on the "Clone" button on the [srctweb GitLab
page](https://git.gmu.edu/srct/srctweb).

```bash
$ git clone https://git.gmu.edu/srct/srctweb.git
```

This will clone the project into the `srctweb` directory. Navigate to
that directory with `cd`.

```bash
$ cd srctweb
```

Let's make sure it worked. List the directory contents with the `ls`
command -- it should be the same as on GitLab.

### Running the project

To run the project on your machine, we recommend using
*Docker*. Docker is a tool for running *containers*, or mini virtual
machines (like mini computers) on your computer. This is useful since
we can just tell docker what to install and what commands to run
instead of doing it all manually.

To install Docker, refer again to the instructions in the [srctweb
README](https://git.gmu.edu/srct/srctweb#docker). Now, run

```bash
$ docker-compose up
```

which should start the website and make it accessible at
<http://localhost:4000>.

**WAIT, SOMETHING BROKE**.

I told you this would happen! Ask in the #srctweb channel on Slack.

### Editing

Now that the project is up and running on our machine, we need a tool
called a *text editor* to edit them. There are [no shortage of
opinions](https://en.wikipedia.org/wiki/Editor_war) on what text
editor you should use, but a great option is [VS
Code](https://code.visualstudio.com/). Go ahead and download it at
that link.

## What we'll be changing

Since writing this, we've had quite a few members graduate! However,
out [list of members](https://srct.gmu.edu/people/) hasn't been
updated to reflect that. Actually, it hasn't even been updated with
the new exec board! Man, just [so much to
do...](https://git.gmu.edu/srct/srctweb/issues)

### One last thing...

Before we go graduating people all willy nilly, we need to create a
*branch* for our work. This is essentially a copy of the project that
will contain only the changes for this specific issue we're working
on. When we're done, the changes can be reviewed in isolation, and
then *merged* into the main branch of the project without the clutter
of all the other changes that others have been making at the same
time.

Head back to our old friend the terminal. To create a branch, use the
`git branch` command.

```bash
$ git branch update-alums
```

Now, we switch over to that branch using `checkout`:

```bash
$ git checkout update-alums
```

Now we're ready to work!

## Getting to work

With your VS Code open, open the `~/SRCT/srctweb` directory. Inside
the next `srctweb` directory is the actual meat of the site. It's not
important to understand what everything is and how it works -- that'll
come in time. For now, learning the process is much more important. If
you're curious though, ask in Slack!

We have a list of all the members in
`srctweb/_data/people.json`. JSON, or *JavaScript Object Notation*, is
a simple way to describe data. This file contains a list (notated by
the surrounding square brackets, `[]`) of *objects* (curly braces, `{}`),
each of which contain info on a member of SRCT.

Since I don't want to do all your work for you, I'll just graduate our
beloved two term president, David Haynes. Change the `alum` field to
be true, and set the exec status to be false. Delete the other lines
in the exec object too.

```json
{
  "name": "David Haynes",
  "email": "dhaynes3@gmu.edu",
  "alum": true,
  "exec": {
    "status": false
  }
},
```

### It worked!

To verify the change was made, go to <http://localhost:4000/people>
and make sure David is an alum.

Now let's make sure git saw the change. In your terminal run

```bash
$ git status
```

You should see the following output:

```
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

	modified:   srctweb/_data/people.json
```

### Serious commitment

Now it's time to save these changes. We do this by making a *commit*
in git, which is a snapshot of the project at a given time on a given
branch. However, git doesn't automatically add your changes to the
commit -- as the `git status` message explained, you must add them
using the `git add` command.

```bash
$ git add srctweb/_data/people.json
```

Now we can make the commit with the `git commit` command. Along with
every commit comes a short message explaining the change.

```bash
$ git commit -m "rip dhaynes"
```

### Push it up!

Now it's time to push your changes to GitLab! To do this, we first
push the branch with your new commit attached to it. Git is stupid and
doesn't know where to push to by default so you need to give it a few
more instructions.

```bash
$ git push --set-upstream origin update-alum
```

**NOTE:** You'll probably get an error doing this for the first
time. You need to be given permission first, so poke into the #srctweb
or #help channels and ask for help.


### Merge it in

To integrate your changes into the main project, you need to make a
*merge request*, or MR. Your MR will then be reviewed by the project
manager to make sure there's no funny business going on and to give
you tips on your code, and will then merge your branch into the
*master* branch.

On the [srctweb GitLab page](https://git.gmu.edu/srct/srctweb), go the
the "Merge Requests" tab and hit "New Merge Request". Select your
branch as the source branch, and hit "Continue". Give your MR an
appropriate title and summary and submit your request.

## You did it!

Hurray! Your MR has been approved and you have successfully removed
dhaynes from his tyrannical throne.

What you just did is by far the biggest hurdle for new members, and
it's easy to see why -- it's a lot of information. Come back to this
article if you ever need reminders, that's what it's here for. Most
importantly, don't be afraid to ask for help in Slack.

### Where to go from here

Come to meetings and say hi. If you can't do that, say hi in
Slack. Browse through our projects and see what interests you. Talk to
the project manager and they will guide you forward.
